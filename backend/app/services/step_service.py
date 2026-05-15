"""Service de passos com regras de acesso e estatísticas."""

import logging
from datetime import date as date_type, timedelta
from typing import List, Optional
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.step_dto import (
    SyncStepsDTO,
    StepLogResponseDTO,
    StepHistoryResponseDTO,
    UpdateStepGoalDTO,
)
from app.models.step_log import StepLog
from app.models.user import User
from app.repositories.step_repository import StepRepository

logger = logging.getLogger(__name__)


class StepAccessDeniedError(Exception):
    """Acesso não autorizado a registros de passos."""


class StepBusinessRuleError(Exception):
    """Violação de regra de negócio do módulo de passos."""


class StepService:
    """Serviço de passos."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.repository = StepRepository(session)

    # ------------------------------------------------------------------
    # Utilitários
    # ------------------------------------------------------------------

    @staticmethod
    def _effective_goal(daily_goal: int, level: Optional[int]) -> int:
        """Meta efetiva após aplicar nível de proteção de sequência."""
        fracs = {1: 3 / 4, 2: 2 / 4, 3: 1 / 4}
        return int(daily_goal * fracs.get(level, 1))

    @staticmethod
    def _calc_calories(steps: int, weight_kg: Optional[float]) -> float:
        """Estima calorias queimadas: steps × 0.04 × (peso/70).
        Fórmula simplificada usada por Fitbit/Google Fit; fallback 70 kg.
        """
        kg = weight_kg if weight_kg and weight_kg > 0 else 70.0
        return round(steps * 0.04 * (kg / 70.0), 1)

    def _to_response(
        self,
        log: StepLog,
        all_time_record: int,
        weight_kg: Optional[float],
    ) -> StepLogResponseDTO:
        is_record = log.steps > 0 and log.steps >= all_time_record
        return StepLogResponseDTO(
            id=log.id,
            user_id=log.user_id,
            date=log.date,
            steps=log.steps,
            distance_meters=log.distance_meters,
            calories_burned=self._calc_calories(log.steps, weight_kg),
            is_all_time_record=is_record,
            handicap_level=log.handicap_level,
            created_at=log.created_at,
            updated_at=log.updated_at,
        )

    def _calculate_streak(
        self,
        logs: List,
        daily_goal: int,
        today: date_type,
    ) -> int:
        """Conta dias consecutivos em que steps >= meta efetiva do dia."""
        logs_by_date = {log.date: log for log in logs}
        streak = 0

        # Verificar se hoje já bateu a meta (conta, mas não quebra se não bateu)
        today_log = logs_by_date.get(today)
        if today_log:
            eff = self._effective_goal(daily_goal, today_log.handicap_level)
            if today_log.steps >= eff:
                streak = 1

        # Retroagir pelos dias anteriores
        current = today - timedelta(days=1)
        while True:
            log = logs_by_date.get(current)
            if not log:
                break
            eff = self._effective_goal(daily_goal, log.handicap_level)
            if log.steps >= eff:
                streak += 1
                current -= timedelta(days=1)
            else:
                break

        return streak

    # ------------------------------------------------------------------
    # Operações principais
    # ------------------------------------------------------------------

    async def _get_user(self, user_id: UUID) -> Optional[User]:
        result = await self.session.execute(select(User).where(User.id == user_id))
        return result.scalars().first()

    async def sync_steps(
        self, user_id: UUID, dto: SyncStepsDTO
    ) -> StepLogResponseDTO:
        """Cria ou atualiza o registro de passos do dia para o usuário."""
        if dto.date > date_type.today():
            raise StepBusinessRuleError(
                "Não é possível registrar passos para uma data futura"
            )

        log = await self.repository.upsert_day(
            user_id=user_id,
            day=dto.date,
            steps=dto.steps,
            distance_meters=dto.distance_meters,
            handicap_level=dto.handicap_level,
        )
        await self.repository.commit()

        user = await self._get_user(user_id)
        weight_kg = user.weight if user else None
        all_time = await self.repository.get_all_time_record(user_id)
        return self._to_response(log, all_time, weight_kg)

    async def _build_history_response(
        self,
        user_id: UUID,
        start_date: date_type,
        end_date: date_type,
    ) -> StepHistoryResponseDTO:
        """Monta StepHistoryResponseDTO com estatísticas para o intervalo informado."""
        logs = await self.repository.list_history(user_id, start_date, end_date)

        today = date_type.today()
        all_time = await self.repository.get_all_time_record(user_id)
        current_week_total = await self.repository.get_current_week_total(user_id, today)

        user = await self._get_user(user_id)
        weight_kg = user.weight if user else None
        daily_goal = user.daily_step_goal if user else 1000

        # Precisa de todos os logs (não só o intervalo) para calcular streak
        all_logs = await self.repository.list_history(
            user_id,
            today - timedelta(days=365),
            today,
        )
        streak = self._calculate_streak(all_logs, daily_goal, today)

        # Calorias de hoje
        today_log = next((l for l in all_logs if l.date == today), None)
        today_steps = today_log.steps if today_log else 0
        total_calories_today = self._calc_calories(today_steps, weight_kg)

        return StepHistoryResponseDTO(
            logs=[self._to_response(log, all_time, weight_kg) for log in logs],
            all_time_record=all_time,
            current_week_total=current_week_total,
            current_streak=streak,
            daily_step_goal=daily_goal,
            total_calories_today=total_calories_today,
        )

    async def get_history(
        self,
        user_id: UUID,
        start_date: Optional[date_type] = None,
        end_date: Optional[date_type] = None,
    ) -> StepHistoryResponseDTO:
        """Histórico de passos do próprio usuário."""
        if end_date is None:
            end_date = date_type.today()
        if start_date is None:
            start_date = end_date - timedelta(days=29)
        if start_date > end_date:
            raise StepBusinessRuleError(
                "start_date deve ser anterior ou igual a end_date"
            )
        return await self._build_history_response(user_id, start_date, end_date)

    async def get_student_history(
        self,
        student_id: UUID,
        requesting_user: User,
        start_date: Optional[date_type] = None,
        end_date: Optional[date_type] = None,
    ) -> StepHistoryResponseDTO:
        """Personal trainer (ou admin) acessa o histórico de um aluno."""
        if requesting_user.role == "admin":
            return await self.get_history(student_id, start_date, end_date)

        from app.utils.role_utils import is_professional
        if not is_professional(requesting_user.role):
            raise StepAccessDeniedError(
                "Apenas profissionais ou admins podem acessar o histórico de outros alunos"
            )

        result = await self.session.execute(select(User).where(User.id == student_id))
        student = result.scalars().first()
        if student is None:
            raise StepAccessDeniedError("Aluno não encontrado")
        if student.trainer_id != requesting_user.id:
            raise StepAccessDeniedError("Aluno não vinculado a este personal trainer")

        return await self._build_history_response(
            student_id,
            start_date or (date_type.today() - timedelta(days=29)),
            end_date or date_type.today(),
        )

    async def update_goal(self, user_id: UUID, dto: UpdateStepGoalDTO) -> None:
        """Atualiza a meta diária de passos do próprio usuário."""
        user = await self._get_user(user_id)
        if user is None:
            raise StepBusinessRuleError("Usuário não encontrado")
        user.daily_step_goal = dto.daily_step_goal
        await self.session.commit()

    async def update_student_goal(
        self,
        trainer: User,
        student_id: UUID,
        dto: UpdateStepGoalDTO,
    ) -> None:
        """Personal trainer atualiza a meta de um aluno."""
        result = await self.session.execute(select(User).where(User.id == student_id))
        student = result.scalars().first()
        if student is None:
            raise StepBusinessRuleError("Aluno não encontrado")
        if trainer.role != "admin" and student.trainer_id != trainer.id:
            raise StepAccessDeniedError("Aluno não vinculado a este personal trainer")
        student.daily_step_goal = dto.daily_step_goal
        await self.session.commit()
