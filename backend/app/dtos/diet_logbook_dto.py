"""
DTOs (Data Transfer Objects) para o Diário Alimentar (Diet Logbook).

Define esquemas Pydantic para validação de entrada e saída dos endpoints
de registro diário de consumo alimentar.
"""

from datetime import date, datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


# ---------------------------------------------------------------------------
# DTOs de Entrada
# ---------------------------------------------------------------------------


class AddLogbookEntryDTO(BaseModel):
    """DTO para registrar um alimento consumido."""

    meal_name: str = Field(
        ..., max_length=255,
        description="Nome da refeição (ex: 'Café da Manhã', 'Almoço')"
    )
    food_id: Optional[int] = Field(None, description="ID do alimento na TACO")
    custom_food_id: Optional[UUID] = Field(None, description="UUID do alimento personalizado")
    quantity_g: float = Field(..., gt=0, description="Quantidade consumida em gramas")
    log_date: Optional[date] = Field(None, description="Data do consumo (default: hoje)")

    @model_validator(mode="after")
    def check_at_least_one_food(self):
        """Valida que pelo menos um dos IDs de alimento está preenchido."""
        if self.food_id is None and self.custom_food_id is None:
            raise ValueError(
                "Pelo menos um dos campos 'food_id' ou 'custom_food_id' deve ser preenchido."
            )
        return self


# ---------------------------------------------------------------------------
# DTOs de Resposta
# ---------------------------------------------------------------------------


class LogbookEntryResponseDTO(BaseModel):
    """DTO de resposta de um item consumido no dia."""

    id: UUID
    logbook_id: UUID
    meal_name: str
    food_id: Optional[int] = None
    custom_food_id: Optional[UUID] = None
    food_name: str = ""
    quantity_g: float
    # Macros (snapshot gravado na inserção)
    kcal: float
    protein: float
    carbs: float
    fats: float


class DietLogbookResponseDTO(BaseModel):
    """DTO de resposta completa do diário alimentar de um dia."""

    id: UUID
    user_id: UUID
    date: date
    total_kcal: float
    total_protein: float
    total_carbs: float
    total_fats: float
    created_at: datetime
    entries: List[LogbookEntryResponseDTO] = []
