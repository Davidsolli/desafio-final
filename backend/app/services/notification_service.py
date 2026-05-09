import asyncio
from uuid import UUID
from typing import List, Optional, Dict
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status

from app.repositories.notification_repository import NotificationRepository
from app.services.fcm_service import FCMService
from app.models.notification import NotificationPreference, NotificationLog
from app.dtos.notification_dto import UpdateNotificationPreferenceDTO, NotificationPreferenceResponseDTO

from app.models.user import User
from sqlalchemy import select

# Notificações essenciais que nunca podem ser desativadas (Card 15.16)
_ESSENTIAL_FIELDS = frozenset({"new_workout_sheet_enabled"})

# Mapeamento de tipo de notificação para o campo de preferência correspondente
_TYPE_TO_PREF_FIELD: Dict[str, str] = {
    "workout_reminder": "workout_reminder_enabled",
    "meal_reminder": "meal_reminder_enabled",
    "new_workout_sheet": "new_workout_sheet_enabled",
}


class NotificationService:
    def __init__(self, session: AsyncSession):
        self.repository = NotificationRepository(session)
        self.session = session
        self.fcm_service = FCMService()

    async def get_or_create_preferences(self, user_id: UUID) -> NotificationPreference:
        pref = await self.repository.get_preferences(user_id)
        if not pref:
            pref = NotificationPreference(user_id=user_id)
            await self.repository.create_preferences(pref)
        return pref

    async def update_preferences(self, user_id: UUID, dto: UpdateNotificationPreferenceDTO) -> NotificationPreference:
        update_data = dto.model_dump(exclude_unset=True)

        # Guard Card 15.16: impedir desativação de notificações essenciais
        for field in _ESSENTIAL_FIELDS:
            if field in update_data and update_data[field] is False:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"A notificação '{field}' é essencial e não pode ser desativada.",
                )

        pref = await self.get_or_create_preferences(user_id)
        for key, value in update_data.items():
            setattr(pref, key, value)

        return await self.repository.update_preferences(pref)

    async def update_fcm_token(self, user_id: UUID, token: str) -> None:
        query = select(User).where(User.id == user_id)
        result = await self.session.execute(query)
        user = result.scalars().first()
        if user:
            user.fcm_token = token
            await self.session.flush()
        else:
            raise HTTPException(status_code=404, detail="Usuário não encontrado")

    async def send_notification(
        self,
        user_id: UUID,
        type: str,
        title: str,
        body: str,
        data: Optional[Dict[str, str]] = None,
    ) -> NotificationLog:
        """
        Envia push notification via FCM e registra o log.
        Aplica todos os guards de preferência antes de chamar o Firebase:
        - notifications_enabled
        - tipo específico (workout_reminder_enabled, meal_reminder_enabled, etc.)
        - quiet hours
        - silent days
        """
        log = NotificationLog(
            user_id=user_id,
            notification_type=type,
            title=title,
            body=body,
            data=data,
            status="pending",
        )

        pref = await self.repository.get_preferences(user_id)

        # Guard 1: master switch
        if pref and not pref.notifications_enabled:
            log.status = "cancelled_by_preference"
            return await self.repository.create_log(log)

        # Guard 2: tipo específico
        pref_field = _TYPE_TO_PREF_FIELD.get(type)
        if pref and pref_field and not getattr(pref, pref_field, True):
            log.status = "cancelled_by_preference"
            return await self.repository.create_log(log)

        # Guard 3: quiet hours
        if pref and pref.quiet_hours_start and pref.quiet_hours_end:
            current_time = datetime.now(timezone.utc).time().replace(tzinfo=None)
            start = pref.quiet_hours_start
            end = pref.quiet_hours_end
            # overnight (ex: 22:00-07:00): start > end
            # same-day  (ex: 12:00-14:00): start <= end
            if start > end:
                in_quiet = current_time >= start or current_time <= end
            else:
                in_quiet = start <= current_time <= end
            if in_quiet:
                log.status = "cancelled_by_quiet_hours"
                return await self.repository.create_log(log)

        # Guard 4: silent days
        if pref and pref.silent_days:
            if datetime.now(timezone.utc).weekday() in pref.silent_days:
                log.status = "cancelled_by_silent_day"
                return await self.repository.create_log(log)

        # Buscar FCM token do usuário
        query = select(User).where(User.id == user_id)
        result = await self.session.execute(query)
        user = result.scalars().first()

        if not user or not user.fcm_token:
            log.status = "failed"
            log.error = "FCM token not found for user"
            return await self.repository.create_log(log)

        # Enviar via Firebase em thread separada para não bloquear o event loop
        success = await asyncio.to_thread(
            self.fcm_service.send_notification,
            token=user.fcm_token,
            title=title,
            body=body,
            data=data,
        )

        if success:
            log.status = "sent"
            log.sent_at = datetime.now(timezone.utc)
        else:
            log.status = "failed"
            log.error = "Firebase error"

        return await self.repository.create_log(log)

    async def get_history(self, user_id: UUID, notification_type: Optional[str] = None, limit: int = 20) -> List[NotificationLog]:
        return await self.repository.get_logs(user_id, notification_type, limit)

    async def mark_as_read(self, user_id: UUID, notification_id: UUID) -> None:
        log = await self.repository.mark_log_as_read(notification_id, user_id)
        if not log:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")
