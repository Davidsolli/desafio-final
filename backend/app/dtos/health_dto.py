"""DTOs para o módulo de dados de saúde (frequência cardíaca e calorias)."""

from datetime import date as date_type, datetime
from typing import List
from uuid import UUID

from pydantic import BaseModel, Field, ConfigDict


class HeartRateSampleDTO(BaseModel):
    """Amostra individual de batimento cardíaco."""

    measured_at: datetime = Field(..., description="Momento da medição (UTC)")
    bpm: int = Field(..., ge=1, le=350, description="Batimentos por minuto")
    is_from_smartwatch: bool = Field(False, description="Medição originada em smartwatch/fitness tracker")
    source_name: str = Field('', max_length=120, description="Nome legível da fonte (ex: 'Garmin Connect')")

    model_config = ConfigDict(json_schema_extra={
        "example": {"measured_at": "2026-05-13T08:30:00Z", "bpm": 72, "is_from_smartwatch": True, "source_name": "Garmin Connect"}
    })


class HealthSyncRequestDTO(BaseModel):
    """DTO para sincronizar frequência cardíaca e calorias do dia."""

    date: date_type = Field(..., description="Data do registro no formato YYYY-MM-DD")
    active_calories: float = Field(0.0, ge=0, description="Calorias ativas queimadas (kcal)")
    total_calories: float = Field(0.0, ge=0, description="Total de calorias queimadas (kcal)")
    heart_rate_readings: List[HeartRateSampleDTO] = Field(
        default_factory=list,
        description="Amostras de frequência cardíaca do período",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "date": "2026-05-13",
                "active_calories": 350.5,
                "total_calories": 2100.0,
                "heart_rate_readings": [
                    {"measured_at": "2026-05-13T08:30:00Z", "bpm": 72},
                    {"measured_at": "2026-05-13T12:00:00Z", "bpm": 85},
                ],
            }
        }
    )


class HealthSyncResponseDTO(BaseModel):
    """Confirmação do sync de dados de saúde."""

    success: bool = True
    message: str = "Dados de saúde sincronizados com sucesso."
    heart_rate_samples_saved: int = Field(0, description="Amostras de FC salvas")
    date: date_type


class HeartRateSampleResponseDTO(BaseModel):
    """Amostra de FC retornada pela API."""

    id: UUID
    measured_at: datetime
    bpm: int
    is_from_smartwatch: bool
    source_name: str

    model_config = ConfigDict(from_attributes=True)


class HealthSummaryResponseDTO(BaseModel):
    """Resumo de saúde do dia: FC média e calorias."""

    date: date_type
    average_heart_rate_bpm: float = Field(0.0, description="BPM médio do dia")
    min_heart_rate_bpm: int = Field(0, description="BPM mínimo do dia")
    max_heart_rate_bpm: int = Field(0, description="BPM máximo do dia")
    heart_rate_samples: int = Field(0, description="Número de amostras de FC")
    active_calories: float = Field(0.0, description="Calorias ativas queimadas (kcal)")
    total_calories: float = Field(0.0, description="Total de calorias queimadas (kcal)")
    is_from_smartwatch: bool = Field(False, description="Alguma amostra do dia veio de smartwatch")
    smartwatch_source_name: str = Field('', description="Nome da fonte smartwatch (se houver)")

    model_config = ConfigDict(from_attributes=True)
