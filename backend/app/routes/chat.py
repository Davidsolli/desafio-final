"""
Endpoints HTTP do Chatbot de Dúvidas.

Rotas:
    POST   /api/v1/chat/send-message
    POST   /api/v1/chat/send-message/stream   (SSE)
    WS     /api/v1/chat/ws
    GET    /api/v1/chat/conversations
    GET    /api/v1/chat/conversations/{id}
    POST   /api/v1/chat/conversations/{id}/rate
    POST   /api/v1/chat/messages/{id}/feedback
    GET    /api/v1/chat/admin/escalated
    POST   /api/v1/chat/admin/knowledge-base
    GET    /api/v1/chat/admin/knowledge-base

Camada de roteamento: apenas valida payload, autentica e delega ao ChatController.
Toda lógica de negócio fica no ChatService (consumido pelo controller).
"""

from __future__ import annotations

import asyncio
import json
import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status, WebSocket, WebSocketDisconnect
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.config.settings import settings
from app.controllers.chat_controller import ChatController
from app.dependencies.auth import get_current_user, get_user_from_token
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
from app.models.user import User
from app.services.chat_service import (
    ChatService,
    ConversationNotFoundError,
    MessageTooLongError,
    RateLimitExceededError,
    UnauthorizedConversationError,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1/chat", tags=["Chatbot"])


# ── Dependency: obter ChatController ─────────────────────────────────────────

async def get_chat_controller(
    session: AsyncSession = Depends(get_db),
) -> ChatController:
    """Cria controller a cada request, injetando service com sessão atual."""
    return ChatController(ChatService(session))


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
    controller: ChatController = Depends(get_chat_controller),
    user_id: UUID = Depends(get_current_user_id),
) -> SendMessageResponseDTO:
    try:
        result = await controller.send_message(
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


@router.post(
    "/send-message/stream",
    status_code=status.HTTP_200_OK,
    summary="Enviar mensagem ao chatbot com resposta streamada (SSE)",
    description=(
        "Envia uma mensagem e recebe a resposta token a token via Server-Sent Events. "
        "Eventos: 'status' (progresso), 'chunk' (fragmento de texto), 'final' (metadados completos). "
        "Erros de validação são enviados como eventos do tipo 'error'."
    ),
)
async def send_message_stream(
    payload: SendMessageDTO,
    session: AsyncSession = Depends(get_db),
    user_id: UUID = Depends(get_current_user_id),
) -> StreamingResponse:
    service = ChatService(session)

    async def event_generator():
        try:
            async for event in service.send_message_stream(
                user_id=user_id,
                message=payload.message,
                conversation_id=payload.conversation_id,
            ):
                yield f"data: {json.dumps(event, ensure_ascii=False)}\n\n"
        except RateLimitExceededError as exc:
            yield f"data: {json.dumps({'type': 'error', 'code': 429, 'error': str(exc)}, ensure_ascii=False)}\n\n"
        except MessageTooLongError as exc:
            yield f"data: {json.dumps({'type': 'error', 'code': 422, 'error': str(exc)}, ensure_ascii=False)}\n\n"
        except UnauthorizedConversationError as exc:
            yield f"data: {json.dumps({'type': 'error', 'code': 403, 'error': str(exc)}, ensure_ascii=False)}\n\n"
        except ConversationNotFoundError as exc:
            yield f"data: {json.dumps({'type': 'error', 'code': 404, 'error': str(exc)}, ensure_ascii=False)}\n\n"
        except Exception as exc:
            logger.error("Erro no stream SSE: %s", exc)
            yield f"data: {json.dumps({'type': 'error', 'code': 500, 'error': 'Erro interno ao processar mensagem'}, ensure_ascii=False)}\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
            "Connection": "keep-alive",
        },
    )


@router.websocket("/ws")
async def chat_websocket(
    websocket: WebSocket,
    session: AsyncSession = Depends(get_db),
):
    """
    Endpoint de WebSocket para chat in-app.

    Protocolo:
        cliente → { "type": "auth", "token": "<jwt>" }
        servidor → { "type": "auth_success", ... } | { "type": "auth_error", ... }
        cliente → { "type": "message", "content": "...", "conversation_id": "<uuid>" (opcional) }
        servidor → { "type": "status", "status": "thinking", "message": "..." }
        servidor → { "type": "status", "status": "searching", "message": "..." }
        servidor → { "type": "status", "status": "generating", "message": "..." }
        servidor → { "type": "response", ... } (resposta final do chatbot)
    """
    await websocket.accept()

    user = None
    controller = ChatController(ChatService(session))
    auth_timeout = 5  # segundos para enviar auth
    inactivity_timeout = 300  # 5 minutos

    try:
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

        user = await get_user_from_token(token, session)

        if not user:
            await websocket.send_json({
                "error": "Token inválido ou usuário não encontrado",
                "type": "auth_error",
            })
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return

        await websocket.send_json({
            "type": "auth_success",
            "message": "Autenticado com sucesso",
        })

        async def forward_status(event: dict) -> None:
            """Repassa cada evento de status do service para o cliente."""
            try:
                await websocket.send_json(event)
            except Exception:
                logger.debug("Falha ao enviar status pelo WebSocket — ignorando")

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

                if len(content) > settings.CHAT_MAX_MESSAGE_LENGTH:
                    await websocket.send_json({
                        "error": f"Mensagem muito longa (máx {settings.CHAT_MAX_MESSAGE_LENGTH} caracteres)",
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

                    result = await controller.send_message(
                        user_id=user.id,
                        message=content,
                        conversation_id=conv_id,
                        on_status=forward_status,
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
    controller: ChatController = Depends(get_chat_controller),
    user_id: UUID = Depends(get_current_user_id),
) -> ConversationListResponseDTO:
    result = await controller.list_conversations(user_id=user_id, page=page, limit=limit)
    return ConversationListResponseDTO(**result)


@router.get(
    "/conversations/{conversation_id}",
    response_model=ConversationDetailDTO,
    summary="Detalhes de uma conversa",
)
async def get_conversation(
    conversation_id: UUID,
    controller: ChatController = Depends(get_chat_controller),
    user_id: UUID = Depends(get_current_user_id),
) -> ConversationDetailDTO:
    try:
        result = await controller.get_conversation(user_id=user_id, conversation_id=conversation_id)
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
    controller: ChatController = Depends(get_chat_controller),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    try:
        return await controller.rate_conversation(
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
    controller: ChatController = Depends(get_chat_controller),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    try:
        return await controller.add_message_feedback(
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
    controller: ChatController = Depends(get_chat_controller),
    user_id: UUID = Depends(get_current_user_id),
) -> EscalatedListResponseDTO:
    result = await controller.list_escalated_conversations(personal_id=user_id)
    return EscalatedListResponseDTO(**result)


@router.post(
    "/admin/knowledge-base",
    status_code=status.HTTP_201_CREATED,
    summary="Criar documento na base de conhecimento (Personal/Gestor)",
)
async def create_knowledge_document(
    payload: CreateKnowledgeDocumentDTO,
    controller: ChatController = Depends(get_chat_controller),
    user_id: UUID = Depends(get_current_user_id),
) -> dict:
    try:
        return await controller.create_knowledge_document(
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
    controller: ChatController = Depends(get_chat_controller),
    user_id: UUID = Depends(get_current_user_id),
) -> KnowledgeListResponseDTO:
    result = await controller.list_knowledge_documents()
    return KnowledgeListResponseDTO(**result)
