"""
DTOs (Data Transfer Objects) para o módulo Logbook.

Define esquemas Pydantic para validação de entrada e saída dos endpoints
de logbook/diário de treino.
"""

from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional, Tuple
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator


# ---------------------------------------------------------------------------
# Enums / Constantes
# ---------------------------------------------------------------------------

VALID_SESSION_STATUSES = {"in_progress", "completed", "incomplete", "skipped"}
VALID_COMPLETE_STATUSES = {"completed", "incomplete", "skipped"}
VALID_EXERCISE_STATUSES = {"completed", "partial", "skipped"}
VALID_MOODS = {"great", "good", "normal", "bad", "terrible"}
VALID_INTENSITIES = {"leve", "moderada", "intensa"}


# ---------------------------------------------------------------------------
# DTO de Criação de Sessão
# ---------------------------------------------------------------------------


class CreateSessionDTO(BaseModel):
    """DTO para iniciar uma nova sessão de treino.

    Aceita tanto o formato completo (workout_sheet_id obrigatório) quanto
    o formato simplificado enviado pelo app mobile (workout_name + campos extras).
    """

    workout_sheet_id: Optional[UUID] = Field(None, description="UUID da ficha de treino (opcional)")
    session_date: datetime = Field(..., description="Data/hora em que treinou (não pode ser futura)")

    # Campos do formato simplificado (compatibilidade com frontend)
    workout_name: Optional[str] = Field(None, max_length=200, description="Nome do treino")
    duration_minutes: Optional[int] = Field(None, ge=0, le=1440, description="Duração em minutos")
    calories_burned: Optional[float] = Field(None, ge=0, description="Calorias queimadas (kcal)")
    intensity: Optional[str] = Field(None, description="Intensidade: leve | moderada | intensa")
    notes: Optional[str] = Field(None, max_length=2000, description="Notas da sessão")

    @field_validator("session_date")
    @classmethod
    def session_date_not_future(cls, v: datetime) -> datetime:
        v_naive = v.replace(tzinfo=None) if v.tzinfo else v
        now = datetime.utcnow()
        if v_naive > now + timedelta(seconds=5):
            raise ValueError("session_date não pode ser uma data futura")
        return v

    @field_validator("intensity")
    @classmethod
    def validate_intensity(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in VALID_INTENSITIES:
            raise ValueError(f"intensity deve ser um de {VALID_INTENSITIES}")
        return v


# ---------------------------------------------------------------------------
# DTO de Exercício na Sessão
# ---------------------------------------------------------------------------


class SessionExerciseDTO(BaseModel):
    """DTO para registrar um exercício dentro de uma sessão."""

    exercise_id: UUID = Field(..., description="UUID do exercício")
    actual_series: Optional[int] = Field(None, gt=0, description="Séries realizadas (> 0)")
    actual_repetitions: Optional[int] = Field(None, gt=0, description="Repetições realizadas (> 0)")
    actual_load_kg: Optional[float] = Field(None, gt=0, description="Carga utilizada em kg (> 0)")
    series_details: Optional[List[Dict[str, Any]]] = Field(
        None, description="Detalhes por série [{series, reps, load}]"
    )
    exercise_notes: Optional[str] = Field(None, max_length=1000, description="Notas sobre o exercício")
    pain_or_discomfort: bool = Field(False, description="Sentiu dor ou desconforto?")
    pain_description: Optional[str] = Field(None, max_length=500, description="Descrição da dor")
    modification: Optional[str] = Field(None, max_length=500, description="Como adaptou o exercício")
    status: str = Field("completed", description="Status: completed | partial | skipped")

    @field_validator("status")
    @classmethod
    def validate_exercise_status(cls, v: str) -> str:
        if v not in VALID_EXERCISE_STATUSES:
            raise ValueError(f"status deve ser um de {VALID_EXERCISE_STATUSES}")
        return v

    @model_validator(mode="after")
    def pain_description_required_when_pain(self) -> "SessionExerciseDTO":
        if self.pain_or_discomfort and not self.pain_description:
            raise ValueError("pain_description é obrigatório quando pain_or_discomfort=True")
        return self


# ---------------------------------------------------------------------------
# DTO de Atualização/Finalização de Sessão
# ---------------------------------------------------------------------------


class UpdateSessionDTO(BaseModel):
    """DTO para finalizar ou atualizar uma sessão de treino."""

    general_notes: Optional[str] = Field(None, max_length=2000, description="Notas gerais da sessão")
    difficulty_level: Optional[int] = Field(
        None, ge=1, le=10, description="Nível de dificuldade percebido (1–10)"
    )
    mood: Optional[str] = Field(None, description="Humor: great | good | normal | bad | terrible")
    status: Optional[str] = Field(None, description="Status: completed | incomplete | skipped")

    @field_validator("mood")
    @classmethod
    def validate_mood(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in VALID_MOODS:
            raise ValueError(f"mood deve ser um de {VALID_MOODS}")
        return v

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in VALID_COMPLETE_STATUSES:
            raise ValueError(f"status deve ser um de {VALID_COMPLETE_STATUSES}")
        return v


# ---------------------------------------------------------------------------
# DTOs de Resposta — Exercício
# ---------------------------------------------------------------------------


class SessionExerciseResponseDTO(BaseModel):
    """Resposta de um exercício dentro de uma sessão."""

    id: UUID
    session_id: UUID
    exercise_id: UUID
    exercise_name: Optional[str] = None  # desnormalizado para evitar joins

    # Valores planejados
    planned_series: Optional[int] = None
    planned_repetitions: Optional[int] = None
    planned_load_kg: Optional[float] = None

    # Valores reais
    actual_series: Optional[int] = None
    actual_repetitions: Optional[int] = None
    actual_load_kg: Optional[float] = None

    series_details: Optional[List[Dict[str, Any]]] = None
    exercise_notes: Optional[str] = None
    pain_or_discomfort: bool
    pain_description: Optional[str] = None
    modification: Optional[str] = None
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# DTOs de Resposta — Sessão
# ---------------------------------------------------------------------------


class SessionResponseDTO(BaseModel):
    """Resposta completa de uma sessão de treino (com exercícios)."""

    id: UUID
    user_id: UUID
    workout_sheet_id: Optional[UUID] = None
    session_date: datetime
    status: str
    workout_name: Optional[str] = None
    duration_minutes: Optional[int] = None
    calories_burned: Optional[float] = None
    intensity: Optional[str] = None
    general_notes: Optional[str] = None
    difficulty_level: Optional[int] = None
    mood: Optional[str] = None
    created_at: datetime
    updated_at: datetime
    completed_at: Optional[datetime] = None
    session_exercises: List[SessionExerciseResponseDTO] = []

    model_config = {"from_attributes": True}


class SessionListItemDTO(BaseModel):
    """Item de sessão na listagem (sem exercícios completos)."""

    id: UUID
    user_id: UUID
    workout_sheet_id: Optional[UUID] = None
    session_date: datetime
    status: str
    workout_name: Optional[str] = None
    duration_minutes: Optional[int] = None
    calories_burned: Optional[float] = None
    intensity: Optional[str] = None
    difficulty_level: Optional[int] = None
    mood: Optional[str] = None
    completed_at: Optional[datetime] = None
    created_at: datetime
    exercise_count: int = 0

    model_config = {"from_attributes": True}


class PaginatedSessionsDTO(BaseModel):
    """Resposta paginada de sessões."""

    total: int
    page: int
    limit: int
    data: List[SessionListItemDTO]


# ---------------------------------------------------------------------------
# DTOs de Calendário
# ---------------------------------------------------------------------------


class CalendarDayDTO(BaseModel):
    """Informações de um dia no calendário de treinos."""

    date: str  # "YYYY-MM-DD"
    day_of_week: int  # 0=segunda … 6=domingo
    status: str  # "completed" | "incomplete" | "skipped" | "no_plan"
    session_id: Optional[UUID] = None
    exercise_count: Optional[int] = None


class CalendarSummaryDTO(BaseModel):
    """Resumo do calendário mensal."""

    completed: int = 0
    incomplete: int = 0
    skipped: int = 0
    no_plan: int = 0


class CalendarResponseDTO(BaseModel):
    """Resposta do calendário mensal de treinos."""

    year: int
    month: int
    user_id: UUID
    days: List[CalendarDayDTO]
    summary: CalendarSummaryDTO


# ---------------------------------------------------------------------------
# DTOs de Progressão
# ---------------------------------------------------------------------------


class ProgressionDataPointDTO(BaseModel):
    """Ponto de dados de progressão de carga de um exercício."""

    session_date: datetime
    actual_load_kg: float
    actual_series: int
    actual_repetitions: int
    volume_kg: float  # séries × reps × carga


class ProgressionStatisticsDTO(BaseModel):
    """Estatísticas calculadas de progressão."""

    total_sessions: int
    avg_load_kg: float
    max_load_kg: float
    min_load_kg: float
    avg_volume_kg: float
    trend: str  # "increasing" | "decreasing" | "stable"
    improvement_percentage: float


class ProgressionResponseDTO(BaseModel):
    """Resposta completa de progressão de um exercício."""

    exercise_id: UUID
    user_id: UUID
    data_points: List[ProgressionDataPointDTO]
    statistics: ProgressionStatisticsDTO
