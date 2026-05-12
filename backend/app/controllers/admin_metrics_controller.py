"""Controller de Métricas Admin. Orquestra service → DTOs."""

from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.admin_metrics_dto import (
    AIAnalyticsDTO,
    PaginatedStudentMetricsDTO,
    PaginatedTrainerMetricsDTO,
    SystemMetricsDTO,
)
from app.services.admin_metrics_service import AdminMetricsService


class AdminMetricsController:
    """Controller para métricas do painel administrativo."""

    def __init__(self, session: AsyncSession):
        self.service = AdminMetricsService(session)

    async def get_student_metrics(
        self,
        trainer_id: Optional[UUID],
        days: int,
        page: int,
        limit: int,
    ) -> PaginatedStudentMetricsDTO:
        return await self.service.get_student_metrics(trainer_id, days, page, limit)

    async def get_trainer_metrics(
        self,
        days: int,
        page: int,
        limit: int,
    ) -> PaginatedTrainerMetricsDTO:
        return await self.service.get_trainer_metrics(days, page, limit)

    async def get_system_metrics(self, days: int) -> SystemMetricsDTO:
        return await self.service.get_system_metrics(days)

    async def get_ai_analytics(self, days: int) -> AIAnalyticsDTO:
        return await self.service.get_ai_analytics(days)
