from uuid import UUID
from typing import List, Optional
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update

from app.models.notification import NotificationPreference, NotificationLog, WorkoutReminderSchedule

class NotificationRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_preferences(self, user_id: UUID) -> Optional[NotificationPreference]:
        query = select(NotificationPreference).where(NotificationPreference.user_id == user_id)
        result = await self.session.execute(query)
        return result.scalars().first()

    async def create_preferences(self, preference: NotificationPreference) -> NotificationPreference:
        self.session.add(preference)
        await self.session.flush()
        return preference

    async def update_preferences(self, preference: NotificationPreference) -> NotificationPreference:
        await self.session.flush()
        return preference

    async def get_logs(self, user_id: UUID, notification_type: Optional[str] = None, limit: int = 20) -> List[NotificationLog]:
        query = select(NotificationLog).where(NotificationLog.user_id == user_id)
        if notification_type:
            query = query.where(NotificationLog.notification_type == notification_type)
        query = query.order_by(NotificationLog.created_at.desc()).limit(limit)
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def create_log(self, log: NotificationLog) -> NotificationLog:
        self.session.add(log)
        await self.session.flush()
        return log

    async def mark_log_as_read(self, log_id: UUID, user_id: UUID) -> Optional[NotificationLog]:
        query = select(NotificationLog).where(
            NotificationLog.id == log_id,
            NotificationLog.user_id == user_id
        )
        result = await self.session.execute(query)
        log = result.scalars().first()

        if log:
            log.read_at = datetime.now(timezone.utc)
            await self.session.flush()

        return log
