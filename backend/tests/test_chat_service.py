"""
Testes de integração para o ChatService (app/services/chat_service.py).

Usa SQLite in-memory + mocks do pipeline RAG para isolar a lógica de negócio
sem chamadas reais à API do Gemini.
"""

from __future__ import annotations

from datetime import datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import UUID, uuid4

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.models.user import Base, User
from app.models.chatbot import (
    ChatConversation,
    ChatFeedback,
    ChatMessage,
    KnowledgeBase,
)
from app.services.chat_service import (
    ChatService,
    ConversationNotFoundError,
    MessageTooLongError,
    RateLimitExceededError,
    UnauthorizedConversationError,
)
from app.ai.rag_chain import RAGResult, RetrievedDocument

# ── Banco de teste (SQLite in-memory) ─────────────────────────────────────────
TEST_DB_URL = "sqlite+aiosqlite:///:memory:"


@pytest_asyncio.fixture(scope="function")
async def db_engine():
    engine = create_async_engine(
        TEST_DB_URL,
        echo=False,
        connect_args={"check_same_thread": False},
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest_asyncio.fixture(scope="function")
async def db_session(db_engine):
    session_factory = async_sessionmaker(
        db_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with session_factory() as session:
        yield session


@pytest_asyncio.fixture
async def sample_user(db_session: AsyncSession) -> User:
    """Criar um usuário de teste no banco."""
    user = User(
        id=uuid4(),
        name="João Silva",
        email="joao@test.com",
        password="hash_fake",
        role="client",
        phone_whatsapp="+55 11 99999-9999",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def chat_service(db_session: AsyncSession) -> ChatService:
    """ChatService com sessão de teste."""
    return ChatService(db_session)


# RAGResult positivo de exemplo
@pytest.fixture
def rag_success_result() -> RAGResult:
    return RAGResult(
        answer="O supino reto deve ser executado com as escápulas retraídas...",
        retrieved_documents=[
            RetrievedDocument(
                id=str(uuid4()),
                title="Como fazer Supino Reto",
                content="Conteúdo...",
                relevance_score=0.91,
                category="exercicio",
            )
        ],
        should_escalate=False,
        escalation_reason="",
        model_used="gemini-1.5-flash",
        tokens_used=110,
        latency_ms=850,
        confidence_score=0.91,
    )


# RAGResult com escalação
@pytest.fixture
def rag_escalated_result() -> RAGResult:
    return RAGResult(
        answer="Sua dúvida precisa da atenção do seu Personal Trainer. Escalando agora! 🎯",
        retrieved_documents=[],
        should_escalate=True,
        escalation_reason="low_confidence",
        model_used="",
        tokens_used=0,
        latency_ms=200,
        confidence_score=0.0,
    )


# ── Testes: sanitize_input ────────────────────────────────────────────────────

class TestSanitizeInput:
    """Testa a sanitização de input (RN-18)."""

    def test_removes_html_tags(self):
        """Deve remover tags HTML."""
        raw = "<script>alert('xss')</script> Como faço supino?"
        result = ChatService.sanitize_input(raw)
        assert "<script>" not in result
        assert "alert" not in result
        assert "Como faço supino?" in result

    def test_removes_sql_injection(self):
        """Deve bloquear padrões básicos de SQL injection."""
        raw = "Como faço supino? DROP TABLE users;"
        result = ChatService.sanitize_input(raw)
        assert "DROP" not in result
        assert "TABLE" not in result

    def test_removes_union_select(self):
        """Deve bloquear UNION SELECT."""
        raw = "msg UNION SELECT * FROM users"
        result = ChatService.sanitize_input(raw)
        assert "UNION" not in result

    def test_truncates_to_max_length(self):
        """Deve truncar a 500 caracteres."""
        long_msg = "x" * 600
        result = ChatService.sanitize_input(long_msg)
        assert len(result) == 500

    def test_normalizes_whitespace(self):
        """Deve normalizar múltiplos espaços."""
        raw = "Como   faço    supino?"
        result = ChatService.sanitize_input(raw)
        assert "  " not in result

    def test_clean_message_unchanged(self):
        """Mensagem limpa não deve ser alterada (além do strip)."""
        raw = "Como faço agachamento livre corretamente?"
        result = ChatService.sanitize_input(raw)
        assert result == raw

    def test_removes_img_tag(self):
        """Deve remover tags de imagem."""
        raw = '<img src="http://evil.com/track.png"> pergunta'
        result = ChatService.sanitize_input(raw)
        assert "<img" not in result
        assert "pergunta" in result


# ── Testes: _check_rate_limit ─────────────────────────────────────────────────

class TestRateLimit:
    """Testa o rate limiting (RN-16: 30 msg/hora)."""

    @pytest.mark.asyncio
    async def test_allows_under_limit(self, chat_service, db_session, sample_user):
        """Não deve bloquear quando abaixo do limite."""
        # Criar 10 mensagens na última hora
        conv = ChatConversation(
            user_id=sample_user.id, channel="app", status="active"
        )
        db_session.add(conv)
        await db_session.flush()

        for _ in range(10):
            msg = ChatMessage(
                conversation_id=conv.id,
                role="user",
                content="Pergunta",
                channel="app",
                created_at=datetime.utcnow(),
            )
            db_session.add(msg)
        await db_session.commit()

        # Não deve lançar exceção
        await chat_service._check_rate_limit(sample_user.id)

    @pytest.mark.asyncio
    async def test_blocks_at_limit(self, chat_service, db_session, sample_user):
        """Deve bloquear quando atingir 30 mensagens/hora (RN-16)."""
        conv = ChatConversation(
            user_id=sample_user.id, channel="app", status="active"
        )
        db_session.add(conv)
        await db_session.flush()

        for _ in range(30):
            msg = ChatMessage(
                conversation_id=conv.id,
                role="user",
                content="Pergunta",
                channel="app",
                created_at=datetime.utcnow(),
            )
            db_session.add(msg)
        await db_session.commit()

        with pytest.raises(RateLimitExceededError):
            await chat_service._check_rate_limit(sample_user.id)

    @pytest.mark.asyncio
    async def test_ignores_old_messages(self, chat_service, db_session, sample_user):
        """Mensagens com mais de 1 hora não devem contar para o rate limit."""
        conv = ChatConversation(
            user_id=sample_user.id, channel="app", status="active"
        )
        db_session.add(conv)
        await db_session.flush()

        old_time = datetime.utcnow() - timedelta(hours=2)
        for _ in range(30):
            msg = ChatMessage(
                conversation_id=conv.id,
                role="user",
                content="Mensagem antiga",
                channel="app",
                created_at=old_time,
            )
            db_session.add(msg)
        await db_session.commit()

        # Não deve bloquear — mensagens são antigas
        await chat_service._check_rate_limit(sample_user.id)

    @pytest.mark.asyncio
    async def test_only_counts_user_messages(self, chat_service, db_session, sample_user):
        """Somente mensagens com role='user' devem contar para o rate limit."""
        conv = ChatConversation(
            user_id=sample_user.id, channel="app", status="active"
        )
        db_session.add(conv)
        await db_session.flush()

        for _ in range(30):
            msg = ChatMessage(
                conversation_id=conv.id,
                role="assistant",  # role assistant não conta
                content="Resposta",
                channel="app",
                created_at=datetime.utcnow(),
            )
            db_session.add(msg)
        await db_session.commit()

        # Não deve bloquear (role=assistant não conta)
        await chat_service._check_rate_limit(sample_user.id)


# ── Testes: send_message ──────────────────────────────────────────────────────

class TestSendMessage:
    """Testa o fluxo principal de envio de mensagem."""

    @pytest.mark.asyncio
    async def test_send_message_success(
        self, chat_service, sample_user, rag_success_result
    ):
        """Fluxo completo de envio deve retornar resposta estruturada correta."""
        with patch("app.services.chat_service.rag_chain") as mock_rag:
            mock_rag.run = AsyncMock(return_value=rag_success_result)

            result = await chat_service.send_message(
                user_id=sample_user.id,
                message="Como faço supino reto?",
            )

        assert result["role"] == "assistant"
        assert result["content"] == rag_success_result.answer
        assert "message_id" in result
        assert "conversation_id" in result
        assert result["escalation"] is None
        assert result["latency_ms"] >= 0
        assert len(result["retrieved_documents"]) == 1

    @pytest.mark.asyncio
    async def test_send_message_creates_new_conversation(
        self, chat_service, db_session, sample_user, rag_success_result
    ):
        """Deve criar nova conversa quando conversation_id é None."""
        with patch("app.services.chat_service.rag_chain") as mock_rag:
            mock_rag.run = AsyncMock(return_value=rag_success_result)

            result = await chat_service.send_message(
                user_id=sample_user.id,
                message="Como faço supino?",
            )

        conv_id = UUID(result["conversation_id"])
        from sqlalchemy import select
        stmt = select(ChatConversation).where(ChatConversation.id == conv_id)
        db_result = await db_session.execute(stmt)
        conversation = db_result.scalar_one_or_none()

        assert conversation is not None
        assert conversation.status == "active"
        assert conversation.channel == "app"

    @pytest.mark.asyncio
    async def test_send_message_persists_both_messages(
        self, chat_service, db_session, sample_user, rag_success_result
    ):
        """Deve salvar mensagem do usuário E resposta do assistente no banco (RN-01)."""
        with patch("app.services.chat_service.rag_chain") as mock_rag:
            mock_rag.run = AsyncMock(return_value=rag_success_result)

            result = await chat_service.send_message(
                user_id=sample_user.id,
                message="Como faço supino?",
            )

        conv_id = UUID(result["conversation_id"])
        from sqlalchemy import select
        stmt = select(ChatMessage).where(ChatMessage.conversation_id == conv_id)
        db_result = await db_session.execute(stmt)
        messages = db_result.scalars().all()

        assert len(messages) == 2
        roles = {m.role for m in messages}
        assert roles == {"user", "assistant"}

    @pytest.mark.asyncio
    async def test_send_message_escalates_conversation(
        self, chat_service, db_session, sample_user, rag_escalated_result
    ):
        """Quando RAG escalar, conversa deve ter status='escalated'."""
        with patch("app.services.chat_service.rag_chain") as mock_rag:
            mock_rag.run = AsyncMock(return_value=rag_escalated_result)

            result = await chat_service.send_message(
                user_id=sample_user.id,
                message="falar com personal",
            )

        assert result["escalation"] is not None
        assert result["escalation"]["escalated"] is True

        conv_id = UUID(result["conversation_id"])
        from sqlalchemy import select
        stmt = select(ChatConversation).where(ChatConversation.id == conv_id)
        db_result = await db_session.execute(stmt)
        conv = db_result.scalar_one_or_none()
        assert conv.status == "escalated"

    @pytest.mark.asyncio
    async def test_send_message_rate_limit_blocks(
        self, chat_service, db_session, sample_user
    ):
        """Deve lançar RateLimitExceededError ao exceder 30 msgs/hora (RN-16)."""
        conv = ChatConversation(
            user_id=sample_user.id, channel="app", status="active"
        )
        db_session.add(conv)
        await db_session.flush()
        for _ in range(30):
            db_session.add(ChatMessage(
                conversation_id=conv.id, role="user",
                content="x", channel="app", created_at=datetime.utcnow(),
            ))
        await db_session.commit()

        with pytest.raises(RateLimitExceededError):
            await chat_service.send_message(
                user_id=sample_user.id,
                message="Mais uma pergunta",
            )

    @pytest.mark.asyncio
    async def test_send_message_too_long_raises(self, chat_service, sample_user):
        """Deve lançar MessageTooLongError para mensagem > 500 caracteres."""
        long_msg = "x" * 501

        with pytest.raises(MessageTooLongError):
            await chat_service.send_message(
                user_id=sample_user.id,
                message=long_msg,
            )

    @pytest.mark.asyncio
    async def test_send_message_invalid_conversation_id(
        self, chat_service, sample_user
    ):
        """Deve lançar ConversationNotFoundError para conversa inexistente."""
        fake_id = uuid4()

        with pytest.raises(ConversationNotFoundError):
            await chat_service.send_message(
                user_id=sample_user.id,
                message="Pergunta",
                conversation_id=fake_id,
            )

    @pytest.mark.asyncio
    async def test_send_message_unauthorized_conversation(
        self, chat_service, db_session, sample_user
    ):
        """Deve lançar UnauthorizedConversationError quando conversa pertence a outro usuário."""
        other_user_id = uuid4()
        conv = ChatConversation(
            user_id=other_user_id, channel="app", status="active"
        )
        db_session.add(conv)
        await db_session.commit()

        with pytest.raises(UnauthorizedConversationError):
            await chat_service.send_message(
                user_id=sample_user.id,
                message="Pergunta",
                conversation_id=conv.id,
            )

    @pytest.mark.asyncio
    async def test_send_message_stores_context_data(
        self, chat_service, db_session, sample_user, rag_success_result
    ):
        """Mensagem do assistente deve ter context_data com retrieved_documents."""
        with patch("app.services.chat_service.rag_chain") as mock_rag:
            mock_rag.run = AsyncMock(return_value=rag_success_result)

            result = await chat_service.send_message(
                user_id=sample_user.id,
                message="Como faço supino?",
            )

        msg_id = UUID(result["message_id"])
        from sqlalchemy import select
        stmt = select(ChatMessage).where(ChatMessage.id == msg_id)
        db_result = await db_session.execute(stmt)
        msg = db_result.scalar_one_or_none()

        assert msg.context_data is not None
        assert "retrieved_documents" in msg.context_data
        assert len(msg.context_data["retrieved_documents"]) == 1


# ── Testes: get_conversation e list_conversations ─────────────────────────────

class TestConversationManagement:
    """Testa listagem e recuperação de conversas."""

    @pytest.mark.asyncio
    async def test_list_conversations_returns_user_conversations(
        self, chat_service, db_session, sample_user
    ):
        """list_conversations deve retornar apenas conversas do usuário."""
        for _ in range(3):
            conv = ChatConversation(user_id=sample_user.id, channel="app", status="active")
            db_session.add(conv)

        # Conversa de outro usuário
        other_conv = ChatConversation(user_id=uuid4(), channel="app", status="active")
        db_session.add(other_conv)
        await db_session.commit()

        result = await chat_service.list_conversations(sample_user.id)

        assert result["total"] == 3
        for c in result["conversations"]:
            assert c["status"] in ("active", "closed", "escalated")

    @pytest.mark.asyncio
    async def test_get_conversation_returns_messages(
        self, chat_service, db_session, sample_user
    ):
        """get_conversation deve retornar mensagens ordenadas."""
        conv = ChatConversation(user_id=sample_user.id, channel="app", status="active")
        db_session.add(conv)
        await db_session.flush()

        for role, content in [("user", "Olá"), ("assistant", "Oi!")]:
            db_session.add(ChatMessage(
                conversation_id=conv.id, role=role, content=content, channel="app"
            ))
        await db_session.commit()

        result = await chat_service.get_conversation(sample_user.id, conv.id)

        assert result["id"] == str(conv.id)
        assert len(result["messages"]) == 2
        assert result["messages"][0]["role"] == "user"
        assert result["messages"][1]["role"] == "assistant"

    @pytest.mark.asyncio
    async def test_get_conversation_not_found(self, chat_service, sample_user):
        """Deve lançar ConversationNotFoundError para conversa inexistente."""
        with pytest.raises(ConversationNotFoundError):
            await chat_service.get_conversation(sample_user.id, uuid4())

    @pytest.mark.asyncio
    async def test_rate_conversation_success(
        self, chat_service, db_session, sample_user
    ):
        """Deve salvar rating e fechar conversa."""
        conv = ChatConversation(user_id=sample_user.id, channel="app", status="active")
        db_session.add(conv)
        await db_session.commit()

        result = await chat_service.rate_conversation(
            user_id=sample_user.id,
            conversation_id=conv.id,
            rating=5,
            feedback="Muito útil!",
        )

        assert result["success"] is True
        await db_session.refresh(conv)
        assert conv.rating == 5
        assert conv.feedback == "Muito útil!"
        assert conv.status == "closed"

    @pytest.mark.asyncio
    async def test_rate_conversation_clamps_rating(
        self, chat_service, db_session, sample_user
    ):
        """Rating deve ser limitado ao intervalo 1-5."""
        conv = ChatConversation(user_id=sample_user.id, channel="app", status="active")
        db_session.add(conv)
        await db_session.commit()

        await chat_service.rate_conversation(
            user_id=sample_user.id,
            conversation_id=conv.id,
            rating=10,  # deve ser limitado a 5
        )

        await db_session.refresh(conv)
        assert conv.rating == 5


# ── Testes: Message Feedback ──────────────────────────────────────────────────

class TestMessageFeedback:
    """Testa feedback em mensagens individuais (RN-21)."""

    @pytest.mark.asyncio
    async def test_add_message_feedback_success(
        self, chat_service, db_session, sample_user
    ):
        """Deve salvar feedback e atualizar contadores da KnowledgeBase (RN-23)."""
        doc_id = uuid4()
        kb_doc = KnowledgeBase(
            id=doc_id,
            title="Supino Reto",
            content="Conteúdo...",
            category="exercicio",
            views_count=10,
            helpful_count=8,
        )
        db_session.add(kb_doc)

        conv = ChatConversation(user_id=sample_user.id, channel="app", status="active")
        db_session.add(conv)
        await db_session.flush()

        msg = ChatMessage(
            conversation_id=conv.id,
            role="assistant",
            content="Resposta sobre supino",
            channel="app",
            context_data={"retrieved_documents": [{"id": str(doc_id), "title": "Supino Reto", "relevance_score": 0.9}]},
        )
        db_session.add(msg)
        await db_session.commit()

        result = await chat_service.add_message_feedback(
            user_id=sample_user.id,
            message_id=msg.id,
            was_helpful=True,
            feedback_type="good",
        )

        assert result["success"] is True
        await db_session.refresh(kb_doc)
        assert kb_doc.views_count == 11
        assert kb_doc.helpful_count == 9

    @pytest.mark.asyncio
    async def test_add_feedback_not_helpful_increments_only_views(
        self, chat_service, db_session, sample_user
    ):
        """Feedback negativo deve incrementar views_count mas não helpful_count."""
        doc_id = uuid4()
        kb_doc = KnowledgeBase(
            id=doc_id, title="Doc", content="...",
            category="exercicio", views_count=5, helpful_count=4,
        )
        db_session.add(kb_doc)

        conv = ChatConversation(user_id=sample_user.id, channel="app", status="active")
        db_session.add(conv)
        await db_session.flush()

        msg = ChatMessage(
            conversation_id=conv.id,
            role="assistant",
            content="Resposta",
            channel="app",
            context_data={"retrieved_documents": [{"id": str(doc_id), "title": "Doc", "relevance_score": 0.8}]},
        )
        db_session.add(msg)
        await db_session.commit()

        await chat_service.add_message_feedback(
            user_id=sample_user.id,
            message_id=msg.id,
            was_helpful=False,
            feedback_type="incorrect",
        )

        await db_session.refresh(kb_doc)
        assert kb_doc.views_count == 6
        assert kb_doc.helpful_count == 4  # não incrementado


# ── Testes: Knowledge Base Admin ─────────────────────────────────────────────

class TestKnowledgeBase:
    """Testa operações de admin na KnowledgeBase."""

    @pytest.mark.asyncio
    async def test_create_knowledge_document_success(
        self, chat_service, db_session, sample_user
    ):
        """Deve criar documento com embedding gerado."""
        fake_embedding = [0.1] * 768

        with patch("app.services.chat_service.rag_chain") as mock_rag_module:
            mock_embeddings = AsyncMock()
            mock_embeddings.aembed_query = AsyncMock(return_value=fake_embedding)
            mock_rag_module._get_embeddings.return_value = mock_embeddings

            # Patch na instância singleton
            with patch("app.ai.rag_chain.rag_chain") as mock_rc:
                mock_rc._get_embeddings.return_value = mock_embeddings

                result = await chat_service.create_knowledge_document(
                    created_by_id=sample_user.id,
                    academy_id=None,
                    title="Como fazer Agachamento Livre",
                    content="# Agachamento\n\nO agachamento livre é...",
                    category="exercicio",
                    muscle_group="Perna",
                    difficulty_level="intermediario",
                )

        assert "id" in result
        assert result["title"] == "Como fazer Agachamento Livre"

    @pytest.mark.asyncio
    async def test_list_knowledge_documents(self, chat_service, db_session):
        """Deve listar apenas documentos ativos."""
        for i, active in enumerate([True, True, False]):
            doc = KnowledgeBase(
                title=f"Doc {i}",
                content="Conteúdo...",
                category="exercicio",
                is_active=active,
                views_count=0,
                helpful_count=0,
            )
            db_session.add(doc)
        await db_session.commit()

        result = await chat_service.list_knowledge_documents()

        assert len(result["documents"]) == 2  # apenas os ativos
        for doc in result["documents"]:
            assert "helpfulness_rate" in doc

    @pytest.mark.asyncio
    async def test_list_escalated_conversations(
        self, chat_service, db_session, sample_user
    ):
        """Deve listar conversas com status='escalated'."""
        # 2 escaladas + 1 ativa
        for status in ["escalated", "escalated", "active"]:
            conv = ChatConversation(
                user_id=sample_user.id, channel="app", status=status,
                escalation_reason="low_confidence" if status == "escalated" else None,
            )
            db_session.add(conv)
        await db_session.commit()

        result = await chat_service.list_escalated_conversations()

        assert result["total"] == 2
        for item in result["escalated_conversations"]:
            assert item["reason"] == "low_confidence"
