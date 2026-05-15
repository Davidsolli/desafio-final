"""
Serviço do módulo Ficha de Treino.

Camada de lógica de negócio para criação, edição, deleção e duplicação
de fichas de treino, bem como busca no catálogo de exercícios.
"""

import logging
from datetime import datetime
from typing import List, Optional
from uuid import UUID, uuid4

from sqlalchemy.ext.asyncio import AsyncSession

logger = logging.getLogger(__name__)

from app.dtos.workout_sheet_dto import (
    CreateWorkoutSheetDTO,
    DuplicateWorkoutSheetDTO,
    ExerciseCatalogItemDTO,
    ExerciseCreateDTO,
    ExerciseResponseDTO,
    PaginatedCatalogDTO,
    PaginatedWorkoutSheetsDTO,
    UpdateWorkoutSheetDTO,
    WorkoutSheetListItemDTO,
    WorkoutSheetResponseDTO,
    CreateWorkoutProgramDTO,
    UpdateWorkoutProgramDTO,
    WorkoutProgramResponseDTO,
    PaginatedWorkoutProgramsDTO,
)
from app.models.workout_sheet import Exercise, WorkoutSheet, WorkoutProgram
from app.repositories.workout_sheet_repository import WorkoutSheetRepository


# ---------------------------------------------------------------------------
# Exceções de Negócio
# ---------------------------------------------------------------------------


class WorkoutSheetNotFoundError(Exception):
    """Ficha de treino não encontrada."""


class WorkoutSheetForbiddenError(Exception):
    """Usuário não tem permissão para esta operação."""


class WorkoutSheetValidationError(Exception):
    """Validação de negócio falhou."""


# ---------------------------------------------------------------------------
# Papéis com permissão de escrita
# ---------------------------------------------------------------------------

def _is_workout_writer(role: str) -> bool:
    """Apenas personal trainers (e admins/gestores) podem criar fichas de treino. Nutricionistas não."""
    from app.utils.role_utils import has_role
    return any(has_role(role, r) for r in {"admin", "personal_trainer", "professor", "gestor"})


WRITE_ROLES = {"admin", "personal_trainer", "professor", "gestor"}


# ---------------------------------------------------------------------------
# Serviço Principal
# ---------------------------------------------------------------------------


class WorkoutProgramNotFoundError(Exception):
    """Programa de treino não encontrado."""

class WorkoutSheetService:
    """Serviço de lógica de negócio para Programas e Fichas de Treino."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = WorkoutSheetRepository(session)

    # ------------------------------------------------------------------
    # Programas de Treino
    # ------------------------------------------------------------------

    async def create_workout_program(
        self, requester_id: UUID, role: str, dto: CreateWorkoutProgramDTO
    ) -> WorkoutProgramResponseDTO:
        if role == "client":
            if dto.user_id != requester_id:
                raise WorkoutSheetForbiddenError(
                    "Você só pode criar programas de treino para você mesmo."
                )
        else:
            self._check_write_permission(role)

        sheets = []
        for sheet_dto in dto.workout_sheets:
            exercises = self._build_exercises(sheet_dto.exercises)
            sheets.append(WorkoutSheet(
                name=sheet_dto.name,
                description=sheet_dto.description,
                day_of_week=sheet_dto.day_of_week,
                order=sheet_dto.order,
                is_active=True,
                exercises=exercises,
            ))

        program = WorkoutProgram(
            user_id=dto.user_id,
            personal_trainer_id=None if role == "client" else requester_id,
            name=dto.name,
            description=dto.description,
            goal=dto.goal,
            is_active=True,
            workout_sheets=sheets,
        )

        created = await self.repository.create_workout_program(program)
        await self.repository.commit()

        # RN08/RN10: notifica o aluno que recebeu o programa (uma notificação
        # por programa criado, não por ficha aninhada).
        await self._notify_new_sheet_safe(
            user_id=created.user_id,
            sheet_id=created.id,
            sheet_name=created.name,
        )
        return self._to_program_response(created)

    async def list_workout_programs(
        self,
        requester_id: UUID,
        role: str,
        user_id_filter: Optional[UUID],
        page: int,
        limit: int,
    ) -> PaginatedWorkoutProgramsDTO:
        effective_user_id = requester_id if role == "client" else user_id_filter
        
        programs, total = await self.repository.list_workout_programs(
            user_id=effective_user_id,
            page=page,
            limit=limit,
        )
        items = [self._to_program_response(p) for p in programs]
        return PaginatedWorkoutProgramsDTO(total=total, page=page, limit=limit, data=items)

    async def get_workout_program(
        self, program_id: UUID, requester_id: UUID, role: str
    ) -> WorkoutProgramResponseDTO:
        program = await self._get_program_and_check_read(program_id, requester_id, role)
        return self._to_program_response(program)

    async def update_workout_program(
        self, program_id: UUID, requester_id: UUID, role: str, dto: UpdateWorkoutProgramDTO
    ) -> WorkoutProgramResponseDTO:
        program = await self.repository.get_workout_program_by_id(program_id)
        if not program:
            raise WorkoutProgramNotFoundError("Programa de treino não encontrado.")

        if role == "client":
            if program.user_id != requester_id or program.personal_trainer_id is not None:
                raise WorkoutSheetForbiddenError(
                    "Você só pode editar seus próprios programas de treino personalizados."
                )
        else:
            self._check_write_permission(role)

        if dto.name is not None:
            program.name = dto.name
        if dto.description is not None:
            program.description = dto.description
        if dto.goal is not None:
            program.goal = dto.goal
        if dto.is_active is not None:
            program.is_active = dto.is_active

        updated = await self.repository.update_workout_program(program)
        await self.repository.commit()
        return self._to_program_response(updated)

    async def delete_workout_program(self, program_id: UUID, requester_id: UUID, role: str) -> None:
        if role == "client":
            program = await self.repository.get_workout_program_by_id(program_id)
            if not program:
                raise WorkoutProgramNotFoundError("Programa de treino não encontrado.")
            if program.user_id != requester_id or program.personal_trainer_id is not None:
                raise WorkoutSheetForbiddenError(
                    "Você só pode deletar seus próprios programas de treino personalizados."
                )
        else:
            self._check_write_permission(role)

        deleted = await self.repository.soft_delete_workout_program(program_id)
        if not deleted:
            raise WorkoutProgramNotFoundError("Programa de treino não encontrado.")
        await self.repository.commit()

    # ------------------------------------------------------------------
    # Fichas de Treino (Rotinas)
    # ------------------------------------------------------------------

    async def create_workout_sheet(
        self, requester_id: UUID, role: str, dto: CreateWorkoutSheetDTO
    ) -> WorkoutSheetResponseDTO:
        self._check_write_permission(role)
        
        if not dto.workout_program_id:
            raise WorkoutSheetValidationError("O ID do programa é obrigatório para criar uma ficha individual.")

        program = await self.repository.get_workout_program_by_id(dto.workout_program_id)
        if not program:
            raise WorkoutProgramNotFoundError("Programa não encontrado.")

        exercises = self._build_exercises(dto.exercises)

        sheet = WorkoutSheet(
            workout_program_id=dto.workout_program_id,
            name=dto.name,
            description=dto.description,
            day_of_week=dto.day_of_week,
            order=dto.order,
            is_active=True,
            exercises=exercises,
        )

        created = await self.repository.create_workout_sheet(sheet)
        await self.repository.commit()

        # RN08/RN10: notifica o aluno dono do programa (falha não derruba a criação).
        # WorkoutSheet pertence a WorkoutProgram; user_id vem do programa.
        await self._notify_new_sheet_safe(
            user_id=program.user_id,
            sheet_id=created.id,
            sheet_name=created.name,
        )
        return self._to_sheet_response(created)

    # ------------------------------------------------------------------
    # Listar Fichas
    # ------------------------------------------------------------------

    async def list_workout_sheets(
        self,
        requester_id: UUID,
        role: str,
        workout_program_id: Optional[UUID],
        page: int,
        limit: int,
    ) -> PaginatedWorkoutSheetsDTO:
        sheets, total = await self.repository.list_workout_sheets(
            workout_program_id=workout_program_id,
            page=page,
            limit=limit,
        )

        items = [
            WorkoutSheetListItemDTO(
                id=s.id,
                workout_program_id=s.workout_program_id,
                name=s.name,
                day_of_week=s.day_of_week,
                order=s.order,
                is_active=s.is_active,
                exercise_count=len(s.exercises) if s.exercises else 0,
                created_at=s.created_at,
            )
            for s in sheets
        ]

        return PaginatedWorkoutSheetsDTO(total=total, page=page, limit=limit, data=items)

    # ------------------------------------------------------------------
    # Buscar Ficha por ID
    # ------------------------------------------------------------------

    async def get_workout_sheet(
        self, sheet_id: UUID, requester_id: UUID, role: str
    ) -> WorkoutSheetResponseDTO:
        sheet = await self._get_sheet_and_check_read(sheet_id, requester_id, role)
        return self._to_sheet_response(sheet)

    # ------------------------------------------------------------------
    # Atualizar Ficha
    # ------------------------------------------------------------------

    async def update_workout_sheet(
        self, sheet_id: UUID, requester_id: UUID, role: str, dto: UpdateWorkoutSheetDTO
    ) -> WorkoutSheetResponseDTO:
        self._check_write_permission(role)

        sheet = await self.repository.get_workout_sheet_by_id(sheet_id)
        if not sheet:
            raise WorkoutSheetNotFoundError("Ficha de treino não encontrada.")

        if dto.name is not None:
            sheet.name = dto.name
        if dto.description is not None:
            sheet.description = dto.description
        if dto.day_of_week is not None:
            sheet.day_of_week = dto.day_of_week
        if dto.order is not None:
            sheet.order = dto.order

        # Substituição total de exercícios
        if dto.exercises is not None:
            await self.repository.delete_exercises_from_sheet(sheet_id)
            sheet.exercises = self._build_exercises(dto.exercises)

        updated = await self.repository.update_workout_sheet(sheet)
        await self.repository.commit()
        return self._to_sheet_response(updated)

    # ------------------------------------------------------------------
    # Deletar Ficha (soft delete)
    # ------------------------------------------------------------------

    async def delete_workout_sheet(
        self, sheet_id: UUID, requester_id: UUID, role: str
    ) -> None:
        """
        Soft delete da ficha (marca is_active=False).

        Raises:
            WorkoutSheetForbiddenError: Aluno tentando deletar.
            WorkoutSheetNotFoundError: Ficha não encontrada.
        """
        self._check_write_permission(role)

        deleted = await self.repository.soft_delete_workout_sheet(sheet_id)
        if not deleted:
            raise WorkoutSheetNotFoundError("Ficha de treino não encontrada.")

        await self.repository.commit()

    # ------------------------------------------------------------------
    # Duplicar Ficha
    # ------------------------------------------------------------------

    async def duplicate_workout_sheet(
        self, sheet_id: UUID, requester_id: UUID, role: str, dto: DuplicateWorkoutSheetDTO
    ) -> WorkoutSheetResponseDTO:
        """
        Duplica uma ficha existente (cria nova com os mesmos exercícios).

        Regras:
        - Apenas personal/admin podem duplicar fichas.
        - O novo user_id padrão é o mesmo da ficha original.
        - RN-01 se for atribuir a um aluno diferente ou mesmo aluno+mesmo dia.
        """
        self._check_write_permission(role)

        original = await self.repository.get_workout_sheet_by_id(sheet_id)
        if not original:
            raise WorkoutSheetNotFoundError("Ficha de treino não encontrada.")

        target_program_id = dto.workout_program_id or original.workout_program_id
        new_name = dto.name or f"{original.name} (Cópia)"

        # Clonar exercícios
        cloned_exercises = [
            Exercise(
                name=ex.name,
                muscle_group=ex.muscle_group,
                series=ex.series,
                repetitions=ex.repetitions,
                load_kg=ex.load_kg,
                rest_seconds=ex.rest_seconds,
                observations=ex.observations,
                image_url=ex.image_url,
                gif_url=ex.gif_url,
                order=ex.order,
            )
            for ex in (original.exercises or [])
        ]

        new_sheet = WorkoutSheet(
            workout_program_id=target_program_id,
            name=new_name,
            description=original.description,
            day_of_week=original.day_of_week,
            order=original.order,
            is_active=True,
            exercises=cloned_exercises,
        )

        created = await self.repository.create_workout_sheet(new_sheet)
        await self.repository.commit()

        # RN08/RN10: notifica o aluno dono do programa destino (idem create).
        target_program = await self.repository.get_workout_program_by_id(target_program_id)
        if target_program is not None:
            await self._notify_new_sheet_safe(
                user_id=target_program.user_id,
                sheet_id=created.id,
                sheet_name=created.name,
            )
        return self._to_sheet_response(created)

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
    ) -> PaginatedCatalogDTO:
        """
        Busca exercícios no catálogo pré-definido.
        Acessível por qualquer usuário autenticado.
        """
        items, total = await self.repository.search_exercise_catalog(
            search=search,
            muscle_group=muscle_group,
            equipment=equipment,
            page=page,
            limit=limit,
        )
        catalog_items = [
            ExerciseCatalogItemDTO(
                id=item.id,
                name=item.name,
                category=item.category,
                level=item.level,
                equipment=item.equipment,
                primary_muscles=item.primary_muscles,
                secondary_muscles=item.secondary_muscles,
                instructions=item.instructions,
                image_url=item.image_url,
                gif_url=item.gif_url,
                muscle_group_mapped=item.muscle_group_mapped,
            )
            for item in items
        ]
        return PaginatedCatalogDTO(total=total, page=page, limit=limit, data=catalog_items)

    # ------------------------------------------------------------------
    # Helpers Privados
    # ------------------------------------------------------------------

    async def _notify_new_sheet_safe(
        self, user_id: UUID, sheet_id: UUID, sheet_name: str
    ) -> None:
        """
        Dispara notify_new_workout_sheet com isolamento de falha (RN10).

        Nunca propaga exceções: log e segue. Importação local para evitar
        ciclo entre workout_sheet_service e notification_service.
        """
        try:
            from app.services.notification_service import NotificationService

            service = NotificationService(self.session)
            await service.notify_new_workout_sheet(
                user_id=user_id,
                sheet_id=sheet_id,
                sheet_name=sheet_name,
            )
        except Exception as exc:
            logger.warning(
                "Falha ao notificar nova ficha de treino (sheet_id=%s): %s",
                sheet_id,
                exc,
            )

    def _check_write_permission(self, role: str) -> None:
        """Verifica se o role tem permissão de escrita (RN-02). Nutricionistas não têm acesso."""
        if not _is_workout_writer(role):
            raise WorkoutSheetForbiddenError(
                "Apenas personal/professor/gestor/admin podem criar ou editar fichas."
            )

    async def _get_program_and_check_read(
        self, program_id: UUID, requester_id: UUID, role: str
    ) -> WorkoutProgram:
        program = await self.repository.get_workout_program_by_id(program_id)
        if not program:
            raise WorkoutProgramNotFoundError("Programa de treino não encontrado.")
        if role == "client" and program.user_id != requester_id:
            raise WorkoutSheetForbiddenError("Você não tem permissão para visualizar este programa.")
        return program

    async def _get_sheet_and_check_read(
        self, sheet_id: UUID, requester_id: UUID, role: str
    ) -> WorkoutSheet:
        """Busca a ficha e valida acesso de leitura."""
        sheet = await self.repository.get_workout_sheet_by_id(sheet_id)
        if not sheet:
            raise WorkoutSheetNotFoundError("Ficha de treino não encontrada.")

        program = await self.repository.get_workout_program_by_id(sheet.workout_program_id)
        # Aluno só pode ver suas próprias fichas
        if role == "client" and program and program.user_id != requester_id:
            raise WorkoutSheetForbiddenError(
                "Você não tem permissão para visualizar esta ficha."
            )

        return sheet

    @staticmethod
    def _build_exercises(exercise_dtos: List[ExerciseCreateDTO]) -> List[Exercise]:
        """Constrói instâncias de Exercise a partir de ExerciseCreateDTO."""
        return [
            Exercise(
                name=dto.name,
                muscle_group=dto.muscle_group,
                series=dto.series,
                repetitions=dto.repetitions,
                load_kg=dto.load_kg,
                rest_seconds=dto.rest_seconds,
                observations=dto.observations,
                image_url=dto.image_url,
                gif_url=dto.gif_url,
                order=dto.order,
            )
            for dto in exercise_dtos
        ]

    @staticmethod
    def _to_program_response(program: WorkoutProgram) -> WorkoutProgramResponseDTO:
        return WorkoutProgramResponseDTO(
            id=program.id,
            user_id=program.user_id,
            personal_trainer_id=program.personal_trainer_id,
            name=program.name,
            description=program.description,
            goal=program.goal,
            is_active=program.is_active,
            created_at=program.created_at,
            updated_at=program.updated_at,
            workout_sheets=[WorkoutSheetService._to_sheet_response(s) for s in sorted(program.workout_sheets or [], key=lambda x: x.order)],
        )

    @staticmethod
    def _to_sheet_response(sheet: WorkoutSheet) -> WorkoutSheetResponseDTO:
        """Converte WorkoutSheet para WorkoutSheetResponseDTO."""
        exercises = [
            ExerciseResponseDTO(
                id=ex.id,
                workout_sheet_id=ex.workout_sheet_id,
                name=ex.name,
                muscle_group=ex.muscle_group,
                series=ex.series,
                repetitions=ex.repetitions,
                load_kg=ex.load_kg,
                rest_seconds=ex.rest_seconds,
                observations=ex.observations,
                image_url=ex.image_url,
                gif_url=ex.gif_url,
                order=ex.order,
                created_at=ex.created_at,
                updated_at=ex.updated_at,
            )
            for ex in sorted(sheet.exercises or [], key=lambda e: e.order)
        ]

        return WorkoutSheetResponseDTO(
            id=sheet.id,
            workout_program_id=sheet.workout_program_id,
            name=sheet.name,
            description=sheet.description,
            day_of_week=sheet.day_of_week,
            order=sheet.order,
            is_active=sheet.is_active,
            created_at=sheet.created_at,
            updated_at=sheet.updated_at,
            exercises=exercises,
        )
