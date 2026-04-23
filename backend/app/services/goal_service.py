"""Service de metas com lógica de progresso e conclusão automática."""

from datetime import datetime
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
from app.models.goal import Goal, GoalProgressEntry
from app.repositories.goal_repository import GoalRepository


class GoalNotFoundError(Exception):
    """Exceção para meta não encontrada."""
    pass


class GoalService:
    """Serviço de metas com cálculo automático de progresso."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.repository = GoalRepository(session)

    @staticmethod
    def _calculate_progress(initial: float, target: float, current: float) -> float:
        """Calcula percentual de progresso (0-100)."""
        diff = target - initial
        if diff == 0:
            return 100.0 if current == target else 0.0
        progress = (current - initial) / diff * 100
        return min(100.0, max(0.0, progress))

    @staticmethod
    def _to_response(goal: Goal) -> GoalResponseDTO:
        return GoalResponseDTO.model_validate(goal)

    @staticmethod
    def _to_detail_response(goal: Goal) -> GoalDetailResponseDTO:
        return GoalDetailResponseDTO.model_validate(goal)

    async def create_goal(self, dto: CreateGoalDTO) -> GoalResponseDTO:
        """Criar nova meta com entrada inicial de progresso."""
        created_by_id = dto.created_by_id or dto.user_id
        target_datetime = datetime.combine(dto.target_date, datetime.min.time())

        goal = Goal(
            user_id=dto.user_id,
            created_by_id=created_by_id,
            title=dto.title,
            description=dto.description,
            category=dto.category,
            target_value=dto.target_value,
            current_value=dto.current_value,
            initial_value=dto.current_value,
            unit=dto.unit,
            start_date=datetime.utcnow(),
            target_date=target_datetime,
            status="active",
            progress_percentage=0.0,
        )

        created_goal = await self.repository.create(goal)

        entry = GoalProgressEntry(
            goal_id=created_goal.id,
            current_value=dto.current_value,
            recorded_at=datetime.utcnow(),
            notes="Meta criada",
        )
        await self.repository.create_progress_entry(entry)
        await self.repository.commit()

        refreshed = await self.repository.get_by_id(created_goal.id)
        return self._to_response(refreshed)

    async def list_goals(
        self,
        user_id: Optional[UUID] = None,
        status: Optional[str] = None,
        page: int = 1,
        limit: int = 10,
    ) -> PaginatedGoalsResponseDTO:
        """Listar metas com filtros e paginação."""
        goals, total = await self.repository.list_goals(user_id, status, page, limit)
        data = [self._to_response(g) for g in goals]
        return PaginatedGoalsResponseDTO(total=total, page=page, data=data)

    async def get_goal_by_id(self, goal_id: UUID) -> GoalDetailResponseDTO:
        """Buscar meta por ID com histórico completo de progresso."""
        goal = await self.repository.get_by_id(goal_id)
        if not goal:
            raise GoalNotFoundError(f"Meta {goal_id} não encontrada")
        return self._to_detail_response(goal)

    async def update_goal(self, goal_id: UUID, dto: UpdateGoalDTO) -> GoalResponseDTO:
        """Atualizar progresso e verificar conclusão automática."""
        goal = await self.repository.get_by_id(goal_id)
        if not goal:
            raise GoalNotFoundError(f"Meta {goal_id} não encontrada")

        if dto.current_value is not None:
            goal.current_value = dto.current_value
            goal.progress_percentage = self._calculate_progress(
                goal.initial_value, goal.target_value, dto.current_value
            )

            if goal.progress_percentage >= 100.0 and goal.status != "completed":
                goal.status = "completed"
                goal.completed_at = datetime.utcnow()

            entry = GoalProgressEntry(
                goal_id=goal.id,
                current_value=dto.current_value,
                recorded_at=datetime.utcnow(),
                notes=dto.notes,
            )
            await self.repository.create_progress_entry(entry)

        if dto.status is not None and goal.status != "completed":
            goal.status = dto.status

        goal.updated_at = datetime.utcnow()
        updated = await self.repository.update(goal)
        await self.repository.commit()

        return self._to_response(updated)

    async def delete_goal(self, goal_id: UUID) -> None:
        """Deletar meta e todo seu histórico."""
        deleted = await self.repository.delete(goal_id)
        if not deleted:
            raise GoalNotFoundError(f"Meta {goal_id} não encontrada")
        await self.repository.commit()
