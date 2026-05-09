"""
Controller do Chatbot.

Camada de orquestração: recebe dados das rotas, invoca o ChatService e
retorna o resultado. Não contém regras de negócio.

A injeção de dependência é feita via construtor (recebendo um ChatService
já instanciado), o que torna o controller fácil de testar com mocks.
"""

from __future__ import annotations

from typing import Any, Awaitable, Callable
from uuid import UUID

from app.services.chat_service import ChatService


class ChatController:
    """Orquestrador HTTP/WebSocket → ChatService."""

    def __init__(self, service: ChatService) -> None:
        self.service = service

    # ── Ações do aluno ────────────────────────────────────────────────────

    async def send_message(
        self,
        user_id: UUID,
        message: str,
        conversation_id: UUID | None = None,
        academy_id: UUID | None = None,
        on_status: Callable[[dict], Awaitable[None]] | None = None,
    ) -> dict[str, Any]:
        """Envia mensagem do aluno ao pipeline e devolve a resposta estruturada."""
        return await self.service.send_message(
            user_id=user_id,
            message=message,
            conversation_id=conversation_id,
            academy_id=academy_id,
            on_status=on_status,
        )

    async def list_conversations(
        self,
        user_id: UUID,
        page: int = 1,
        limit: int = 20,
    ) -> dict[str, Any]:
        """Lista as conversas do aluno autenticado."""
        return await self.service.list_conversations(
            user_id=user_id, page=page, limit=limit
        )

    async def get_conversation(
        self,
        user_id: UUID,
        conversation_id: UUID,
    ) -> dict[str, Any]:
        """Detalhes de uma conversa do aluno autenticado."""
        return await self.service.get_conversation(
            user_id=user_id, conversation_id=conversation_id
        )

    async def rate_conversation(
        self,
        user_id: UUID,
        conversation_id: UUID,
        rating: int,
        feedback: str | None = None,
    ) -> dict[str, Any]:
        """Salva avaliação numérica do aluno sobre a conversa."""
        return await self.service.rate_conversation(
            user_id=user_id,
            conversation_id=conversation_id,
            rating=rating,
            feedback=feedback,
        )

    async def add_message_feedback(
        self,
        user_id: UUID,
        message_id: UUID,
        was_helpful: bool,
        feedback_type: str = "good",
        comment: str | None = None,
    ) -> dict[str, Any]:
        """Feedback granular em uma mensagem específica."""
        return await self.service.add_message_feedback(
            user_id=user_id,
            message_id=message_id,
            was_helpful=was_helpful,
            feedback_type=feedback_type,
            comment=comment,
        )

    # ── Ações administrativas ─────────────────────────────────────────────

    async def list_escalated_conversations(
        self, personal_id: UUID | None = None
    ) -> dict[str, Any]:
        """Lista conversas em estado escalado."""
        return await self.service.list_escalated_conversations(personal_id=personal_id)

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
        return await self.service.create_knowledge_document(
            created_by_id=created_by_id,
            academy_id=academy_id,
            title=title,
            content=content,
            category=category,
            muscle_group=muscle_group,
            difficulty_level=difficulty_level,
            exercise_id=exercise_id,
        )

    async def list_knowledge_documents(
        self, academy_id: UUID | None = None
    ) -> dict[str, Any]:
        return await self.service.list_knowledge_documents(academy_id=academy_id)
