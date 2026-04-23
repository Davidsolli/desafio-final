"""DTOs para o módulo de metas."""

from datetime import date, datetime
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, ConfigDict

VALID_CATEGORIES = {"strength", "endurance", "composition", "frequency"}
VALID_STATUSES = {"active", "paused", "failed"}


class CreateGoalDTO(BaseModel):
    """DTO para criação de uma nova meta."""

    user_id: UUID = Field(..., description="ID do aluno dono da meta")
    created_by_id: Optional[UUID] = Field(None, description="ID do criador (padrão: user_id)")
    title: str = Field(..., min_length=3, max_length=255, description="Título da meta")
    description: Optional[str] = Field(None, max_length=1000, description="Descrição detalhada")
    category: str = Field(..., description="strength, endurance, composition, frequency")
    target_value: float = Field(..., description="Valor alvo a atingir")
    current_value: float = Field(..., description="Valor atual ao criar a meta")
    unit: str = Field(..., min_length=1, max_length=50, description="Unidade: kg, %, cm, etc.")
    target_date: date = Field(..., description="Data limite para atingir a meta")

    @field_validator("category")
    @classmethod
    def validate_category(cls, v: str) -> str:
        if v not in VALID_CATEGORIES:
            raise ValueError(f"Categoria deve ser uma de: {', '.join(sorted(VALID_CATEGORIES))}")
        return v

    @field_validator("target_date")
    @classmethod
    def validate_target_date(cls, v: date) -> date:
        if v <= date.today():
            raise ValueError("Data alvo deve ser uma data futura")
        return v

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "user_id": "550e8400-e29b-41d4-a716-446655440000",
                "title": "Aumentar supino em 10kg",
                "description": "Do 80kg para 90kg",
                "category": "strength",
                "target_value": 90.0,
                "current_value": 80.0,
                "unit": "kg",
                "target_date": "2026-12-31",
            }
        }
    )


class UpdateGoalDTO(BaseModel):
    """DTO para atualizar progresso de uma meta."""

    current_value: Optional[float] = Field(None, description="Novo valor atual (atualiza progresso)")
    notes: Optional[str] = Field(None, max_length=500, description="Observações sobre o progresso")
    status: Optional[str] = Field(None, description="Novo status: active, paused, failed")

    @field_validator("status")
    @classmethod
    def validate_status(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return v
        if v not in VALID_STATUSES:
            raise ValueError(f"Status deve ser um de: {', '.join(sorted(VALID_STATUSES))}")
        return v

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "current_value": 85.0,
                "notes": "Consegui 85kg com 4 séries",
            }
        }
    )


class GoalProgressEntryResponseDTO(BaseModel):
    """DTO para resposta de entrada de progresso."""

    id: UUID
    current_value: float
    recorded_at: datetime
    notes: Optional[str]

    model_config = ConfigDict(from_attributes=True)


class GoalResponseDTO(BaseModel):
    """DTO para resposta de meta (sem histórico detalhado)."""

    id: UUID
    user_id: UUID
    created_by_id: UUID
    title: str
    category: str
    target_value: float
    current_value: float
    initial_value: float
    unit: str
    start_date: datetime
    target_date: datetime
    status: str
    progress_percentage: float
    days_remaining: int
    completed_at: Optional[datetime]
    created_at: datetime

    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "example": {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "user_id": "550e8400-e29b-41d4-a716-446655440001",
                "title": "Aumentar supino em 10kg",
                "category": "strength",
                "target_value": 90.0,
                "current_value": 82.5,
                "initial_value": 80.0,
                "unit": "kg",
                "status": "active",
                "progress_percentage": 25.0,
                "days_remaining": 55,
                "completed_at": None,
            }
        },
    )


class GoalDetailResponseDTO(GoalResponseDTO):
    """DTO para resposta detalhada de meta (com histórico)."""

    description: Optional[str]
    progress_entries: List[GoalProgressEntryResponseDTO] = []


class PaginatedGoalsResponseDTO(BaseModel):
    """DTO para resposta paginada de metas."""

    total: int = Field(..., description="Total de metas")
    page: int = Field(..., description="Página atual")
    data: List[GoalResponseDTO] = Field(..., description="Lista de metas")
