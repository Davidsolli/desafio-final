"""Repositório para operações CRUD de registros de passos."""

from datetime import date as date_type, timedelta
from typing import Optional, List
from uuid import UUID

from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.step_log import StepLog


class StepRepository:
    """Repositório para operações de StepLog."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def get_by_user_and_date(
        self, user_id: UUID, day: date_type
    ) -> Optional[StepLog]:
        query = select(StepLog).where(
            and_(StepLog.user_id == user_id, StepLog.date == day)
        )
        result = await self.session.execute(query)
        return result.scalars().first()

    async def upsert_day(
        self,
        user_id: UUID,
        day: date_type,
        steps: int,
        distance_meters: float,
        handicap_level: Optional[int] = None,
    ) -> StepLog:
        """Cria ou atualiza o registro do dia para o usuário."""
        existing = await self.get_by_user_and_date(user_id, day)
        if existing is not None:
            # Atualiza apenas se a nova contagem for maior (sensor é cumulativo)
            if steps > existing.steps:
                existing.steps = steps
                existing.distance_meters = distance_meters
            # Handicap é sempre atualizado (usuário pode mudar o nível durante o dia)
            existing.handicap_level = handicap_level
            return existing

        log = StepLog(
            user_id=user_id,
            date=day,
            steps=steps,
            distance_meters=distance_meters,
            handicap_level=handicap_level,
        )
        self.session.add(log)
        await self.session.flush()
        await self.session.refresh(log)
        return log

    async def list_history(
        self,
        user_id: UUID,
        start_date: date_type,
        end_date: date_type,
    ) -> List[StepLog]:
        query = (
            select(StepLog)
            .where(
                and_(
                    StepLog.user_id == user_id,
                    StepLog.date >= start_date,
                    StepLog.date <= end_date,
                )
            )
            .order_by(StepLog.date.asc())
        )
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def get_all_time_record(self, user_id: UUID) -> int:
        """Retorna a maior contagem de passos num único dia já registrada."""
        query = select(func.max(StepLog.steps)).where(StepLog.user_id == user_id)
        result = await self.session.execute(query)
        return int(result.scalar() or 0)

    async def get_current_week_total(self, user_id: UUID, today: date_type) -> int:
        """Total de passos da semana atual (segunda → domingo)."""
        monday = today - timedelta(days=today.weekday())
        sunday = monday + timedelta(days=6)

        query = select(func.coalesce(func.sum(StepLog.steps), 0)).where(
            and_(
                StepLog.user_id == user_id,
                StepLog.date >= monday,
                StepLog.date <= sunday,
            )
        )
        result = await self.session.execute(query)
        total = result.scalar() or 0
        return int(total)

    async def commit(self) -> None:
        await self.session.commit()

    async def rollback(self) -> None:
        await self.session.rollback()
