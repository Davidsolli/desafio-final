"""
Endpoints HTTP do Chatbot de Dúvidas.

Rotas:
    POST   /api/v1/chat/send-message
    GET    /api/v1/chat/conversations
    GET    /api/v1/chat/conversations/{id}
    POST   /api/v1/chat/conversations/{id}/rate
    POST   /api/v1/chat/messages/{id}/feedback
    GET    /api/v1/chat/admin/escalated
    POST   /api/v1/chat/admin/knowledge-base
    GET    /api/v1/chat/admin/knowledge-base
"""

from __future__ import annotations

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.dtos.chat_dto import (
    ConversationDetailDTO,
    ConversationListResponseDTO,
    CreateKnowledgeDocumentDTO,
    EscalatedListResponseDTO,
    KnowledgeListResponseDTO,
    MessageFeedbackDTO,
    RateConversationDTO,
    SendMessageDTO,
    SendMessageResponseDTO,
)
from app.services.chat_service import (
    ChatService,
    ConversationNotFoundError,
    MessageTooLongError,
    RateLimitExceededError,
    UnauthorizedConversationError,
)

router = APIRouter(prefix="/api/v1/chat", tags=["Chatbot"])


# ── Dependency: obter ChatService ─────────────────────────────────────────────

async def get_chat_service(session: AsyncSession = Depends(get_db)) -> ChatService:
    return ChatService(session)


# ── TODO: substituir por dependency de JWT real quando auth estiver integrado ──
async def get_current_user_id() -> UUID:
    """
    Placeholder: retorna UUID fixo de dev.
    Substituir por JWT auth dependency na integração real.
    """
    from uuid import UUID
    return UUID("00000000-0000-0000-0000-000000000001")


# ── Endpoints do Aluno ────────────────────────────────────────────────────────

@router.post(
    "/send-message",
    response_model=SendMessageResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Enviar mensagem ao chatbot",
    description=(
        "Envia uma mensagem para o chatbot e retorna a resposta gerada via RAG. "
        "Campo `channel` é fixado como 'app' no MVP 1."
    ),
)
async def send_message(
    payload: SendMessageDTO,
    service: ChatService = Depends(get_chat_service),
    user_id: UUID = Depends(get_current_user_id),
) -> SendMessageResponseDTO:
    try:
        result = await service.send_message(
            user_id=user_id,
            message=payload.message,
            conversation_id=payload.conversation_id,
        )
        return SendMessageResponseDTO(**result)
    except RateLimitExceededError as exc:
        raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(exc))
    except MessageTooLongError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))
    except UnauthorizedConversationError as exc:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(exc))
    except ConversationNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro interno ao processar mensagem: {exc}",
        )


@router.get(
    "/conversations",
    response_model=ConversationListResponseDTO,
    summary="Listar conversas do aluno",
)
async def list_conversations(
    page: int = 1,
    limit: int = 20,
    service: ChatService = Depends(get_chat_service),
    user_id: UUID = Depends(get_current_user_id),
) -> ConversationListResponseDTO:
    result = await service.list_conversations(user_id=user_id, page=page, limit=limit)
    return ConversationListResponseDTO(**result)


@router.get(
    "/conversations/{conversation_id}",
    response_model=ConversationDetailDTO,
    summary="Detalhes de uma conversa",
)
async def get_conversation(
    conversation_id: UUID,
    service: ChatService = Depends(get_chat_service),
    user_id: UUID = Depends(get_current_user_id),
) -> ConversationDetailDTO:
    try:
        result = await service.get_conversation(user_id=user_id, conversation_id=conversation_id)
        return ConversationDetailDTO(**result)
    except ConversationNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))


@router.post(
    "/conversations/{conversation_id}/rate",
    summary="Avaliar conversa",
)
async def rate_conversation(
    conversation_id: UUID,
    payload: RateConversationDTO,
    service: ChatService = Depends(get_chat_service),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    try:
        return await service.rate_conversation(
            user_id=user_id,
            conversation_id=conversation_id,
            rating=payload.rating,
            feedback=payload.feedback,
        )
    except ConversationNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))


@router.post(
    "/messages/{message_id}/feedback",
    summary="Feedback em mensagem específica",
)
async def message_feedback(
    message_id: UUID,
    payload: MessageFeedbackDTO,
    service: ChatService = Depends(get_chat_service),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    try:
        return await service.add_message_feedback(
            user_id=user_id,
            message_id=message_id,
            was_helpful=payload.was_helpful,
            feedback_type=payload.feedback_type,
            comment=payload.comment,
        )
    except ConversationNotFoundError as exc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc))


# ── Endpoints Admin/Personal ──────────────────────────────────────────────────

@router.get(
    "/admin/escalated",
    response_model=EscalatedListResponseDTO,
    summary="Listar conversas escaladas (Personal)",
)
async def list_escalated(
    service: ChatService = Depends(get_chat_service),
    user_id: UUID = Depends(get_current_user_id),
) -> EscalatedListResponseDTO:
    result = await service.list_escalated_conversations(personal_id=user_id)
    return EscalatedListResponseDTO(**result)


@router.post(
    "/admin/knowledge-base",
    status_code=status.HTTP_201_CREATED,
    summary="Criar documento na base de conhecimento (Personal/Gestor)",
)
async def create_knowledge_document(
    payload: CreateKnowledgeDocumentDTO,
    service: ChatService = Depends(get_chat_service),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    try:
        return await service.create_knowledge_document(
            created_by_id=user_id,
            academy_id=None,
            title=payload.title,
            content=payload.content,
            category=payload.category,
            muscle_group=payload.muscle_group,
            difficulty_level=payload.difficulty_level,
            exercise_id=payload.exercise_id,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro ao criar documento: {exc}",
        )


@router.get(
    "/admin/knowledge-base",
    response_model=KnowledgeListResponseDTO,
    summary="Listar base de conhecimento com métricas",
)
async def list_knowledge_documents(
    service: ChatService = Depends(get_chat_service),
    user_id: UUID = Depends(get_current_user_id),
) -> KnowledgeListResponseDTO:
    result = await service.list_knowledge_documents()
    return KnowledgeListResponseDTO(**result)
