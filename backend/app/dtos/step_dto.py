"""DTOs para o módulo de contador de passos."""

from datetime import date as date_type, datetime
from typing import List
from uuid import UUID

from pydantic import BaseModel, Field, ConfigDict


class SyncStepsDTO(BaseModel):
    """DTO para sincronizar a contagem de passos do dia."""

    date: date_type = Field(..., description="Data no formato YYYY-MM-DD")
    steps: int = Field(..., ge=0, le=200000, description="Total de passos do dia")
    distance_meters: float = Field(
        ..., ge=0, description="Distância estimada em metros (calculada no cliente)"
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "date": "2026-05-10",
                "steps": 8542,
                "distance_meters": 6347.0,
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
    is_week_record: bool = Field(
        False,
        description="Indica se este é o melhor dia da semana atual para o usuário",
    )
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class StepHistoryResponseDTO(BaseModel):
    """DTO para resposta de histórico de passos com estatísticas."""

    logs: List[StepLogResponseDTO] = Field(..., description="Lista de registros diários")
    weekly_best: int = Field(
        0, description="Maior soma semanal de passos já registrada pelo usuário"
    )
    current_week_total: int = Field(
        0, description="Total de passos da semana corrente"
    )
    is_new_week_record: bool = Field(
        False,
        description="Se o total da semana atual é o novo recorde do usuário",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "logs": [],
                "weekly_best": 52340,
                "current_week_total": 41820,
                "is_new_week_record": False,
            }
        }
    )
