"""
Controller do módulo Logbook.

Camada de orquestração: recebe dados das rotas, invoca o serviço
e retorna DTOs de resposta. Não contém lógica de negócio.
"""

from datetime import datetime
from typing import Optional
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.logbook_dto import (
    CalendarResponseDTO,
    CreateSessionDTO,
    FrequencyResponseDTO,
    PaginatedSessionsDTO,
    ProgressionResponseDTO,
    SessionExerciseDTO,
    SessionExerciseResponseDTO,
    SessionResponseDTO,
    UpdateSessionDTO,
)
from app.services.logbook_service import LogbookService


class LogbookController:
    """Orquestrador do módulo Logbook."""

    def __init__(self, session: AsyncSession) -> None:
        self.service = LogbookService(session)

    async def create_session(
        self,
        user_id: UUID,
        dto: CreateSessionDTO,
    ) -> SessionResponseDTO:
        """Inicia uma nova sessão de treino."""
        return await self.service.create_session(user_id, dto)

    async def add_exercise(
        self,
        session_id: UUID,
        user_id: UUID,
        role: str,
        dto: SessionExerciseDTO,
    ) -> tuple[SessionExerciseResponseDTO, bool]:
        """
        Registra ou atualiza exercício em uma sessão.

        Returns:
            Tuple com (DTO do exercício, bool indicando se foi criado).
        """
        return await self.service.add_exercise_to_session(session_id, user_id, role, dto)

    async def update_session(
        self,
        session_id: UUID,
        user_id: UUID,
        role: str,
        dto: UpdateSessionDTO,
    ) -> SessionResponseDTO:
        """Atualiza ou finaliza uma sessão de treino."""
        return await self.service.update_session(session_id, user_id, role, dto)

    async def get_session(
        self,
        session_id: UUID,
        user_id: UUID,
        role: str,
    ) -> SessionResponseDTO:
        """Busca uma sessão específica."""
        return await self.service.get_session(session_id, user_id, role)

    async def list_sessions(
        self,
        requester_id: UUID,
        role: str,
        user_id_filter: Optional[UUID],
        start_date: Optional[datetime],
        end_date: Optional[datetime],
        status_filter: Optional[str],
        page: int,
        limit: int,
    ) -> PaginatedSessionsDTO:
        """Lista sessões com filtros e paginação."""
        return await self.service.list_sessions(
            requester_id=requester_id,
            role=role,
            user_id_filter=user_id_filter,
            start_date=start_date,
            end_date=end_date,
            status_filter=status_filter,
            page=page,
            limit=limit,
        )

    async def delete_session(
        self,
        session_id: UUID,
        user_id: UUID,
        role: str,
    ) -> None:
        """Soft delete de uma sessão."""
        return await self.service.delete_session(session_id, user_id, role)

    async def get_calendar(
        self,
        user_id: UUID,
        year: int,
        month: int,
    ) -> CalendarResponseDTO:
        """Retorna calendário mensal de treinos."""
        return await self.service.get_calendar(user_id, year, month)

    async def get_progression(
        self,
        exercise_id: UUID,
        user_id: UUID,
        weeks: Optional[int],
        start_date: Optional[datetime],
        end_date: Optional[datetime],
        group_by: Optional[str] = None,
    ) -> ProgressionResponseDTO:
        """Retorna evolução de carga de um exercício."""
        return await self.service.get_progression(
            exercise_id=exercise_id,
            user_id=user_id,
            weeks=weeks,
            start_date=start_date,
            end_date=end_date,
            group_by=group_by,
        )

    async def get_frequency(
        self,
        user_id: UUID,
        period: str,
        limit: Optional[int],
    ) -> FrequencyResponseDTO:
        """Retorna frequência de treinos agrupados por período."""
        return await self.service.get_frequency(
            user_id=user_id,
            period=period,
            limit=limit,
        )
