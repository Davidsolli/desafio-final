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

import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, WebSocket, WebSocketDisconnect
from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.config.settings import settings
from app.dependencies.auth import get_current_user, get_current_user_ws
from app.models.user import User
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

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/chat", tags=["Chatbot"])


# ── Dependency: obter ChatService ─────────────────────────────────────────────

async def get_chat_service(session: AsyncSession = Depends(get_db)) -> ChatService:
    return ChatService(session)


async def get_current_user_id(
    current_user: User = Depends(get_current_user)
) -> UUID:
    """Extrai o UUID do usuário autenticado via JWT."""
    return current_user.id


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


@router.websocket("/ws")
async def chat_websocket(
    websocket: WebSocket,
    session: AsyncSession = Depends(get_db),
):
    """
    Endpoint de WebSocket para chat in-app.
    Autenticação via JWT na primeira mensagem (tipo 'auth').
    Cliente deve enviar:
      1. { "type": "auth", "token": "<jwt>" } (obrigatório primeiro)
      2. { "type": "message", "content": "...", "conversation_id": "uuid" (opcional) }
    """
    await websocket.accept()

    user = None
    service = ChatService(session)
    auth_timeout = 5  # segundos para enviar auth

    try:
        import asyncio

        # Espera autenticação  (com timeout)
        try:
            first_msg = await asyncio.wait_for(
                websocket.receive_json(),
                timeout=auth_timeout,
            )
        except asyncio.TimeoutError:
            await websocket.send_json({
                "error": "Timeout na autenticação",
                "type": "auth_error",
            })
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        if first_msg.get("type") != "auth":
            await websocket.send_json({
                "error": "Primeira mensagem deve ser autenticação com type='auth'",
                "type": "auth_error",
            })
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        token = first_msg.get("token", "")
        if not token:
            await websocket.send_json({
                "error": "Token JWT não fornecido",
                "type": "auth_error",
            })
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        # Autentica usuário via JWT token
        from app.repositories.user_repository import UserRepository

        try:
            payload = jwt.decode(
                token,
                settings.SECRET_KEY,
                algorithms=[settings.ALGORITHM],
            )
            user_id_str: str | None = payload.get("sub")
            if user_id_str is None:
                await websocket.send_json({
                    "error": "Token inválido",
                    "type": "auth_error",
                })
                await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
                return

            user_id = UUID(user_id_str)

            # Busca usuário no banco
            user_repo = UserRepository(session)
            user = await user_repo.get_by_id(user_id)

            if not user:
                await websocket.send_json({
                    "error": "Usuário não encontrado",
                    "type": "auth_error",
                })
                await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
                return

            # Confirma autenticação
            await websocket.send_json({
                "type": "auth_success",
                "message": "Autenticado com sucesso",
            })

        except Exception as exc:
            logger.error(f"Erro na autenticação WebSocket: {exc}")
            await websocket.send_json({
                "error": "Erro ao autenticar",
                "type": "auth_error",
            })
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        # Loop de mensagens (com timeout de inatividade)
        inactivity_timeout = 300  # 5 minutos

        while True:
            try:
                data = await asyncio.wait_for(
                    websocket.receive_json(),
                    timeout=inactivity_timeout,
                )
            except asyncio.TimeoutError:
                logger.info(f"WebSocket inativo por {inactivity_timeout}s: user_id={user.id}")
                await websocket.send_json({
                    "error": "Sessão expirada por inatividade",
                    "type": "timeout",
                })
                await websocket.close(code=status.WS_1000_NORMAL_CLOSURE)
                return

            msg_type = data.get("type")

            if msg_type == "message":
                content = data.get("content", "").strip()
                conversation_id_str = data.get("conversation_id")

                # Valida tamanho da mensagem
                max_msg_len = 1000
                if len(content) > max_msg_len:
                    await websocket.send_json({
                        "error": f"Mensagem muito longa (máx {max_msg_len} caracteres)",
                        "type": "error",
                    })
                    continue

                if not content:
                    await websocket.send_json({
                        "error": "A mensagem não pode estar vazia.",
                        "type": "error",
                    })
                    continue

                try:
                    conv_id = None
                    if conversation_id_str:
                        try:
                            conv_id = UUID(conversation_id_str)
                        except ValueError:
                            await websocket.send_json({
                                "error": "Formato de conversation_id inválido.",
                                "type": "error",
                            })
                            continue

                    result = await service.send_message(
                        user_id=user.id,
                        message=content,
                        conversation_id=conv_id,
                    )
                    result["type"] = "response"
                    await websocket.send_json(result)
                except Exception as exc:
                    logger.error(f"Erro ao processar mensagem: {exc}")
                    await websocket.send_json({
                        "error": str(exc),
                        "type": "error",
                    })
            else:
                await websocket.send_json({
                    "error": f"Tipo de mensagem desconhecido: {msg_type}",
                    "type": "error",
                })

    except WebSocketDisconnect:
        if user:
            logger.info(f"WebSocket desconectado: user_id={user.id}")
    except Exception as exc:
        logger.error(f"Erro no WebSocket: {exc}")
        try:
            await websocket.close(code=status.WS_1011_INTERNAL_ERROR)
        except Exception:
            pass


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
