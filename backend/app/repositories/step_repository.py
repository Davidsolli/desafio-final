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
    ) -> StepLog:
        """Cria ou atualiza o registro do dia para o usuário."""
        existing = await self.get_by_user_and_date(user_id, day)
        if existing is not None:
            # Atualiza apenas se a nova contagem for maior (sensor é cumulativo)
            if steps > existing.steps:
                existing.steps = steps
                existing.distance_meters = distance_meters
            return existing

        log = StepLog(
            user_id=user_id,
            date=day,
            steps=steps,
            distance_meters=distance_meters,
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

    async def get_weekly_best(self, user_id: UUID) -> int:
        """
        Calcula a maior soma semanal de passos já registrada pelo usuário.
        Usa semana ISO (segunda a domingo).
        """
        # date_trunc não suporta 'isoweek', então truncamos para 'week' (segunda-feira no PG)
        week_col = func.date_trunc("week", StepLog.date)
        query = (
            select(week_col.label("week_start"), func.sum(StepLog.steps).label("total"))
            .where(StepLog.user_id == user_id)
            .group_by(week_col)
            .order_by(func.sum(StepLog.steps).desc())
            .limit(1)
        )
        result = await self.session.execute(query)
        row = result.first()
        if row is None:
            return 0
        return int(row.total or 0)

    async def get_current_week_total(self, user_id: UUID, today: date_type) -> int:
        """Total de passos da semana atual (segunda → domingo)."""
        # Segunda-feira da semana atual (Python: weekday() = 0 para segunda)
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

    async def get_max_day_in_week(
        self, user_id: UUID, day: date_type
    ) -> int:
        """Maior contagem de passos em um único dia da semana de `day`."""
        monday = day - timedelta(days=day.weekday())
        sunday = monday + timedelta(days=6)

        query = select(func.coalesce(func.max(StepLog.steps), 0)).where(
            and_(
                StepLog.user_id == user_id,
                StepLog.date >= monday,
                StepLog.date <= sunday,
            )
        )
        result = await self.session.execute(query)
        return int(result.scalar() or 0)

    async def commit(self) -> None:
        await self.session.commit()

    async def rollback(self) -> None:
        await self.session.rollback()
