"""
Testes unitários dos DTOs do módulo Logbook.

Valida regras de validação Pydantic sem dependência de banco.
"""

from datetime import datetime, timedelta
from uuid import uuid4

import pytest

from app.dtos.logbook_dto import (
    CreateSessionDTO,
    SessionExerciseDTO,
    UpdateSessionDTO,
)


VALID_EXERCISE_ID = uuid4()
VALID_SHEET_ID = uuid4()


# ---------------------------------------------------------------------------
# CreateSessionDTO
# ---------------------------------------------------------------------------


class TestCreateSessionDTO:
    def test_valido_com_data_passada(self):
        dto = CreateSessionDTO(
            workout_sheet_id=VALID_SHEET_ID,
            session_date=datetime.utcnow() - timedelta(hours=1),
        )
        assert dto.workout_sheet_id == VALID_SHEET_ID

    def test_rejeita_data_futura(self):
        with pytest.raises(ValueError, match="futuro"):
            CreateSessionDTO(
                workout_sheet_id=VALID_SHEET_ID,
                session_date=datetime.utcnow() + timedelta(days=1),
            )

    def test_rejeita_workout_sheet_id_invalido(self):
        with pytest.raises(Exception):
            CreateSessionDTO(
                workout_sheet_id="nao-e-uuid",
                session_date=datetime.utcnow() - timedelta(hours=1),
            )


# ---------------------------------------------------------------------------
# SessionExerciseDTO
# ---------------------------------------------------------------------------


class TestSessionExerciseDTO:
    def _valid(self, **overrides):
        defaults = {
            "exercise_id": VALID_EXERCISE_ID,
            "actual_series": 3,
            "actual_repetitions": 10,
            "actual_load_kg": 60.0,
            "status": "completed",
        }
        defaults.update(overrides)
        return SessionExerciseDTO(**defaults)

    def test_valido_completo(self):
        dto = self._valid()
        assert dto.actual_series == 3
        assert dto.status == "completed"

    def test_rejeita_series_zero(self):
        with pytest.raises(ValueError):
            self._valid(actual_series=0)

    def test_rejeita_series_negativa(self):
        with pytest.raises(ValueError):
            self._valid(actual_series=-1)

    def test_rejeita_repeticoes_zero(self):
        with pytest.raises(ValueError):
            self._valid(actual_repetitions=0)

    def test_rejeita_carga_negativa(self):
        with pytest.raises(ValueError):
            self._valid(actual_load_kg=-5.0)

    def test_rejeita_carga_zero(self):
        with pytest.raises(ValueError):
            self._valid(actual_load_kg=0.0)

    def test_rejeita_status_invalido(self):
        with pytest.raises(ValueError):
            self._valid(status="feito")

    def test_aceita_status_partial(self):
        dto = self._valid(status="partial")
        assert dto.status == "partial"

    def test_aceita_status_skipped(self):
        dto = self._valid(status="skipped")
        assert dto.status == "skipped"

    def test_pain_sem_description_rejeita(self):
        with pytest.raises(ValueError, match="pain_description"):
            self._valid(pain_or_discomfort=True, pain_description=None)

    def test_pain_com_description_aceita(self):
        dto = self._valid(
            pain_or_discomfort=True,
            pain_description="Dor no ombro esquerdo",
        )
        assert dto.pain_or_discomfort is True
        assert dto.pain_description == "Dor no ombro esquerdo"

    def test_sem_pain_sem_description_aceita(self):
        dto = self._valid(pain_or_discomfort=False)
        assert dto.pain_or_discomfort is False

    def test_series_details_aceita_lista_json(self):
        details = [{"series": 1, "reps": 8, "load": 80}]
        dto = self._valid(series_details=details)
        assert dto.series_details == details


# ---------------------------------------------------------------------------
# UpdateSessionDTO
# ---------------------------------------------------------------------------


class TestUpdateSessionDTO:
    def test_valido_todos_campos(self):
        dto = UpdateSessionDTO(
            general_notes="Treino ótimo",
            difficulty_level=7,
            mood="great",
            status="completed",
        )
        assert dto.mood == "great"
        assert dto.difficulty_level == 7

    def test_valido_campos_opcionais_nulos(self):
        dto = UpdateSessionDTO()
        assert dto.general_notes is None
        assert dto.mood is None

    def test_rejeita_mood_invalido(self):
        with pytest.raises(ValueError):
            UpdateSessionDTO(mood="superfeliz")

    def test_rejeita_status_invalido(self):
        with pytest.raises(ValueError):
            UpdateSessionDTO(status="in_progress")

    def test_rejeita_difficulty_fora_do_range(self):
        with pytest.raises(ValueError):
            UpdateSessionDTO(difficulty_level=11)

    def test_rejeita_difficulty_zero(self):
        with pytest.raises(ValueError):
            UpdateSessionDTO(difficulty_level=0)

    def test_aceita_todos_moods(self):
        for mood in ("great", "good", "normal", "bad", "terrible"):
            dto = UpdateSessionDTO(mood=mood)
            assert dto.mood == mood

    def test_aceita_status_incomplete(self):
        dto = UpdateSessionDTO(status="incomplete")
        assert dto.status == "incomplete"

    def test_aceita_status_skipped(self):
        dto = UpdateSessionDTO(status="skipped")
        assert dto.status == "skipped"
