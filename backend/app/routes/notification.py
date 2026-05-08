from fastapi import APIRouter
from app.controllers.notification_controller import NotificationController
from app.dtos.notification_dto import NotificationPreferenceResponseDTO

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
    summary="Obter histórico de notificações do usuário"
)

router.add_api_route(
    "/mark-read",
    NotificationController.mark_read,
    methods=["POST"],
    summary="Marcar uma notificação específica como lida"
)

router.add_api_route(
    "/token",
    NotificationController.update_token,
    methods=["PUT"],
    summary="Atualizar FCM Token (dispositivo) do usuário para receber pushes"
)
