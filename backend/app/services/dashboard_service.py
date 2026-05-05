"""
Service do Dashboard Profissional (RF-43 a RF-48).

Responsável por:
- Lógica de status/adesão
- Guard de acesso personal × aluno
- Agregação dos dados para cada DTO
- Geração de PDF com ReportLab (RF-48)
"""

from datetime import datetime, timedelta
from io import BytesIO
from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.dashboard_dto import (
    AdminOverviewDTO,
    DietAdhierenceDTO,
    DashboardFiltersDTO,
    GoalSummaryDTO,
    MuscleGroupDTO,
    PaginatedStudentsDTO,
    Student360DTO,
    StudentSummaryDTO,
    WorkoutSummaryDTO,
)
from app.repositories.dashboard_repository import DashboardRepository


# ---------------------------------------------------------------------------
# Exceções de domínio
# ---------------------------------------------------------------------------


class DashboardForbiddenError(Exception):
    pass


class DashboardNotFoundError(Exception):
    pass


# ---------------------------------------------------------------------------
# Helpers de cálculo
# ---------------------------------------------------------------------------


def compute_status(last_workout_date: Optional[datetime]) -> str:
    """
    Determina o status semáforo com base na última sessão completada.

    - engaged  : treinou nos últimos 7 dias
    - at_risk  : 7–14 dias sem treinar
    - inactive : mais de 14 dias (ou nunca treinou)
    """
    if last_workout_date is None:
        return "inactive"
    days_since = (datetime.utcnow() - last_workout_date).days
    if days_since <= 7:
        return "engaged"
    if days_since <= 14:
        return "at_risk"
    return "inactive"


def compute_adherence(completed: int, planned: int) -> float:
    if planned <= 0:
        return 0.0
    return round(min((completed / planned) * 100, 100.0), 1)


def _period_since(period: str) -> datetime:
    mapping = {"week": 7, "month": 30, "year": 365}
    days = mapping.get(period, 30)
    return datetime.utcnow() - timedelta(days=days)


# ---------------------------------------------------------------------------
# DashboardService
# ---------------------------------------------------------------------------


class DashboardService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repo = DashboardRepository(session)

    # -----------------------------------------------------------------------
    # RF-43: Lista de alunos com indicadores
    # -----------------------------------------------------------------------

    async def get_personal_students(
        self,
        personal_id: UUID,
        role: str,
        filters: DashboardFiltersDTO,
    ) -> PaginatedStudentsDTO:
        if role == "admin":
            students = await self.repo.get_all_active_students()
        else:
            students = await self.repo.get_students_of_personal(personal_id)

        since_30d = datetime.utcnow() - timedelta(days=30)
        summaries: list[StudentSummaryDTO] = []

        for student in students:
            analytics = await self.repo.get_analytics_for_student(student.id)

            if analytics:
                last_wd = analytics.last_workout_date
                adherence = analytics.adherence_percentage
                total_30d = analytics.total_workouts_30d
                status = analytics.status
            else:
                last_wd = await self.repo.get_last_workout_date(student.id)
                total_30d = await self.repo.count_completed_sessions(student.id, since_30d)
                planned_30d = await self.repo.count_planned_sessions_30d(student.id)
                adherence = compute_adherence(total_30d, planned_30d)
                status = compute_status(last_wd)

            if filters.status and status != filters.status:
                continue

            active_goals = await self.repo.get_active_goals(student.id)

            summaries.append(
                StudentSummaryDTO(
                    student_id=student.id,
                    name=student.name,
                    email=student.email,
                    last_workout_date=last_wd,
                    adherence_percentage=adherence,
                    total_workouts_30d=total_30d,
                    active_goals=len(active_goals),
                    status=status,
                )
            )

        total = len(summaries)
        start = (filters.page - 1) * filters.limit
        paginated = summaries[start : start + filters.limit]

        return PaginatedStudentsDTO(
            total=total,
            page=filters.page,
            limit=filters.limit,
            data=paginated,
        )

    # -----------------------------------------------------------------------
    # RF-44: Visão 360° do aluno
    # -----------------------------------------------------------------------

    async def get_student_360(
        self, requester_id: UUID, student_id: UUID, role: str
    ) -> Student360DTO:
        from app.repositories.user_repository import UserRepository

        user_repo = UserRepository(self.session)
        student = await user_repo.get_by_id(student_id)
        if student is None:
            raise DashboardNotFoundError(f"Aluno {student_id} não encontrado")

        if role == "personal_trainer":
            if not await self.repo.is_student_of_personal(student_id, requester_id):
                raise DashboardForbiddenError(
                    "Acesso negado: aluno não é seu vinculado"
                )

        since_30d = datetime.utcnow() - timedelta(days=30)
        analytics = await self.repo.get_analytics_for_student(student_id)

        if analytics:
            last_wd = analytics.last_workout_date
            adherence = analytics.adherence_percentage
            total_30d = analytics.total_workouts_30d
            status = analytics.status
        else:
            last_wd = await self.repo.get_last_workout_date(student_id)
            total_30d = await self.repo.count_completed_sessions(student_id, since_30d)
            planned_30d = await self.repo.count_planned_sessions_30d(student_id)
            adherence = compute_adherence(total_30d, planned_30d)
            status = compute_status(last_wd)

        recent_sessions = await self.repo.get_recent_workouts(student_id, limit=5)
        recent_workouts: list[WorkoutSummaryDTO] = []
        for s in recent_sessions:
            ex_count = await self.repo.count_exercises_in_session(s.id)
            recent_workouts.append(
                WorkoutSummaryDTO(
                    session_id=s.id,
                    session_date=s.session_date,
                    status=s.status,
                    difficulty_level=s.difficulty_level,
                    mood=s.mood,
                    total_exercises=ex_count,
                )
            )

        goals = await self.repo.get_active_goals(student_id)
        active_goals: list[GoalSummaryDTO] = [
            GoalSummaryDTO(
                goal_id=g.id,
                title=g.title,
                category=g.category,
                progress_percentage=g.progress_percentage,
                status=g.status,
                target_date=g.target_date,
                days_remaining=g.days_remaining,
            )
            for g in goals
        ]

        diet_data = await self.repo.get_diet_adherence_7d(student_id)
        diet_adherence = DietAdhierenceDTO(**diet_data) if diet_data["days_logged"] > 0 else None

        muscle_freq_raw = await self.repo.get_muscle_group_frequency_30d(student_id)
        muscle_freq = [MuscleGroupDTO(**m) for m in muscle_freq_raw]

        return Student360DTO(
            student_id=student.id,
            name=student.name,
            email=student.email,
            weight=student.weight,
            height=student.height,
            age=student.age,
            gender=student.gender,
            status=status,
            adherence_percentage=adherence,
            total_workouts_30d=total_30d,
            last_workout_date=last_wd,
            recent_workouts=recent_workouts,
            active_goals=active_goals,
            diet_adherence=diet_adherence,
            muscle_group_frequency=muscle_freq,
        )

    # -----------------------------------------------------------------------
    # RF-46: Visão do Gestor (Admin only)
    # -----------------------------------------------------------------------

    async def get_admin_overview(self, role: str) -> AdminOverviewDTO:
        if role not in ("admin", "gestor"):
            raise DashboardForbiddenError("Acesso exclusivo para administradores")

        total_students = await self.repo.count_active_students()
        total_personals = await self.repo.count_personal_trainers()
        dau = await self.repo.count_dau()
        mau = await self.repo.count_mau()
        adherence_avg = await self.repo.get_global_adherence_avg()
        status_counts = await self.repo.get_status_counts()

        return AdminOverviewDTO(
            total_active_students=total_students,
            total_personal_trainers=total_personals,
            dau=dau,
            mau=mau,
            global_adherence_avg=adherence_avg,
            students_engaged=status_counts.get("engaged", 0),
            students_at_risk=status_counts.get("at_risk", 0),
            students_inactive=status_counts.get("inactive", 0),
        )

    # -----------------------------------------------------------------------
    # RF-48: Geração de PDF
    # -----------------------------------------------------------------------

    async def generate_pdf_report(
        self, requester_id: UUID, student_id: UUID, role: str
    ) -> BytesIO:
        """
        Gera relatório executivo do aluno em PDF via ReportLab.
        Retorna BytesIO posicionado em 0 (pronto para StreamingResponse).
        """
        data = await self.get_student_360(requester_id, student_id, role)
        return _build_pdf(data)

    # -----------------------------------------------------------------------
    # Refresh de analytics (chamado pelo APScheduler)
    # -----------------------------------------------------------------------

    async def refresh_all_analytics(self) -> int:
        """
        Recalcula métricas de todos os alunos ativos e persiste em student_analytics.
        Retorna o número de registros atualizados.
        """
        students = await self.repo.get_all_active_students()
        since_30d = datetime.utcnow() - timedelta(days=30)
        updated = 0

        for student in students:
            last_wd = await self.repo.get_last_workout_date(student.id)
            total_30d = await self.repo.count_completed_sessions(student.id, since_30d)
            planned_30d = await self.repo.count_planned_sessions_30d(student.id)
            adherence = compute_adherence(total_30d, planned_30d)
            status = compute_status(last_wd)
            personal_id = await self.repo.get_personal_id_for_student(student.id)

            await self.repo.upsert_student_analytics(
                user_id=student.id,
                personal_trainer_id=personal_id,
                total_workouts_30d=total_30d,
                workouts_planned_30d=planned_30d,
                adherence_percentage=adherence,
                last_workout_date=last_wd,
                status=status,
            )
            updated += 1

        await self.repo.commit()
        return updated


# ---------------------------------------------------------------------------
# PDF builder (ReportLab — sem dependências de sistema)
# ---------------------------------------------------------------------------


def _build_pdf(data: Student360DTO) -> BytesIO:
    try:
        from reportlab.lib import colors
        from reportlab.lib.pagesizes import A4
        from reportlab.lib.styles import getSampleStyleSheet
        from reportlab.lib.units import cm
        from reportlab.platypus import (
            Paragraph,
            SimpleDocTemplate,
            Spacer,
            Table,
            TableStyle,
        )
    except ImportError as exc:
        raise RuntimeError(
            "reportlab não instalado. Adicione 'reportlab>=4.0' ao requirements.txt"
        ) from exc

    buffer = BytesIO()
    doc = SimpleDocTemplate(buffer, pagesize=A4, leftMargin=2 * cm, rightMargin=2 * cm)
    styles = getSampleStyleSheet()
    story = []

    # Cabeçalho
    story.append(Paragraph("OmniConnect Fitness — Relatório do Aluno", styles["Title"]))
    story.append(Spacer(1, 0.4 * cm))
    story.append(
        Paragraph(
            f"Gerado em: {datetime.utcnow().strftime('%d/%m/%Y %H:%M')} UTC",
            styles["Normal"],
        )
    )
    story.append(Spacer(1, 0.6 * cm))

    # Informações do aluno
    story.append(Paragraph("Dados do Aluno", styles["Heading2"]))
    info_data = [
        ["Nome", data.name],
        ["Email", data.email],
        ["Status", data.status.upper()],
        ["Adesão (30 dias)", f"{data.adherence_percentage:.1f}%"],
        ["Treinos (30 dias)", str(data.total_workouts_30d)],
        ["Último treino", data.last_workout_date.strftime("%d/%m/%Y") if data.last_workout_date else "—"],
    ]
    if data.weight:
        info_data.append(["Peso", f"{data.weight} kg"])
    if data.height:
        info_data.append(["Altura", f"{data.height} cm"])

    story.append(_make_table(info_data))
    story.append(Spacer(1, 0.6 * cm))

    # Metas ativas
    if data.active_goals:
        story.append(Paragraph("Metas Ativas", styles["Heading2"]))
        goals_data = [["Meta", "Categoria", "Progresso", "Dias restantes"]]
        for g in data.active_goals:
            goals_data.append([
                g.title,
                g.category,
                f"{g.progress_percentage:.1f}%",
                str(g.days_remaining),
            ])
        story.append(_make_table(goals_data, header=True))
        story.append(Spacer(1, 0.6 * cm))

    # Últimos treinos
    if data.recent_workouts:
        story.append(Paragraph("Últimos Treinos", styles["Heading2"]))
        workouts_data = [["Data", "Status", "Exercícios", "Dificuldade", "Humor"]]
        for w in data.recent_workouts:
            workouts_data.append([
                w.session_date.strftime("%d/%m/%Y"),
                w.status,
                str(w.total_exercises),
                str(w.difficulty_level) if w.difficulty_level else "—",
                w.mood or "—",
            ])
        story.append(_make_table(workouts_data, header=True))
        story.append(Spacer(1, 0.6 * cm))

    # Frequência por grupo muscular
    if data.muscle_group_frequency:
        story.append(Paragraph("Frequência por Grupo Muscular (30 dias)", styles["Heading2"]))
        muscle_data = [["Grupo Muscular", "Sessões"]]
        for m in data.muscle_group_frequency:
            muscle_data.append([m.muscle_group, str(m.sessions_count)])
        story.append(_make_table(muscle_data, header=True))
        story.append(Spacer(1, 0.6 * cm))

    # Nutrição
    if data.diet_adherence:
        story.append(Paragraph("Nutrição — Média dos últimos 7 dias", styles["Heading2"]))
        diet_data = [
            ["Dias registrados", str(data.diet_adherence.days_logged)],
            ["Kcal média", f"{data.diet_adherence.avg_kcal:.0f} kcal"],
            ["Proteína média", f"{data.diet_adherence.avg_protein:.1f} g"],
            ["Carboidratos médio", f"{data.diet_adherence.avg_carbs:.1f} g"],
            ["Gordura média", f"{data.diet_adherence.avg_fats:.1f} g"],
        ]
        story.append(_make_table(diet_data))

    doc.build(story)
    buffer.seek(0)
    return buffer


def _make_table(data: list, header: bool = False):
    from reportlab.lib import colors
    from reportlab.platypus import Table, TableStyle

    t = Table(data, hAlign="LEFT")
    style = [
        ("GRID", (0, 0), (-1, -1), 0.5, colors.grey),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("ROWBACKGROUNDS", (0, 0 if not header else 1), (-1, -1), [colors.white, colors.lightgrey]),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]
    if header:
        style += [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#2c3e50")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
        ]
    t.setStyle(TableStyle(style))
    return t
