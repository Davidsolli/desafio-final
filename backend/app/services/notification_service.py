from uuid import UUID
from typing import List, Optional, Any, Dict
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status

from app.repositories.notification_repository import NotificationRepository
from app.services.fcm_service import FCMService
from app.models.notification import NotificationPreference, NotificationLog
from app.dtos.notification_dto import UpdateNotificationPreferenceDTO, NotificationPreferenceResponseDTO

# Para pegar o fcm_token do usuário:
from app.models.user import User
from sqlalchemy import select

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
        pref = await self.get_or_create_preferences(user_id)
        
        update_data = dto.model_dump(exclude_unset=True)
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

    async def send_notification(self, user_id: UUID, type: str, title: str, body: str, data: Optional[Dict[str, str]] = None) -> NotificationLog:
        """Envia uma push notification usando FCM e registra o log."""
        
        # 1. Pegar o usuário e token
        query = select(User).where(User.id == user_id)
        result = await self.session.execute(query)
        user = result.scalars().first()
        
        # 2. Criar registro inicial
        log = NotificationLog(
            user_id=user_id,
            notification_type=type,
            title=title,
            body=body,
            data=data,
            status="pending"
        )
        
        if not user or not user.fcm_token:
            log.status = "failed"
            log.error = "FCM token not found for user"
            await self.repository.create_log(log)
            return log

        # 3. Enviar via Firebase
        success = self.fcm_service.send_notification(
            token=user.fcm_token,
            title=title,
            body=body,
            data=data
        )
        
        # 4. Atualizar registro
        from datetime import datetime
        if success:
            log.status = "delivered"
            log.sent_at = datetime.utcnow()
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
