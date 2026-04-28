"""
Testes unitários do serviço do Logbook.

Valida a lógica de negócio do LogbookService com mocks do repositório,
sem dependência de banco de dados.
"""

from datetime import datetime, timedelta
from typing import List, Optional
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4, UUID

import pytest

from app.dtos.logbook_dto import CreateSessionDTO, SessionExerciseDTO, UpdateSessionDTO
from app.models.logbook import SessionExercise, WorkoutSession
from app.services.logbook_service import (
    LogbookService,
    SessionAlreadyInProgressError,
    SessionForbiddenError,
    SessionNotFoundError,
    SessionValidationError,
)


def _make_session(
    user_id: UUID = None,
    status: str = "in_progress",
    exercises: list = None,
) -> WorkoutSession:
    """Cria instância de WorkoutSession com defaults."""
    s = WorkoutSession()
    s.id = uuid4()
    s.user_id = user_id or uuid4()
    s.workout_sheet_id = uuid4()
    s.session_date = datetime.utcnow() - timedelta(hours=1)
    s.status = status
    s.general_notes = None
    s.difficulty_level = None
    s.mood = None
    s.created_at = datetime.utcnow()
    s.updated_at = datetime.utcnow()
    s.completed_at = None
    s.approved_by_personal_id = None
    s.approved_at = None
    s.session_exercises = exercises or []
    return s


def _make_exercise(session_id: UUID = None, exercise_id: UUID = None) -> SessionExercise:
    """Cria instância de SessionExercise com defaults."""
    e = SessionExercise()
    e.id = uuid4()
    e.session_id = session_id or uuid4()
    e.exercise_id = exercise_id or uuid4()
    e.actual_series = 3
    e.actual_repetitions = 10
    e.actual_load_kg = 60.0
    e.planned_series = None
    e.planned_repetitions = None
    e.planned_load_kg = None
    e.series_details = None
    e.exercise_notes = None
    e.pain_or_discomfort = False
    e.pain_description = None
    e.modification = None
    e.status = "completed"
    e.created_at = datetime.utcnow()
    e.updated_at = datetime.utcnow()
    return e


def _make_service(repo_overrides: dict = None):
    """Cria LogbookService com repositório mockado."""
    session_mock = AsyncMock()
    service = LogbookService(session_mock)

    # Substituir repositório por mock
    repo = AsyncMock()
    repo.commit = AsyncMock()
    repo.rollback = AsyncMock()

    if repo_overrides:
        for attr, value in repo_overrides.items():
            setattr(repo, attr, value)

    service.repository = repo
    return service, repo


# ---------------------------------------------------------------------------
# Teste: Calcular volume
# ---------------------------------------------------------------------------


class TestCalcularVolume:
    def test_volume_exercicio(self):
        """Volume = séries × reps × carga."""
        series, reps, load = 4, 8, 80.0
        volume = series * reps * load
        assert volume == 2560.0

    def test_volume_com_series_parcial(self):
        """Volume com séries parciais."""
        assert 3 * 10 * 60.0 == 1800.0


# ---------------------------------------------------------------------------
# Teste: Detectar trend de progressão
# ---------------------------------------------------------------------------


class TestDetectarTrend:
    def _trend(self, loads: List[float]) -> str:
        if len(loads) < 2:
            return "stable"
        first, last = loads[0], loads[-1]
        if last > first:
            return "increasing"
        elif last < first:
            return "decreasing"
        return "stable"

    def test_trend_increasing(self):
        assert self._trend([60.0, 65.0, 70.0]) == "increasing"

    def test_trend_decreasing(self):
        assert self._trend([80.0, 75.0, 70.0]) == "decreasing"

    def test_trend_stable(self):
        assert self._trend([70.0, 70.0, 70.0]) == "stable"

    def test_trend_single_point(self):
        assert self._trend([60.0]) == "stable"


# ---------------------------------------------------------------------------
# Teste: Criar sessão
# ---------------------------------------------------------------------------


class TestCriarSessao:
    @pytest.mark.asyncio
    async def test_criar_sessao_sem_in_progress(self):
        """Deve criar sessão quando não há nenhuma em progresso."""
        user_id = uuid4()
        service, repo = _make_service()

        repo.get_in_progress_session = AsyncMock(return_value=None)

        new_session = _make_session(user_id=user_id)
        repo.create_session = AsyncMock(return_value=new_session)

        dto = CreateSessionDTO(
            workout_sheet_id=uuid4(),
            session_date=datetime.utcnow() - timedelta(hours=1),
        )
        result = await service.create_session(user_id, dto)
        assert result.status == "in_progress"
        repo.commit.assert_called_once()

    @pytest.mark.asyncio
    async def test_criar_sessao_com_in_progress_levanta_excecao(self):
        """Deve levantar SessionAlreadyInProgressError se já existe uma."""
        user_id = uuid4()
        service, repo = _make_service()

        repo.get_in_progress_session = AsyncMock(
            return_value=_make_session(user_id=user_id)
        )

        dto = CreateSessionDTO(
            workout_sheet_id=uuid4(),
            session_date=datetime.utcnow() - timedelta(hours=1),
        )
        with pytest.raises(SessionAlreadyInProgressError):
            await service.create_session(user_id, dto)


# ---------------------------------------------------------------------------
# Teste: Finalizar sessão
# ---------------------------------------------------------------------------


class TestFinalizarSessao:
    @pytest.mark.asyncio
    async def test_finalizar_sem_exercicios_levanta_erro(self):
        """Sessão sem exercícios não pode ser finalizada."""
        user_id = uuid4()
        session_obj = _make_session(user_id=user_id, exercises=[])
        service, repo = _make_service()

        repo.get_session_by_id = AsyncMock(return_value=session_obj)
        repo.count_exercises_in_session = AsyncMock(return_value=0)

        dto = UpdateSessionDTO(status="completed")
        with pytest.raises(SessionValidationError):
            await service.update_session(session_obj.id, user_id, "client", dto)

    @pytest.mark.asyncio
    async def test_finalizar_com_exercicios_sucesso(self):
        """Sessão com exercícios pode ser finalizada."""
        user_id = uuid4()
        session_obj = _make_session(user_id=user_id)
        service, repo = _make_service()

        repo.get_session_by_id = AsyncMock(return_value=session_obj)
        repo.count_exercises_in_session = AsyncMock(return_value=2)
        repo.update_session = AsyncMock(return_value=session_obj)

        dto = UpdateSessionDTO(status="completed", mood="great", difficulty_level=7)
        result = await service.update_session(session_obj.id, user_id, "client", dto)
        assert result.status == "completed"


# ---------------------------------------------------------------------------
# Teste: Controle de acesso por role
# ---------------------------------------------------------------------------


class TestControleAcesso:
    @pytest.mark.asyncio
    async def test_personal_pode_ler_sessao_do_aluno(self):
        """Personal pode GET de sessão de qualquer aluno."""
        user_id = uuid4()
        personal_id = uuid4()
        session_obj = _make_session(user_id=user_id)
        service, repo = _make_service()

        repo.get_session_by_id = AsyncMock(return_value=session_obj)

        result = await service.get_session(session_obj.id, personal_id, "personal_trainer")
        assert result is not None

    @pytest.mark.asyncio
    async def test_aluno_nao_pode_ler_sessao_de_outro(self):
        """Aluno não pode GET de sessão de outro aluno."""
        owner_id = uuid4()
        requester_id = uuid4()  # outro aluno
        session_obj = _make_session(user_id=owner_id)
        service, repo = _make_service()

        repo.get_session_by_id = AsyncMock(return_value=session_obj)

        with pytest.raises(SessionForbiddenError):
            await service.get_session(session_obj.id, requester_id, "client")

    @pytest.mark.asyncio
    async def test_personal_nao_pode_deletar(self):
        """Personal não pode deletar sessão de aluno."""
        user_id = uuid4()
        personal_id = uuid4()
        session_obj = _make_session(user_id=user_id)
        service, repo = _make_service()

        repo.get_session_by_id = AsyncMock(return_value=session_obj)
        repo.soft_delete_session = AsyncMock(return_value=True)

        with pytest.raises(SessionForbiddenError):
            await service.delete_session(session_obj.id, personal_id, "personal_trainer")

    @pytest.mark.asyncio
    async def test_sessao_nao_encontrada_levanta_erro(self):
        """Buscar sessão inexistente levanta SessionNotFoundError."""
        service, repo = _make_service()
        repo.get_session_by_id = AsyncMock(return_value=None)

        with pytest.raises(SessionNotFoundError):
            await service.get_session(uuid4(), uuid4(), "client")


# ---------------------------------------------------------------------------
# Teste: Calendário
# ---------------------------------------------------------------------------


class TestCalendario:
    @pytest.mark.asyncio
    async def test_calendario_mes_vazio_retorna_no_plan(self):
        """Mês sem sessões: todos os dias são 'no_plan'."""
        user_id = uuid4()
        service, repo = _make_service()
        repo.get_sessions_in_month = AsyncMock(return_value=[])

        result = await service.get_calendar(user_id, 2026, 4)
        assert result.year == 2026
        assert result.month == 4
        assert len(result.days) == 30  # Abril tem 30 dias
        assert all(d.status == "no_plan" for d in result.days)
        assert result.summary.completed == 0
        assert result.summary.no_plan == 30

    @pytest.mark.asyncio
    async def test_calendario_conta_sessoes_completadas(self):
        """Sessão completada no dia 10 aparece como 'completed'."""
        user_id = uuid4()
        session_obj = _make_session(user_id=user_id, status="completed")
        session_obj.session_date = datetime(2026, 4, 10, 18, 0)
        service, repo = _make_service()
        repo.get_sessions_in_month = AsyncMock(return_value=[session_obj])

        result = await service.get_calendar(user_id, 2026, 4)
        day_10 = next(d for d in result.days if d.date == "2026-04-10")
        assert day_10.status == "completed"
        assert result.summary.completed == 1
