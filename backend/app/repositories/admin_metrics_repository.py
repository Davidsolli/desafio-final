"""
Repositório de Métricas Admin.

Executa agregações no banco de dados para o dashboard administrativo.
Todas as queries são async e usam SQLAlchemy ORM com expressões declarativas.
"""

from datetime import date, datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import case, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.chatbot import ChatConversation, ChatFeedback, ChatMessage
from app.models.diet_logbook import DietLogbook
from app.models.goal import Goal
from app.models.invitation import Invitation
from app.models.logbook import WorkoutSession
from app.models.step_log import StepLog
from app.models.user import User


def _start_of_period(days: int) -> datetime:
    return datetime.now(timezone.utc) - timedelta(days=days)


def _naive(dt: datetime) -> datetime:
    """Remove timezone info para uso em colunas TIMESTAMP WITHOUT TIME ZONE.

    Colunas sem fuso (users.created_at, chat_messages.created_at, etc.) são
    armazenadas como UTC mas sem tzinfo. asyncpg rejeita datetime timezone-aware
    nesses parâmetros — esta função faz a conversão segura.
    """
    return dt.replace(tzinfo=None) if dt.tzinfo is not None else dt


class AdminMetricsRepository:
    """Queries de agregação para o dashboard do admin."""

    def __init__(self, session: AsyncSession):
        self.session = session

    # ──────────────────────────────────────────────────────────────────────
    # STUDENT METRICS
    # ──────────────────────────────────────────────────────────────────────

    async def count_students(self, trainer_id: Optional[UUID] = None) -> int:
        """Retorna o total de alunos ativos (com filtro opcional por trainer)."""
        conditions = [User.role == "client", User.is_active == True]
        if trainer_id:
            conditions.append(User.trainer_id == trainer_id)

        stmt = select(func.count(User.id)).where(*conditions)
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_students_page(
        self,
        trainer_id: Optional[UUID],
        page: int,
        limit: int,
    ) -> list[User]:
        """Retorna uma página de alunos ativos."""
        conditions = [User.role == "client", User.is_active == True]
        if trainer_id:
            conditions.append(User.trainer_id == trainer_id)

        stmt = (
            select(User)
            .where(*conditions)
            .order_by(User.created_at.desc())
            .offset((page - 1) * limit)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_all_student_ids(self, trainer_id: Optional[UUID] = None) -> list[UUID]:
        """Retorna TODOS os IDs de alunos ativos sem paginação (para cálculo global de summary)."""
        conditions = [User.role == "client", User.is_active == True]
        if trainer_id:
            conditions.append(User.trainer_id == trainer_id)
        stmt = select(User.id).where(*conditions)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_session_stats_bulk(
        self,
        user_ids: list[UUID],
        start_date: datetime,
    ) -> dict[UUID, dict]:
        """
        Retorna métricas de sessões de treino para uma lista de alunos.

        Returns dict: { user_id -> {completed, total, last_session} }
        """
        if not user_ids:
            return {}

        stmt = select(
            WorkoutSession.user_id,
            func.count(WorkoutSession.id).label("total"),
            func.sum(
                case((WorkoutSession.status == "completed", 1), else_=0)
            ).label("completed"),
            func.max(WorkoutSession.session_date).label("last_session"),
        ).where(
            WorkoutSession.user_id.in_(user_ids),
            WorkoutSession.session_date >= start_date,
            WorkoutSession.status != "deleted",
        ).group_by(WorkoutSession.user_id)

        result = await self.session.execute(stmt)
        rows = result.all()

        return {
            row.user_id: {
                "sessions_total": row.total or 0,
                "sessions_completed": row.completed or 0,
                "last_session": row.last_session,
            }
            for row in rows
        }

    async def get_diet_stats_bulk(
        self,
        user_ids: list[UUID],
        start_date: datetime,
    ) -> dict[UUID, dict]:
        """
        Retorna métricas de dieta para uma lista de alunos.

        Returns dict: { user_id -> {diet_days, last_diet} }
        """
        if not user_ids:
            return {}

        start_date_only = start_date.date() if isinstance(start_date, datetime) else start_date

        stmt = select(
            DietLogbook.user_id,
            func.count(DietLogbook.id).label("diet_days"),
            func.max(DietLogbook.date).label("last_diet"),
        ).where(
            DietLogbook.user_id.in_(user_ids),
            DietLogbook.date >= start_date_only,
        ).group_by(DietLogbook.user_id)

        result = await self.session.execute(stmt)
        rows = result.all()

        return {
            row.user_id: {
                "diet_logs_count": row.diet_days or 0,
                "last_diet": row.last_diet,
            }
            for row in rows
        }

    async def get_step_stats_bulk(
        self,
        user_ids: list[UUID],
        start_date: datetime,
    ) -> dict[UUID, dict]:
        """Retorna a última data de passos registrada para cada aluno."""
        if not user_ids:
            return {}

        start_date_only = start_date.date() if isinstance(start_date, datetime) else start_date

        stmt = select(
            StepLog.user_id,
            func.max(StepLog.date).label("last_step"),
        ).where(
            StepLog.user_id.in_(user_ids),
            StepLog.date >= start_date_only,
        ).group_by(StepLog.user_id)

        result = await self.session.execute(stmt)
        rows = result.all()

        return {row.user_id: {"last_step": row.last_step} for row in rows}

    async def get_goal_progress_bulk(
        self,
        user_ids: list[UUID],
    ) -> dict[UUID, float]:
        """
        Retorna a média de progresso das metas ativas de cada aluno.

        Returns dict: { user_id -> avg_progress_percentage }
        """
        if not user_ids:
            return {}

        stmt = select(
            Goal.user_id,
            func.avg(Goal.progress_percentage).label("avg_progress"),
        ).where(
            Goal.user_id.in_(user_ids),
            Goal.status == "active",
        ).group_by(Goal.user_id)

        result = await self.session.execute(stmt)
        rows = result.all()

        return {row.user_id: float(row.avg_progress or 0.0) for row in rows}

    # ──────────────────────────────────────────────────────────────────────
    # TRAINER METRICS
    # ──────────────────────────────────────────────────────────────────────

    async def count_trainers(self) -> int:
        """Retorna o total de profissionais ativos (personal trainers e/ou nutricionistas)."""
        stmt = select(func.count(User.id)).where(
            User.role.contains("personal_trainer") | User.role.contains("nutritionist"),
            User.is_active == True,
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_trainers_page(self, page: int, limit: int) -> list[User]:
        """Retorna uma página de profissionais ativos."""
        stmt = (
            select(User)
            .where(
                User.role.contains("personal_trainer") | User.role.contains("nutritionist"),
                User.is_active == True,
            )
            .order_by(User.created_at.desc())
            .offset((page - 1) * limit)
            .limit(limit)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_student_counts_by_trainer(
        self,
        trainer_ids: list[UUID],
    ) -> dict[UUID, int]:
        """Retorna o total de alunos ativos por trainer."""
        if not trainer_ids:
            return {}

        stmt = select(
            User.trainer_id,
            func.count(User.id).label("student_count"),
        ).where(
            User.trainer_id.in_(trainer_ids),
            User.role == "client",
            User.is_active == True,
        ).group_by(User.trainer_id)

        result = await self.session.execute(stmt)
        return {row.trainer_id: row.student_count for row in result.all()}

    async def get_active_student_ids_by_trainer(
        self,
        trainer_ids: list[UUID],
        days: int = 14,
    ) -> dict[UUID, set[UUID]]:
        """
        Retorna IDs de alunos que tiveram atividade nos últimos N dias por trainer.
        Um aluno "ativo" tem ao menos 1 sessão completada nos últimos N dias.
        """
        if not trainer_ids:
            return {}

        start_date = _start_of_period(days)

        # Alunos com sessão completada recentemente
        subq = select(
            User.id.label("student_id"),
            User.trainer_id,
        ).where(
            User.trainer_id.in_(trainer_ids),
            User.role == "client",
            User.is_active == True,
        ).subquery()

        stmt = select(
            subq.c.trainer_id,
            subq.c.student_id,
        ).join(
            WorkoutSession,
            (WorkoutSession.user_id == subq.c.student_id)
            & (WorkoutSession.status == "completed")
            & (WorkoutSession.session_date >= start_date),
        ).distinct()

        result = await self.session.execute(stmt)
        rows = result.all()

        out: dict[UUID, set[UUID]] = {t: set() for t in trainer_ids}
        for row in rows:
            out[row.trainer_id].add(row.student_id)
        return out

    async def get_at_risk_student_ids_by_trainer(
        self,
        trainer_ids: list[UUID],
        days: int = 30,
    ) -> dict[UUID, set[UUID]]:
        """
        Retorna IDs de alunos com baixa adesão nos últimos N dias por trainer.
        "Em risco" = menos de 50% de sessões completadas (ou sem nenhuma sessão).
        """
        if not trainer_ids:
            return {}

        start_date = _start_of_period(days)

        # Pega todos os alunos e verifica quais têm baixa adesão
        students_stmt = select(User.id, User.trainer_id).where(
            User.trainer_id.in_(trainer_ids),
            User.role == "client",
            User.is_active == True,
        )
        students_result = await self.session.execute(students_stmt)
        students = students_result.all()

        if not students:
            return {t: set() for t in trainer_ids}

        student_ids = [s.id for s in students]

        sessions_stmt = select(
            WorkoutSession.user_id,
            func.count(WorkoutSession.id).label("total"),
            func.sum(case((WorkoutSession.status == "completed", 1), else_=0)).label("completed"),
        ).where(
            WorkoutSession.user_id.in_(student_ids),
            WorkoutSession.session_date >= start_date,
            WorkoutSession.status != "deleted",
        ).group_by(WorkoutSession.user_id)

        sessions_result = await self.session.execute(sessions_stmt)
        sessions_by_user: dict[UUID, dict] = {
            row.user_id: {"total": row.total, "completed": row.completed or 0}
            for row in sessions_result.all()
        }

        out: dict[UUID, set[UUID]] = {t: set() for t in trainer_ids}
        for student in students:
            stats = sessions_by_user.get(student.id, {"total": 0, "completed": 0})
            total = stats["total"]
            completed = stats["completed"]

            if total == 0:
                adherence = 0.0
            else:
                adherence = (completed / total) * 100

            if adherence < 50.0:
                out[student.trainer_id].add(student.id)

        return out

    async def get_avg_adherence_by_trainer(
        self,
        trainer_ids: list[UUID],
        days: int = 30,
    ) -> dict[UUID, float]:
        """Retorna a média de adesão dos alunos de cada trainer."""
        if not trainer_ids:
            return {}

        start_date = _start_of_period(days)

        students_stmt = select(User.id, User.trainer_id).where(
            User.trainer_id.in_(trainer_ids),
            User.role == "client",
            User.is_active == True,
        )
        students_result = await self.session.execute(students_stmt)
        students = students_result.all()

        if not students:
            return {t: 0.0 for t in trainer_ids}

        student_ids = [s.id for s in students]
        student_to_trainer = {s.id: s.trainer_id for s in students}

        sessions_stmt = select(
            WorkoutSession.user_id,
            func.count(WorkoutSession.id).label("total"),
            func.sum(case((WorkoutSession.status == "completed", 1), else_=0)).label("completed"),
        ).where(
            WorkoutSession.user_id.in_(student_ids),
            WorkoutSession.session_date >= start_date,
            WorkoutSession.status != "deleted",
        ).group_by(WorkoutSession.user_id)

        sessions_result = await self.session.execute(sessions_stmt)

        # group adherence per trainer
        trainer_rates: dict[UUID, list[float]] = {t: [] for t in trainer_ids}
        for row in sessions_result.all():
            total = row.total or 0
            completed = row.completed or 0
            adherence = (completed / total * 100) if total > 0 else 0.0
            trainer_id = student_to_trainer.get(row.user_id)
            if trainer_id:
                trainer_rates[trainer_id].append(adherence)

        # Excluir alunos com 0% de adesão (sem atividade no período)
        # para calcular média apenas de alunos que tiveram sessões
        return {
            t_id: (
                sum(rates) / len(rates) if rates else 0.0
            )
            for t_id, rates in trainer_rates.items()
        }

    async def get_invitation_stats_by_trainer(
        self,
        trainer_ids: list[UUID],
    ) -> dict[UUID, dict]:
        """Retorna estatísticas de convites por trainer."""
        if not trainer_ids:
            return {}

        stmt = select(
            Invitation.trainer_id,
            func.count(Invitation.id).label("generated"),
            func.sum(case((Invitation.used == True, 1), else_=0)).label("used"),
        ).where(Invitation.trainer_id.in_(trainer_ids)).group_by(Invitation.trainer_id)

        result = await self.session.execute(stmt)
        rows = result.all()

        out: dict[UUID, dict] = {t: {"generated": 0, "used": 0} for t in trainer_ids}
        for row in rows:
            out[row.trainer_id] = {
                "generated": row.generated or 0,
                "used": row.used or 0,
            }
        return out

    # ──────────────────────────────────────────────────────────────────────
    # SYSTEM METRICS
    # ──────────────────────────────────────────────────────────────────────

    async def get_user_counts(self, period_start: datetime) -> dict:
        """Retorna contagens gerais de usuários."""
        total_stmt = select(func.count(User.id)).where(User.is_active == True)
        trainers_stmt = select(func.count(User.id)).where(
            User.role.contains("personal_trainer") | User.role.contains("nutritionist"),
            User.is_active == True,
        )
        students_stmt = select(func.count(User.id)).where(
            User.role == "client", User.is_active == True
        )
        new_users_stmt = select(func.count(User.id)).where(
            User.is_active == True,
            User.role == "client",
            User.created_at >= _naive(period_start),
        )

        total = (await self.session.execute(total_stmt)).scalar() or 0
        trainers = (await self.session.execute(trainers_stmt)).scalar() or 0
        students = (await self.session.execute(students_stmt)).scalar() or 0
        new_users = (await self.session.execute(new_users_stmt)).scalar() or 0

        return {
            "total_users": total,
            "total_trainers": trainers,
            "total_students": students,
            "new_users_in_period": new_users,
        }

    async def get_dau(self) -> int:
        """Conta usuários alunos únicos com atividade hoje (workout, dieta ou passos)."""
        today = date.today()

        workout_users = select(WorkoutSession.user_id.distinct()).where(
            func.date(WorkoutSession.session_date) == today
        )
        diet_users = select(DietLogbook.user_id.distinct()).where(
            DietLogbook.date == today
        )
        step_users = select(StepLog.user_id.distinct()).where(
            StepLog.date == today
        )

        workout_result = await self.session.execute(workout_users)
        diet_result = await self.session.execute(diet_users)
        step_result = await self.session.execute(step_users)

        unique_users: set = (
            set(workout_result.scalars().all())
            | set(diet_result.scalars().all())
            | set(step_result.scalars().all())
        )

        if not unique_users:
            return 0

        # Filtrar para contar apenas alunos (role='client')
        stmt = select(func.count(User.id)).where(
            User.id.in_(unique_users),
            User.role == "client",
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_mau(self) -> int:
        """Conta usuários alunos únicos com atividade nos últimos 30 dias."""
        start = date.today() - timedelta(days=30)

        workout_users = select(WorkoutSession.user_id.distinct()).where(
            func.date(WorkoutSession.session_date) >= start
        )
        diet_users = select(DietLogbook.user_id.distinct()).where(
            DietLogbook.date >= start
        )
        step_users = select(StepLog.user_id.distinct()).where(
            StepLog.date >= start
        )

        workout_result = await self.session.execute(workout_users)
        diet_result = await self.session.execute(diet_users)
        step_result = await self.session.execute(step_users)

        unique_users: set = (
            set(workout_result.scalars().all())
            | set(diet_result.scalars().all())
            | set(step_result.scalars().all())
        )

        if not unique_users:
            return 0

        # Filtrar para contar apenas alunos (role='client')
        stmt = select(func.count(User.id)).where(
            User.id.in_(unique_users),
            User.role == "client",
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_workout_completion_count(self, period_start: datetime) -> int:
        """Conta sessões completadas no período."""
        stmt = select(func.count(WorkoutSession.id)).where(
            WorkoutSession.status == "completed",
            WorkoutSession.session_date >= period_start,
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_diet_log_count(self, period_start: datetime) -> int:
        """Conta registros de dieta no período."""
        start_date = period_start.date()
        stmt = select(func.count(DietLogbook.id)).where(
            DietLogbook.date >= start_date
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_chatbot_adoption(
        self, total_active_users: int, period_start: datetime
    ) -> tuple[float, float]:
        """
        Retorna (adoption_rate, quality_score) do chatbot no período.

        adoption_rate = % de usuários ativos com ao menos 1 conversa no período
        quality_score = % de feedbacks positivos no período
        """
        if total_active_users == 0:
            return 0.0, 0.0

        users_with_chat_stmt = select(
            func.count(ChatConversation.user_id.distinct())
        ).where(
            ChatConversation.created_at >= _naive(period_start)
        )
        users_with_chat = (
            await self.session.execute(users_with_chat_stmt)
        ).scalar() or 0

        adoption_rate = (users_with_chat / total_active_users) * 100

        total_feedback_stmt = select(func.count(ChatFeedback.id)).where(
            ChatFeedback.created_at >= _naive(period_start)
        )
        helpful_feedback_stmt = select(func.count(ChatFeedback.id)).where(
            ChatFeedback.was_helpful == True,
            ChatFeedback.created_at >= _naive(period_start),
        )
        total_fb = (await self.session.execute(total_feedback_stmt)).scalar() or 0
        helpful_fb = (await self.session.execute(helpful_feedback_stmt)).scalar() or 0

        quality_score = (helpful_fb / total_fb * 100) if total_fb > 0 else 0.0

        return round(adoption_rate, 2), round(quality_score, 2)

    # ──────────────────────────────────────────────────────────────────────
    # AI ANALYTICS
    # ──────────────────────────────────────────────────────────────────────

    async def get_ai_message_stats(self, period_start: datetime) -> dict:
        """Retorna totais de mensagens, tokens e latência no período."""
        stmt = select(
            func.count(ChatMessage.id).label("total_messages"),
            func.coalesce(func.sum(ChatMessage.tokens_used), 0).label("total_tokens"),
            func.coalesce(func.avg(ChatMessage.latency_ms), 0).label("avg_latency"),
        ).where(
            ChatMessage.role == "assistant",
            ChatMessage.created_at >= _naive(period_start),
        )

        result = await self.session.execute(stmt)
        row = result.first()

        return {
            "total_messages": row.total_messages or 0,
            "total_tokens": int(row.total_tokens or 0),
            "avg_latency_ms": float(row.avg_latency or 0),
        }

    async def get_ai_stats_by_model(self, period_start: datetime) -> list[dict]:
        """Retorna estatísticas de uso agrupadas por modelo."""
        stmt = select(
            ChatMessage.model_used,
            func.count(ChatMessage.id).label("messages_count"),
            func.coalesce(func.sum(ChatMessage.tokens_used), 0).label("total_tokens"),
            func.coalesce(func.avg(ChatMessage.latency_ms), 0).label("avg_latency"),
        ).where(
            ChatMessage.role == "assistant",
            ChatMessage.created_at >= _naive(period_start),
            ChatMessage.model_used.is_not(None),
        ).group_by(ChatMessage.model_used).order_by(func.count(ChatMessage.id).desc())

        result = await self.session.execute(stmt)
        rows = result.all()

        return [
            {
                "model": row.model_used or "unknown",
                "messages_count": row.messages_count or 0,
                "total_tokens": int(row.total_tokens or 0),
                "avg_latency_ms": float(row.avg_latency or 0),
            }
            for row in rows
        ]

    async def get_ai_quality_score(self, period_start: datetime) -> float:
        """Retorna % de feedbacks positivos de IA no período."""
        naive_start = _naive(period_start)
        total_stmt = select(func.count(ChatFeedback.id)).join(
            ChatMessage, ChatFeedback.message_id == ChatMessage.id
        ).where(ChatMessage.created_at >= naive_start)

        helpful_stmt = select(func.count(ChatFeedback.id)).join(
            ChatMessage, ChatFeedback.message_id == ChatMessage.id
        ).where(
            ChatMessage.created_at >= naive_start,
            ChatFeedback.was_helpful == True,
        )

        total = (await self.session.execute(total_stmt)).scalar() or 0
        helpful = (await self.session.execute(helpful_stmt)).scalar() or 0

        return round((helpful / total * 100) if total > 0 else 0.0, 2)
