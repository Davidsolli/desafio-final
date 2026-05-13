"""
Controller do módulo de Dieta.

Camada de orquestração: recebe dados das rotas, invoca o serviço
e retorna DTOs de resposta. Não contém lógica de negócio.
"""

from datetime import date
from typing import List, Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.diet_dto import (
    CreateCustomFoodDTO,
    CreateDietDTO,
    CustomFoodResponseDTO,
    DietResponseDTO,
    DuplicateDietDTO,
    PaginatedDietsDTO,
    UpdateDietDTO,
)
from app.dtos.diet_logbook_dto import (
    AddLogbookEntryDTO,
    DietLogbookResponseDTO,
    LogbookEntryResponseDTO,
    NutritionAnalyticsSummaryResponseDTO,
)
from app.services.diet_service import DietService
from app.services.diet_logbook_service import DietLogbookService


class DietController:
    """Orquestrador do módulo de Dieta."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.diet_service = DietService(session)
        self.logbook_service = DietLogbookService(session)

    # ------------------------------------------------------------------
    # Custom Foods
    # ------------------------------------------------------------------

    async def create_custom_food(
        self, user_id: UUID, dto: CreateCustomFoodDTO
    ) -> CustomFoodResponseDTO:
        """Cria um alimento personalizado."""
        return await self.diet_service.create_custom_food(user_id, dto)

    async def list_custom_foods(
        self, user_id: UUID, search: Optional[str] = None
    ) -> List[CustomFoodResponseDTO]:
        """Lista alimentos personalizados do usuário."""
        return await self.diet_service.list_custom_foods(user_id, search)

    # ------------------------------------------------------------------
    # Dietas
    # ------------------------------------------------------------------

    async def create_diet(
        self, requester_id: UUID, role: str, dto: CreateDietDTO
    ) -> DietResponseDTO:
        """Cria uma nova dieta."""
        return await self.diet_service.create_diet(requester_id, role, dto)

    async def list_diets(
        self,
        requester_id: UUID,
        role: str,
        user_id_filter: Optional[UUID],
        is_custom: Optional[bool],
        page: int,
        limit: int,
    ) -> PaginatedDietsDTO:
        """Lista dietas com filtros e paginação."""
        return await self.diet_service.list_diets(
            requester_id, role, user_id_filter, is_custom, page, limit
        )

    async def get_diet(
        self, diet_id: UUID, requester_id: UUID, role: str
    ) -> DietResponseDTO:
        """Busca dieta pelo ID."""
        return await self.diet_service.get_diet(diet_id, requester_id, role)

    async def update_diet(
        self, diet_id: UUID, requester_id: UUID, role: str, dto: UpdateDietDTO
    ) -> DietResponseDTO:
        """Atualiza uma dieta."""
        return await self.diet_service.update_diet(diet_id, requester_id, role, dto)

    async def delete_diet(
        self, diet_id: UUID, requester_id: UUID, role: str
    ) -> None:
        """Soft delete de uma dieta."""
        return await self.diet_service.delete_diet(diet_id, requester_id, role)

    async def duplicate_diet(
        self, diet_id: UUID, requester_id: UUID, role: str, dto: DuplicateDietDTO
    ) -> DietResponseDTO:
        """Duplica uma dieta existente."""
        return await self.diet_service.duplicate_diet(diet_id, requester_id, role, dto)

    # ------------------------------------------------------------------
    # Logbook
    # ------------------------------------------------------------------

    async def add_logbook_entry(
        self, user_id: UUID, dto: AddLogbookEntryDTO
    ) -> LogbookEntryResponseDTO:
        """Registra alimento consumido no diário."""
        return await self.logbook_service.add_entry(user_id, dto)

    async def get_logbook(
        self, user_id: UUID, log_date: date
    ) -> Optional[DietLogbookResponseDTO]:
        """Retorna diário do dia."""
        return await self.logbook_service.get_logbook(user_id, log_date)

    async def remove_logbook_entry(
        self, entry_id: UUID, user_id: UUID
    ) -> None:
        """Remove registro do diário."""
        return await self.logbook_service.remove_entry(entry_id, user_id)

    async def get_nutrition_analytics(
        self,
        user_id: UUID,
        start_date: date,
        end_date: date,
    ) -> NutritionAnalyticsSummaryResponseDTO:
        """Retorna sumário histórico de nutrição com distribuição por refeição."""
        from app.models.user import User  # importação local para evitar ciclo

        # Enriquece com o peso atual do usuário (não há tracking histórico de peso)
        user = await self.session.get(User, user_id)
        weight_kg = user.weight if user and user.weight else None

        return await self.logbook_service.get_analytics_summary(
            user_id=user_id,
            start_date=start_date,
            end_date=end_date,
            weight_kg=weight_kg,
        )
