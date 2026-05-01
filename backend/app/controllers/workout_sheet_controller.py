"""
Controller do módulo Ficha de Treino.

Camada de orquestração: recebe dados das rotas, invoca o serviço
e retorna DTOs de resposta. Não contém lógica de negócio.
"""

from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.workout_sheet_dto import (
    CreateWorkoutSheetDTO,
    DuplicateWorkoutSheetDTO,
    PaginatedCatalogDTO,
    PaginatedWorkoutSheetsDTO,
    UpdateWorkoutSheetDTO,
    WorkoutSheetResponseDTO,
)
from app.services.workout_sheet_service import WorkoutSheetService


class WorkoutSheetController:
    """Orquestrador do módulo Ficha de Treino."""

    def __init__(self, session: AsyncSession) -> None:
        self.service = WorkoutSheetService(session)

    async def create_workout_sheet(
        self,
        requester_id: UUID,
        role: str,
        dto: CreateWorkoutSheetDTO,
    ) -> WorkoutSheetResponseDTO:
        """Cria uma nova ficha de treino."""
        return await self.service.create_workout_sheet(requester_id, role, dto)

    async def list_workout_sheets(
        self,
        requester_id: UUID,
        role: str,
        user_id_filter: Optional[UUID],
        day_of_week: Optional[int],
        page: int,
        limit: int,
    ) -> PaginatedWorkoutSheetsDTO:
        """Lista fichas com filtros e paginação."""
        return await self.service.list_workout_sheets(
            requester_id=requester_id,
            role=role,
            user_id_filter=user_id_filter,
            day_of_week=day_of_week,
            page=page,
            limit=limit,
        )

    async def get_workout_sheet(
        self,
        sheet_id: UUID,
        requester_id: UUID,
        role: str,
    ) -> WorkoutSheetResponseDTO:
        """Busca uma ficha pelo ID."""
        return await self.service.get_workout_sheet(sheet_id, requester_id, role)

    async def update_workout_sheet(
        self,
        sheet_id: UUID,
        requester_id: UUID,
        role: str,
        dto: UpdateWorkoutSheetDTO,
    ) -> WorkoutSheetResponseDTO:
        """Atualiza uma ficha de treino."""
        return await self.service.update_workout_sheet(sheet_id, requester_id, role, dto)

    async def delete_workout_sheet(
        self,
        sheet_id: UUID,
        requester_id: UUID,
        role: str,
    ) -> None:
        """Soft delete de uma ficha."""
        return await self.service.delete_workout_sheet(sheet_id, requester_id, role)

    async def duplicate_workout_sheet(
        self,
        sheet_id: UUID,
        requester_id: UUID,
        role: str,
        dto: DuplicateWorkoutSheetDTO,
    ) -> WorkoutSheetResponseDTO:
        """Duplica uma ficha existente."""
        return await self.service.duplicate_workout_sheet(sheet_id, requester_id, role, dto)

    async def search_exercise_catalog(
        self,
        search: Optional[str],
        muscle_group: Optional[str],
        page: int,
        limit: int,
    ) -> PaginatedCatalogDTO:
        """Busca exercícios no catálogo."""
        return await self.service.search_exercise_catalog(search, muscle_group, page, limit)
