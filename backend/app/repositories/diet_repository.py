"""
Repositório do módulo de Dieta.

Responsável pelo acesso direto ao banco de dados para custom foods,
dietas, refeições, itens e logbook alimentar. Sem lógica de negócio.
"""

from datetime import date, datetime
from typing import List, Optional, Tuple
from uuid import UUID

from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.diet import CustomFood, Diet, DietItem, DietMeal
from app.models.diet_logbook import DietLogbook, DietLogbookEntry
from app.models.food_catalog import FoodCatalog


class DietRepository:
    """Repositório de operações de banco para o módulo de Dieta."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    # ------------------------------------------------------------------
    # Custom Foods
    # ------------------------------------------------------------------

    async def create_custom_food(self, food: CustomFood) -> CustomFood:
        """Persiste um novo alimento personalizado."""
        self.session.add(food)
        await self.session.flush()
        await self.session.refresh(food)
        return food

    async def list_custom_foods(
        self,
        user_id: UUID,
        search: Optional[str] = None,
    ) -> List[CustomFood]:
        """Lista alimentos personalizados de um usuário."""
        stmt = select(CustomFood).where(CustomFood.user_id == user_id)
        if search:
            stmt = stmt.where(CustomFood.name.ilike(f"%{search}%"))
        stmt = stmt.order_by(CustomFood.name.asc())
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_custom_food_by_id(self, food_id: UUID) -> Optional[CustomFood]:
        """Busca alimento personalizado pelo ID."""
        stmt = select(CustomFood).where(CustomFood.id == food_id)
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def update_custom_food(self, food: CustomFood) -> CustomFood:
        """Atualiza os dados de um alimento personalizado."""
        await self.session.flush()
        await self.session.refresh(food)
        return food

    async def delete_custom_food(self, food_id: UUID) -> bool:
        """Deleta um alimento personalizado pelo ID."""
        stmt = select(CustomFood).where(CustomFood.id == food_id)
        result = await self.session.execute(stmt)
        food = result.scalars().first()
        if not food:
            return False
        await self.session.delete(food)
        await self.session.flush()
        return True

    # ------------------------------------------------------------------
    # Catálogo TACO
    # ------------------------------------------------------------------

    async def get_food_by_id(self, food_id: int) -> Optional[FoodCatalog]:
        """Busca alimento na tabela TACO pelo ID."""
        stmt = select(FoodCatalog).where(FoodCatalog.id == food_id)
        result = await self.session.execute(stmt)
        return result.scalars().first()

    # ------------------------------------------------------------------
    # Dietas
    # ------------------------------------------------------------------

    async def create_diet(self, diet: Diet) -> Diet:
        """Persiste uma nova dieta (com cascade de meals→items)."""
        self.session.add(diet)
        await self.session.flush()
        await self.session.refresh(diet)
        return diet

    async def get_diet_by_id(self, diet_id: UUID) -> Optional[Diet]:
        """Busca dieta ativa pelo UUID (com meals e items via selectin)."""
        stmt = select(Diet).where(
            Diet.id == diet_id,
            Diet.is_active.is_(True),
        )
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def list_diets(
        self,
        user_id: UUID,
        is_custom: Optional[bool] = None,
        page: int = 1,
        limit: int = 10,
    ) -> Tuple[List[Diet], int]:
        """Lista dietas ativas do aluno com paginação."""
        base_stmt = select(Diet).where(
            Diet.user_id == user_id,
            Diet.is_active.is_(True),
        )
        if is_custom is not None:
            base_stmt = base_stmt.where(Diet.is_custom == is_custom)

        # Total
        count_stmt = select(func.count()).select_from(base_stmt.subquery())
        total_result = await self.session.execute(count_stmt)
        total = total_result.scalar() or 0

        # Página
        offset = (page - 1) * limit
        paged_stmt = (
            base_stmt.order_by(Diet.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        result = await self.session.execute(paged_stmt)
        diets = list(result.scalars().all())

        return diets, total

    async def deactivate_diets(self, user_id: UUID, is_custom: bool) -> int:
        """
        Desativa todas as dietas ativas de um tipo para o aluno.

        RN-01: No máximo uma dieta ativa por tipo (prescrita/custom).
        Retorna a quantidade de dietas desativadas.
        """
        stmt = (
            update(Diet)
            .where(
                Diet.user_id == user_id,
                Diet.is_custom == is_custom,
                Diet.is_active.is_(True),
            )
            .values(is_active=False, updated_at=datetime.utcnow())
        )
        result = await self.session.execute(stmt)
        return result.rowcount

    async def update_diet(self, diet: Diet) -> Diet:
        """Persiste alterações em uma dieta."""
        diet.updated_at = datetime.utcnow()
        await self.session.flush()
        await self.session.refresh(diet)
        return diet

    async def soft_delete_diet(self, diet_id: UUID) -> bool:
        """Marca dieta como inativa (soft delete). Retorna True se encontrada."""
        diet = await self.get_diet_by_id(diet_id)
        if not diet:
            return False
        diet.is_active = False
        diet.updated_at = datetime.utcnow()
        await self.session.flush()
        return True

    async def delete_meals_from_diet(self, diet_id: UUID) -> None:
        """Remove todas as refeições de uma dieta (para substituição no update)."""
        stmt = select(DietMeal).where(DietMeal.diet_id == diet_id)
        result = await self.session.execute(stmt)
        for meal in result.scalars().all():
            await self.session.delete(meal)
        await self.session.flush()

    # ------------------------------------------------------------------
    # Logbook
    # ------------------------------------------------------------------

    async def get_or_create_logbook(self, user_id: UUID, log_date: date) -> DietLogbook:
        """Busca ou cria o logbook do dia para o aluno."""
        stmt = select(DietLogbook).where(
            DietLogbook.user_id == user_id,
            DietLogbook.date == log_date,
        )
        result = await self.session.execute(stmt)
        logbook = result.scalars().first()

        if logbook is None:
            logbook = DietLogbook(
                user_id=user_id,
                date=log_date,
                total_kcal=0.0,
                total_protein=0.0,
                total_carbs=0.0,
                total_fats=0.0,
            )
            self.session.add(logbook)
            await self.session.flush()
            await self.session.refresh(logbook)

        return logbook

    async def add_logbook_entry(self, entry: DietLogbookEntry) -> DietLogbookEntry:
        """Persiste uma nova entrada no logbook."""
        self.session.add(entry)
        await self.session.flush()
        await self.session.refresh(entry)
        return entry

    async def get_logbook_entry_by_id(
        self, entry_id: UUID
    ) -> Optional[DietLogbookEntry]:
        """Busca uma entrada do logbook pelo ID."""
        stmt = select(DietLogbookEntry).where(DietLogbookEntry.id == entry_id)
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def delete_logbook_entry(self, entry: DietLogbookEntry) -> None:
        """Remove uma entrada do logbook."""
        await self.session.delete(entry)
        await self.session.flush()

    async def get_logbooks_in_range(
        self, user_id: UUID, start_date: date, end_date: date
    ) -> List[DietLogbook]:
        """Retorna todos os logbooks de um período (inclusive nos limites)."""
        stmt = (
            select(DietLogbook)
            .where(
                DietLogbook.user_id == user_id,
                DietLogbook.date >= start_date,
                DietLogbook.date <= end_date,
            )
            .order_by(DietLogbook.date.asc())
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_logbook_by_date(
        self, user_id: UUID, log_date: date
    ) -> Optional[DietLogbook]:
        """Busca o logbook completo do dia (com entries via selectin)."""
        stmt = select(DietLogbook).where(
            DietLogbook.user_id == user_id,
            DietLogbook.date == log_date,
        )
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def update_logbook_totals(
        self,
        logbook_id: UUID,
        total_kcal: float,
        total_protein: float,
        total_carbs: float,
        total_fats: float,
    ) -> None:
        """Atualiza os totais de macros de um logbook."""
        stmt = (
            update(DietLogbook)
            .where(DietLogbook.id == logbook_id)
            .values(
                total_kcal=total_kcal,
                total_protein=total_protein,
                total_carbs=total_carbs,
                total_fats=total_fats,
            )
        )
        await self.session.execute(stmt)

    # ------------------------------------------------------------------
    # Transação
    # ------------------------------------------------------------------

    async def commit(self) -> None:
        """Commit da transação atual."""
        await self.session.commit()

    async def rollback(self) -> None:
        """Rollback da transação atual."""
        await self.session.rollback()
