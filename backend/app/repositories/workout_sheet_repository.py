"""
Repositório do módulo Ficha de Treino.

Responsável pelo acesso direto ao banco de dados para workout sheets,
exercises e o catálogo de exercícios. Sem lógica de negócio — apenas queries.
"""

from datetime import datetime
from typing import List, Optional, Tuple
from uuid import UUID, uuid4

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.workout_sheet import Exercise, WorkoutSheet
from app.models.exercise_catalog import ExerciseCatalog


class WorkoutSheetRepository:
    """Repositório de operações de banco para o módulo Ficha de Treino."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    # ------------------------------------------------------------------
    # Fichas de Treino
    # ------------------------------------------------------------------

    async def create_workout_sheet(self, sheet: WorkoutSheet) -> WorkoutSheet:
        """Persiste uma nova ficha de treino (com exercícios via cascade)."""
        self.session.add(sheet)
        await self.session.flush()
        await self.session.refresh(sheet)
        return sheet

    async def get_workout_sheet_by_id(self, sheet_id: UUID) -> Optional[WorkoutSheet]:
        """Busca ficha ativa pelo UUID."""
        stmt = select(WorkoutSheet).where(
            WorkoutSheet.id == sheet_id,
            WorkoutSheet.is_active.is_(True),
        )
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def get_workout_sheet_by_id_any_status(self, sheet_id: UUID) -> Optional[WorkoutSheet]:
        """Busca ficha pelo UUID independente do status (inclusive inativas)."""
        stmt = select(WorkoutSheet).where(WorkoutSheet.id == sheet_id)
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def count_active_sheets_for_day(
        self, user_id: UUID, day_of_week: int, exclude_id: Optional[UUID] = None
    ) -> int:
        """
        Conta fichas ativas do aluno para um dado dia da semana.
        Usado para validar RN-01: uma ficha ativa por dia.
        """
        stmt = select(func.count()).where(
            WorkoutSheet.user_id == user_id,
            WorkoutSheet.day_of_week == day_of_week,
            WorkoutSheet.is_active.is_(True),
        )
        if exclude_id is not None:
            stmt = stmt.where(WorkoutSheet.id != exclude_id)
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def list_workout_sheets(
        self,
        user_id: Optional[UUID],
        personal_trainer_id: Optional[UUID],
        day_of_week: Optional[int],
        page: int,
        limit: int,
    ) -> Tuple[List[WorkoutSheet], int]:
        """
        Lista fichas ativas com filtros e paginação.

        Returns:
            Tuple[List[WorkoutSheet], int]: Fichas da página e total.
        """
        base_stmt = select(WorkoutSheet).where(WorkoutSheet.is_active.is_(True))

        if user_id is not None:
            base_stmt = base_stmt.where(WorkoutSheet.user_id == user_id)
        if personal_trainer_id is not None:
            base_stmt = base_stmt.where(
                WorkoutSheet.personal_trainer_id == personal_trainer_id
            )
        if day_of_week is not None:
            base_stmt = base_stmt.where(WorkoutSheet.day_of_week == day_of_week)

        # Total
        count_stmt = select(func.count()).select_from(base_stmt.subquery())
        total_result = await self.session.execute(count_stmt)
        total = total_result.scalar() or 0

        # Página
        offset = (page - 1) * limit
        paged_stmt = (
            base_stmt.order_by(WorkoutSheet.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        result = await self.session.execute(paged_stmt)
        sheets = list(result.scalars().all())

        return sheets, total

    async def update_workout_sheet(self, sheet: WorkoutSheet) -> WorkoutSheet:
        """Persiste alterações em uma ficha."""
        sheet.updated_at = datetime.utcnow()
        await self.session.flush()
        await self.session.refresh(sheet)
        return sheet

    async def soft_delete_workout_sheet(self, sheet_id: UUID) -> bool:
        """Marca a ficha como inativa (soft delete). Retorna True se encontrada."""
        sheet = await self.get_workout_sheet_by_id(sheet_id)
        if not sheet:
            return False
        sheet.is_active = False
        sheet.updated_at = datetime.utcnow()
        await self.session.flush()
        return True

    async def delete_exercises_from_sheet(self, sheet_id: UUID) -> None:
        """Remove todos os exercícios de uma ficha (para substituição no update)."""
        stmt = select(Exercise).where(Exercise.workout_sheet_id == sheet_id)
        result = await self.session.execute(stmt)
        for exercise in result.scalars().all():
            await self.session.delete(exercise)
        await self.session.flush()

    # ------------------------------------------------------------------
    # Catálogo de Exercícios
    # ------------------------------------------------------------------

    async def search_exercise_catalog(
        self,
        search: Optional[str] = None,
        muscle_group: Optional[str] = None,
        equipment: Optional[str] = None,
        page: int = 1,
        limit: int = 20,
    ) -> Tuple[List[ExerciseCatalog], int]:
        """
        Busca paginada no catálogo de exercícios.

        Args:
            search: Termo de busca no nome (case-insensitive, parcial)
            muscle_group: Filtro por muscle_group_mapped
            equipment: Filtro por equipamento (ex: maquina, peso-do-corpo)
            page: Página (1-indexed)
            limit: Itens por página

        Returns:
            Tuple[List[ExerciseCatalog], int]: Itens da página e total.
        """
        base_stmt = select(ExerciseCatalog)

        if search:
            base_stmt = base_stmt.where(
                ExerciseCatalog.name.ilike(f"%{search}%")
            )
        if muscle_group:
            base_stmt = base_stmt.where(
                ExerciseCatalog.muscle_group_mapped == muscle_group
            )
        if equipment:
            base_stmt = base_stmt.where(
                ExerciseCatalog.equipment == equipment
            )

        # Total
        count_stmt = select(func.count()).select_from(base_stmt.subquery())
        total_result = await self.session.execute(count_stmt)
        total = total_result.scalar() or 0

        # Página
        offset = (page - 1) * limit
        paged_stmt = (
            base_stmt.order_by(ExerciseCatalog.name.asc())
            .offset(offset)
            .limit(limit)
        )
        result = await self.session.execute(paged_stmt)
        items = list(result.scalars().all())

        return items, total

    # ------------------------------------------------------------------
    # Transação
    # ------------------------------------------------------------------

    async def commit(self) -> None:
        """Commit da transação atual."""
        await self.session.commit()

    async def rollback(self) -> None:
        """Rollback da transação atual."""
        await self.session.rollback()
