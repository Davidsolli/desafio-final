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
    POST   /api/v1/chat/send-audio        (audio food logging)

Camada de roteamento: apenas valida payload, autentica e delega ao ChatController.
Toda lógica de negócio fica no ChatService (consumido pelo controller).
"""

from __future__ import annotations

import asyncio
import json
import logging
from uuid import UUID

from fastapi import APIRouter, Depends, File, Form, HTTPException, status, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.config.settings import settings
from app.controllers.chat_controller import ChatController
from app.dependencies.auth import get_current_user, get_user_from_token
from app.dtos.chat_dto import (
    AudioFoodResponseDTO,
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


@router.post(
    "/send-audio",
    response_model=AudioFoodResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Registrar refeição por áudio",
    description=(
        "Recebe um arquivo de áudio onde o usuário descreve o que comeu "
        "(alimento + quantidade em gramas). Transcreve com Groq Whisper, "
        "identifica o alimento no catálogo TACO via LLM e registra "
        "automaticamente no diário alimentar do dia."
    ),
)
async def send_audio_message(
    audio: UploadFile = File(
        ...,
        description="Arquivo de áudio (mp3, m4a, wav, webm, ogg — máx 25 MB)",
    ),
    conversation_id: str | None = Form(
        None,
        description="UUID de conversa existente (opcional — cria nova se omitido)",
    ),
    log_date: str | None = Form(
        None,
        description="Data local do dispositivo (YYYY-MM-DD). Usada no logbook para evitar divergência de fuso.",
    ),
    local_hour: int | None = Form(
        None,
        description="Hora local do dispositivo (0-23). Usada para inferir o nome da refeição.",
    ),
    session: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> AudioFoodResponseDTO:
    """
    Fluxo:
    1. Transcreve o áudio com Groq Whisper (pt-BR)
    2. LLM extrai alimento, quantidade e refeição do texto
    3. Busca no catálogo TACO e escolhe o melhor match
    4. Registra no DietLogbook do dia com snapshot de macros
    5. Salva mensagem na conversa do chatbot e retorna confirmação
    """
    from datetime import datetime, timezone
    from uuid import uuid4

    from app.ai.audio_transcriber import (
        AudioFormatError,
        AudioTooLargeError,
        AudioTranscriptionError,
        audio_transcriber,
    )
    from app.ai.food_parser import (
        FoodNotFoundError,
        FoodParseError,
        QuantityNotFoundError,
        food_parser,
    )
    from app.dtos.diet_logbook_dto import AddLogbookEntryDTO
    from app.models.chatbot import ChatConversation, ChatMessage
    from app.services.diet_logbook_service import DietLogbookService

    # ── 1. Ler o arquivo de áudio ─────────────────────────────────────────
    audio_bytes = await audio.read()

    # ── 2. Transcrição (Groq Whisper) ─────────────────────────────────────
    try:
        transcription = await audio_transcriber.transcribe(
            audio_bytes=audio_bytes,
            filename=audio.filename or "audio.m4a",
            content_type=audio.content_type or "audio/m4a",
        )
    except AudioTooLargeError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "AUDIO_TOO_LARGE", "message": str(exc)},
        )
    except AudioFormatError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail={"code": "AUDIO_FORMAT_ERROR", "message": str(exc)},
        )
    except AudioTranscriptionError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "TRANSCRIPTION_FAILED", "message": str(exc)},
        )

    if not transcription:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "TRANSCRIPTION_FAILED", "message": "Áudio inaudível ou sem conteúdo."},
        )

    # ── 3. Parser de refeição (TACO → web → LLM estimate) ────────────────
    try:
        parse_result = await food_parser.parse(
            transcription,
            session,
            local_hour=local_hour,
            user_id=current_user.id,
        )
    except QuantityNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "QUANTITY_NOT_FOUND", "message": str(exc)},
        )
    except FoodNotFoundError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "FOOD_NOT_FOUND", "message": str(exc)},
        )
    except FoodParseError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "PARSE_ERROR", "message": str(exc)},
        )

    # ── 4. Registrar no DietLogbook ───────────────────────────────────────
    from datetime import date as _date
    parsed_log_date: _date | None = None
    if log_date:
        try:
            parsed_log_date = _date.fromisoformat(log_date)
        except ValueError:
            pass

    # Determinar se a fonte é TACO (food_id) ou CustomFood (custom_food_id)
    logbook_service = DietLogbookService(session)
    if parse_result.source == "taco" and parse_result.catalog_item is not None:
        entry_dto = AddLogbookEntryDTO(
            meal_name=parse_result.meal_name,
            food_id=parse_result.catalog_item.id,
            quantity_g=parse_result.quantity_g,
            log_date=parsed_log_date,
        )
        food_name_display = parse_result.catalog_item.name
    else:
        # fonte: "web" ou "estimativa" — usa CustomFood criado pelo parser
        assert parse_result.custom_food is not None
        entry_dto = AddLogbookEntryDTO(
            meal_name=parse_result.meal_name,
            custom_food_id=parse_result.custom_food.id,
            quantity_g=parse_result.quantity_g,
            log_date=parsed_log_date,
        )
        food_name_display = parse_result.custom_food.name

    logbook_entry = await logbook_service.add_entry(
        user_id=current_user.id,
        dto=entry_dto,
    )

    # ── 5. Montar mensagem de confirmação do Vitali ───────────────────────
    qty = parse_result.quantity_g
    meal = parse_result.meal_name

    # Sufixo contextual por fonte
    source_note = {
        "taco": "",
        "web": " _(dados nutricionais encontrados na web)_",
        "estimativa": " _(macros estimados pela IA — podem variar por marca)_",
    }.get(parse_result.source, "")

    vitali_message = (
        f"✅ Registrei **{qty:.0f}g de {food_name_display}**"
        f" no seu {meal}!{source_note}\n\n"
        f"📊 Macros adicionados:\n"
        f"• Calorias: {logbook_entry.kcal:.0f} kcal\n"
        f"• Proteínas: {logbook_entry.protein:.1f}g\n"
        f"• Carboidratos: {logbook_entry.carbs:.1f}g\n"
        f"• Gorduras: {logbook_entry.fats:.1f}g\n\n"
        f"💡 Você também pode perguntar: qual é meu total de calorias de hoje?"
    )

    # ── 6. Salvar na conversa do chatbot ──────────────────────────────────
    conv_id: UUID | None = None
    if conversation_id:
        try:
            conv_id = UUID(conversation_id)
        except ValueError:
            pass

    if conv_id:
        from sqlalchemy import select as sa_select
        stmt = sa_select(ChatConversation).where(
            ChatConversation.id == conv_id,
            ChatConversation.user_id == current_user.id,
        )
        result = await session.execute(stmt)
        conversation = result.scalar_one_or_none()
    else:
        conversation = None

    if conversation is None:
        conversation = ChatConversation(
            user_id=current_user.id,
            channel="app",
            status="active",
        )
        session.add(conversation)
        await session.flush()

    user_msg = ChatMessage(
        conversation_id=conversation.id,
        role="user",
        content=f"🎤 {transcription}",
        channel="app",
    )
    session.add(user_msg)
    await session.flush()

    context_food: dict = {
        "food_name": food_name_display,
        "quantity_g": qty,
        "meal_name": meal,
        "food_source": parse_result.source,
        "logbook_entry_id": str(logbook_entry.id),
    }
    if parse_result.source == "taco" and parse_result.catalog_item:
        context_food["food_id"] = parse_result.catalog_item.id
    elif parse_result.custom_food:
        context_food["custom_food_id"] = str(parse_result.custom_food.id)

    assistant_msg = ChatMessage(
        conversation_id=conversation.id,
        role="assistant",
        content=vitali_message,
        channel="app",
        model_used="food_logging",
        context_data={"food_logged": context_food},
    )
    session.add(assistant_msg)
    await session.commit()
    await session.refresh(assistant_msg)

    # ── 7. Resposta ───────────────────────────────────────────────────────
    return AudioFoodResponseDTO(
        message_id=str(assistant_msg.id),
        conversation_id=str(conversation.id),
        transcription=transcription,
        content=vitali_message,
        food_logged={
            "food_name": food_name_display,
            "quantity_g": qty,
            "meal_name": meal,
            "kcal": logbook_entry.kcal,
            "protein": logbook_entry.protein,
            "carbs": logbook_entry.carbs,
            "fats": logbook_entry.fats,
            "logbook_entry_id": str(logbook_entry.id),
            "food_source": parse_result.source,
        },
        parse_confidence=parse_result.confidence,
        created_at=assistant_msg.created_at.isoformat() + "Z",
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
