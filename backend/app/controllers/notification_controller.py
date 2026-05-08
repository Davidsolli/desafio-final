from uuid import UUID
from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.dtos.notification_dto import (
    UpdateNotificationPreferenceDTO,
    NotificationPreferenceResponseDTO,
    NotificationLogResponseDTO,
    MarkNotificationReadDTO
)
from app.services.notification_service import NotificationService

class NotificationController:
    
    @staticmethod
    async def get_preferences(
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user)
    ) -> NotificationPreferenceResponseDTO:
        service = NotificationService(db)
        pref = await service.get_or_create_preferences(current_user.id)
        return NotificationPreferenceResponseDTO.model_validate(pref)

    @staticmethod
    async def update_preferences(
        dto: UpdateNotificationPreferenceDTO,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user)
    ) -> NotificationPreferenceResponseDTO:
        service = NotificationService(db)
        pref = await service.update_preferences(current_user.id, dto)
        await db.commit()
        return NotificationPreferenceResponseDTO.model_validate(pref)

    @staticmethod
    async def get_history(
        type: Optional[str] = Query(None, description="Filtro opcional pelo tipo de notificação"),
        limit: int = Query(20, ge=1, le=100),
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user)
    ) -> dict:
        service = NotificationService(db)
        logs = await service.get_history(current_user.id, type, limit)
        data = [NotificationLogResponseDTO.model_validate(log) for log in logs]
        return {
            "total": len(data),
            "data": data
        }

    @staticmethod
    async def mark_read(
        dto: MarkNotificationReadDTO,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user)
    ) -> dict:
        service = NotificationService(db)
        await service.mark_as_read(current_user.id, dto.notification_id)
        await db.commit()
        return {"status": "success", "message": "Notification marked as read"}

    @staticmethod
    async def update_token(
        fcm_token: str,
        db: AsyncSession = Depends(get_db),
        current_user: User = Depends(get_current_user)
    ) -> dict:
        service = NotificationService(db)
        await service.update_fcm_token(current_user.id, fcm_token)
        await db.commit()
        return {"status": "success", "message": "FCM Token updated"}
