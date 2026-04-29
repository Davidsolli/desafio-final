"""
Testes unitários para os DTOs de Ficha de Treino.

Verifica validações do Pydantic sem depender do banco de dados.
"""

import pytest
from uuid import uuid4
from pydantic import ValidationError

from app.dtos.workout_sheet_dto import (
    ExerciseCreateDTO,
    CreateWorkoutSheetDTO,
    UpdateWorkoutSheetDTO,
    DuplicateWorkoutSheetDTO,
    VALID_MUSCLE_GROUPS,
)


# ---------------------------------------------------------------------------
# Teste 1: ExerciseCreateDTO válido
# ---------------------------------------------------------------------------


def test_exercise_create_dto_valid():
    """DTO de exercício válido deve ser criado sem erros."""
    dto = ExerciseCreateDTO(
        name="Supino Reto",
        muscle_group="peito",
        series=4,
        repetitions=8,
        load_kg=80.0,
        rest_seconds=120,
        observations="Manter escápula retraída",
        order=1,
    )
    assert dto.name == "Supino Reto"
    assert dto.muscle_group == "peito"
    assert dto.series == 4
    assert dto.repetitions == 8
    assert dto.load_kg == 80.0


# ---------------------------------------------------------------------------
# Teste 2: Todos os muscle_groups válidos devem ser aceitos
# ---------------------------------------------------------------------------


@pytest.mark.parametrize("mg", list(VALID_MUSCLE_GROUPS))
def test_exercise_all_valid_muscle_groups(mg):
    """Todos os muscle_groups do VALID_MUSCLE_GROUPS devem ser aceitos."""
    dto = ExerciseCreateDTO(
        name=f"Exercício {mg}",
        muscle_group=mg,
        series=3,
        repetitions=10,
        load_kg=50.0,
        order=1,
    )
    assert dto.muscle_group == mg


# ---------------------------------------------------------------------------
# Teste 3: muscle_group inválido deve lançar ValidationError
# ---------------------------------------------------------------------------


def test_exercise_invalid_muscle_group():
    """muscle_group fora do conjunto válido deve lançar ValidationError."""
    with pytest.raises(ValidationError) as exc_info:
        ExerciseCreateDTO(
            name="Exercício",
            muscle_group="INVALIDO_XPTO",
            series=3,
            repetitions=10,
            load_kg=50.0,
            order=1,
        )
    errors = exc_info.value.errors()
    assert any("muscle_group" in str(e) for e in errors)


# ---------------------------------------------------------------------------
# Teste 4: series <= 0 deve lançar ValidationError
# ---------------------------------------------------------------------------


def test_exercise_series_zero():
    """series = 0 deve lançar ValidationError."""
    with pytest.raises(ValidationError):
        ExerciseCreateDTO(
            name="Exercício",
            muscle_group="peito",
            series=0,
            repetitions=10,
            load_kg=50.0,
            order=1,
        )


def test_exercise_series_negative():
    """series < 0 deve lançar ValidationError."""
    with pytest.raises(ValidationError):
        ExerciseCreateDTO(
            name="Exercício",
            muscle_group="peito",
            series=-1,
            repetitions=10,
            load_kg=50.0,
            order=1,
        )


# ---------------------------------------------------------------------------
# Teste 5: repetitions <= 0 deve lançar ValidationError
# ---------------------------------------------------------------------------


def test_exercise_repetitions_zero():
    """repetitions = 0 deve lançar ValidationError."""
    with pytest.raises(ValidationError):
        ExerciseCreateDTO(
            name="Exercício",
            muscle_group="peito",
            series=3,
            repetitions=0,
            load_kg=50.0,
            order=1,
        )


# ---------------------------------------------------------------------------
# Teste 6: load_kg <= 0 deve lançar ValidationError
# ---------------------------------------------------------------------------


def test_exercise_load_zero():
    """load_kg = 0 deve lançar ValidationError."""
    with pytest.raises(ValidationError):
        ExerciseCreateDTO(
            name="Exercício",
            muscle_group="peito",
            series=3,
            repetitions=10,
            load_kg=0.0,
            order=1,
        )


def test_exercise_load_negative():
    """load_kg < 0 deve lançar ValidationError."""
    with pytest.raises(ValidationError):
        ExerciseCreateDTO(
            name="Exercício",
            muscle_group="peito",
            series=3,
            repetitions=10,
            load_kg=-10.0,
            order=1,
        )


# ---------------------------------------------------------------------------
# Teste 7: rest_seconds = 0 é válido (descanso mínimo)
# ---------------------------------------------------------------------------


def test_exercise_rest_seconds_zero_valid():
    """rest_seconds = 0 deve ser aceito (sem descanso)."""
    dto = ExerciseCreateDTO(
        name="Exercício",
        muscle_group="core",
        series=3,
        repetitions=20,
        load_kg=10.0,
        rest_seconds=0,
        order=1,
    )
    assert dto.rest_seconds == 0


# ---------------------------------------------------------------------------
# Teste 8: CreateWorkoutSheetDTO válido
# ---------------------------------------------------------------------------


def test_create_workout_sheet_dto_valid():
    """CreateWorkoutSheetDTO válido deve ser criado sem erros."""
    user_id = uuid4()
    dto = CreateWorkoutSheetDTO(
        user_id=user_id,
        name="Treino A - Peito",
        description="Foco em força",
        day_of_week=0,
        exercises=[
            ExerciseCreateDTO(
                name="Supino Reto",
                muscle_group="peito",
                series=4,
                repetitions=8,
                load_kg=80.0,
                order=1,
            )
        ],
    )
    assert dto.user_id == user_id
    assert dto.day_of_week == 0
    assert len(dto.exercises) == 1


# ---------------------------------------------------------------------------
# Teste 9: day_of_week fora de 0-6 deve falhar
# ---------------------------------------------------------------------------


def test_create_sheet_invalid_day_of_week():
    """day_of_week = 7 deve lançar ValidationError."""
    with pytest.raises(ValidationError):
        CreateWorkoutSheetDTO(
            user_id=uuid4(),
            name="Treino",
            day_of_week=7,  # inválido
            exercises=[],
        )


def test_create_sheet_negative_day_of_week():
    """day_of_week = -1 deve lançar ValidationError."""
    with pytest.raises(ValidationError):
        CreateWorkoutSheetDTO(
            user_id=uuid4(),
            name="Treino",
            day_of_week=-1,
            exercises=[],
        )


# ---------------------------------------------------------------------------
# Teste 10: UpdateWorkoutSheetDTO — todos os campos opcionais
# ---------------------------------------------------------------------------


def test_update_workout_sheet_dto_all_optional():
    """UpdateWorkoutSheetDTO com todos os campos None deve ser válido."""
    dto = UpdateWorkoutSheetDTO()
    assert dto.name is None
    assert dto.exercises is None
    assert dto.day_of_week is None


def test_update_workout_sheet_dto_partial():
    """UpdateWorkoutSheetDTO pode ter apenas alguns campos."""
    dto = UpdateWorkoutSheetDTO(name="Novo Nome")
    assert dto.name == "Novo Nome"
    assert dto.exercises is None


# ---------------------------------------------------------------------------
# Teste 11: DuplicateWorkoutSheetDTO — campos opcionais
# ---------------------------------------------------------------------------


def test_duplicate_dto_defaults():
    """DuplicateWorkoutSheetDTO sem campos deve ter valores None."""
    dto = DuplicateWorkoutSheetDTO()
    assert dto.name is None
    assert dto.user_id is None


def test_duplicate_dto_with_name():
    """DuplicateWorkoutSheetDTO com nome deve funcionar."""
    dto = DuplicateWorkoutSheetDTO(name="Cópia do Treino A")
    assert dto.name == "Cópia do Treino A"
