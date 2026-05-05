"""
Repository do Dashboard Profissional.

Responsável pelas queries de agregação que alimentam os endpoints RF-43–RF-46.
Todas as queries usam async/await com AsyncSession.
"""

from datetime import datetime, timedelta
from typing import Optional
from uuid import UUID

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.dashboard import StudentAnalytics
from app.models.diet_logbook import DietLogbook
from app.models.goal import Goal
from app.models.logbook import SessionExercise, WorkoutSession
from app.models.user import User
from app.models.workout_sheet import WorkoutSheet


class DashboardRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    # -----------------------------------------------------------------------
    # RF-43: Alunos do personal
    # -----------------------------------------------------------------------

    async def get_students_of_personal(self, personal_id: UUID) -> list[User]:
        """Retorna alunos distintos que possuem ficha ativa criada pelo personal."""
        stmt = (
            select(User)
            .join(WorkoutSheet, WorkoutSheet.user_id == User.id)
            .where(
                WorkoutSheet.personal_trainer_id == personal_id,
                WorkoutSheet.is_active == True,
                User.is_active == True,
            )
            .distinct()
            .order_by(User.name)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_all_active_students(self) -> list[User]:
        """Admin: retorna todos os usuários com role 'client' e is_active=True."""
        stmt = (
            select(User)
            .where(User.role == "client", User.is_active == True)
            .order_by(User.name)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def is_student_of_personal(self, student_id: UUID, personal_id: UUID) -> bool:
        """Verifica se o aluno possui ao menos uma ficha ativa do personal."""
        stmt = select(WorkoutSheet.id).where(
            WorkoutSheet.user_id == student_id,
            WorkoutSheet.personal_trainer_id == personal_id,
            WorkoutSheet.is_active == True,
        )
        result = await self.session.execute(stmt)
        return result.first() is not None

    # -----------------------------------------------------------------------
    # Analytics: métricas por aluno (usadas pelo service e pelo refresh)
    # -----------------------------------------------------------------------

    async def count_completed_sessions(
        self, user_id: UUID, since: datetime
    ) -> int:
        """Conta sessões com status='completed' a partir de uma data."""
        stmt = select(func.count(WorkoutSession.id)).where(
            WorkoutSession.user_id == user_id,
            WorkoutSession.status == "completed",
            WorkoutSession.session_date >= since,
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_last_workout_date(self, user_id: UUID) -> Optional[datetime]:
        """Data da sessão mais recente com status='completed'."""
        stmt = (
            select(WorkoutSession.session_date)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.status == "completed",
            )
            .order_by(WorkoutSession.session_date.desc())
            .limit(1)
        )
        result = await self.session.execute(stmt)
        return result.scalar()

    async def count_planned_sessions_30d(self, user_id: UUID) -> int:
        """
        Estima sessões planejadas nos últimos 30 dias com base nas fichas ativas.
        Cada ficha representa um dia da semana → 4 ocorrências em ~30 dias.
        """
        stmt = select(func.count(WorkoutSheet.id)).where(
            WorkoutSheet.user_id == user_id,
            WorkoutSheet.is_active == True,
        )
        result = await self.session.execute(stmt)
        sheets_count = result.scalar() or 0
        return sheets_count * 4

    async def get_personal_id_for_student(self, student_id: UUID) -> Optional[UUID]:
        """Retorna o personal_trainer_id do primeiro WorkoutSheet ativo do aluno."""
        stmt = (
            select(WorkoutSheet.personal_trainer_id)
            .where(
                WorkoutSheet.user_id == student_id,
                WorkoutSheet.is_active == True,
                WorkoutSheet.personal_trainer_id.is_not(None),
            )
            .limit(1)
        )
        result = await self.session.execute(stmt)
        return result.scalar()

    # -----------------------------------------------------------------------
    # RF-44: Visão 360° — seções detalhadas
    # -----------------------------------------------------------------------

    async def get_recent_workouts(
        self, user_id: UUID, limit: int = 5
    ) -> list[WorkoutSession]:
        """Últimas N sessões do aluno, incluindo exercícios (selectin no model)."""
        stmt = (
            select(WorkoutSession)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.status.in_(["completed", "incomplete"]),
            )
            .order_by(WorkoutSession.session_date.desc())
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def count_exercises_in_session(self, session_id: UUID) -> int:
        stmt = select(func.count(SessionExercise.id)).where(
            SessionExercise.session_id == session_id
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_active_goals(self, user_id: UUID) -> list[Goal]:
        stmt = (
            select(Goal)
            .where(Goal.user_id == user_id, Goal.status == "active")
            .order_by(Goal.target_date.asc())
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_diet_adherence_7d(self, user_id: UUID) -> dict:
        """
        Retorna médias de macros dos últimos 7 dias com registro no logbook alimentar.
        """
        since = datetime.utcnow().date() - timedelta(days=7)
        stmt = (
            select(
                func.count(DietLogbook.id).label("days_logged"),
                func.avg(DietLogbook.total_kcal).label("avg_kcal"),
                func.avg(DietLogbook.total_protein).label("avg_protein"),
                func.avg(DietLogbook.total_carbs).label("avg_carbs"),
                func.avg(DietLogbook.total_fats).label("avg_fats"),
            )
            .where(
                DietLogbook.user_id == user_id,
                DietLogbook.date >= since,
            )
        )
        result = await self.session.execute(stmt)
        row = result.one()
        return {
            "days_logged": row.days_logged or 0,
            "avg_kcal": round(row.avg_kcal or 0.0, 1),
            "avg_protein": round(row.avg_protein or 0.0, 1),
            "avg_carbs": round(row.avg_carbs or 0.0, 1),
            "avg_fats": round(row.avg_fats or 0.0, 1),
        }

    async def get_muscle_group_frequency_30d(self, user_id: UUID) -> list[dict]:
        """
        Conta sessões por grupo muscular nos últimos 30 dias (via session_exercises + exercises).
        Retorna lista de {muscle_group, sessions_count} ordenada desc.
        """
        since = datetime.utcnow() - timedelta(days=30)
        stmt = text(
            """
            SELECT e.muscle_group, COUNT(DISTINCT se.session_id) AS sessions_count
            FROM session_exercises se
            JOIN exercises e ON e.id = se.exercise_id
            JOIN workout_sessions ws ON ws.id = se.session_id
            WHERE ws.user_id = :user_id
              AND ws.status = 'completed'
              AND ws.session_date >= :since
            GROUP BY e.muscle_group
            ORDER BY sessions_count DESC
            """
        )
        result = await self.session.execute(stmt, {"user_id": str(user_id), "since": since})
        return [{"muscle_group": row[0], "sessions_count": row[1]} for row in result]

    # -----------------------------------------------------------------------
    # RF-46: Admin overview
    # -----------------------------------------------------------------------

    async def count_active_students(self) -> int:
        stmt = select(func.count(User.id)).where(
            User.role == "client", User.is_active == True
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def count_personal_trainers(self) -> int:
        stmt = select(func.count(User.id)).where(
            User.role == "personal_trainer", User.is_active == True
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def count_dau(self) -> int:
        """Usuários únicos com sessão completada hoje."""
        today = datetime.utcnow().date()
        stmt = select(func.count(func.distinct(WorkoutSession.user_id))).where(
            func.date(WorkoutSession.session_date) == today,
            WorkoutSession.status == "completed",
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def count_mau(self) -> int:
        """Usuários únicos com sessão completada no mês atual."""
        now = datetime.utcnow()
        month_start = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        stmt = select(func.count(func.distinct(WorkoutSession.user_id))).where(
            WorkoutSession.session_date >= month_start,
            WorkoutSession.status == "completed",
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_status_counts(self) -> dict:
        """Contagem de alunos por status na tabela student_analytics."""
        stmt = (
            select(StudentAnalytics.status, func.count(StudentAnalytics.id))
            .group_by(StudentAnalytics.status)
        )
        result = await self.session.execute(stmt)
        counts = {"engaged": 0, "at_risk": 0, "inactive": 0}
        for status, count in result:
            counts[status] = count
        return counts

    async def get_global_adherence_avg(self) -> float:
        stmt = select(func.avg(StudentAnalytics.adherence_percentage))
        result = await self.session.execute(stmt)
        val = result.scalar()
        return round(val or 0.0, 1)

    # -----------------------------------------------------------------------
    # Cache: upsert na tabela student_analytics
    # -----------------------------------------------------------------------

    async def upsert_student_analytics(
        self,
        user_id: UUID,
        personal_trainer_id: Optional[UUID],
        total_workouts_30d: int,
        workouts_planned_30d: int,
        adherence_percentage: float,
        last_workout_date: Optional[datetime],
        status: str,
    ) -> None:
        """Insere ou atualiza a linha de analytics para o aluno."""
        stmt = (
            select(StudentAnalytics)
            .where(StudentAnalytics.user_id == user_id)
        )
        result = await self.session.execute(stmt)
        record = result.scalars().first()

        if record:
            record.personal_trainer_id = personal_trainer_id
            record.total_workouts_30d = total_workouts_30d
            record.workouts_planned_30d = workouts_planned_30d
            record.adherence_percentage = adherence_percentage
            record.last_workout_date = last_workout_date
            record.status = status
            record.updated_at = datetime.utcnow()
        else:
            record = StudentAnalytics(
                user_id=user_id,
                personal_trainer_id=personal_trainer_id,
                total_workouts_30d=total_workouts_30d,
                workouts_planned_30d=workouts_planned_30d,
                adherence_percentage=adherence_percentage,
                last_workout_date=last_workout_date,
                status=status,
            )
            self.session.add(record)

    async def get_analytics_for_student(self, user_id: UUID) -> Optional[StudentAnalytics]:
        stmt = select(StudentAnalytics).where(StudentAnalytics.user_id == user_id)
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def commit(self) -> None:
        await self.session.commit()

    async def rollback(self) -> None:
        await self.session.rollback()
