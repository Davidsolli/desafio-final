"""
Repositório de Nutrição.

Operações de banco de dados para refeições e catálogo de alimentos.
"""

from datetime import date
from typing import List, Optional, Tuple
from uuid import UUID

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.nutrition import Food, Meal, MealFoodEntry


class NutritionRepository:
    """Repositório para operações de nutrição."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    # ------------------------------------------------------------------
    # Refeições
    # ------------------------------------------------------------------

    async def create_meal(self, meal: Meal) -> Meal:
        """Persiste uma nova refeição."""
        self.session.add(meal)
        await self.session.flush()
        await self.session.refresh(meal)
        return meal

    async def get_meal_by_id(self, meal_id: UUID) -> Optional[Meal]:
        """Busca refeição por ID (apenas não deletadas)."""
        result = await self.session.execute(
            select(Meal).where(Meal.id == meal_id, Meal.is_deleted == False)
        )
        return result.scalar_one_or_none()

    async def list_meals(
        self,
        user_id: UUID,
        meal_date: Optional[date] = None,
        limit: int = 10,
        offset: int = 0,
    ) -> Tuple[List[Meal], int]:
        """Lista refeições do usuário com filtro opcional por data."""
        conditions = [Meal.user_id == user_id, Meal.is_deleted == False]
        if meal_date:
            conditions.append(Meal.meal_date == meal_date)

        count_q = select(func.count(Meal.id)).where(*conditions)
        total = (await self.session.execute(count_q)).scalar() or 0

        query = (
            select(Meal)
            .where(*conditions)
            .order_by(Meal.meal_date.desc(), Meal.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        result = await self.session.execute(query)
        meals = list(result.scalars().all())
        return meals, total

    async def update_meal(self, meal: Meal) -> Meal:
        """Persiste alterações em uma refeição."""
        await self.session.flush()
        await self.session.refresh(meal)
        return meal

    async def soft_delete_meal(self, meal: Meal) -> None:
        """Marca refeição como deletada (soft delete — LGPD)."""
        meal.is_deleted = True
        await self.session.flush()

    async def delete_entries_for_meal(self, meal_id: UUID) -> None:
        """Remove todos os itens de uma refeição antes de atualizar."""
        entries = await self.session.execute(
            select(MealFoodEntry).where(MealFoodEntry.meal_id == meal_id)
        )
        for entry in entries.scalars().all():
            await self.session.delete(entry)
        await self.session.flush()

    async def add_food_entry(self, entry: MealFoodEntry) -> MealFoodEntry:
        """Adiciona um item de alimento à refeição."""
        self.session.add(entry)
        await self.session.flush()
        return entry

    async def commit(self) -> None:
        """Confirma a transação."""
        await self.session.commit()

    # ------------------------------------------------------------------
    # Catálogo de Alimentos
    # ------------------------------------------------------------------

    async def search_foods(
        self,
        query: str,
        limit: int = 20,
    ) -> List[Food]:
        """Busca alimentos no catálogo por nome (case-insensitive, parcial)."""
        result = await self.session.execute(
            select(Food)
            .where(Food.name.ilike(f"%{query}%"))
            .order_by(Food.name)
            .limit(limit)
        )
        return list(result.scalars().all())

    async def get_food_by_id(self, food_id: UUID) -> Optional[Food]:
        """Busca alimento pelo ID."""
        result = await self.session.execute(
            select(Food).where(Food.id == food_id)
        )
        return result.scalar_one_or_none()

    async def create_food(self, food: Food) -> Food:
        """Adiciona alimento ao catálogo."""
        self.session.add(food)
        await self.session.flush()
        await self.session.refresh(food)
        return food

    async def list_foods(
        self,
        limit: int = 50,
        offset: int = 0,
    ) -> Tuple[List[Food], int]:
        """Lista todos os alimentos do catálogo paginado."""
        total = (await self.session.execute(
            select(func.count(Food.id))
        )).scalar() or 0

        result = await self.session.execute(
            select(Food).order_by(Food.name).offset(offset).limit(limit)
        )
        return list(result.scalars().all()), total
