"""Controller para o módulo de dados de saúde."""

from datetime import date as date_type
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.health_dto import (
    HealthSyncRequestDTO,
    HealthSyncResponseDTO,
    HealthSummaryResponseDTO,
)
from app.services.health_service import HealthService


class HealthController:
    """Controller de saúde: orquestra requests HTTP → service."""

    def __init__(self, session: AsyncSession):
        self.service = HealthService(session)

    async def sync_health_data(
        self, user_id: UUID, dto: HealthSyncRequestDTO
    ) -> HealthSyncResponseDTO:
        return await self.service.sync_health_data(user_id, dto)

    async def get_summary(
        self, user_id: UUID, day: date_type
    ) -> HealthSummaryResponseDTO:
        return await self.service.get_summary(user_id, day)
