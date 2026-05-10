"""
Repositório do módulo Logbook.

Responsável pelo acesso direto ao banco de dados para sessões de treino
e exercícios registrados. Sem lógica de negócio — apenas queries.
"""

from datetime import datetime
from typing import List, Optional, Tuple
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.logbook import SessionExercise, WorkoutSession


class LogbookRepository:
    """Repositório de operações de banco para o módulo Logbook."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    # ------------------------------------------------------------------
    # Sessões
    # ------------------------------------------------------------------

    async def create_session(self, session_obj: WorkoutSession) -> WorkoutSession:
        """Persiste uma nova sessão de treino."""
        self.session.add(session_obj)
        await self.session.flush()
        await self.session.refresh(session_obj)
        return session_obj

    async def get_session_by_id(self, session_id: UUID) -> Optional[WorkoutSession]:
        """Busca sessão pelo UUID, excluindo soft-deleted."""
        stmt = select(WorkoutSession).where(
            WorkoutSession.id == session_id,
            WorkoutSession.status != "deleted",
        )
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def get_session_by_id_any_status(self, session_id: UUID) -> Optional[WorkoutSession]:
        """Busca sessão pelo UUID independente do status (inclusive deleted)."""
        stmt = select(WorkoutSession).where(WorkoutSession.id == session_id)
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def get_in_progress_session(self, user_id: UUID) -> Optional[WorkoutSession]:
        """Retorna a sessão 'in_progress' de um aluno, se existir."""
        stmt = select(WorkoutSession).where(
            WorkoutSession.user_id == user_id,
            WorkoutSession.status == "in_progress",
        )
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def update_session(self, session_obj: WorkoutSession) -> WorkoutSession:
        """Atualiza a sessão no banco."""
        session_obj.updated_at = datetime.utcnow()
        await self.session.flush()
        await self.session.refresh(session_obj)
        return session_obj

    async def soft_delete_session(self, session_id: UUID) -> bool:
        """Marca a sessão como 'deleted' (soft delete). Retorna True se encontrada."""
        session_obj = await self.get_session_by_id(session_id)
        if not session_obj:
            return False
        session_obj.status = "deleted"
        session_obj.updated_at = datetime.utcnow()
        await self.session.flush()
        return True

    async def list_sessions(
        self,
        user_id: Optional[UUID],
        start_date: Optional[datetime],
        end_date: Optional[datetime],
        status_filter: Optional[str],
        page: int,
        limit: int,
    ) -> Tuple[List[WorkoutSession], int]:
        """
        Lista sessões com filtros e paginação.

        Returns:
            Tuple[List[WorkoutSession], int]: Sessões da página e total.
        """
        base_stmt = select(WorkoutSession).where(WorkoutSession.status != "deleted")

        if user_id is not None:
            base_stmt = base_stmt.where(WorkoutSession.user_id == user_id)
        if start_date is not None:
            base_stmt = base_stmt.where(WorkoutSession.session_date >= start_date)
        if end_date is not None:
            base_stmt = base_stmt.where(WorkoutSession.session_date <= end_date)
        if status_filter is not None:
            base_stmt = base_stmt.where(WorkoutSession.status == status_filter)

        # Total
        count_stmt = select(func.count()).select_from(base_stmt.subquery())
        total_result = await self.session.execute(count_stmt)
        total = total_result.scalar() or 0

        # Página
        offset = (page - 1) * limit
        paged_stmt = (
            base_stmt.order_by(WorkoutSession.session_date.desc())
            .offset(offset)
            .limit(limit)
        )
        result = await self.session.execute(paged_stmt)
        sessions = list(result.scalars().all())

        return sessions, total

    async def count_exercises_in_session(self, session_id: UUID) -> int:
        """Conta quantos exercícios existem em uma sessão."""
        stmt = select(func.count()).where(SessionExercise.session_id == session_id)
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    # ------------------------------------------------------------------
    # Exercícios
    # ------------------------------------------------------------------

    async def add_exercise(self, exercise: SessionExercise) -> SessionExercise:
        """Persiste um exercício em uma sessão."""
        self.session.add(exercise)
        await self.session.flush()
        await self.session.refresh(exercise)
        return exercise

    async def get_exercise_by_session_and_exercise(
        self, session_id: UUID, exercise_id: UUID
    ) -> Optional[SessionExercise]:
        """Busca exercício pelo session_id + exercise_id (para upsert)."""
        stmt = select(SessionExercise).where(
            SessionExercise.session_id == session_id,
            SessionExercise.exercise_id == exercise_id,
        )
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def update_exercise(self, exercise: SessionExercise) -> SessionExercise:
        """Atualiza um exercício existente."""
        exercise.updated_at = datetime.utcnow()
        await self.session.flush()
        await self.session.refresh(exercise)
        return exercise

    async def list_exercises_for_session(self, session_id: UUID) -> List[SessionExercise]:
        """Lista todos os exercícios de uma sessão."""
        stmt = select(SessionExercise).where(SessionExercise.session_id == session_id)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    # ------------------------------------------------------------------
    # Calendário
    # ------------------------------------------------------------------

    async def get_sessions_in_month(
        self, user_id: UUID, year: int, month: int
    ) -> List[WorkoutSession]:
        """
        Retorna sessões do aluno em um dado mês/ano.
        Exclui soft-deleted.
        """
        from datetime import date
        import calendar

        first_day = datetime(year, month, 1)
        last_day_num = calendar.monthrange(year, month)[1]
        last_day = datetime(year, month, last_day_num, 23, 59, 59)

        stmt = select(WorkoutSession).where(
            WorkoutSession.user_id == user_id,
            WorkoutSession.status != "deleted",
            WorkoutSession.session_date >= first_day,
            WorkoutSession.session_date <= last_day,
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    # ------------------------------------------------------------------
    # Progressão
    # ------------------------------------------------------------------

    async def get_progression_data(
        self,
        user_id: UUID,
        exercise_id: UUID,
        start_date: Optional[datetime],
        end_date: Optional[datetime],
    ) -> List[SessionExercise]:
        """
        Retorna exercícios de um aluno para um dado exercise_id,
        ordenados por data da sessão.
        """
        stmt = (
            select(SessionExercise)
            .join(
                WorkoutSession,
                SessionExercise.session_id == WorkoutSession.id,
            )
            .where(
                WorkoutSession.user_id == user_id,
                SessionExercise.exercise_id == exercise_id,
                WorkoutSession.status == "completed",
                SessionExercise.actual_load_kg.isnot(None),
            )
        )

        if start_date is not None:
            stmt = stmt.where(WorkoutSession.session_date >= start_date)
        if end_date is not None:
            stmt = stmt.where(WorkoutSession.session_date <= end_date)

        stmt = stmt.order_by(WorkoutSession.session_date.asc())
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_session_date_for_exercise(self, exercise: SessionExercise) -> Optional[datetime]:
        """Obtém a session_date da sessão associada a um exercício."""
        session_obj = await self.session.get(WorkoutSession, exercise.session_id)
        return session_obj.session_date if session_obj else None

    # ------------------------------------------------------------------
    # Frequência (Novo)
    # ------------------------------------------------------------------

    async def get_frequency_data(
        self,
        user_id: UUID,
        period: str,
        start_date: Optional[datetime],
        end_date: Optional[datetime],
    ) -> List[Tuple[datetime, int]]:
        """
        Retorna frequência de treinos agrupados por período.

        Args:
            user_id: ID do aluno
            period: "week" ou "month"
            start_date: Data inicial (opcional)
            end_date: Data final (opcional)

        Returns:
            Lista de tuplas (period_start_datetime, count)
        """
        if self.session.bind.dialect.name == "sqlite":
            from collections import defaultdict
            from datetime import timedelta

            stmt = (
                select(WorkoutSession.session_date)
                .where(
                    WorkoutSession.user_id == user_id,
                    WorkoutSession.status == "completed",
                )
                .order_by(WorkoutSession.session_date.asc())
            )
            if start_date is not None:
                stmt = stmt.where(WorkoutSession.session_date >= start_date)
            if end_date is not None:
                stmt = stmt.where(WorkoutSession.session_date <= end_date)

            result = await self.session.execute(stmt)
            session_dates = [row[0] for row in result.all()]

            counts = defaultdict(int)
            for dt in session_dates:
                if isinstance(dt, str):
                    dt = datetime.fromisoformat(dt)
                if period == "week":
                    truncated = dt - timedelta(days=dt.weekday())
                elif period == "month":
                    truncated = datetime(dt.year, dt.month, 1)
                else:
                    raise ValueError("period deve ser 'week' ou 'month'")

                truncated = truncated.replace(hour=0, minute=0, second=0, microsecond=0)
                counts[truncated] += 1

            return [(dt, count) for dt, count in sorted(counts.items())]

        if period == "week":
            date_trunc_expr = func.date_trunc("week", WorkoutSession.session_date)
        elif period == "month":
            date_trunc_expr = func.date_trunc("month", WorkoutSession.session_date)
        else:
            raise ValueError("period deve ser 'week' ou 'month'")

        stmt = (
            select(
                date_trunc_expr.label("period_start"),
                func.count(WorkoutSession.id).label("count"),
            )
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.status == "completed",
            )
            .group_by(date_trunc_expr)
            .order_by(date_trunc_expr.asc())
        )

        if start_date is not None:
            stmt = stmt.where(WorkoutSession.session_date >= start_date)
        if end_date is not None:
            stmt = stmt.where(WorkoutSession.session_date <= end_date)

        result = await self.session.execute(stmt)
        rows = result.all()

        return [(row[0], row[1]) for row in rows]

    # ------------------------------------------------------------------
    # Foco Muscular (Novo)
    # ------------------------------------------------------------------

    async def get_muscle_group_distribution(
        self,
        user_id: UUID,
        start_date: datetime,
        end_date: datetime,
    ) -> List[Tuple[str, int]]:
        """
        Retorna a contagem de exercícios executados em sessões completadas,
        agrupados por grupo muscular.
        """
        from app.models.workout_sheet import Exercise

        stmt = (
            select(
                Exercise.muscle_group,
                func.count(SessionExercise.id).label("count"),
            )
            .join(
                WorkoutSession,
                SessionExercise.session_id == WorkoutSession.id,
            )
            .join(
                Exercise,
                SessionExercise.exercise_id == Exercise.id,
            )
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.status == "completed",
                WorkoutSession.session_date >= start_date,
                WorkoutSession.session_date <= end_date,
            )
            .group_by(Exercise.muscle_group)
            .order_by(func.count(SessionExercise.id).desc())
        )

        result = await self.session.execute(stmt)
        rows = result.all()

        return [(row[0], row[1]) for row in rows]

    # ------------------------------------------------------------------
    # Transação
    # ------------------------------------------------------------------

    async def commit(self) -> None:
        """Commit da transação atual."""
        await self.session.commit()

    async def rollback(self) -> None:
        """Rollback da transação atual."""
        await self.session.rollback()

