"""Controller para o módulo de metas."""

from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.goal_dto import (
    CreateGoalDTO,
    UpdateGoalDTO,
    GoalResponseDTO,
    GoalDetailResponseDTO,
    PaginatedGoalsResponseDTO,
)
from app.services.goal_service import GoalService


class GoalController:
    """Controller para operações de metas."""

    def __init__(self, session: AsyncSession):
        self.service = GoalService(session)

    async def create_goal(self, dto: CreateGoalDTO) -> GoalResponseDTO:
        return await self.service.create_goal(dto)

    async def list_goals(
        self,
        user_id: Optional[UUID],
        status: Optional[str],
        page: int,
        limit: int,
    ) -> PaginatedGoalsResponseDTO:
        return await self.service.list_goals(user_id, status, page, limit)

    async def get_goal_by_id(self, goal_id: UUID) -> GoalDetailResponseDTO:
        return await self.service.get_goal_by_id(goal_id)

    async def update_goal(self, goal_id: UUID, dto: UpdateGoalDTO) -> GoalResponseDTO:
        return await self.service.update_goal(goal_id, dto)

    async def delete_goal(self, goal_id: UUID) -> None:
        await self.service.delete_goal(goal_id)
