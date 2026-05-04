"""
DTOs (Data Transfer Objects) para o módulo de Nutrição (RF-59 a RF-66).

Define esquemas Pydantic para validação de entrada e saída dos endpoints
de refeições e catálogo de alimentos.
"""

from datetime import date, datetime
from typing import Any, Dict, List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, field_validator


VALID_MEAL_TYPES = {"breakfast", "lunch", "dinner", "snack"}


# ---------------------------------------------------------------------------
# DTOs de Alimento
# ---------------------------------------------------------------------------


class FoodEntryInputDTO(BaseModel):
    """Item de alimento ao criar/atualizar uma refeição."""

    food_id: Optional[UUID] = Field(None, description="UUID do alimento no catálogo (opcional)")
    food_name: str = Field(..., min_length=1, max_length=200, description="Nome do alimento")
    quantity_grams: float = Field(100.0, gt=0, description="Quantidade em gramas")
    calories: float = Field(0.0, ge=0, description="Calorias consumidas (kcal)")
    protein: float = Field(0.0, ge=0, description="Proteína consumida (g)")
    carbs: float = Field(0.0, ge=0, description="Carboidratos consumidos (g)")
    fat: float = Field(0.0, ge=0, description="Gordura consumida (g)")


class FoodEntryResponseDTO(BaseModel):
    """Resposta de um item de alimento dentro de uma refeição."""

    id: UUID
    food_id: Optional[UUID] = None
    name: str
    quantity_grams: float
    calories: float
    protein: float
    carbs: float
    fat: float

    model_config = {"from_attributes": True}


class FoodResponseDTO(BaseModel):
    """Alimento do catálogo (retornado na busca de alimentos)."""

    id: UUID
    name: str
    brand: Optional[str] = None
    calories: float  # por 100g
    protein: float
    carbs: float
    fat: float
    fiber: Optional[float] = None

    model_config = {"from_attributes": True}


class CreateFoodDTO(BaseModel):
    """DTO para criar um alimento no catálogo (admin/personal)."""

    name: str = Field(..., min_length=1, max_length=200)
    brand: Optional[str] = Field(None, max_length=100)
    calories_per_100g: float = Field(..., ge=0)
    protein_per_100g: float = Field(..., ge=0)
    carbs_per_100g: float = Field(..., ge=0)
    fat_per_100g: float = Field(..., ge=0)
    fiber_per_100g: Optional[float] = Field(None, ge=0)


# ---------------------------------------------------------------------------
# DTOs de Refeição
# ---------------------------------------------------------------------------


class CreateMealDTO(BaseModel):
    """DTO para criar uma nova refeição."""

    meal_type: str = Field(
        ..., description="Tipo: breakfast | lunch | dinner | snack"
    )
    meal_date: date = Field(..., description="Data da refeição (YYYY-MM-DD)")
    foods: List[FoodEntryInputDTO] = Field(
        default_factory=list, description="Lista de alimentos"
    )
    notes: Optional[str] = Field(None, max_length=1000, description="Observações")

    @field_validator("meal_type")
    @classmethod
    def validate_meal_type(cls, v: str) -> str:
        if v not in VALID_MEAL_TYPES:
            raise ValueError(f"meal_type deve ser um de {VALID_MEAL_TYPES}")
        return v

    @field_validator("meal_date")
    @classmethod
    def validate_not_too_old(cls, v: date) -> date:
        from datetime import date as dt
        days_ago = (dt.today() - v).days
        if days_ago > 365:
            raise ValueError("Não é possível registrar refeições com mais de 1 ano atrás")
        return v


class UpdateMealDTO(BaseModel):
    """DTO para atualizar uma refeição existente."""

    meal_type: Optional[str] = Field(None, description="Tipo da refeição")
    meal_date: Optional[date] = Field(None, description="Data da refeição")
    foods: Optional[List[FoodEntryInputDTO]] = Field(
        None, description="Lista de alimentos (substitui existentes)"
    )
    notes: Optional[str] = Field(None, max_length=1000)

    @field_validator("meal_type")
    @classmethod
    def validate_meal_type(cls, v: Optional[str]) -> Optional[str]:
        if v is not None and v not in VALID_MEAL_TYPES:
            raise ValueError(f"meal_type deve ser um de {VALID_MEAL_TYPES}")
        return v


class MealResponseDTO(BaseModel):
    """Resposta completa de uma refeição (com alimentos)."""

    id: UUID
    user_id: UUID
    meal_type: str
    meal_date: date
    calories: float
    protein: float
    carbs: float
    fat: float
    foods: List[FoodEntryResponseDTO] = []
    notes: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class DailySummaryDTO(BaseModel):
    """Resumo diário de macronutrientes."""

    date: date
    total_calories: float
    total_protein: float
    total_carbs: float
    total_fat: float
    meal_count: int
    meals: List[MealResponseDTO]
