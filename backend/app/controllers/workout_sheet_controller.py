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
    CreateWorkoutProgramDTO,
    UpdateWorkoutProgramDTO,
    WorkoutProgramResponseDTO,
    PaginatedWorkoutProgramsDTO,
)
from app.services.workout_sheet_service import WorkoutSheetService


class WorkoutSheetController:
    """Orquestrador do módulo Ficha de Treino."""

    def __init__(self, session: AsyncSession) -> None:
        self.service = WorkoutSheetService(session)

    # ------------------------------------------------------------------
    # Programas de Treino
    # ------------------------------------------------------------------

    async def create_workout_program(
        self,
        requester_id: UUID,
        role: str,
        dto: CreateWorkoutProgramDTO,
    ) -> WorkoutProgramResponseDTO:
        return await self.service.create_workout_program(requester_id, role, dto)

    async def list_workout_programs(
        self,
        requester_id: UUID,
        role: str,
        user_id_filter: Optional[UUID],
        page: int,
        limit: int,
    ) -> PaginatedWorkoutProgramsDTO:
        return await self.service.list_workout_programs(
            requester_id=requester_id,
            role=role,
            user_id_filter=user_id_filter,
            page=page,
            limit=limit,
        )

    async def get_workout_program(
        self,
        program_id: UUID,
        requester_id: UUID,
        role: str,
    ) -> WorkoutProgramResponseDTO:
        return await self.service.get_workout_program(program_id, requester_id, role)

    async def update_workout_program(
        self,
        program_id: UUID,
        requester_id: UUID,
        role: str,
        dto: UpdateWorkoutProgramDTO,
    ) -> WorkoutProgramResponseDTO:
        return await self.service.update_workout_program(program_id, requester_id, role, dto)

    async def delete_workout_program(
        self,
        program_id: UUID,
        requester_id: UUID,
        role: str,
    ) -> None:
        return await self.service.delete_workout_program(program_id, requester_id, role)

    # ------------------------------------------------------------------
    # Fichas de Treino
    # ------------------------------------------------------------------

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
        workout_program_id: Optional[UUID],
        page: int,
        limit: int,
    ) -> PaginatedWorkoutSheetsDTO:
        """Lista fichas com filtros e paginação."""
        return await self.service.list_workout_sheets(
            requester_id=requester_id,
            role=role,
            workout_program_id=workout_program_id,
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
        search: Optional[str] = None,
        muscle_group: Optional[str] = None,
        equipment: Optional[str] = None,
        page: int = 1,
        limit: int = 20,
    ) -> PaginatedCatalogDTO:
        """Busca paginada no catálogo de exercícios predefinidos."""
        return await self.service.search_exercise_catalog(
            search=search,
            muscle_group=muscle_group,
            equipment=equipment,
            page=page,
            limit=limit,
        )
