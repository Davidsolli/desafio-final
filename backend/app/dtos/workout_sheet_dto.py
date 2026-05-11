"""
DTOs (Data Transfer Objects) para o módulo Ficha de Treino.

Define esquemas Pydantic para validação de entrada e saída dos endpoints
de fichas de treino (workout sheets).
"""

from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, AnyHttpUrl


# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------

VALID_MUSCLE_GROUPS = {
    "peito",
    "costa",
    "ombro",
    "bíceps",
    "tríceps",
    "antebraço",
    "core",
    "perna_anterior",
    "perna_posterior",
    "panturrilha",
}


# ---------------------------------------------------------------------------
# DTOs de Exercício (dentro da ficha)
# ---------------------------------------------------------------------------


class ExerciseCreateDTO(BaseModel):
    """DTO para criar um exercício dentro de uma ficha."""

    name: str = Field(..., max_length=255, description="Nome do exercício")
    muscle_group: str = Field(..., description="Grupo muscular (lista pré-definida)")
    series: int = Field(..., gt=0, description="Número de séries (> 0)")
    repetitions: int = Field(..., gt=0, description="Número de repetições (> 0)")
    load_kg: float = Field(..., gt=0, description="Carga sugerida em kg (> 0)")
    rest_seconds: int = Field(60, ge=0, description="Descanso entre séries em segundos (>= 0)")
    observations: Optional[str] = Field(None, description="Observações técnicas")
    image_url: Optional[str] = Field(None, max_length=2048, description="URL da imagem demonstrativa")
    gif_url: Optional[str] = Field(None, max_length=2048, description="URL do GIF demonstrativo")
    order: int = Field(1, ge=1, description="Ordem de execução na ficha")

    @field_validator("muscle_group")
    @classmethod
    def validate_muscle_group(cls, v: str) -> str:
        if v not in VALID_MUSCLE_GROUPS:
            raise ValueError(
                f"muscle_group inválido. Valores aceitos: {sorted(VALID_MUSCLE_GROUPS)}"
            )
        return v


class ExerciseResponseDTO(BaseModel):
    """DTO de resposta de um exercício dentro de uma ficha."""

    id: UUID
    workout_sheet_id: UUID
    name: str
    muscle_group: str
    series: int
    repetitions: int
    load_kg: float
    rest_seconds: int
    observations: Optional[str] = None
    image_url: Optional[str] = None
    gif_url: Optional[str] = None
    order: int
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# DTOs de Ficha de Treino
# ---------------------------------------------------------------------------


class CreateWorkoutSheetDTO(BaseModel):
    """DTO para criar uma nova rotina (ficha) de treino."""

    workout_program_id: Optional[UUID] = Field(None, description="Programa ao qual a ficha pertence")
    name: str = Field(..., max_length=255, description="Nome da ficha (ex: 'Treino A - Peito')")
    description: Optional[str] = Field(None, description="Descrição opcional da ficha")
    day_of_week: Optional[int] = Field(None, ge=0, le=6, description="Dia sugerido da semana (0=seg, ..., 6=dom)")
    order: int = Field(1, description="Ordem de execução dentro do programa")
    exercises: List[ExerciseCreateDTO] = Field(
        default_factory=list, description="Lista de exercícios da ficha"
    )


class UpdateWorkoutSheetDTO(BaseModel):
    """DTO para atualizar uma ficha de treino (todos os campos opcionais)."""

    name: Optional[str] = Field(None, max_length=255)
    description: Optional[str] = None
    day_of_week: Optional[int] = Field(None, ge=0, le=6)
    order: Optional[int] = None
    exercises: Optional[List[ExerciseCreateDTO]] = Field(
        None,
        description="Se fornecido, substitui todos os exercícios da ficha"
    )


class DuplicateWorkoutSheetDTO(BaseModel):
    """DTO para duplicar uma ficha de treino."""

    name: Optional[str] = Field(None, max_length=255, description="Novo nome (opcional)")
    workout_program_id: Optional[UUID] = Field(
        None, description="Atribuir a outro programa (opcional, padrão: mesmo programa)"
    )


class WorkoutSheetResponseDTO(BaseModel):
    """Resposta completa de uma ficha de treino (com exercícios)."""

    id: UUID
    workout_program_id: UUID
    name: str
    description: Optional[str] = None
    day_of_week: Optional[int] = None
    order: int
    is_active: bool
    created_at: datetime
    updated_at: datetime
    exercises: List[ExerciseResponseDTO] = []

    model_config = {"from_attributes": True}


class WorkoutSheetListItemDTO(BaseModel):
    """Item de ficha na listagem (sem exercícios completos, com contagem)."""

    id: UUID
    workout_program_id: UUID
    name: str
    day_of_week: Optional[int] = None
    order: int
    is_active: bool
    exercise_count: int = 0
    created_at: datetime

    model_config = {"from_attributes": True}


class PaginatedWorkoutSheetsDTO(BaseModel):
    """Resposta paginada de fichas de treino."""

    total: int
    page: int
    limit: int
    data: List[WorkoutSheetListItemDTO]


# ---------------------------------------------------------------------------
# DTOs de Workout Program (Programa de Treino)
# ---------------------------------------------------------------------------

class CreateWorkoutProgramDTO(BaseModel):
    user_id: UUID = Field(..., description="UUID do aluno que receberá o programa")
    name: str = Field(..., max_length=255, description="Nome do programa")
    description: Optional[str] = None
    goal: Optional[str] = None
    workout_sheets: List[CreateWorkoutSheetDTO] = []

class UpdateWorkoutProgramDTO(BaseModel):
    name: Optional[str] = Field(None, max_length=255)
    description: Optional[str] = None
    goal: Optional[str] = None
    is_active: Optional[bool] = None

class WorkoutProgramResponseDTO(BaseModel):
    id: UUID
    user_id: UUID
    personal_trainer_id: Optional[UUID] = None
    name: str
    description: Optional[str] = None
    goal: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    workout_sheets: List[WorkoutSheetResponseDTO] = []

    model_config = {"from_attributes": True}

class PaginatedWorkoutProgramsDTO(BaseModel):
    total: int
    page: int
    limit: int
    data: List[WorkoutProgramResponseDTO]


# ---------------------------------------------------------------------------
# DTOs do Catálogo de Exercícios
# ---------------------------------------------------------------------------


class ExerciseCatalogItemDTO(BaseModel):
    """Item do catálogo de exercícios (para busca/autocompletar)."""

    id: str
    name: str
    category: Optional[str] = None
    level: Optional[str] = None
    equipment: Optional[str] = None
    primary_muscles: Optional[List[str]] = None
    secondary_muscles: Optional[List[str]] = None
    instructions: Optional[List[str]] = None
    image_url: Optional[str] = None
    gif_url: Optional[str] = None
    muscle_group_mapped: Optional[str] = None

    model_config = {"from_attributes": True}


class PaginatedCatalogDTO(BaseModel):
    """Resposta paginada do catálogo de exercícios."""

    total: int
    page: int
    limit: int
    data: List[ExerciseCatalogItemDTO]
