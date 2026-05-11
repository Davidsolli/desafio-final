"""Service de metas com lógica de progresso e conclusão automática."""

import logging
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

logger = logging.getLogger(__name__)


class GoalNotFoundError(Exception):
    """Exceção para meta não encontrada."""
    pass


class GoalAccessDeniedError(Exception):
    """Exceção para acesso não autorizado a uma meta."""
    pass


class BusinessRuleError(Exception):
    """Exceção para violação de regra de negócio."""
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

    @staticmethod
    def _assert_owner_or_privileged(goal: Goal, requesting_user_id: UUID, user_role: str) -> None:
        """Verifica se o usuário tem permissão para modificar a meta.

        Aceita:
        - Dono da meta (user_id)
        - Criador da meta (created_by_id)
        - Personal trainer ou admin (qualquer meta)
        """
        is_owner = goal.user_id == requesting_user_id or goal.created_by_id == requesting_user_id
        is_privileged = user_role in ["personal_trainer", "admin"]

        if not (is_owner or is_privileged):
            raise GoalAccessDeniedError(
                "Acesso negado: apenas o dono, criador da meta, personal trainer ou admin podem modificá-la"
            )

    @staticmethod
    def _assert_not_completed(goal: Goal) -> None:
        """Garante que uma meta já concluída não seja editada."""
        if goal.status == "completed":
            raise BusinessRuleError("Meta já concluída não pode ser alterada")

    @staticmethod
    def _assert_progress_direction(goal: Goal, new_value: float) -> None:
        """Garante que o novo valor avança em direção ao target (nunca retrocede).

        Para metas de aumento (target > initial): new_value >= current_value.
        Para metas de redução (target < initial): new_value <= current_value.
        """
        is_reduction_goal = goal.target_value < goal.initial_value
        if is_reduction_goal:
            if new_value > goal.current_value:
                raise BusinessRuleError(
                    f"Para metas de redução, current_value não pode aumentar "
                    f"(atual: {goal.current_value}, informado: {new_value})"
                )
        else:
            if new_value < goal.current_value:
                raise BusinessRuleError(
                    f"current_value não pode diminuir "
                    f"(atual: {goal.current_value}, informado: {new_value})"
                )

    def _maybe_complete(self, goal: Goal) -> bool:
        """
        Marca meta como concluída se progresso atingiu 100%. Idempotente.

        Retorna True se houve transição para 'completed' agora (gatilho
        de notificação de conquista).
        """
        if goal.progress_percentage >= 100.0 and goal.status != "completed":
            goal.status = "completed"
            goal.completed_at = datetime.utcnow()
            logger.info("Meta concluída: goal_id=%s user_id=%s", goal.id, goal.user_id)
            return True
        return False

    async def update_goal(
        self,
        goal_id: UUID,
        dto: UpdateGoalDTO,
        requesting_user_id: UUID,
        user_role: str = "client",
    ) -> GoalResponseDTO:
        """Atualizar progresso com validação de acesso e regras de negócio."""
        goal = await self.repository.get_by_id(goal_id)
        if not goal:
            raise GoalNotFoundError(f"Meta {goal_id} não encontrada")

        self._assert_owner_or_privileged(goal, requesting_user_id, user_role)
        self._assert_not_completed(goal)

        completed_now = False
        if dto.current_value is not None:
            self._assert_progress_direction(goal, dto.current_value)
            goal.current_value = dto.current_value
            goal.progress_percentage = self._calculate_progress(
                goal.initial_value, goal.target_value, dto.current_value
            )
            completed_now = self._maybe_complete(goal)

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

        # RN09/RN10: dispara notificação de conquista (falha silenciosa)
        if completed_now:
            await self._notify_achievement_safe(updated)

        return self._to_response(updated)

    async def _notify_achievement_safe(self, goal: Goal) -> None:
        """Dispara notify_achievement com isolamento de falha (RN10)."""
        try:
            from app.services.notification_service import NotificationService

            service = NotificationService(self.session)
            await service.notify_achievement(
                user_id=goal.user_id,
                goal_id=goal.id,
                goal_title=goal.title,
            )
        except Exception as exc:
            logger.warning(
                "Falha ao notificar conquista (goal_id=%s): %s", goal.id, exc
            )

    async def delete_goal(
        self,
        goal_id: UUID,
        requesting_user_id: UUID,
        user_role: str = "client",
    ) -> None:
        """Deletar meta com validação de acesso."""
        goal = await self.repository.get_by_id(goal_id)
        if not goal:
            raise GoalNotFoundError(f"Meta {goal_id} não encontrada")
        self._assert_owner_or_privileged(goal, requesting_user_id, user_role)

        await self.repository.delete(goal_id)
        await self.repository.commit()
