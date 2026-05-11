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
)
from app.models.workout_sheet import Exercise, WorkoutSheet
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

WRITE_ROLES = {"admin", "personal_trainer", "professor", "gestor"}


# ---------------------------------------------------------------------------
# Serviço Principal
# ---------------------------------------------------------------------------


class WorkoutSheetService:
    """Serviço de lógica de negócio para Fichas de Treino."""

    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.repository = WorkoutSheetRepository(session)

    # ------------------------------------------------------------------
    # Criar Ficha
    # ------------------------------------------------------------------

    async def create_workout_sheet(
        self, requester_id: UUID, role: str, dto: CreateWorkoutSheetDTO
    ) -> WorkoutSheetResponseDTO:
        """
        Cria uma nova ficha de treino com exercícios.

        Regras:
        - RN-02: Apenas personal/professor/gestor/admin podem criar fichas.
        - RN-01: Um aluno só pode ter uma ficha ativa por dia da semana.

        Raises:
            WorkoutSheetForbiddenError: Usuário sem permissão de escrita.
            WorkoutSheetValidationError: Já existe ficha ativa para o dia.
        """
        self._check_write_permission(role)

        # RN-01: verificar se já existe ficha ativa para esse aluno e dia
        existing_count = await self.repository.count_active_sheets_for_day(
            user_id=dto.user_id,
            day_of_week=dto.day_of_week,
        )
        if existing_count > 0:
            raise WorkoutSheetValidationError(
                f"O aluno já possui uma ficha ativa para o dia {dto.day_of_week}. "
                "Delete ou desative a ficha existente primeiro."
            )

        exercises = self._build_exercises(dto.exercises)

        sheet = WorkoutSheet(
            user_id=dto.user_id,
            personal_trainer_id=requester_id,
            name=dto.name,
            description=dto.description,
            day_of_week=dto.day_of_week,
            is_active=True,
            exercises=exercises,
        )

        created = await self.repository.create_workout_sheet(sheet)
        await self.repository.commit()

        # RN08/RN10: notifica o aluno (falha não derruba a criação)
        await self._notify_new_sheet_safe(
            user_id=created.user_id,
            sheet_id=created.id,
            sheet_name=created.name,
        )
        return self._to_response(created)

    # ------------------------------------------------------------------
    # Listar Fichas
    # ------------------------------------------------------------------

    async def list_workout_sheets(
        self,
        requester_id: UUID,
        role: str,
        user_id_filter: Optional[UUID],
        day_of_week: Optional[int],
        page: int,
        limit: int,
    ) -> PaginatedWorkoutSheetsDTO:
        """
        Lista fichas com filtros e paginação.

        - Aluno (client) só vê suas próprias fichas.
        - Personal/Admin pode filtrar por user_id.
        """
        if role == "client":
            effective_user_id = requester_id
            personal_id = None
        elif role == "personal_trainer":
            effective_user_id = user_id_filter
            personal_id = requester_id if user_id_filter is None else None
        else:
            # Admin vê tudo
            effective_user_id = user_id_filter
            personal_id = None

        sheets, total = await self.repository.list_workout_sheets(
            user_id=effective_user_id,
            personal_trainer_id=personal_id,
            day_of_week=day_of_week,
            page=page,
            limit=limit,
        )

        items = [
            WorkoutSheetListItemDTO(
                id=s.id,
                user_id=s.user_id,
                personal_trainer_id=s.personal_trainer_id,
                name=s.name,
                day_of_week=s.day_of_week,
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
        """
        Busca uma ficha com controle de acesso.

        - Aluno só pode ver suas próprias fichas.
        - Personal/Admin pode ver qualquer ficha.
        """
        sheet = await self._get_and_check_read(sheet_id, requester_id, role)
        return self._to_response(sheet)

    # ------------------------------------------------------------------
    # Atualizar Ficha
    # ------------------------------------------------------------------

    async def update_workout_sheet(
        self, sheet_id: UUID, requester_id: UUID, role: str, dto: UpdateWorkoutSheetDTO
    ) -> WorkoutSheetResponseDTO:
        """
        Atualiza uma ficha (nome, descrição, dia, exercícios).

        Regras:
        - Apenas personal/admin podem editar fichas.
        - Aluno (client) recebe 403.
        - Se `exercises` fornecido, substitui TODOS os exercícios existentes.
        - RN-01: se alterar dia_semana, verificar conflito.
        """
        self._check_write_permission(role)

        sheet = await self.repository.get_workout_sheet_by_id(sheet_id)
        if not sheet:
            raise WorkoutSheetNotFoundError("Ficha de treino não encontrada.")

        # RN-01: verificar conflito de dia ao mudar day_of_week
        if dto.day_of_week is not None and dto.day_of_week != sheet.day_of_week:
            existing_count = await self.repository.count_active_sheets_for_day(
                user_id=sheet.user_id,
                day_of_week=dto.day_of_week,
                exclude_id=sheet_id,
            )
            if existing_count > 0:
                raise WorkoutSheetValidationError(
                    f"O aluno já possui uma ficha ativa para o dia {dto.day_of_week}."
                )

        if dto.name is not None:
            sheet.name = dto.name
        if dto.description is not None:
            sheet.description = dto.description
        if dto.day_of_week is not None:
            sheet.day_of_week = dto.day_of_week

        # Substituição total de exercícios
        if dto.exercises is not None:
            await self.repository.delete_exercises_from_sheet(sheet_id)
            sheet.exercises = self._build_exercises(dto.exercises)

        updated = await self.repository.update_workout_sheet(sheet)
        await self.repository.commit()
        return self._to_response(updated)

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

        target_user_id = dto.user_id or original.user_id
        new_name = dto.name or f"{original.name} (Cópia)"

        # RN-01: verificar conflito de dia para o aluno destino
        existing_count = await self.repository.count_active_sheets_for_day(
            user_id=target_user_id,
            day_of_week=original.day_of_week,
        )
        if existing_count > 0:
            raise WorkoutSheetValidationError(
                f"O aluno já possui uma ficha ativa para o dia {original.day_of_week}. "
                "Especifique um user_id diferente ou delete a ficha existente."
            )

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
            user_id=target_user_id,
            personal_trainer_id=requester_id,
            name=new_name,
            description=original.description,
            day_of_week=original.day_of_week,
            is_active=True,
            exercises=cloned_exercises,
        )

        created = await self.repository.create_workout_sheet(new_sheet)
        await self.repository.commit()

        # RN08/RN10: notifica o aluno (idem create)
        await self._notify_new_sheet_safe(
            user_id=created.user_id,
            sheet_id=created.id,
            sheet_name=created.name,
        )
        return self._to_response(created)

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
        """Verifica se o role tem permissão de escrita (RN-02)."""
        if role not in WRITE_ROLES:
            raise WorkoutSheetForbiddenError(
                "Apenas personal/professor/gestor/admin podem criar ou editar fichas."
            )

    async def _get_and_check_read(
        self, sheet_id: UUID, requester_id: UUID, role: str
    ) -> WorkoutSheet:
        """Busca a ficha e valida acesso de leitura."""
        sheet = await self.repository.get_workout_sheet_by_id(sheet_id)
        if not sheet:
            raise WorkoutSheetNotFoundError("Ficha de treino não encontrada.")

        # Aluno só pode ver suas próprias fichas
        if role == "client" and sheet.user_id != requester_id:
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
    def _to_response(sheet: WorkoutSheet) -> WorkoutSheetResponseDTO:
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
            user_id=sheet.user_id,
            personal_trainer_id=sheet.personal_trainer_id,
            name=sheet.name,
            description=sheet.description,
            day_of_week=sheet.day_of_week,
            is_active=sheet.is_active,
            created_at=sheet.created_at,
            updated_at=sheet.updated_at,
            exercises=exercises,
        )
