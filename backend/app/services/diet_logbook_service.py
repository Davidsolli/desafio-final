"""
Serviço do Diário Alimentar (Diet Logbook).

Camada de lógica de negócio para registrar, consultar e remover
entradas do diário alimentar, com snapshot de macros.
"""

from datetime import date
from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.diet_logbook_dto import (
    AddLogbookEntryDTO,
    DietLogbookResponseDTO,
    LogbookEntryResponseDTO,
)
from app.models.diet_logbook import DietLogbookEntry
from app.repositories.diet_repository import DietRepository


# ---------------------------------------------------------------------------
# Exceções de Negócio
# ---------------------------------------------------------------------------


class LogbookEntryNotFoundError(Exception):
    """Entrada do logbook não encontrada."""


class LogbookForbiddenError(Exception):
    """Sem permissão para esta operação no logbook."""


class LogbookValidationError(Exception):
    """Validação de negócio do logbook falhou."""


# ---------------------------------------------------------------------------
# Serviço
# ---------------------------------------------------------------------------


class DietLogbookService:
    """Serviço de lógica de negócio para o Diário Alimentar."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = DietRepository(session)

    # ------------------------------------------------------------------
    # Adicionar Entry
    # ------------------------------------------------------------------

    async def add_entry(
        self, user_id: UUID, dto: AddLogbookEntryDTO
    ) -> LogbookEntryResponseDTO:
        """
        Registra um alimento consumido no diário.

        1. Busca dados nutricionais na TACO ou CustomFood
        2. Calcula macros proporcionais (value × quantity_g / 100)
        3. Grava snapshot no DietLogbookEntry
        4. Atualiza totais do logbook do dia
        """
        # Buscar dados do alimento
        food_name, kcal_per100, prot_per100, carb_per100, fat_per100 = (
            await self._resolve_food(user_id, dto)
        )

        # Calcular macros proporcionais
        ratio = dto.quantity_g / 100.0
        kcal = round(kcal_per100 * ratio, 2)
        protein = round(prot_per100 * ratio, 2)
        carbs = round(carb_per100 * ratio, 2)
        fats = round(fat_per100 * ratio, 2)

        # Data padrão: hoje
        log_date = dto.log_date or date.today()

        # Get-or-create logbook do dia
        logbook = await self.repository.get_or_create_logbook(user_id, log_date)

        # Criar entry com snapshot
        entry = DietLogbookEntry(
            logbook_id=logbook.id,
            meal_name=dto.meal_name,
            food_id=dto.food_id,
            custom_food_id=dto.custom_food_id,
            food_name=food_name,
            quantity_g=dto.quantity_g,
            kcal=kcal,
            protein=protein,
            carbs=carbs,
            fats=fats,
        )
        created_entry = await self.repository.add_logbook_entry(entry)

        # Atualizar totais do logbook (somar diretamente no objeto)
        logbook.total_kcal = round(logbook.total_kcal + kcal, 2)
        logbook.total_protein = round(logbook.total_protein + protein, 2)
        logbook.total_carbs = round(logbook.total_carbs + carbs, 2)
        logbook.total_fats = round(logbook.total_fats + fats, 2)
        
        await self.repository.commit()

        return LogbookEntryResponseDTO(
            id=created_entry.id,
            logbook_id=created_entry.logbook_id,
            meal_name=created_entry.meal_name,
            food_id=created_entry.food_id,
            custom_food_id=created_entry.custom_food_id,
            food_name=food_name,
            quantity_g=created_entry.quantity_g,
            kcal=kcal,
            protein=protein,
            carbs=carbs,
            fats=fats,
        )

    # ------------------------------------------------------------------
    # Remover Entry
    # ------------------------------------------------------------------

    async def remove_entry(
        self, entry_id: UUID, user_id: UUID
    ) -> None:
        """
        Remove uma entrada do logbook e subtrai dos totais do dia.
        """
        entry = await self.repository.get_logbook_entry_by_id(entry_id)
        if not entry:
            raise LogbookEntryNotFoundError("Registro não encontrado.")

        # Verificar que o logbook pertence ao usuário
        logbook = await self.repository.get_logbook_by_date(
            user_id=user_id,
            log_date=entry.logbook.date if hasattr(entry, "logbook") else date.today(),
        )
        if not logbook or entry.logbook_id != logbook.id:
            raise LogbookForbiddenError(
                "Você não tem permissão para remover este registro."
            )

        # Subtrair dos totais
        new_kcal = max(0, logbook.total_kcal - entry.kcal)
        new_protein = max(0, logbook.total_protein - entry.protein)
        new_carbs = max(0, logbook.total_carbs - entry.carbs)
        new_fats = max(0, logbook.total_fats - entry.fats)

        await self.repository.delete_logbook_entry(entry)
        await self.repository.update_logbook_totals(
            logbook_id=logbook.id,
            total_kcal=round(new_kcal, 2),
            total_protein=round(new_protein, 2),
            total_carbs=round(new_carbs, 2),
            total_fats=round(new_fats, 2),
        )
        await self.repository.commit()

    # ------------------------------------------------------------------
    # Consultar Dia
    # ------------------------------------------------------------------

    async def get_logbook(
        self, user_id: UUID, log_date: date
    ) -> Optional[DietLogbookResponseDTO]:
        """Retorna o logbook completo do dia."""
        logbook = await self.repository.get_logbook_by_date(user_id, log_date)
        if not logbook:
            return None

        entries = [
            LogbookEntryResponseDTO(
                id=e.id,
                logbook_id=e.logbook_id,
                meal_name=e.meal_name,
                food_id=e.food_id,
                custom_food_id=e.custom_food_id,
                food_name=e.food_name,
                quantity_g=e.quantity_g,
                kcal=e.kcal,
                protein=e.protein,
                carbs=e.carbs,
                fats=e.fats,
            )
            for e in (logbook.entries or [])
        ]

        return DietLogbookResponseDTO(
            id=logbook.id,
            user_id=logbook.user_id,
            date=logbook.date,
            total_kcal=logbook.total_kcal,
            total_protein=logbook.total_protein,
            total_carbs=logbook.total_carbs,
            total_fats=logbook.total_fats,
            created_at=logbook.created_at,
            entries=entries,
        )

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    async def _resolve_food(
        self, user_id: UUID, dto: AddLogbookEntryDTO
    ) -> tuple:
        """
        Busca dados nutricionais do alimento (TACO ou Custom).

        Returns:
            (name, kcal_per100, protein_per100, carbs_per100, fats_per100)
        """
        if dto.food_id is not None:
            food = await self.repository.get_food_by_id(dto.food_id)
            if food:
                return (
                    food.name,
                    food.energy_kcal,
                    food.protein_g,
                    food.carbohydrate_g,
                    food.lipid_g,
                )

        if dto.custom_food_id is not None:
            food = await self.repository.get_custom_food_by_id(dto.custom_food_id)
            if food:
                # Verificar que o custom food pertence ao usuário
                if food.user_id != user_id:
                    raise LogbookValidationError(
                        "Alimento personalizado não pertence ao usuário."
                    )
                return (
                    food.name,
                    food.energy_kcal,
                    food.protein_g,
                    food.carbohydrate_g,
                    food.lipid_g,
                )

        raise LogbookValidationError("Alimento não encontrado no catálogo.")
