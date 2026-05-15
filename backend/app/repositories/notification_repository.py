from uuid import UUID
from typing import List, Optional
from datetime import datetime, timezone, timedelta
from zoneinfo import ZoneInfo
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, func

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

    async def has_log_today_local(
        self,
        user_id: UUID,
        notification_type: str,
        tz_name: str,
    ) -> bool:
        """
        Retorna True se já existe um NotificationLog do tipo dado para o
        usuário cujo `created_at` cai no mesmo dia local (no fuso `tz_name`).

        Usado pela idempotência diária do meal_reminder (RN05/RN08 da Fase 2).
        Não delega ao banco a conversão de timezone para evitar dependência de
        dialeto (alguns testes rodam em SQLite); calcula limites em UTC e
        filtra por `created_at` no intervalo.
        """
        try:
            tz = ZoneInfo(tz_name)
        except Exception:
            tz = ZoneInfo("America/Sao_Paulo")

        now_local = datetime.now(tz)
        start_local = now_local.replace(hour=0, minute=0, second=0, microsecond=0)
        end_local = start_local + timedelta(days=1)
        start_utc = start_local.astimezone(timezone.utc)
        end_utc = end_local.astimezone(timezone.utc)

        query = (
            select(NotificationLog.id)
            .where(
                NotificationLog.user_id == user_id,
                NotificationLog.notification_type == notification_type,
                NotificationLog.created_at >= start_utc,
                NotificationLog.created_at < end_utc,
            )
            .limit(1)
        )
        result = await self.session.execute(query)
        return result.scalars().first() is not None
