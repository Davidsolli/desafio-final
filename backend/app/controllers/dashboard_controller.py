"""
Controller do Dashboard Profissional.

Orquestra chamadas ao DashboardService e converte exceções de domínio
em HTTPException antes de chegarem ao router.
"""

from io import BytesIO
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.dashboard_dto import (
    AdminOverviewDTO,
    DashboardFiltersDTO,
    PaginatedStudentsDTO,
    Student360DTO,
)
from app.services.dashboard_service import (
    DashboardForbiddenError,
    DashboardNotFoundError,
    DashboardService,
)


class DashboardController:
    def __init__(self, session: AsyncSession) -> None:
        self.service = DashboardService(session)

    async def list_students(
        self,
        requester_id: UUID,
        role: str,
        filters: DashboardFiltersDTO,
    ) -> PaginatedStudentsDTO:
        return await self.service.get_personal_students(requester_id, role, filters)

    async def get_student_360(
        self, requester_id: UUID, student_id: UUID, role: str
    ) -> Student360DTO:
        return await self.service.get_student_360(requester_id, student_id, role)

    async def get_admin_overview(self, role: str) -> AdminOverviewDTO:
        return await self.service.get_admin_overview(role)

    async def generate_pdf(
        self, requester_id: UUID, student_id: UUID, role: str
    ) -> BytesIO:
        return await self.service.generate_pdf_report(requester_id, student_id, role)
