"""Controller para o módulo de contador de passos."""

from datetime import date as date_type
from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.step_dto import (
    SyncStepsDTO,
    StepLogResponseDTO,
    StepHistoryResponseDTO,
    UpdateStepGoalDTO,
)
from app.models.user import User
from app.services.step_service import StepService


class StepController:
    """Controller para operações de passos."""

    def __init__(self, session: AsyncSession):
        self.service = StepService(session)

    async def sync_steps(
        self, user_id: UUID, dto: SyncStepsDTO
    ) -> StepLogResponseDTO:
        return await self.service.sync_steps(user_id, dto)

    async def get_history(
        self,
        user_id: UUID,
        start_date: Optional[date_type] = None,
        end_date: Optional[date_type] = None,
    ) -> StepHistoryResponseDTO:
        return await self.service.get_history(user_id, start_date, end_date)

    async def get_student_history(
        self,
        student_id: UUID,
        requesting_user: User,
        start_date: Optional[date_type] = None,
        end_date: Optional[date_type] = None,
    ) -> StepHistoryResponseDTO:
        return await self.service.get_student_history(
            student_id, requesting_user, start_date, end_date
        )

    async def update_goal(self, user_id: UUID, dto: UpdateStepGoalDTO) -> None:
        return await self.service.update_goal(user_id, dto)

    async def update_student_goal(
        self, trainer: User, student_id: UUID, dto: UpdateStepGoalDTO
    ) -> None:
        return await self.service.update_student_goal(trainer, student_id, dto)
