"""DTOs para o módulo de contador de passos."""

from datetime import date as date_type, datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, ConfigDict


class SyncStepsDTO(BaseModel):
    """DTO para sincronizar a contagem de passos do dia."""

    date: date_type = Field(..., description="Data no formato YYYY-MM-DD")
    steps: int = Field(..., ge=0, le=200000, description="Total de passos do dia")
    distance_meters: float = Field(
        ..., ge=0, description="Distância estimada em metros (calculada no cliente)"
    )
    handicap_level: Optional[int] = Field(
        None,
        ge=1,
        le=3,
        description="Nível de proteção da sequência (1=75%, 2=50%, 3=25% da meta)",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "date": "2026-05-10",
                "steps": 8542,
                "distance_meters": 6347.0,
                "handicap_level": None,
            }
        }
    )


class StepLogResponseDTO(BaseModel):
    """DTO para resposta de um registro de passos diário."""

    id: UUID
    user_id: UUID
    date: date_type
    steps: int
    distance_meters: float
    calories_burned: float = Field(
        0.0, description="Calorias estimadas queimadas (kcal)"
    )
    is_all_time_record: bool = Field(
        False,
        description="Indica se este é o dia com mais passos de toda a história do usuário",
    )
    handicap_level: Optional[int] = Field(
        None,
        description="Nível de proteção de sequência aplicado neste dia (1-3), ou null",
    )
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class StepHistoryResponseDTO(BaseModel):
    """DTO para resposta de histórico de passos com estatísticas."""

    logs: List[StepLogResponseDTO] = Field(..., description="Lista de registros diários")
    all_time_record: int = Field(
        0, description="Maior contagem de passos em um único dia (all-time)"
    )
    current_week_total: int = Field(
        0, description="Total de passos da semana corrente"
    )
    current_streak: int = Field(
        0, description="Dias consecutivos batendo a meta diária de passos"
    )
    daily_step_goal: int = Field(
        1000, description="Meta diária de passos configurada pelo usuário"
    )
    total_calories_today: float = Field(
        0.0, description="Calorias estimadas queimadas hoje"
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "logs": [],
                "all_time_record": 12500,
                "current_week_total": 41820,
                "current_streak": 5,
                "daily_step_goal": 1000,
                "total_calories_today": 342.0,
            }
        }
    )


class UpdateStepGoalDTO(BaseModel):
    """DTO para atualizar a meta diária de passos."""

    daily_step_goal: int = Field(
        ..., ge=100, le=100000, description="Nova meta diária de passos"
    )
