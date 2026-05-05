"""
Testes unitários do DashboardService.

Cobre:
- compute_status: semáforo baseado em last_workout_date
- compute_adherence: cálculo com edge cases (zero planejado)
- _build_pdf: BytesIO com conteúdo PDF válido
"""

from datetime import datetime, timedelta
from io import BytesIO
from uuid import uuid4

import pytest

from app.services.dashboard_service import compute_status, compute_adherence, _build_pdf
from app.dtos.dashboard_dto import Student360DTO


# ---------------------------------------------------------------------------
# compute_status
# ---------------------------------------------------------------------------


class TestComputeStatus:
    def test_none_date_returns_inactive(self):
        assert compute_status(None) == "inactive"

    def test_today_returns_engaged(self):
        assert compute_status(datetime.utcnow()) == "engaged"

    def test_6_days_ago_returns_engaged(self):
        assert compute_status(datetime.utcnow() - timedelta(days=6)) == "engaged"

    def test_exactly_7_days_ago_returns_engaged(self):
        assert compute_status(datetime.utcnow() - timedelta(days=7)) == "engaged"

    def test_8_days_ago_returns_at_risk(self):
        assert compute_status(datetime.utcnow() - timedelta(days=8)) == "at_risk"

    def test_14_days_ago_returns_at_risk(self):
        assert compute_status(datetime.utcnow() - timedelta(days=14)) == "at_risk"

    def test_15_days_ago_returns_inactive(self):
        assert compute_status(datetime.utcnow() - timedelta(days=15)) == "inactive"

    def test_30_days_ago_returns_inactive(self):
        assert compute_status(datetime.utcnow() - timedelta(days=30)) == "inactive"


# ---------------------------------------------------------------------------
# compute_adherence
# ---------------------------------------------------------------------------


class TestComputeAdherence:
    def test_zero_planned_returns_zero(self):
        assert compute_adherence(5, 0) == 0.0

    def test_negative_planned_returns_zero(self):
        assert compute_adherence(5, -1) == 0.0

    def test_perfect_adherence(self):
        assert compute_adherence(10, 10) == 100.0

    def test_half_adherence(self):
        assert compute_adherence(5, 10) == 50.0

    def test_over_100_is_capped_at_100(self):
        assert compute_adherence(15, 10) == 100.0

    def test_rounding_to_one_decimal(self):
        result = compute_adherence(1, 3)
        assert result == 33.3

    def test_zero_completed(self):
        assert compute_adherence(0, 10) == 0.0


# ---------------------------------------------------------------------------
# _build_pdf
# ---------------------------------------------------------------------------


class TestBuildPdf:
    def _minimal_360(self) -> Student360DTO:
        return Student360DTO(
            student_id=uuid4(),
            name="Aluno Teste",
            email="aluno@teste.com",
            status="engaged",
            adherence_percentage=75.0,
            total_workouts_30d=12,
            last_workout_date=datetime.utcnow() - timedelta(days=2),
            recent_workouts=[],
            active_goals=[],
            diet_adherence=None,
            muscle_group_frequency=[],
        )

    def test_returns_bytesio(self):
        pdf = _build_pdf(self._minimal_360())
        assert isinstance(pdf, BytesIO)

    def test_pdf_has_content(self):
        pdf = _build_pdf(self._minimal_360())
        content = pdf.read()
        assert len(content) > 0

    def test_pdf_starts_with_pdf_header(self):
        pdf = _build_pdf(self._minimal_360())
        content = pdf.read()
        assert content[:4] == b"%PDF"

    def test_buffer_is_seeked_to_zero(self):
        pdf = _build_pdf(self._minimal_360())
        assert pdf.tell() == 0

    def test_pdf_with_goals_and_workouts(self):
        from app.dtos.dashboard_dto import GoalSummaryDTO, WorkoutSummaryDTO

        data = self._minimal_360()
        data.active_goals = [
            GoalSummaryDTO(
                goal_id=uuid4(),
                title="Perder 5kg",
                category="weight_loss",
                progress_percentage=40.0,
                status="active",
                target_date=datetime.utcnow() + timedelta(days=60),
                days_remaining=60,
            )
        ]
        data.recent_workouts = [
            WorkoutSummaryDTO(
                session_id=uuid4(),
                session_date=datetime.utcnow() - timedelta(days=1),
                status="completed",
                difficulty_level=7,
                mood="good",
                total_exercises=5,
            )
        ]
        pdf = _build_pdf(data)
        assert pdf.read()[:4] == b"%PDF"
