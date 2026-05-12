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
from sqlalchemy.orm import selectinload

from app.models.workout_sheet import Exercise, WorkoutSheet, WorkoutProgram
from app.models.exercise_catalog import ExerciseCatalog


class WorkoutSheetRepository:
    """Repositório de operações de banco para o módulo Ficha de Treino."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    # ------------------------------------------------------------------
    # Programas de Treino (Workout Programs)
    # ------------------------------------------------------------------

    async def create_workout_program(self, program: WorkoutProgram) -> WorkoutProgram:
        self.session.add(program)
        await self.session.flush()
        # Força o retorno do programa com eager loading completo para evitar erros de lazy loading pós-commit
        return await self.get_workout_program_by_id(program.id)

    async def get_workout_program_by_id(self, program_id: UUID) -> Optional[WorkoutProgram]:
        stmt = select(WorkoutProgram).where(
            WorkoutProgram.id == program_id,
            WorkoutProgram.is_active.is_(True),
        ).options(
            selectinload(WorkoutProgram.workout_sheets).selectinload(WorkoutSheet.exercises)
        )
        result = await self.session.execute(stmt)
        return result.scalars().first()

    async def list_workout_programs(
        self,
        user_id: Optional[UUID],
        page: int,
        limit: int,
    ) -> Tuple[List[WorkoutProgram], int]:
        base_stmt = select(WorkoutProgram).where(WorkoutProgram.is_active.is_(True))

        if user_id is not None:
            base_stmt = base_stmt.where(WorkoutProgram.user_id == user_id)

        count_stmt = select(func.count()).select_from(base_stmt.subquery())
        total = (await self.session.execute(count_stmt)).scalar() or 0

        offset = (page - 1) * limit
        paged_stmt = base_stmt.order_by(WorkoutProgram.created_at.desc()).offset(offset).limit(limit)
        result = await self.session.execute(paged_stmt)
        
        return list(result.scalars().all()), total

    async def update_workout_program(self, program: WorkoutProgram) -> WorkoutProgram:
        program.updated_at = datetime.utcnow()
        await self.session.flush()
        await self.session.refresh(program)
        return program

    async def soft_delete_workout_program(self, program_id: UUID) -> bool:
        program = await self.get_workout_program_by_id(program_id)
        if not program:
            return False
        program.is_active = False
        program.updated_at = datetime.utcnow()
        await self.session.flush()
        return True

    # ------------------------------------------------------------------
    # Fichas de Treino (Workout Sheets)
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

    # (Removido count_active_sheets_for_day, não há limite por dia na nova arquitetura)

    async def list_workout_sheets(
        self,
        workout_program_id: Optional[UUID],
        page: int,
        limit: int,
    ) -> Tuple[List[WorkoutSheet], int]:
        """
        Lista fichas ativas.

        Returns:
            Tuple[List[WorkoutSheet], int]: Fichas da página e total.
        """
        base_stmt = select(WorkoutSheet).where(WorkoutSheet.is_active.is_(True))

        if workout_program_id is not None:
            base_stmt = base_stmt.where(WorkoutSheet.workout_program_id == workout_program_id)

        # Total
        count_stmt = select(func.count()).select_from(base_stmt.subquery())
        total_result = await self.session.execute(count_stmt)
        total = total_result.scalar() or 0

        # Página
        offset = (page - 1) * limit
        paged_stmt = (
            base_stmt.options(selectinload(WorkoutSheet.exercises))
            .order_by(WorkoutSheet.order.asc(), WorkoutSheet.created_at.desc())
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
# reload
