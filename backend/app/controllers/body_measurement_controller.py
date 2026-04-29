from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.body_measurement_dto import (
    CreateMeasurementDTO,
    EvolutionResponseDTO,
    MeasurementResponseDTO,
    PaginatedMeasurementsResponseDTO,
)
from app.models.user import User
from app.services.body_measurement_service import BodyMeasurementService


class BodyMeasurementController:
    def __init__(self, session: AsyncSession):
        self.service = BodyMeasurementService(session)

    async def create_measurement(
        self, dto: CreateMeasurementDTO, current_user: User
    ) -> MeasurementResponseDTO:
        return await self.service.create(dto, current_user)

    async def list_measurements(
        self,
        user_id: UUID | None,
        requesting_user: User,
        page: int,
        limit: int,
    ) -> PaginatedMeasurementsResponseDTO:
        return await self.service.list_measurements(user_id, requesting_user, page, limit)

    async def get_latest(
        self, user_id: UUID | None, requesting_user: User
    ) -> MeasurementResponseDTO:
        return await self.service.get_latest(user_id, requesting_user)

    async def get_evolution(
        self,
        user_id: UUID | None,
        metric: str,
        days: int,
        requesting_user: User,
    ) -> EvolutionResponseDTO:
        return await self.service.get_evolution(user_id, metric, days, requesting_user)
