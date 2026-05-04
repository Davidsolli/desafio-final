"""
Serviço de Nutrição (RF-59 a RF-66).

Lógica de negócio para registro de refeições, cálculo de macronutrientes
e gestão do diário alimentar.
"""

from datetime import date
from typing import List, Optional, Tuple
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.nutrition_dto import (
    CreateFoodDTO,
    CreateMealDTO,
    DailySummaryDTO,
    FoodEntryResponseDTO,
    FoodResponseDTO,
    MealResponseDTO,
    UpdateMealDTO,
)
from app.models.nutrition import Food, Meal, MealFoodEntry
from app.repositories.nutrition_repository import NutritionRepository


# ---------------------------------------------------------------------------
# Exceções de Negócio
# ---------------------------------------------------------------------------


class MealNotFoundError(Exception):
    """Refeição não encontrada."""


class MealForbiddenError(Exception):
    """Usuário não tem permissão para esta refeição."""


class FoodNotFoundError(Exception):
    """Alimento não encontrado no catálogo."""


# ---------------------------------------------------------------------------
# Serviço
# ---------------------------------------------------------------------------


class NutritionService:
    """Serviço de lógica de negócio para o módulo de Nutrição."""

    def __init__(self, session: AsyncSession) -> None:
        self.repository = NutritionRepository(session)

    # ------------------------------------------------------------------
    # Refeições
    # ------------------------------------------------------------------

    async def create_meal(self, user_id: UUID, dto: CreateMealDTO) -> MealResponseDTO:
        """
        Cria uma nova refeição com seus alimentos.

        Os totais de macronutrientes são calculados a partir dos itens.
        """
        total_cal = sum(f.calories for f in dto.foods)
        total_prot = sum(f.protein for f in dto.foods)
        total_carb = sum(f.carbs for f in dto.foods)
        total_fat = sum(f.fat for f in dto.foods)

        meal = Meal(
            user_id=user_id,
            meal_type=dto.meal_type,
            meal_date=dto.meal_date,
            total_calories=total_cal,
            total_protein=total_prot,
            total_carbs=total_carb,
            total_fat=total_fat,
            notes=dto.notes,
        )

        created = await self.repository.create_meal(meal)

        for food_entry in dto.foods:
            entry = MealFoodEntry(
                meal_id=created.id,
                food_id=food_entry.food_id,
                food_name=food_entry.food_name,
                quantity_grams=food_entry.quantity_grams,
                calories=food_entry.calories,
                protein=food_entry.protein,
                carbs=food_entry.carbs,
                fat=food_entry.fat,
            )
            await self.repository.add_food_entry(entry)

        await self.repository.commit()
        meal_with_entries = await self.repository.get_meal_by_id(created.id)
        return self._to_meal_response(meal_with_entries)  # type: ignore[arg-type]

    async def list_meals(
        self,
        user_id: UUID,
        meal_date: Optional[date] = None,
        limit: int = 10,
        offset: int = 0,
    ) -> Tuple[List[MealResponseDTO], int]:
        """Lista refeições do usuário com filtro opcional por data."""
        meals, total = await self.repository.list_meals(
            user_id, meal_date=meal_date, limit=limit, offset=offset
        )
        return [self._to_meal_response(m) for m in meals], total

    async def get_meal(self, meal_id: UUID, user_id: UUID) -> MealResponseDTO:
        """Busca uma refeição específica do usuário."""
        meal = await self.repository.get_meal_by_id(meal_id)
        if not meal:
            raise MealNotFoundError(f"Refeição {meal_id} não encontrada")
        if meal.user_id != user_id:
            raise MealForbiddenError("Você não tem acesso a essa refeição")
        return self._to_meal_response(meal)

    async def update_meal(
        self, meal_id: UUID, user_id: UUID, dto: UpdateMealDTO
    ) -> MealResponseDTO:
        """
        Atualiza uma refeição e seus alimentos.

        Se `foods` for informado, os itens existentes são substituídos.
        """
        meal = await self.repository.get_meal_by_id(meal_id)
        if not meal:
            raise MealNotFoundError(f"Refeição {meal_id} não encontrada")
        if meal.user_id != user_id:
            raise MealForbiddenError("Você não tem acesso a essa refeição")

        if dto.meal_type is not None:
            meal.meal_type = dto.meal_type
        if dto.meal_date is not None:
            meal.meal_date = dto.meal_date
        if dto.notes is not None:
            meal.notes = dto.notes

        if dto.foods is not None:
            await self.repository.delete_entries_for_meal(meal_id)

            total_cal = sum(f.calories for f in dto.foods)
            total_prot = sum(f.protein for f in dto.foods)
            total_carb = sum(f.carbs for f in dto.foods)
            total_fat = sum(f.fat for f in dto.foods)

            meal.total_calories = total_cal
            meal.total_protein = total_prot
            meal.total_carbs = total_carb
            meal.total_fat = total_fat

            for food_entry in dto.foods:
                entry = MealFoodEntry(
                    meal_id=meal.id,
                    food_id=food_entry.food_id,
                    food_name=food_entry.food_name,
                    quantity_grams=food_entry.quantity_grams,
                    calories=food_entry.calories,
                    protein=food_entry.protein,
                    carbs=food_entry.carbs,
                    fat=food_entry.fat,
                )
                await self.repository.add_food_entry(entry)

        await self.repository.update_meal(meal)
        await self.repository.commit()

        updated = await self.repository.get_meal_by_id(meal_id)
        return self._to_meal_response(updated)  # type: ignore[arg-type]

    async def delete_meal(self, meal_id: UUID, user_id: UUID) -> None:
        """Soft delete de uma refeição (LGPD: dados não são removidos)."""
        meal = await self.repository.get_meal_by_id(meal_id)
        if not meal:
            raise MealNotFoundError(f"Refeição {meal_id} não encontrada")
        if meal.user_id != user_id:
            raise MealForbiddenError("Você não tem acesso a essa refeição")
        await self.repository.soft_delete_meal(meal)
        await self.repository.commit()

    async def get_daily_summary(
        self, user_id: UUID, summary_date: date
    ) -> DailySummaryDTO:
        """Retorna resumo diário de macronutrientes de um dia específico."""
        meals, _ = await self.repository.list_meals(
            user_id, meal_date=summary_date, limit=100
        )
        meal_dtos = [self._to_meal_response(m) for m in meals]

        return DailySummaryDTO(
            date=summary_date,
            total_calories=sum(m.calories for m in meal_dtos),
            total_protein=sum(m.protein for m in meal_dtos),
            total_carbs=sum(m.carbs for m in meal_dtos),
            total_fat=sum(m.fat for m in meal_dtos),
            meal_count=len(meal_dtos),
            meals=meal_dtos,
        )

    # ------------------------------------------------------------------
    # Catálogo de Alimentos
    # ------------------------------------------------------------------

    async def search_foods(self, query: str, limit: int = 20) -> List[FoodResponseDTO]:
        """Busca alimentos no catálogo por nome."""
        foods = await self.repository.search_foods(query, limit=limit)
        return [self._to_food_response(f) for f in foods]

    async def create_food(self, dto: CreateFoodDTO) -> FoodResponseDTO:
        """Adiciona um alimento ao catálogo (admin/personal)."""
        food = Food(
            name=dto.name,
            brand=dto.brand,
            calories_per_100g=dto.calories_per_100g,
            protein_per_100g=dto.protein_per_100g,
            carbs_per_100g=dto.carbs_per_100g,
            fat_per_100g=dto.fat_per_100g,
            fiber_per_100g=dto.fiber_per_100g,
        )
        created = await self.repository.create_food(food)
        await self.repository.commit()
        return self._to_food_response(created)

    # ------------------------------------------------------------------
    # Helpers de Mapeamento
    # ------------------------------------------------------------------

    @staticmethod
    def _to_meal_response(meal: Meal) -> MealResponseDTO:
        """Converte Meal para MealResponseDTO."""
        entries = []
        if hasattr(meal, "food_entries") and meal.food_entries:
            entries = [
                FoodEntryResponseDTO(
                    id=entry.id,
                    food_id=entry.food_id,
                    name=entry.food_name,
                    quantity_grams=entry.quantity_grams,
                    calories=entry.calories,
                    protein=entry.protein,
                    carbs=entry.carbs,
                    fat=entry.fat,
                )
                for entry in meal.food_entries
            ]

        return MealResponseDTO(
            id=meal.id,
            user_id=meal.user_id,
            meal_type=meal.meal_type,
            meal_date=meal.meal_date,
            calories=meal.total_calories,
            protein=meal.total_protein,
            carbs=meal.total_carbs,
            fat=meal.total_fat,
            foods=entries,
            notes=meal.notes,
            created_at=meal.created_at,
        )

    @staticmethod
    def _to_food_response(food: Food) -> FoodResponseDTO:
        """Converte Food para FoodResponseDTO."""
        return FoodResponseDTO(
            id=food.id,
            name=food.name,
            brand=food.brand,
            calories=food.calories_per_100g,
            protein=food.protein_per_100g,
            carbs=food.carbs_per_100g,
            fat=food.fat_per_100g,
            fiber=food.fiber_per_100g,
        )
