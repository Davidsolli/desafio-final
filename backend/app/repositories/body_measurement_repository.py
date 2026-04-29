from datetime import datetime
from typing import List, Optional, Tuple
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.body_measurement import BodyMeasurement


class BodyMeasurementRepository:
    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(self, measurement: BodyMeasurement) -> BodyMeasurement:
        self.session.add(measurement)
        await self.session.flush()
        await self.session.refresh(measurement)
        return measurement

    async def get_by_id(self, measurement_id: UUID) -> Optional[BodyMeasurement]:
        result = await self.session.execute(
            select(BodyMeasurement).where(BodyMeasurement.id == measurement_id)
        )
        return result.scalar_one_or_none()

    async def list_by_user(
        self, user_id: UUID, page: int, limit: int
    ) -> Tuple[List[BodyMeasurement], int]:
        offset = (page - 1) * limit

        count_result = await self.session.execute(
            select(func.count()).where(BodyMeasurement.user_id == user_id)
        )
        total = count_result.scalar_one()

        result = await self.session.execute(
            select(BodyMeasurement)
            .where(BodyMeasurement.user_id == user_id)
            .order_by(BodyMeasurement.measured_at.desc())
            .offset(offset)
            .limit(limit)
        )
        return result.scalars().all(), total

    async def get_latest_by_user(self, user_id: UUID) -> Optional[BodyMeasurement]:
        result = await self.session.execute(
            select(BodyMeasurement)
            .where(BodyMeasurement.user_id == user_id)
            .order_by(BodyMeasurement.measured_at.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()

    async def get_evolution(
        self, user_id: UUID, since: datetime
    ) -> List[BodyMeasurement]:
        result = await self.session.execute(
            select(BodyMeasurement)
            .where(
                BodyMeasurement.user_id == user_id,
                BodyMeasurement.measured_at >= since,
            )
            .order_by(BodyMeasurement.measured_at.asc())
        )
        return result.scalars().all()

    async def commit(self) -> None:
        await self.session.commit()

    async def rollback(self) -> None:
        await self.session.rollback()
