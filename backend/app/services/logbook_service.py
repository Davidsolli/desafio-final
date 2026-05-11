"""
Serviço do módulo Logbook.

Camada de lógica de negócio para gerenciamento de sessões de treino,
exercícios registrados, calendário e progressão de carga.
"""

import calendar
from collections import defaultdict
from datetime import date, datetime, timedelta
from typing import Dict, List, Optional, Tuple
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.logbook_dto import (
    CalendarDayDTO,
    CalendarResponseDTO,
    CalendarSummaryDTO,
    CreateSessionDTO,
    FrequencyDataPointDTO,
    FrequencyResponseDTO,
    MuscleGroupDistributionItemDTO,
    MuscleGroupDistributionResponseDTO,
    PaginatedSessionsDTO,
    ProgressionDataPointDTO,
    ProgressionResponseDTO,
    ProgressionStatisticsDTO,
    SessionExerciseDTO,
    SessionExerciseResponseDTO,
    SessionListItemDTO,
    SessionResponseDTO,
    UpdateSessionDTO,
)
from app.models.logbook import SessionExercise, WorkoutSession
from app.repositories.logbook_repository import LogbookRepository


# ---------------------------------------------------------------------------
# Exceções de Negócio
# ---------------------------------------------------------------------------


class SessionNotFoundError(Exception):
    """Sessão não encontrada."""


class SessionAlreadyInProgressError(Exception):
    """Aluno já tem uma sessão em progresso."""


class SessionForbiddenError(Exception):
    """Usuário não tem permissão para esta operação."""


class SessionValidationError(Exception):
    """Validação de negócio falhou."""


# ---------------------------------------------------------------------------
# Serviço Principal
# ---------------------------------------------------------------------------


class LogbookService:
    """Serviço de lógica de negócio para o Logbook."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = LogbookRepository(session)

    # ------------------------------------------------------------------
    # Criar Sessão
    # ------------------------------------------------------------------

    async def create_session(
        self, user_id: UUID, dto: CreateSessionDTO
    ) -> SessionResponseDTO:
        """
        Inicia uma nova sessão de treino.

        Regras:
        - Aluno só pode ter 1 sessão 'in_progress' por vez.
        - session_date não pode ser futura (validado no DTO).

        Raises:
            SessionAlreadyInProgressError: Se já existe sessão em progresso.
        """
        in_progress = await self.repository.get_in_progress_session(user_id)
        if in_progress:
            raise SessionAlreadyInProgressError(
                "Já existe uma sessão em progresso. Finalize-a primeiro."
            )

        session_obj = WorkoutSession(
            user_id=user_id,
            workout_sheet_id=dto.workout_sheet_id,
            session_date=dto.session_date,
            status="in_progress",
        )

        created = await self.repository.create_session(session_obj)
        await self.repository.commit()
        return self._to_session_response(created)

    # ------------------------------------------------------------------
    # Adicionar / Atualizar Exercício
    # ------------------------------------------------------------------

    async def add_exercise_to_session(
        self,
        session_id: UUID,
        user_id: UUID,
        role: str,
        dto: SessionExerciseDTO,
    ) -> Tuple[SessionExerciseResponseDTO, bool]:
        """
        Registra ou atualiza um exercício na sessão (upsert por exercise_id).

        Returns:
            Tuple[SessionExerciseResponseDTO, bool]: DTO do exercício e True se criado.

        Raises:
            SessionNotFoundError: Sessão não encontrada.
            SessionForbiddenError: Aluno tentando editar sessão de outro.
            SessionValidationError: Sessão não está em progresso.
        """
        session_obj = await self._get_session_and_check_access(
            session_id, user_id, role, require_owner=True
        )

        if session_obj.status != "in_progress":
            raise SessionValidationError(
                "Só é possível adicionar exercícios a sessões 'in_progress'."
            )

        existing = await self.repository.get_exercise_by_session_and_exercise(
            session_id, dto.exercise_id
        )

        if existing:
            # Atualizar exercício existente
            self._apply_exercise_dto(existing, dto)
            updated = await self.repository.update_exercise(existing)
            await self.repository.commit()
            return self._to_exercise_response(updated), False
        else:
            # Criar novo exercício
            exercise = SessionExercise(
                session_id=session_id,
                exercise_id=dto.exercise_id,
                actual_series=dto.actual_series,
                actual_repetitions=dto.actual_repetitions,
                actual_load_kg=dto.actual_load_kg,
                series_details=dto.series_details,
                exercise_notes=dto.exercise_notes,
                pain_or_discomfort=dto.pain_or_discomfort,
                pain_description=dto.pain_description,
                modification=dto.modification,
                status=dto.status,
            )
            created = await self.repository.add_exercise(exercise)
            await self.repository.commit()
            return self._to_exercise_response(created), True

    # ------------------------------------------------------------------
    # Atualizar / Finalizar Sessão
    # ------------------------------------------------------------------

    async def update_session(
        self,
        session_id: UUID,
        user_id: UUID,
        role: str,
        dto: UpdateSessionDTO,
    ) -> SessionResponseDTO:
        """
        Atualiza ou finaliza uma sessão de treino.

        Regras:
        - Personal não pode editar sessão de aluno.
        - Para finalizar (status='completed'), precisa ter ≥1 exercício.

        Raises:
            SessionNotFoundError, SessionForbiddenError, SessionValidationError.
        """
        session_obj = await self._get_session_and_check_access(
            session_id, user_id, role, require_owner=True
        )

        # Validação: completar sessão exige pelo menos 1 exercício
        if dto.status == "completed":
            count = await self.repository.count_exercises_in_session(session_id)
            if count == 0:
                raise SessionValidationError(
                    "Adicione pelo menos 1 exercício antes de finalizar a sessão."
                )

        if dto.general_notes is not None:
            session_obj.general_notes = dto.general_notes
        if dto.difficulty_level is not None:
            session_obj.difficulty_level = dto.difficulty_level
        if dto.mood is not None:
            session_obj.mood = dto.mood
        if dto.status is not None:
            session_obj.status = dto.status
            if dto.status == "completed" and session_obj.completed_at is None:
                session_obj.completed_at = datetime.utcnow()

        updated = await self.repository.update_session(session_obj)
        await self.repository.commit()
        return self._to_session_response(updated)

    # ------------------------------------------------------------------
    # Buscar Sessão
    # ------------------------------------------------------------------

    async def get_session(
        self, session_id: UUID, user_id: UUID, role: str
    ) -> SessionResponseDTO:
        """
        Busca uma sessão com controle de acesso.

        - Aluno só vê suas próprias sessões.
        - Personal/Admin pode visualizar qualquer sessão.
        """
        session_obj = await self._get_session_and_check_access(
            session_id, user_id, role, require_owner=False
        )
        return self._to_session_response(session_obj)

    # ------------------------------------------------------------------
    # Listar Sessões
    # ------------------------------------------------------------------

    async def list_sessions(
        self,
        requester_id: UUID,
        role: str,
        user_id_filter: Optional[UUID],
        start_date: Optional[datetime],
        end_date: Optional[datetime],
        status_filter: Optional[str],
        page: int,
        limit: int,
    ) -> PaginatedSessionsDTO:
        """
        Lista sessões com filtros e paginação.

        - Aluno só vê as próprias sessões (ignora user_id_filter).
        - Personal/Admin pode filtrar por user_id.
        """
        if role == "client":
            effective_user_id = requester_id
        else:
            effective_user_id = user_id_filter  # pode ser None = todos

        sessions, total = await self.repository.list_sessions(
            user_id=effective_user_id,
            start_date=start_date,
            end_date=end_date,
            status_filter=status_filter,
            page=page,
            limit=limit,
        )

        items = []
        for s in sessions:
            exercises = s.session_exercises if hasattr(s, "session_exercises") else []
            items.append(
                SessionListItemDTO(
                    id=s.id,
                    user_id=s.user_id,
                    workout_sheet_id=s.workout_sheet_id,
                    session_date=s.session_date,
                    status=s.status,
                    difficulty_level=s.difficulty_level,
                    mood=s.mood,
                    completed_at=s.completed_at,
                    created_at=s.created_at,
                    exercise_count=len(exercises),
                )
            )

        return PaginatedSessionsDTO(total=total, page=page, limit=limit, data=items)

    # ------------------------------------------------------------------
    # Deletar Sessão
    # ------------------------------------------------------------------

    async def delete_session(
        self, session_id: UUID, user_id: UUID, role: str
    ) -> None:
        """
        Soft delete de uma sessão.

        - Apenas o próprio aluno pode deletar suas sessões.
        - Personal/Admin não pode deletar.

        Raises:
            SessionNotFoundError, SessionForbiddenError.
        """
        session_obj = await self._get_session_and_check_access(
            session_id, user_id, role, require_owner=True
        )
        if role in ("personal_trainer",):
            raise SessionForbiddenError(
                "Personal não tem permissão para deletar sessões de alunos."
            )
        await self.repository.soft_delete_session(session_obj.id)
        await self.repository.commit()

    # ------------------------------------------------------------------
    # Calendário
    # ------------------------------------------------------------------

    async def get_calendar(
        self,
        user_id: UUID,
        year: int,
        month: int,
    ) -> CalendarResponseDTO:
        """
        Monta o calendário mensal de treinos.

        Cada dia recebe status:
        - 'completed': sessão completa nesse dia
        - 'incomplete': sessão incompleta
        - 'skipped': sessão marcada como pulada
        - 'no_plan': dia sem sessão registrada
        """
        sessions = await self.repository.get_sessions_in_month(user_id, year, month)

        # Mapear dia -> sessão
        session_by_date: dict = {}
        for s in sessions:
            day_key = s.session_date.date().isoformat()
            # Priorizar 'completed' se houver múltiplas sessões no mesmo dia
            if day_key not in session_by_date or s.status == "completed":
                session_by_date[day_key] = s

        num_days = calendar.monthrange(year, month)[1]
        days: List[CalendarDayDTO] = []
        summary = CalendarSummaryDTO()

        for day in range(1, num_days + 1):
            date_obj = datetime(year, month, day).date()
            day_str = date_obj.isoformat()
            weekday = date_obj.weekday()  # 0=segunda … 6=domingo

            if day_str in session_by_date:
                s = session_by_date[day_str]
                ex_count = len(s.session_exercises) if hasattr(s, "session_exercises") else 0
                day_dto = CalendarDayDTO(
                    date=day_str,
                    day_of_week=weekday,
                    status=s.status,
                    session_id=s.id,
                    exercise_count=ex_count,
                )
                # Atualizar resumo
                if s.status == "completed":
                    summary.completed += 1
                elif s.status == "incomplete":
                    summary.incomplete += 1
                elif s.status == "skipped":
                    summary.skipped += 1
                else:
                    summary.no_plan += 1
            else:
                day_dto = CalendarDayDTO(
                    date=day_str,
                    day_of_week=weekday,
                    status="no_plan",
                )
                summary.no_plan += 1

            days.append(day_dto)

        return CalendarResponseDTO(
            year=year,
            month=month,
            user_id=user_id,
            days=days,
            summary=summary,
        )

    # ------------------------------------------------------------------
    # Progressão
    # ------------------------------------------------------------------

    async def get_progression(
        self,
        exercise_id: UUID,
        user_id: UUID,
        weeks: Optional[int],
        start_date: Optional[datetime],
        end_date: Optional[datetime],
        group_by: Optional[str] = None,
    ) -> ProgressionResponseDTO:
        """
        Calcula a evolução de carga de um exercício para um aluno.

        - Se `weeks` fornecido, calcula a janela de data automaticamente.
        - `trend`: "increasing" | "decreasing" | "stable"
        """
        if start_date is None and end_date is None and weeks:
            end_date = datetime.utcnow()
            start_date = end_date - timedelta(weeks=weeks)

        exercises = await self.repository.get_progression_data(
            user_id, exercise_id, start_date, end_date
        )

        if not exercises:
            return ProgressionResponseDTO(
                exercise_id=exercise_id,
                user_id=user_id,
                data_points=[],
                statistics=ProgressionStatisticsDTO(
                    total_sessions=0,
                    avg_load_kg=0.0,
                    max_load_kg=0.0,
                    min_load_kg=0.0,
                    avg_volume_kg=0.0,
                    trend="stable",
                    improvement_percentage=0.0,
                ),
            )

        data_points: List[ProgressionDataPointDTO] = []
        for ex in exercises:
            session_date = await self.repository.get_session_date_for_exercise(ex)
            if session_date is None:
                continue

            series = ex.actual_series or 0
            reps = ex.actual_repetitions or 0
            load = ex.actual_load_kg or 0.0
            volume = series * reps * load

            data_points.append(
                ProgressionDataPointDTO(
                    session_date=session_date,
                    actual_load_kg=load,
                    actual_series=series,
                    actual_repetitions=reps,
                    volume_kg=volume,
                )
            )

        # Agrupar por período se solicitado
        if group_by in ("week", "month") and data_points:
            data_points = self._group_data_points(data_points, group_by)

        # Calcular estatísticas
        loads = [dp.actual_load_kg for dp in data_points]
        volumes = [dp.volume_kg for dp in data_points]

        avg_load = sum(loads) / len(loads) if loads else 0.0
        max_load = max(loads) if loads else 0.0
        min_load = min(loads) if loads else 0.0
        avg_volume = sum(volumes) / len(volumes) if volumes else 0.0

        # Trend: comparar primeira vs última carga
        trend = "stable"
        improvement = 0.0
        if len(loads) >= 2:
            first, last = loads[0], loads[-1]
            if last > first:
                trend = "increasing"
                improvement = round(((last - first) / first) * 100, 2) if first > 0 else 0.0
            elif last < first:
                trend = "decreasing"
                improvement = round(((last - first) / first) * 100, 2) if first > 0 else 0.0

        statistics = ProgressionStatisticsDTO(
            total_sessions=len(data_points),
            avg_load_kg=round(avg_load, 2),
            max_load_kg=max_load,
            min_load_kg=min_load,
            avg_volume_kg=round(avg_volume, 2),
            trend=trend,
            improvement_percentage=improvement,
        )

        return ProgressionResponseDTO(
            exercise_id=exercise_id,
            user_id=user_id,
            data_points=data_points,
            statistics=statistics,
        )

    # ------------------------------------------------------------------
    # Helpers Privados
    # ------------------------------------------------------------------

    async def _get_session_and_check_access(
        self,
        session_id: UUID,
        user_id: UUID,
        role: str,
        require_owner: bool,
    ) -> WorkoutSession:
        """
        Busca a sessão e valida permissões de acesso.

        - `require_owner=True`: apenas o dono (aluno) pode operar.
        - `require_owner=False`: personal/admin também pode visualizar.
        """
        session_obj = await self.repository.get_session_by_id(session_id)
        if not session_obj:
            raise SessionNotFoundError("Sessão de treino não encontrada.")

        if role == "client" and session_obj.user_id != user_id:
            raise SessionForbiddenError(
                "Você não tem permissão para acessar esta sessão."
            )

        if require_owner and role in ("personal_trainer",):
            if session_obj.user_id != user_id:
                raise SessionForbiddenError(
                    "Personal não tem permissão para editar sessões de alunos."
                )

        return session_obj

    @staticmethod
    def _to_session_response(session_obj: WorkoutSession) -> SessionResponseDTO:
        """Converte WorkoutSession para SessionResponseDTO."""
        exercises = []
        if hasattr(session_obj, "session_exercises") and session_obj.session_exercises:
            exercises = [
                LogbookService._to_exercise_response(ex)
                for ex in session_obj.session_exercises
            ]

        return SessionResponseDTO(
            id=session_obj.id,
            user_id=session_obj.user_id,
            workout_sheet_id=session_obj.workout_sheet_id,
            session_date=session_obj.session_date,
            status=session_obj.status,
            general_notes=session_obj.general_notes,
            difficulty_level=session_obj.difficulty_level,
            mood=session_obj.mood,
            created_at=session_obj.created_at,
            updated_at=session_obj.updated_at,
            completed_at=session_obj.completed_at,
            session_exercises=exercises,
        )

    @staticmethod
    def _to_exercise_response(exercise: SessionExercise) -> SessionExerciseResponseDTO:
        """Converte SessionExercise para SessionExerciseResponseDTO."""
        return SessionExerciseResponseDTO(
            id=exercise.id,
            session_id=exercise.session_id,
            exercise_id=exercise.exercise_id,
            planned_series=exercise.planned_series,
            planned_repetitions=exercise.planned_repetitions,
            planned_load_kg=exercise.planned_load_kg,
            actual_series=exercise.actual_series,
            actual_repetitions=exercise.actual_repetitions,
            actual_load_kg=exercise.actual_load_kg,
            series_details=exercise.series_details,
            exercise_notes=exercise.exercise_notes,
            pain_or_discomfort=exercise.pain_or_discomfort,
            pain_description=exercise.pain_description,
            modification=exercise.modification,
            status=exercise.status,
            created_at=exercise.created_at,
            updated_at=exercise.updated_at,
        )

    @staticmethod
    def _apply_exercise_dto(exercise: SessionExercise, dto: SessionExerciseDTO) -> None:
        """Aplica os campos do DTO a um exercício existente (update)."""
        if dto.actual_series is not None:
            exercise.actual_series = dto.actual_series
        if dto.actual_repetitions is not None:
            exercise.actual_repetitions = dto.actual_repetitions
        if dto.actual_load_kg is not None:
            exercise.actual_load_kg = dto.actual_load_kg
        if dto.series_details is not None:
            exercise.series_details = dto.series_details
        if dto.exercise_notes is not None:
            exercise.exercise_notes = dto.exercise_notes
        exercise.pain_or_discomfort = dto.pain_or_discomfort
        if dto.pain_description is not None:
            exercise.pain_description = dto.pain_description
        if dto.modification is not None:
            exercise.modification = dto.modification
        exercise.status = dto.status

    # ------------------------------------------------------------------
    # Frequência
    # ------------------------------------------------------------------

    async def get_frequency(
        self,
        user_id: UUID,
        period: str,
        limit: Optional[int],
    ) -> FrequencyResponseDTO:
        """
        Retorna frequência de treinos agrupados por período (semana ou mês).

        Args:
            user_id: ID do aluno
            period: "weekly" ou "monthly"
            limit: Número de períodos a retornar (ex: 12 últimas semanas)
        """
        if period not in ("weekly", "monthly"):
            raise ValueError("period deve ser 'weekly' ou 'monthly'")

        period_key = "week" if period == "weekly" else "month"

        # Calcular datas de início e fim
        now = datetime.utcnow()
        if period == "weekly":
            if limit is None:
                limit = 12
            start_date = now - timedelta(weeks=limit)
        else:
            if limit is None:
                limit = 6
            start_date = self._subtract_months(now, limit)

        end_date = now

        # Buscar dados agrupados
        grouped_data = await self.repository.get_frequency_data(
            user_id=user_id,
            period=period_key,
            start_date=start_date,
            end_date=end_date,
        )

        # Gerar todos os períodos entre start_date e end_date (preenchendo zeros)
        all_periods = self._generate_periods(start_date, end_date, period)

        # Criar mapa de dados agrupados
        data_map = {}
        for period_start_dt, count in grouped_data:
            data_map[period_start_dt.date()] = count

        # Criar data points preenchendo períodos sem dados
        data_points = []
        for period_start, period_end in all_periods:
            count = data_map.get(period_start.date(), 0)
            data_points.append(
                FrequencyDataPointDTO(
                    period_start=period_start,
                    period_end=period_end,
                    count=count,
                )
            )

        return FrequencyResponseDTO(
            user_id=user_id,
            period=period,
            data_points=data_points,
        )

    @staticmethod
    def _generate_periods(
        start_date: datetime, end_date: datetime, period: str
    ) -> List[Tuple[datetime, datetime]]:
        """
        Gera lista de períodos entre start_date e end_date.

        Args:
            start_date: Data inicial
            end_date: Data final
            period: "weekly" ou "monthly"

        Returns:
            Lista de tuplas (period_start, period_end)
        """
        periods = []
        current = start_date.replace(hour=0, minute=0, second=0, microsecond=0)

        if period == "weekly":
            # Segunda-feira da semana de start_date
            days_since_monday = current.weekday()
            current = current - timedelta(days=days_since_monday)

            while current <= end_date:
                period_start = current
                period_end = datetime.combine(
                    (current + timedelta(days=6)).date(), datetime.max.time()
                )
                periods.append((period_start, period_end))
                current += timedelta(days=7)
        else:  # monthly
            # Primeiro dia do mes
            current = current.replace(day=1)

            while current <= end_date:
                period_start = current
                # Último dia do mês
                if current.month == 12:
                    period_end = date(current.year + 1, 1, 1) - timedelta(days=1)
                    period_end = datetime.combine(
                        period_end, datetime.max.time()
                    )
                else:
                    period_end = (
                        date(current.year, current.month + 1, 1) - timedelta(days=1)
                    )
                    period_end = datetime.combine(
                        period_end, datetime.max.time()
                    )

                periods.append((period_start, period_end))
                if current.month == 12:
                    current = datetime(current.year + 1, 1, 1)
                else:
                    current = datetime(current.year, current.month + 1, 1)

        return periods

    @staticmethod
    def _subtract_months(dt: datetime, months: int) -> datetime:
        """Subtrai `months` meses de `dt`, respeitando o último dia do mês alvo."""
        month = dt.month - months
        year = dt.year
        while month <= 0:
            month += 12
            year -= 1
        last_day = calendar.monthrange(year, month)[1]
        return dt.replace(year=year, month=month, day=min(dt.day, last_day))

    @staticmethod
    def _group_data_points(
        data_points: List[ProgressionDataPointDTO],
        group_by: str,
    ) -> List[ProgressionDataPointDTO]:
        """Agrupa data_points por semana ou mês, mantendo o registro de maior carga por período."""
        def period_key(dt: datetime) -> datetime:
            if group_by == "week":
                return (dt - timedelta(days=dt.weekday())).replace(
                    hour=0, minute=0, second=0, microsecond=0
                )
            return dt.replace(day=1, hour=0, minute=0, second=0, microsecond=0)

        groups: Dict[datetime, List[ProgressionDataPointDTO]] = defaultdict(list)
        for dp in data_points:
            groups[period_key(dp.session_date)].append(dp)

        result = []
        for key in sorted(groups.keys()):
            best = max(groups[key], key=lambda dp: dp.actual_load_kg)
            result.append(best)
        return result

    # ------------------------------------------------------------------
    # Foco Muscular (Novo)
    # ------------------------------------------------------------------

    async def get_muscle_group_distribution(
        self,
        user_id: UUID,
        days: int = 30,
    ) -> MuscleGroupDistributionResponseDTO:
        """
        Retorna a distribuição de exercícios concluídos por grupo muscular.

        Args:
            user_id: ID do aluno
            days: Janela de dias retroativos (padrão 30)
        """
        end_date = datetime.utcnow()
        start_date = end_date - timedelta(days=days)

        raw_distribution = await self.repository.get_muscle_group_distribution(
            user_id=user_id,
            start_date=start_date,
            end_date=end_date,
        )

        distribution_items = [
            MuscleGroupDistributionItemDTO(muscle_group=muscle, count=count)
            for muscle, count in raw_distribution
        ]

        return MuscleGroupDistributionResponseDTO(
            user_id=user_id,
            days=days,
            distribution=distribution_items,
        )

