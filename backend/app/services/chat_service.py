"""
Serviço de Chatbot — Camada de Negócio.

Responsabilidades:
- Processar mensagens do aluno via pipeline RAG
- Gerenciar ciclo de vida de conversas (criar, reabrir, fechar, escalar)
- Armazenar ChatMessage com rastreamento completo
- Aplicar rate limiting (RN-16: 30 msg/hora por usuário)
- Sanitizar input do usuário (RN-18)
- Gerenciar feedback de mensagens
"""

from __future__ import annotations

import logging
import re
import time
from datetime import datetime, timedelta
from typing import Any
from uuid import UUID, uuid4

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.ai.rag_chain import RAGResult, rag_chain
from app.config.settings import settings
from app.models.chatbot import (
    ChatConversation,
    ChatFeedback,
    ChatMessage,
    KnowledgeBase,
)
from app.models.user import User

logger = logging.getLogger(__name__)

# Aliases para constantes centralizadas em settings
RATE_LIMIT_MESSAGES = settings.CHAT_RATE_LIMIT_MESSAGES
RATE_LIMIT_WINDOW_HOURS = settings.CHAT_RATE_LIMIT_WINDOW_HOURS
MAX_MESSAGE_LENGTH = settings.CHAT_MAX_MESSAGE_LENGTH
INACTIVITY_CLOSE_HOURS = settings.CHAT_INACTIVITY_CLOSE_HOURS


# ── Exceções de Domínio ───────────────────────────────────────────────────────

class ConversationNotFoundError(Exception):
    """Conversa não encontrada."""


class RateLimitExceededError(Exception):
    """Limite de mensagens excedido (RN-16)."""


class MessageTooLongError(Exception):
    """Mensagem excede 500 caracteres (RN segurança)."""


class UnauthorizedConversationError(Exception):
    """Usuário não tem acesso à conversa."""


# ── Serviço Principal ─────────────────────────────────────────────────────────

class ChatService:
    """Serviço de negócio para o Chatbot de Dúvidas."""

    def __init__(self, session: AsyncSession) -> None:
        """
        Inicializar ChatService.

        Args:
            session: Sessão assíncrona do banco de dados para operações CRUD.

        Side effects:
            - Armazena referência à sessão do banco
            - Preparado para executar operações de chat (send_message, escalação, feedback)
        """
        self.session = session

    # ── Sanitização de Input ──────────────────────────────────────────────

    @staticmethod
    def sanitize_input(text: str) -> str:
        """
        Sanitizar mensagem do usuário (RN-18).

        - Remove tags HTML/script
        - Bloqueia padrões de SQL injection
        - Limita a MAX_MESSAGE_LENGTH caracteres
        """
        # Remover tags script e seu conteúdo
        text = re.sub(r"<script.*?>.*?</script>", "", text, flags=re.IGNORECASE | re.DOTALL)
        # Remover tags HTML residuais
        text = re.sub(r"<[^>]+>", "", text)
        # Remover padrões SQL injection básicos
        sql_patterns = [
            r"(--|;|/\*|\*/|xp_|EXEC\s|UNION\s|SELECT\s|INSERT\s|DROP\s|ALTER\s|TABLE\s)",
        ]
        for pattern in sql_patterns:
            text = re.sub(pattern, "", text, flags=re.IGNORECASE)
        # Normalizar espaços
        text = " ".join(text.split())
        return text[:MAX_MESSAGE_LENGTH]

    # ── Rate Limiting ─────────────────────────────────────────────────────

    async def _check_rate_limit(self, user_id: UUID) -> None:
        """
        Verificar rate limit do usuário (RN-16: 30 msg/hora).

        Raises:
            RateLimitExceededError se limite excedido.
        """
        window_start = datetime.utcnow() - timedelta(hours=RATE_LIMIT_WINDOW_HOURS)
        stmt = (
            select(func.count(ChatMessage.id))
            .join(ChatConversation, ChatMessage.conversation_id == ChatConversation.id)
            .where(
                ChatConversation.user_id == user_id,
                ChatMessage.role == "user",
                ChatMessage.created_at >= window_start,
            )
        )
        result = await self.session.execute(stmt)
        count = result.scalar_one_or_none() or 0

        if count >= RATE_LIMIT_MESSAGES:
            raise RateLimitExceededError(
                f"Limite de {RATE_LIMIT_MESSAGES} mensagens por hora atingido. "
                "Aguarde antes de enviar novamente."
            )

    # ── Gestão de Conversas ───────────────────────────────────────────────

    async def _get_or_create_conversation(
        self,
        user_id: UUID,
        conversation_id: UUID | None,
        academy_id: UUID | None,
    ) -> ChatConversation:
        """
        Obter conversa existente ou criar nova.

        - Se conversation_id fornecido → valida acesso e retorna
        - Se None → cria nova conversa ativa
        - RN-02: fecha conversas inativas > 24h automaticamente
        """
        if conversation_id:
            stmt = (
                select(ChatConversation)
                .options(selectinload(ChatConversation.messages))
                .where(ChatConversation.id == conversation_id)
            )
            result = await self.session.execute(stmt)
            conversation = result.scalar_one_or_none()

            if not conversation:
                raise ConversationNotFoundError(
                    f"Conversa {conversation_id} não encontrada."
                )
            if conversation.user_id != user_id:
                raise UnauthorizedConversationError(
                    "Acesso negado a esta conversa."
                )

            # RN-02: reabrir se estava fechada mas usuário está enviando
            if conversation.status == "closed":
                conversation.status = "active"
                conversation.ended_at = None
                self.session.add(conversation)

            return conversation

        # Criar nova conversa
        conversation = ChatConversation(
            user_id=user_id,
            academy_id=academy_id,
            channel="app",
            status="active",
            started_at=datetime.utcnow(),
        )
        self.session.add(conversation)
        await self.session.flush()
        return conversation

    async def _get_conversation_history(
        self, conversation: ChatConversation
    ) -> list[dict[str, str]]:
        """Obter histórico de mensagens formatado para o pipeline RAG."""
        # Para evitar lazy loading, buscar messages explicitamente do banco
        from sqlalchemy import and_
        stmt = (
            select(ChatMessage)
            .where(ChatMessage.conversation_id == conversation.id)
            .order_by(ChatMessage.created_at.desc())
            .limit(10)
        )
        result = await self.session.execute(stmt)
        messages = result.scalars().all()

        if not messages:
            return []

        # Reverter ordre para histórico cronológico
        return [
            {"role": msg.role, "content": msg.content}
            for msg in reversed(messages)
        ]

    async def _build_user_context(self, user_id: UUID) -> dict[str, Any]:
        """
        Montar contexto do aluno para o pipeline RAG.

        Busca perfil do usuário. A ficha ativa seria buscada do módulo
        de treinos quando disponível (PRD_FICHA_TREINO).
        """
        stmt = select(User).where(User.id == user_id, User.is_active == True)
        result = await self.session.execute(stmt)
        user = result.scalar_one_or_none()

        user_profile: dict[str, Any] = {}
        if user:
            user_profile = {
                "name": user.name,
                "role": user.role,
                "level": "não informado",     # Campo futuro do perfil
                "objective": "não informado", # Campo futuro do perfil
            }

        return {
            "user_profile": user_profile,
            "active_workout_sheet": None,  # Integração futura com PRD_FICHA_TREINO
        }

    # ── Enviar Mensagem (fluxo principal) ─────────────────────────────────

    async def send_message(
        self,
        user_id: UUID,
        message: str,
        conversation_id: UUID | None = None,
        academy_id: UUID | None = None,
    ) -> dict[str, Any]:
        """
        Processar mensagem do aluno e retornar resposta do chatbot.

        Fluxo:
            1. Sanitizar input
            2. Verificar rate limit
            3. Obter/criar conversa
            4. Executar pipeline RAG
            5. Persistir mensagens (user + assistant)
            6. Escalar se necessário

        Args:
            user_id: UUID do aluno autenticado.
            message: Texto da mensagem.
            conversation_id: UUID da conversa existente (None = nova).
            academy_id: UUID da academia para filtrar RAG.

        Returns:
            Dicionário com message_id, conversation_id, content, retrieved_documents, etc.

        Raises:
            RateLimitExceededError: Limite de mensagens atingido.
            MessageTooLongError: Mensagem muito longa.
        """
        # 1. Sanitizar e validar
        clean_message = self.sanitize_input(message)
        if len(message) > MAX_MESSAGE_LENGTH:
            raise MessageTooLongError(
                f"Mensagem excede {MAX_MESSAGE_LENGTH} caracteres."
            )

        # 2. Rate limit
        await self._check_rate_limit(user_id)

        # 3. Obter/criar conversa
        conversation = await self._get_or_create_conversation(
            user_id, conversation_id, academy_id
        )

        # 4. Contexto do aluno e histórico
        user_context = await self._build_user_context(user_id)
        history = await self._get_conversation_history(conversation)

        # 5. Salvar mensagem do usuário
        user_msg = ChatMessage(
            conversation_id=conversation.id,
            role="user",
            content=clean_message,
            channel="app",
        )
        self.session.add(user_msg)
        await self.session.flush()

        # 6. Pipeline RAG
        start = time.monotonic()
        rag_result: RAGResult = await rag_chain.run(
            query=clean_message,
            session=self.session,
            academy_id=str(academy_id) if academy_id else None,
            user_context=user_context,
            conversation_history=history,
        )
        latency_ms = int((time.monotonic() - start) * 1000)

        # 7. Salvar resposta do assistente
        context_data = {
            "user_profile": user_context.get("user_profile", {}),
            "active_workout_sheet": user_context.get("active_workout_sheet"),
            "retrieved_documents": [
                {
                    "id": doc.id,
                    "title": doc.title,
                    "relevance_score": doc.relevance_score,
                }
                for doc in rag_result.retrieved_documents
            ],
        }

        assistant_msg = ChatMessage(
            conversation_id=conversation.id,
            role="assistant",
            content=rag_result.answer,
            context_data=context_data,
            channel="app",
            model_used=rag_result.model_used,
            tokens_used=rag_result.tokens_used,
            latency_ms=rag_result.latency_ms or latency_ms,
            needs_human_review=rag_result.should_escalate,
        )
        self.session.add(assistant_msg)

        # 8. Escalar conversa se necessário
        if rag_result.should_escalate and conversation.status != "escalated":
            conversation.status = "escalated"
            conversation.escalation_reason = rag_result.escalation_reason
            conversation.escalated_at = datetime.utcnow()
            self.session.add(conversation)

        await self.session.commit()
        await self.session.refresh(assistant_msg)

        # 9. Montar resposta
        return {
            "message_id": str(assistant_msg.id),
            "conversation_id": str(conversation.id),
            "role": "assistant",
            "content": rag_result.answer,
            "retrieved_documents": [
                {
                    "id": doc.id,
                    "title": doc.title,
                    "relevance_score": doc.relevance_score,
                }
                for doc in rag_result.retrieved_documents
            ],
            "escalation": (
                {
                    "escalated": True,
                    "reason": rag_result.escalation_reason,
                }
                if rag_result.should_escalate
                else None
            ),
            "latency_ms": latency_ms,
            "created_at": assistant_msg.created_at.isoformat() + "Z",
        }

    # ── Listar Conversas ──────────────────────────────────────────────────

    async def list_conversations(
        self,
        user_id: UUID,
        page: int = 1,
        limit: int = 20,
    ) -> dict[str, Any]:
        """Listar conversas do aluno com paginação."""
        offset = (page - 1) * limit

        # Total
        count_stmt = select(func.count(ChatConversation.id)).where(
            ChatConversation.user_id == user_id
        )
        total = (await self.session.execute(count_stmt)).scalar_one()

        # Conversas
        stmt = (
            select(ChatConversation)
            .where(ChatConversation.user_id == user_id)
            .order_by(ChatConversation.started_at.desc())
            .offset(offset)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        conversations = result.scalars().all()

        # Contar mensagens por conversa
        items = []
        for conv in conversations:
            msg_count_stmt = select(func.count(ChatMessage.id)).where(
                ChatMessage.conversation_id == conv.id
            )
            msg_count = (await self.session.execute(msg_count_stmt)).scalar_one()
            items.append(
                {
                    "id": str(conv.id),
                    "started_at": conv.started_at.isoformat() + "Z",
                    "ended_at": (conv.ended_at.isoformat() + "Z") if conv.ended_at else None,
                    "status": conv.status,
                    "channel": conv.channel,
                    "rating": conv.rating,
                    "escalated": conv.status == "escalated",
                    "message_count": msg_count,
                }
            )

        return {"conversations": items, "total": total, "page": page}

    # ── Obter Conversa ────────────────────────────────────────────────────

    async def get_conversation(
        self, user_id: UUID, conversation_id: UUID
    ) -> dict[str, Any]:
        """Obter detalhes de uma conversa com mensagens."""
        stmt = (
            select(ChatConversation)
            .options(selectinload(ChatConversation.messages))
            .where(
                ChatConversation.id == conversation_id,
                ChatConversation.user_id == user_id,
            )
        )
        result = await self.session.execute(stmt)
        conversation = result.scalar_one_or_none()

        if not conversation:
            raise ConversationNotFoundError(f"Conversa {conversation_id} não encontrada.")

        messages = [
            {
                "id": str(msg.id),
                "role": msg.role,
                "content": msg.content,
                "retrieved_documents": (
                    (msg.context_data or {}).get("retrieved_documents", [])
                    if msg.role == "assistant"
                    else []
                ),
                "latency_ms": msg.latency_ms,
                "created_at": msg.created_at.isoformat() + "Z",
            }
            for msg in conversation.messages
        ]

        return {
            "id": str(conversation.id),
            "started_at": conversation.started_at.isoformat() + "Z",
            "ended_at": (conversation.ended_at.isoformat() + "Z") if conversation.ended_at else None,
            "status": conversation.status,
            "escalated": conversation.status == "escalated",
            "escalation_reason": conversation.escalation_reason,
            "messages": messages,
            "rating": conversation.rating,
            "feedback": conversation.feedback,
        }

    # ── Avaliar Conversa ──────────────────────────────────────────────────

    async def rate_conversation(
        self,
        user_id: UUID,
        conversation_id: UUID,
        rating: int,
        feedback: str | None = None,
    ) -> dict[str, Any]:
        """Salvar avaliação (1-5) e feedback do aluno na conversa."""
        stmt = select(ChatConversation).where(
            ChatConversation.id == conversation_id,
            ChatConversation.user_id == user_id,
        )
        result = await self.session.execute(stmt)
        conversation = result.scalar_one_or_none()

        if not conversation:
            raise ConversationNotFoundError(f"Conversa {conversation_id} não encontrada.")

        conversation.rating = max(1, min(5, rating))
        conversation.feedback = feedback
        if conversation.status == "active":
            conversation.status = "closed"
            conversation.ended_at = datetime.utcnow()

        self.session.add(conversation)
        await self.session.commit()

        return {"success": True, "message": "Feedback registrado"}

    # ── Feedback em Mensagem ──────────────────────────────────────────────

    async def add_message_feedback(
        self,
        user_id: UUID,
        message_id: UUID,
        was_helpful: bool,
        feedback_type: str = "good",
        comment: str | None = None,
    ) -> dict[str, Any]:
        """Adicionar feedback a uma mensagem específica (RN-21)."""
        # Validar acesso: a mensagem deve ser de uma conversa do usuário
        stmt = (
            select(ChatMessage)
            .join(ChatConversation, ChatMessage.conversation_id == ChatConversation.id)
            .where(
                ChatMessage.id == message_id,
                ChatConversation.user_id == user_id,
                ChatMessage.role == "assistant",
            )
        )
        result = await self.session.execute(stmt)
        message = result.scalar_one_or_none()

        if not message:
            raise ConversationNotFoundError(f"Mensagem {message_id} não encontrada.")

        feedback = ChatFeedback(
            message_id=message_id,
            user_id=user_id,
            was_helpful=was_helpful,
            feedback_type=feedback_type,
            comment=comment,
        )
        self.session.add(feedback)

        # Atualizar contadores na KnowledgeBase (RN-23)
        if message.context_data:
            retrieved = message.context_data.get("retrieved_documents", [])
            for doc_ref in retrieved:
                doc_id = doc_ref.get("id")
                if doc_id:
                    if isinstance(doc_id, str):
                        doc_id = UUID(doc_id)
                    doc_stmt = select(KnowledgeBase).where(
                        KnowledgeBase.id == doc_id
                    )
                    doc_result = await self.session.execute(doc_stmt)
                    kb_doc = doc_result.scalar_one_or_none()
                    if kb_doc:
                        kb_doc.views_count = (kb_doc.views_count or 0) + 1
                        if was_helpful:
                            kb_doc.helpful_count = (kb_doc.helpful_count or 0) + 1
                        self.session.add(kb_doc)

        await self.session.commit()
        return {"success": True, "message": "Feedback registrado"}

    # ── Admin: Conversas Escaladas ────────────────────────────────────────

    async def list_escalated_conversations(
        self, personal_id: UUID | None = None
    ) -> dict[str, Any]:
        """Listar conversas escaladas para o Personal (RN-04)."""
        stmt = (
            select(ChatConversation)
            .options(selectinload(ChatConversation.messages))
            .where(ChatConversation.status == "escalated")
            .order_by(ChatConversation.escalated_at.desc())
        )
        result = await self.session.execute(stmt)
        conversations = result.scalars().all()

        items = []
        for conv in conversations:
            # Buscar nome do aluno
            user_stmt = select(User).where(User.id == conv.user_id)
            user_result = await self.session.execute(user_stmt)
            user = user_result.scalar_one_or_none()

            # Primeira mensagem do aluno = pergunta original
            first_user_msg = next(
                (m.content for m in conv.messages if m.role == "user"), ""
            )

            items.append(
                {
                    "id": str(conv.id),
                    "student_id": str(conv.user_id),
                    "student_name": user.name if user else "Desconhecido",
                    "reason": conv.escalation_reason,
                    "original_question": first_user_msg[:200],
                    "escalated_at": (
                        conv.escalated_at.isoformat() + "Z"
                        if conv.escalated_at
                        else None
                    ),
                    "message_count": len(conv.messages),
                }
            )

        return {"escalated_conversations": items, "total": len(items)}

    # ── Admin: Knowledge Base ─────────────────────────────────────────────

    async def create_knowledge_document(
        self,
        created_by_id: UUID,
        academy_id: UUID | None,
        title: str,
        content: str,
        category: str,
        muscle_group: str | None = None,
        difficulty_level: str | None = None,
        exercise_id: UUID | None = None,
    ) -> dict[str, Any]:
        """
        Criar documento na KnowledgeBase e gerar embedding (RN-10).

        O embedding é gerado via GoogleGenerativeAIEmbeddings (768 dims).
        """
        from app.ai.rag_chain import rag_chain as rc

        # Gerar embedding do conteúdo
        embeddings_model = rc._get_embeddings()
        try:
            embedding_vector = await embeddings_model.aembed_query(
                f"{title}\n\n{content}"
            )
        except Exception as exc:
            logger.error("Erro ao gerar embedding para KB: %s", exc)
            embedding_vector = None

        doc = KnowledgeBase(
            academy_id=academy_id,
            created_by_id=created_by_id,
            title=title,
            content=content,
            category=category,
            muscle_group=muscle_group,
            difficulty_level=difficulty_level,
            exercise_id=exercise_id,
            embedding=embedding_vector,
            embedding_model="google:text-embedding-004",
            is_active=True,
        )
        self.session.add(doc)
        await self.session.commit()
        await self.session.refresh(doc)

        return {
            "id": str(doc.id),
            "title": doc.title,
            "category": doc.category,
            "embedding_generated": embedding_vector is not None,
            "created_at": doc.created_at.isoformat() + "Z",
        }

    async def list_knowledge_documents(
        self, academy_id: UUID | None = None
    ) -> dict[str, Any]:
        """Listar documentos da KnowledgeBase com métricas (RN-23)."""
        stmt = select(KnowledgeBase).where(KnowledgeBase.is_active == True)
        if academy_id:
            stmt = stmt.where(KnowledgeBase.academy_id == academy_id)
        stmt = stmt.order_by(KnowledgeBase.created_at.desc())

        result = await self.session.execute(stmt)
        docs = result.scalars().all()

        return {
            "documents": [
                {
                    "id": str(doc.id),
                    "title": doc.title,
                    "category": doc.category,
                    "muscle_group": doc.muscle_group,
                    "difficulty_level": doc.difficulty_level,
                    "views_count": doc.views_count,
                    "helpful_count": doc.helpful_count,
                    "helpfulness_rate": doc.helpfulness_rate,
                    "created_at": doc.created_at.isoformat() + "Z",
                }
                for doc in docs
            ]
        }
