from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.config.limiter import limiter
from app.controllers.notification_controller import NotificationController
from app.dependencies.auth import get_current_user
from app.dtos.notification_dto import (
    NotificationPreferenceResponseDTO,
    NotificationLogResponseDTO,
    UpdateFCMTokenDTO,
)
from app.models.user import User

router = APIRouter(
    prefix="/api/v1/notifications",
    tags=["Notifications"],
)

router.add_api_route(
    "/preferences",
    NotificationController.get_preferences,
    methods=["GET"],
    response_model=NotificationPreferenceResponseDTO,
    summary="Obter preferências de notificação do usuário atual"
)

router.add_api_route(
    "/preferences",
    NotificationController.update_preferences,
    methods=["PUT"],
    response_model=NotificationPreferenceResponseDTO,
    summary="Atualizar preferências de notificação do usuário atual"
)

router.add_api_route(
    "/history",
    NotificationController.get_history,
    methods=["GET"],
    response_model=dict,
    summary="Obter histórico de notificações do usuário"
)

router.add_api_route(
    "/mark-read",
    NotificationController.mark_read,
    methods=["POST"],
    response_model=dict,
    summary="Marcar uma notificação específica como lida"
)


@router.put(
    "/token",
    summary="Atualizar FCM Token (dispositivo) do usuário para receber pushes",
    responses={
        200: {"description": "Token atualizado"},
        401: {"description": "Não autenticado"},
        429: {"description": "Muitas tentativas — tente novamente mais tarde"},
    },
)
@limiter.limit("60/minute")
async def update_token(
    request: Request,
    dto: UpdateFCMTokenDTO,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
) -> dict:
    return await NotificationController.update_token(
        dto=dto,
        db=db,
        current_user=current_user,
    )
