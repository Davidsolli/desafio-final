"""Service de passos com regras de acesso e estatísticas."""

import logging
from datetime import date as date_type, datetime, timedelta
from typing import Optional
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.step_dto import (
    SyncStepsDTO,
    StepLogResponseDTO,
    StepHistoryResponseDTO,
)
from app.models.step_log import StepLog
from app.models.user import User
from app.repositories.step_repository import StepRepository

logger = logging.getLogger(__name__)


class StepAccessDeniedError(Exception):
    """Acesso não autorizado a registros de passos."""
    pass


class StepBusinessRuleError(Exception):
    """Violação de regra de negócio do módulo de passos."""
    pass


class StepService:
    """Serviço de passos."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.repository = StepRepository(session)

    @staticmethod
    def _to_response(log: StepLog, max_in_week: int) -> StepLogResponseDTO:
        is_record = log.steps > 0 and log.steps >= max_in_week
        return StepLogResponseDTO(
            id=log.id,
            user_id=log.user_id,
            date=log.date,
            steps=log.steps,
            distance_meters=log.distance_meters,
            is_week_record=is_record,
            created_at=log.created_at,
            updated_at=log.updated_at,
        )

    async def sync_steps(
        self, user_id: UUID, dto: SyncStepsDTO
    ) -> StepLogResponseDTO:
        """Cria ou atualiza o registro de passos do dia para o usuário."""
        if dto.date > date_type.today():
            raise StepBusinessRuleError("Não é possível registrar passos para uma data futura")

        log = await self.repository.upsert_day(
            user_id=user_id,
            day=dto.date,
            steps=dto.steps,
            distance_meters=dto.distance_meters,
        )
        await self.repository.commit()

        max_in_week = await self.repository.get_max_day_in_week(user_id, dto.date)
        return self._to_response(log, max_in_week)

    async def _build_history_response(
        self,
        user_id: UUID,
        start_date: date_type,
        end_date: date_type,
    ) -> StepHistoryResponseDTO:
        """Monta StepHistoryResponseDTO com estatísticas para o intervalo informado."""
        logs = await self.repository.list_history(user_id, start_date, end_date)

        today = date_type.today()
        max_in_week = await self.repository.get_max_day_in_week(user_id, today)
        weekly_best = await self.repository.get_weekly_best(user_id)
        current_week_total = await self.repository.get_current_week_total(user_id, today)

        is_new_record = (
            current_week_total > 0 and current_week_total >= weekly_best
        )

        return StepHistoryResponseDTO(
            logs=[self._to_response(log, max_in_week) for log in logs],
            weekly_best=weekly_best,
            current_week_total=current_week_total,
            is_new_week_record=is_new_record,
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
            raise StepBusinessRuleError("start_date deve ser anterior ou igual a end_date")

        return await self._build_history_response(user_id, start_date, end_date)

    async def get_student_history(
        self,
        student_id: UUID,
        requesting_user: User,
        start_date: Optional[date_type] = None,
        end_date: Optional[date_type] = None,
    ) -> StepHistoryResponseDTO:
        """
        Personal trainer (ou admin) acessa o histórico de um aluno.
        Valida que o aluno está vinculado ao personal solicitante.
        """
        if requesting_user.role == "admin":
            return await self.get_history(student_id, start_date, end_date)

        if requesting_user.role != "personal_trainer":
            raise StepAccessDeniedError(
                "Apenas personal trainers ou admins podem acessar o histórico de outros alunos"
            )

        # Valida vínculo trainer-aluno
        query = select(User).where(User.id == student_id)
        result = await self.session.execute(query)
        student = result.scalars().first()
        if student is None:
            raise StepAccessDeniedError("Aluno não encontrado")
        if student.trainer_id != requesting_user.id:
            raise StepAccessDeniedError(
                "Aluno não vinculado a este personal trainer"
            )

        return await self._build_history_response(
            student_id,
            start_date or (date_type.today() - timedelta(days=29)),
            end_date or date_type.today(),
        )
