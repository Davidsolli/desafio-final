"""Repositório para operações CRUD de registros de saúde."""

import uuid as uuid_lib
from datetime import date as date_type, datetime
from typing import List, Optional, Tuple
from uuid import UUID

from sqlalchemy import select, func, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.health_log import HeartRateLog, CalorieLog


class HealthRepository:
    """Repositório para HeartRateLog e CalorieLog."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def upsert_heart_rate_samples(
        self,
        user_id: UUID,
        samples: List[Tuple[datetime, int, bool, str]],
    ) -> int:
        """Insere amostras de FC ignorando duplicatas (mesmo user_id + measured_at).
        Retorna o número de amostras efetivamente inseridas.
        """
        if not samples:
            return 0

        # Normaliza para UTC naive (sem tzinfo) para compatibilidade com SQLite,
        # que armazena DATETIME sem fuso — Pydantic parseia "Z" como aware UTC.
        def _naive(dt: datetime) -> datetime:
            if dt.tzinfo is not None:
                return dt.replace(tzinfo=None)
            return dt

        normalized = [(_naive(ts), bpm, sw, sn) for ts, bpm, sw, sn in samples]
        timestamps = [ts for ts, *_ in normalized]

        existing_query = select(HeartRateLog.measured_at).where(
            and_(
                HeartRateLog.user_id == user_id,
                HeartRateLog.measured_at.in_(timestamps),
            )
        )
        result = await self.session.execute(existing_query)
        existing_ts = {row[0] for row in result.all()}

        inserted = 0
        for ts, bpm, is_from_smartwatch, source_name in normalized:
            if ts in existing_ts:
                continue
            log = HeartRateLog(
                id=uuid_lib.uuid4(),
                user_id=user_id,
                measured_at=ts,
                bpm=bpm,
                is_from_smartwatch=is_from_smartwatch,
                source_name=source_name or None,
            )
            self.session.add(log)
            existing_ts.add(ts)
            inserted += 1

        if inserted:
            await self.session.flush()
        return inserted

    async def upsert_daily_calories(
        self,
        user_id: UUID,
        day: date_type,
        active_calories: float,
        total_calories: float,
    ) -> CalorieLog:
        """Cria ou atualiza o registro de calorias do dia."""
        query = select(CalorieLog).where(
            and_(CalorieLog.user_id == user_id, CalorieLog.date == day)
        )
        result = await self.session.execute(query)
        existing = result.scalars().first()

        if existing is not None:
            existing.active_calories = active_calories
            existing.total_calories = total_calories
            return existing

        log = CalorieLog(
            user_id=user_id,
            date=day,
            active_calories=active_calories,
            total_calories=total_calories,
        )
        self.session.add(log)
        await self.session.flush()
        await self.session.refresh(log)
        return log

    async def get_daily_summary(
        self, user_id: UUID, day: date_type
    ) -> Optional[CalorieLog]:
        query = select(CalorieLog).where(
            and_(CalorieLog.user_id == user_id, CalorieLog.date == day)
        )
        result = await self.session.execute(query)
        return result.scalars().first()

    async def get_heart_rate_stats(
        self, user_id: UUID, day: date_type
    ) -> dict:
        """Retorna avg, min, max, contagem de BPM e metadados de smartwatch para o dia."""
        start = datetime.combine(day, datetime.min.time())
        end = datetime.combine(day, datetime.max.time())

        query = select(
            func.avg(HeartRateLog.bpm).label("avg_bpm"),
            func.min(HeartRateLog.bpm).label("min_bpm"),
            func.max(HeartRateLog.bpm).label("max_bpm"),
            func.count(HeartRateLog.id).label("count"),
        ).where(
            and_(
                HeartRateLog.user_id == user_id,
                HeartRateLog.measured_at >= start,
                HeartRateLog.measured_at <= end,
            )
        )
        result = await self.session.execute(query)
        row = result.one()

        # Busca o nome da fonte smartwatch (primeira amostra com is_from_smartwatch=True)
        smartwatch_query = (
            select(HeartRateLog.source_name)
            .where(
                and_(
                    HeartRateLog.user_id == user_id,
                    HeartRateLog.measured_at >= start,
                    HeartRateLog.measured_at <= end,
                    HeartRateLog.is_from_smartwatch.is_(True),
                )
            )
            .limit(1)
        )
        sw_result = await self.session.execute(smartwatch_query)
        sw_row = sw_result.first()

        return {
            "avg_bpm": float(row.avg_bpm) if row.avg_bpm else 0.0,
            "min_bpm": int(row.min_bpm) if row.min_bpm else 0,
            "max_bpm": int(row.max_bpm) if row.max_bpm else 0,
            "count": int(row.count),
            "is_from_smartwatch": sw_row is not None,
            "smartwatch_source_name": (sw_row[0] or "") if sw_row else "",
        }

    async def commit(self) -> None:
        """Persiste todas as alterações pendentes na sessão."""
        await self.session.commit()
