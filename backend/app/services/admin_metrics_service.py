"""
Serviço de Métricas Admin.

Orquestra as queries do repositório e aplica as regras de negócio:
- Cálculo de adherence_rate
- Scoring de risco de churn
- Categorização de alunos e trainers
"""

from datetime import datetime, timezone, timedelta
from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.admin_metrics_dto import (
    AIAnalyticsDTO,
    AIModelStatsDTO,
    PaginatedStudentMetricsDTO,
    PaginatedTrainerMetricsDTO,
    StudentMetricsItemDTO,
    StudentMetricsSummaryDTO,
    SystemMetricsDTO,
    TrainerMetricsItemDTO,
)
from app.repositories.admin_metrics_repository import AdminMetricsRepository


def _adherence_category(rate: float) -> str:
    if rate >= 80:
        return "high"
    if rate >= 50:
        return "medium"
    return "low"


def _risk_score(adherence_rate: float, days_inactive: int) -> int:
    score = 0
    if adherence_rate < 30:
        score += 5
    elif adherence_rate < 50:
        score += 3

    if days_inactive > 7:
        score += 3
    elif days_inactive > 3:
        score += 1

    return score


def _risk_level(score: int) -> str:
    if score >= 7:
        return "critical"
    if score >= 4:
        return "high"
    if score >= 2:
        return "medium"
    return "low"


def _most_recent_date(*dates) -> Optional[datetime]:
    """Retorna a data mais recente dentre as fornecidas, ignorando None.

    Normaliza tudo para UTC-aware antes de comparar: colunas TIMESTAMP (naive)
    retornadas pelo asyncpg são tratadas como UTC, e objetos date são elevados
    a datetime meia-noite UTC.
    """
    candidates = [d for d in dates if d is not None]
    if not candidates:
        return None
    normalized: list[datetime] = []
    for d in candidates:
        if isinstance(d, datetime):
            normalized.append(d if d.tzinfo is not None else d.replace(tzinfo=timezone.utc))
        else:
            normalized.append(datetime(d.year, d.month, d.day, tzinfo=timezone.utc))
    return max(normalized)


def _days_since(dt: Optional[datetime]) -> int:
    """Retorna quantos dias se passaram desde dt (ou 999 se None)."""
    if dt is None:
        return 999
    now = datetime.now(timezone.utc)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return max(0, (now - dt).days)


class AdminMetricsService:
    """Serviço de métricas para o painel administrativo."""

    def __init__(self, session: AsyncSession):
        self.repo = AdminMetricsRepository(session)

    # ──────────────────────────────────────────────────────────────────────
    # STUDENT METRICS
    # ──────────────────────────────────────────────────────────────────────

    async def get_student_metrics(
        self,
        trainer_id: Optional[UUID],
        days: int,
        page: int,
        limit: int,
    ) -> PaginatedStudentMetricsDTO:
        """
        Retorna métricas paginadas de alunos com adherence_rate e risk_level.

        Args:
            trainer_id: Filtrar por trainer específico (None = todos)
            days: Janela temporal em dias (ex: 30 = últimos 30 dias)
            page: Página atual
            limit: Itens por página
        """
        start_date = datetime.now(timezone.utc) - timedelta(days=days)

        total = await self.repo.count_students(trainer_id)
        all_ids = await self.repo.get_all_student_ids(trainer_id)

        if not all_ids:
            summary = StudentMetricsSummaryDTO(
                total_students=0,
                high_adherence_count=0,
                medium_adherence_count=0,
                low_adherence_count=0,
                avg_adherence_rate=0.0,
                at_risk_critical=0,
                at_risk_high=0,
                at_risk_medium=0,
                at_risk_low=0,
            )
            return PaginatedStudentMetricsDTO(
                total=total, page=page, limit=limit, data=[], summary=summary
            )

        # Bulk queries para TODOS os alunos — usadas tanto nos items paginados
        # quanto no cálculo do summary global.
        all_session_stats = await self.repo.get_session_stats_bulk(all_ids, start_date)
        all_diet_stats = await self.repo.get_diet_stats_bulk(all_ids, start_date)
        all_step_stats = await self.repo.get_step_stats_bulk(all_ids, start_date)

        # Página atual de alunos (para montar os items de resposta)
        students = await self.repo.get_students_page(trainer_id, page, limit)

        # goal_progress apenas para a página (não entra no summary)
        page_ids = [s.id for s in students]
        goal_progress = await self.repo.get_goal_progress_bulk(page_ids)

        # Carregar nomes dos trainers atrelados à página
        trainer_ids_needed = {s.trainer_id for s in students if s.trainer_id}
        trainers_by_id: dict[UUID, str] = {}
        if trainer_ids_needed:
            from app.models.user import User
            from sqlalchemy import select
            stmt = select(User.id, User.name).where(User.id.in_(trainer_ids_needed))
            result = await self.repo.session.execute(stmt)
            trainers_by_id = {row.id: row.name for row in result.all()}

        _empty_session = {"sessions_total": 0, "sessions_completed": 0, "last_session": None}
        _empty_diet = {"diet_logs_count": 0, "last_diet": None}
        _empty_step = {"last_step": None}

        # Montar itens paginados reutilizando os bulk stats já carregados
        items: list[StudentMetricsItemDTO] = []
        for student in students:
            s_stats = all_session_stats.get(student.id, _empty_session)
            d_stats = all_diet_stats.get(student.id, _empty_diet)
            st_stats = all_step_stats.get(student.id, _empty_step)

            sessions_total = s_stats["sessions_total"]
            sessions_completed = s_stats["sessions_completed"]
            adherence_rate = round(
                (sessions_completed / sessions_total * 100) if sessions_total > 0 else 0.0, 2
            )

            last_activity = _most_recent_date(
                s_stats["last_session"],
                d_stats["last_diet"],
                st_stats["last_step"],
            )
            days_inactive = _days_since(last_activity)
            score = _risk_score(adherence_rate, days_inactive)

            items.append(StudentMetricsItemDTO(
                user_id=student.id,
                user_name=student.name,
                trainer_id=student.trainer_id,
                trainer_name=trainers_by_id.get(student.trainer_id) if student.trainer_id else None,
                adherence_rate=adherence_rate,
                adherence_category=_adherence_category(adherence_rate),
                sessions_completed=sessions_completed,
                sessions_total=sessions_total,
                diet_logs_count=d_stats["diet_logs_count"],
                risk_level=_risk_level(score),
                risk_score=score,
                days_inactive=days_inactive,
                last_activity=last_activity,
                goal_progress=goal_progress.get(student.id),
            ))

        # Summary global — itera sobre TODOS os alunos, não só a página
        high = medium = low = 0
        at_risk_critical = at_risk_high = at_risk_medium = at_risk_low = 0
        total_adherence = 0.0

        for uid in all_ids:
            s_stats = all_session_stats.get(uid, _empty_session)
            d_stats = all_diet_stats.get(uid, _empty_diet)
            st_stats = all_step_stats.get(uid, _empty_step)

            s_total = s_stats["sessions_total"]
            s_completed = s_stats["sessions_completed"]
            rate = (s_completed / s_total * 100) if s_total > 0 else 0.0

            category = _adherence_category(rate)
            if category == "high":
                high += 1
            elif category == "medium":
                medium += 1
            else:
                low += 1

            last_act = _most_recent_date(
                s_stats["last_session"],
                d_stats["last_diet"],
                st_stats["last_step"],
            )
            score = _risk_score(rate, _days_since(last_act))
            level = _risk_level(score)
            if level == "critical":
                at_risk_critical += 1
            elif level == "high":
                at_risk_high += 1
            elif level == "medium":
                at_risk_medium += 1
            else:
                at_risk_low += 1

            total_adherence += rate

        n = len(all_ids)
        avg_adherence = round(total_adherence / n, 2) if n > 0 else 0.0

        summary = StudentMetricsSummaryDTO(
            total_students=total,
            high_adherence_count=high,
            medium_adherence_count=medium,
            low_adherence_count=low,
            avg_adherence_rate=avg_adherence,
            at_risk_critical=at_risk_critical,
            at_risk_high=at_risk_high,
            at_risk_medium=at_risk_medium,
            at_risk_low=at_risk_low,
        )

        return PaginatedStudentMetricsDTO(
            total=total, page=page, limit=limit, data=items, summary=summary
        )

    # ──────────────────────────────────────────────────────────────────────
    # TRAINER METRICS
    # ──────────────────────────────────────────────────────────────────────

    async def get_trainer_metrics(
        self,
        days: int,
        page: int,
        limit: int,
    ) -> PaginatedTrainerMetricsDTO:
        """
        Retorna métricas paginadas de trainers com portfolio_health e funil de vendas.
        """
        total = await self.repo.count_trainers()
        trainers = await self.repo.get_trainers_page(page, limit)

        if not trainers:
            return PaginatedTrainerMetricsDTO(
                total=total, page=page, limit=limit, data=[]
            )

        trainer_ids = [t.id for t in trainers]

        student_counts = await self.repo.get_student_counts_by_trainer(trainer_ids)
        active_ids_map = await self.repo.get_active_student_ids_by_trainer(trainer_ids, days=14)
        at_risk_ids_map = await self.repo.get_at_risk_student_ids_by_trainer(trainer_ids, days=days)
        avg_adherence_map = await self.repo.get_avg_adherence_by_trainer(trainer_ids, days=days)
        invitations_map = await self.repo.get_invitation_stats_by_trainer(trainer_ids)

        items: list[TrainerMetricsItemDTO] = []
        for trainer in trainers:
            total_students = student_counts.get(trainer.id, 0)
            active_students = len(active_ids_map.get(trainer.id, set()))
            at_risk_students = len(at_risk_ids_map.get(trainer.id, set()))
            portfolio_health = (active_students / total_students * 100) if total_students > 0 else 0.0
            avg_adherence = avg_adherence_map.get(trainer.id, 0.0)

            inv = invitations_map.get(trainer.id, {"generated": 0, "used": 0})
            invites_generated = inv["generated"]
            invites_used = inv["used"]
            conversion_rate = (invites_used / invites_generated * 100) if invites_generated > 0 else 0.0

            items.append(TrainerMetricsItemDTO(
                trainer_id=trainer.id,
                trainer_name=trainer.name,
                total_students=total_students,
                active_students=active_students,
                at_risk_students=at_risk_students,
                portfolio_health=round(portfolio_health, 2),
                avg_student_adherence=round(avg_adherence, 2),
                invites_generated=invites_generated,
                invites_used=invites_used,
                conversion_rate=round(conversion_rate, 2),
            ))

        return PaginatedTrainerMetricsDTO(
            total=total, page=page, limit=limit, data=items
        )

    # ──────────────────────────────────────────────────────────────────────
    # SYSTEM METRICS
    # ──────────────────────────────────────────────────────────────────────

    async def get_system_metrics(self, days: int) -> SystemMetricsDTO:
        """Retorna métricas globais do sistema (DAU, MAU, chatbot, etc.)."""
        period_start = datetime.now(timezone.utc) - timedelta(days=days)

        user_counts = await self.repo.get_user_counts(period_start)
        dau = await self.repo.get_dau()
        mau = await self.repo.get_mau()
        workouts_completed = await self.repo.get_workout_completion_count(period_start)
        diet_logs = await self.repo.get_diet_log_count(period_start)

        total_active = user_counts["total_users"]
        adoption_rate, quality_score = await self.repo.get_chatbot_adoption(total_active, period_start)

        dau_mau_ratio = round((dau / mau) * 100, 2) if mau > 0 else 0.0

        return SystemMetricsDTO(
            period_days=days,
            total_users=user_counts["total_users"],
            active_users=total_active,
            new_users_in_period=user_counts["new_users_in_period"],
            total_trainers=user_counts["total_trainers"],
            total_students=user_counts["total_students"],
            dau=dau,
            mau=mau,
            dau_mau_ratio=dau_mau_ratio,
            total_workouts_completed=workouts_completed,
            total_diet_logs=diet_logs,
            chatbot_adoption_rate=adoption_rate,
            chatbot_quality_score=quality_score,
        )

    # ──────────────────────────────────────────────────────────────────────
    # AI ANALYTICS
    # ──────────────────────────────────────────────────────────────────────

    async def get_ai_analytics(self, days: int) -> AIAnalyticsDTO:
        """Retorna analytics de uso e qualidade de IA no período."""
        period_start = datetime.now(timezone.utc) - timedelta(days=days)

        stats = await self.repo.get_ai_message_stats(period_start)
        by_model_raw = await self.repo.get_ai_stats_by_model(period_start)
        quality_score = await self.repo.get_ai_quality_score(period_start)

        total_messages = stats["total_messages"]
        total_tokens = stats["total_tokens"]
        avg_tokens = total_tokens / total_messages if total_messages > 0 else 0.0

        by_model: list[AIModelStatsDTO] = []
        for m in by_model_raw:
            percent = (m["messages_count"] / total_messages * 100) if total_messages > 0 else 0.0
            by_model.append(AIModelStatsDTO(
                model=m["model"],
                messages_count=m["messages_count"],
                total_tokens=m["total_tokens"],
                avg_latency_ms=round(m["avg_latency_ms"], 2),
                percent_of_total=round(percent, 2),
            ))

        return AIAnalyticsDTO(
            period_days=days,
            total_messages=total_messages,
            total_tokens=total_tokens,
            avg_tokens_per_message=round(avg_tokens, 2),
            avg_latency_ms=round(stats["avg_latency_ms"], 2),
            quality_score=quality_score,
            by_model=by_model,
        )
