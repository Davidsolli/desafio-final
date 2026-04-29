from datetime import datetime, date
from typing import Optional, List
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, ConfigDict


VALID_ACTIVITY_LEVELS = {"sedentary", "light", "moderate", "active", "very_active"}
VALID_METRICS = {"weight", "bmi", "body_fat_percentage", "waist_cm", "hip_cm", "chest_cm", "thigh_cm", "arm_cm"}


class CreateMeasurementDTO(BaseModel):
    weight_kg: float = Field(..., gt=0, description="Peso em kg")
    height_cm: float = Field(..., gt=0, description="Altura em cm")
    chest_cm: Optional[float] = Field(None, gt=0)
    waist_cm: Optional[float] = Field(None, gt=0)
    hip_cm: Optional[float] = Field(None, gt=0)
    thigh_cm: Optional[float] = Field(None, gt=0)
    arm_cm: Optional[float] = Field(None, gt=0)
    body_fat_percentage: Optional[float] = Field(None, ge=0, le=100)
    activity_level: str = Field(..., description="Nível de atividade física")
    measured_at: Optional[datetime] = Field(default_factory=datetime.utcnow)
    notes: Optional[str] = None

    @field_validator("activity_level")
    @classmethod
    def validate_activity_level(cls, v: str) -> str:
        if v not in VALID_ACTIVITY_LEVELS:
            raise ValueError(f"activity_level deve ser um de: {', '.join(sorted(VALID_ACTIVITY_LEVELS))}")
        return v


class MeasurementResponseDTO(BaseModel):
    id: UUID
    user_id: UUID
    weight_kg: float
    height_cm: float
    chest_cm: Optional[float] = None
    waist_cm: Optional[float] = None
    hip_cm: Optional[float] = None
    thigh_cm: Optional[float] = None
    arm_cm: Optional[float] = None
    body_fat_percentage: Optional[float] = None
    bmi: float
    bmr_kcal: float
    tdee_kcal: float
    activity_level: str
    measured_at: datetime
    notes: Optional[str] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class PaginatedMeasurementsResponseDTO(BaseModel):
    total: int
    page: int
    limit: int
    data: List[MeasurementResponseDTO]


class EvolutionPointDTO(BaseModel):
    date: date
    value: float


class EvolutionStatisticsDTO(BaseModel):
    current: float
    initial: float
    change: float
    change_percentage: float


class EvolutionResponseDTO(BaseModel):
    metric: str
    data: List[EvolutionPointDTO]
    statistics: EvolutionStatisticsDTO
