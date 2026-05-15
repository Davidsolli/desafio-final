"""
DTOs (Data Transfer Objects) para o módulo de Dieta.

Define esquemas Pydantic para validação de entrada e saída dos endpoints
de alimentos personalizados e dietas.
"""

from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


# ---------------------------------------------------------------------------
# Constantes
# ---------------------------------------------------------------------------

VALID_GOALS = {"bulking", "cutting", "maintenance"}


# ---------------------------------------------------------------------------
# DTOs de Alimento Personalizado (CustomFood)
# ---------------------------------------------------------------------------


class CreateCustomFoodDTO(BaseModel):
    """DTO para criar um alimento personalizado."""

    name: str = Field(..., max_length=255, description="Nome do alimento")
    category: Optional[str] = Field(None, max_length=100, description="Categoria (ex: Suplementos)")
    energy_kcal: float = Field(..., ge=0, description="Calorias por 100g")
    protein_g: float = Field(..., ge=0, description="Proteínas por 100g")
    carbohydrate_g: float = Field(..., ge=0, description="Carboidratos por 100g")
    lipid_g: float = Field(..., ge=0, description="Gorduras por 100g")
    fiber_g: float = Field(0.0, ge=0, description="Fibras por 100g")


class CustomFoodResponseDTO(BaseModel):
    """DTO de resposta de um alimento personalizado."""

    id: UUID
    user_id: UUID
    name: str
    category: Optional[str] = None
    energy_kcal: float
    protein_g: float
    carbohydrate_g: float
    lipid_g: float
    fiber_g: float
    created_at: datetime

    model_config = {"from_attributes": True}


# ---------------------------------------------------------------------------
# DTOs de Item da Dieta (DietItem)
# ---------------------------------------------------------------------------


class DietItemCreateDTO(BaseModel):
    """DTO para criar um item dentro de uma refeição."""

    food_id: Optional[int] = Field(None, description="ID do alimento na TACO")
    custom_food_id: Optional[UUID] = Field(None, description="UUID do alimento personalizado")
    quantity_g: float = Field(..., gt=0, description="Quantidade em gramas")
    observations: Optional[str] = Field(None, description="Observações (ex: 'Grelhado')")

    @model_validator(mode="after")
    def check_at_least_one_food(self):
        """Valida que pelo menos um dos IDs de alimento está preenchido."""
        if self.food_id is None and self.custom_food_id is None:
            raise ValueError(
                "Pelo menos um dos campos 'food_id' ou 'custom_food_id' deve ser preenchido."
            )
        return self


class DietItemResponseDTO(BaseModel):
    """DTO de resposta de um item da dieta com macros calculados."""

    id: UUID
    meal_id: UUID
    food_id: Optional[int] = None
    custom_food_id: Optional[UUID] = None
    food_name: str = ""
    quantity_g: float
    observations: Optional[str] = None
    # Macros calculados (food × quantity_g / 100)
    kcal: float = 0.0
    protein: float = 0.0
    carbs: float = 0.0
    fats: float = 0.0


# ---------------------------------------------------------------------------
# DTOs de Refeição (DietMeal)
# ---------------------------------------------------------------------------


class DietMealCreateDTO(BaseModel):
    """DTO para criar uma refeição dentro de uma dieta."""

    name: str = Field(..., max_length=255, description="Nome da refeição (ex: Café da Manhã)")
    time: Optional[str] = Field(None, pattern=r"^\d{2}:\d{2}$", description="Horário HH:MM")
    order: int = Field(1, ge=1, description="Ordem no dia (1, 2, 3...)")
    items: List[DietItemCreateDTO] = Field(
        default_factory=list, description="Alimentos desta refeição"
    )


class DietMealResponseDTO(BaseModel):
    """DTO de resposta de uma refeição com itens e subtotais de macros."""

    id: UUID
    diet_id: UUID
    name: str
    time: Optional[str] = None
    order: int
    items: List[DietItemResponseDTO] = []
    # Subtotais calculados (soma dos itens)
    subtotal_kcal: float = 0.0
    subtotal_protein: float = 0.0
    subtotal_carbs: float = 0.0
    subtotal_fats: float = 0.0


# ---------------------------------------------------------------------------
# DTOs de Dieta
# ---------------------------------------------------------------------------


class CreateDietDTO(BaseModel):
    """DTO para criar uma nova dieta."""

    user_id: UUID = Field(..., description="UUID do aluno que receberá a dieta")
    name: str = Field(..., max_length=255, description="Nome da dieta")
    goal: Optional[str] = Field(None, description="Objetivo: bulking, cutting, maintenance")
    meals: List[DietMealCreateDTO] = Field(
        default_factory=list, description="Refeições da dieta"
    )
    water_target_ml: Optional[int] = Field(None, ge=0, description="Meta diária de água em ml")


class UpdateDietDTO(BaseModel):
    """DTO para atualizar uma dieta (todos os campos opcionais)."""

    name: Optional[str] = Field(None, max_length=255)
    goal: Optional[str] = None
    meals: Optional[List[DietMealCreateDTO]] = Field(
        None,
        description="Se fornecido, substitui TODAS as refeições"
    )
    water_target_ml: Optional[int] = Field(None, ge=0)


class DuplicateDietDTO(BaseModel):
    """DTO para duplicar uma dieta."""

    name: Optional[str] = Field(None, max_length=255, description="Novo nome (opcional)")
    user_id: Optional[UUID] = Field(
        None, description="Atribuir a outro aluno (opcional)"
    )


class DietResponseDTO(BaseModel):
    """Resposta completa de uma dieta com refeições e macros totais."""

    id: UUID
    user_id: UUID
    professional_id: Optional[UUID] = None
    is_custom: bool
    name: str
    goal: Optional[str] = None
    is_active: bool
    created_at: datetime
    updated_at: datetime
    meals: List[DietMealResponseDTO] = []
    # Totais calculados (soma de todas as refeições)
    total_kcal: float = 0.0
    total_protein: float = 0.0
    total_carbs: float = 0.0
    total_fats: float = 0.0
    water_target_ml: Optional[int] = None


class DietListItemDTO(BaseModel):
    """Item de dieta na listagem (sem refeições detalhadas)."""

    id: UUID
    user_id: UUID
    professional_id: Optional[UUID] = None
    is_custom: bool
    name: str
    goal: Optional[str] = None
    is_active: bool
    meal_count: int = 0
    total_kcal: float = 0.0
    created_at: datetime
    water_target_ml: Optional[int] = None

    model_config = {"from_attributes": True}


class PaginatedDietsDTO(BaseModel):
    """Resposta paginada de dietas."""

    total: int
    page: int
    limit: int
    data: List[DietListItemDTO]
