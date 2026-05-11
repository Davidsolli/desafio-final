"""
Rotas HTTP do módulo Ficha de Treino.

Endpoints:
- POST   /api/v1/workout-sheets                         → Criar ficha (201)
- GET    /api/v1/workout-sheets                         → Listar fichas (200)
- GET    /api/v1/workout-sheets/{id}                    → Buscar ficha (200)
- PUT    /api/v1/workout-sheets/{id}                    → Atualizar ficha (200)
- DELETE /api/v1/workout-sheets/{id}                    → Soft delete (204)
- POST   /api/v1/workout-sheets/{id}/duplicate          → Duplicar ficha (201)
- GET    /api/v1/exercise-catalog                       → Buscar catálogo (200)
"""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.controllers.workout_sheet_controller import WorkoutSheetController
from app.dependencies.auth import get_current_user
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
from app.models.user import User
from app.services.workout_sheet_service import (
    WorkoutSheetForbiddenError,
    WorkoutSheetNotFoundError,
    WorkoutSheetValidationError,
)

router = APIRouter(
    prefix="/api/v1/workout-sheets",
    tags=["workout-sheets"],
    responses={
        401: {"description": "Não autenticado"},
        500: {"description": "Erro interno do servidor"},
    },
)

program_router = APIRouter(
    prefix="/api/v1/workout-programs",
    tags=["workout-programs"],
    responses={
        401: {"description": "Não autenticado"},
        500: {"description": "Erro interno do servidor"},
    },
)

catalog_router = APIRouter(
    prefix="/api/v1/exercise-catalog",
    tags=["exercise-catalog"],
    responses={
        401: {"description": "Não autenticado"},
    },
)


# ---------------------------------------------------------------------------
# POST /workout-programs — Criar Programa
# ---------------------------------------------------------------------------

@program_router.post(
    "",
    response_model=WorkoutProgramResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Criar programa de treino",
)
async def create_workout_program(
    dto: CreateWorkoutProgramDTO,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WorkoutProgramResponseDTO:
    controller = WorkoutSheetController(db)
    try:
        return await controller.create_workout_program(
            requester_id=current_user.id,
            role=current_user.role,
            dto=dto,
        )
    except WorkoutSheetForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Erro interno")


@program_router.get(
    "",
    response_model=PaginatedWorkoutProgramsDTO,
    status_code=status.HTTP_200_OK,
    summary="Listar programas de treino",
)
async def list_workout_programs(
    user_id: Optional[UUID] = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PaginatedWorkoutProgramsDTO:
    controller = WorkoutSheetController(db)
    try:
        return await controller.list_workout_programs(
            requester_id=current_user.id,
            role=current_user.role,
            user_id_filter=user_id,
            page=page,
            limit=limit,
        )
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Erro interno")


@program_router.get(
    "/{program_id}",
    response_model=WorkoutProgramResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Buscar programa por ID",
)
async def get_workout_program(
    program_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WorkoutProgramResponseDTO:
    controller = WorkoutSheetController(db)
    try:
        return await controller.get_workout_program(
            program_id=program_id, requester_id=current_user.id, role=current_user.role
        )
    except WorkoutSheetNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except WorkoutSheetForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Erro interno")


@program_router.put(
    "/{program_id}",
    response_model=WorkoutProgramResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Atualizar programa de treino",
)
async def update_workout_program(
    program_id: UUID,
    dto: UpdateWorkoutProgramDTO,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WorkoutProgramResponseDTO:
    controller = WorkoutSheetController(db)
    try:
        return await controller.update_workout_program(
            program_id=program_id, requester_id=current_user.id, role=current_user.role, dto=dto
        )
    except WorkoutSheetNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except WorkoutSheetForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Erro interno")


@program_router.delete(
    "/{program_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Deletar programa de treino",
)
async def delete_workout_program(
    program_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    controller = WorkoutSheetController(db)
    try:
        await controller.delete_workout_program(
            program_id=program_id, requester_id=current_user.id, role=current_user.role
        )
    except WorkoutSheetNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except WorkoutSheetForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Erro interno")

# ---------------------------------------------------------------------------
# Fichas (Rotinas) - workout-sheets
# ---------------------------------------------------------------------------


@router.post(
    "",
    response_model=WorkoutSheetResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Criar ficha de treino",
    responses={
        201: {"description": "Ficha criada com sucesso"},
        400: {"description": "Usuário (aluno) não encontrado"},
        403: {"description": "Sem permissão para criar fichas"},
        409: {"description": "Aluno já tem ficha ativa para esse dia"},
        422: {"description": "Dados inválidos"},
    },
)
async def create_workout_sheet(
    dto: CreateWorkoutSheetDTO,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WorkoutSheetResponseDTO:
    """
    Cria uma nova ficha de treino com exercícios.

    **Regras:**
    - Apenas **personal/professor/gestor/admin** podem criar fichas (RN-02).
    - Um aluno só pode ter **uma ficha ativa por dia da semana** (RN-01).
    - `exercises` pode ser uma lista vazia (ficha sem exercícios inicialmente).
    """
    controller = WorkoutSheetController(db)
    try:
        return await controller.create_workout_sheet(
            requester_id=current_user.id,
            role=current_user.role,
            dto=dto,
        )
    except WorkoutSheetForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except WorkoutSheetValidationError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao criar ficha de treino.",
        )


# ---------------------------------------------------------------------------
# GET /workout-sheets — Listar Fichas
# ---------------------------------------------------------------------------


@router.get(
    "",
    response_model=PaginatedWorkoutSheetsDTO,
    status_code=status.HTTP_200_OK,
    summary="Listar fichas de treino",
    responses={
        200: {"description": "Lista de fichas retornada"},
    },
)
async def list_workout_sheets(
    workout_program_id: Optional[UUID] = Query(None, description="Filtrar por programa de treino"),
    page: int = Query(1, ge=1, description="Número da página"),
    limit: int = Query(10, ge=1, le=100, description="Itens por página (máx. 100)"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PaginatedWorkoutSheetsDTO:
    """
    Lista fichas de treino com paginação e filtros opcionais.
    """
    controller = WorkoutSheetController(db)
    try:
        return await controller.list_workout_sheets(
            requester_id=current_user.id,
            role=current_user.role,
            workout_program_id=workout_program_id,
            page=page,
            limit=limit,
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao listar fichas de treino.",
        )


# ---------------------------------------------------------------------------
# GET /workout-sheets/{id} — Buscar Ficha
# ---------------------------------------------------------------------------


@router.get(
    "/{sheet_id}",
    response_model=WorkoutSheetResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Buscar ficha de treino por ID",
    responses={
        200: {"description": "Ficha encontrada"},
        403: {"description": "Sem permissão para visualizar esta ficha"},
        404: {"description": "Ficha não encontrada"},
    },
)
async def get_workout_sheet(
    sheet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WorkoutSheetResponseDTO:
    """
    Retorna uma ficha de treino completa com todos os exercícios em ordem.

    - **Aluno:** pode ver apenas suas próprias fichas.
    - **Personal/Admin:** pode ver qualquer ficha.
    """
    controller = WorkoutSheetController(db)
    try:
        return await controller.get_workout_sheet(
            sheet_id=sheet_id,
            requester_id=current_user.id,
            role=current_user.role,
        )
    except WorkoutSheetNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except WorkoutSheetForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao buscar ficha de treino.",
        )


# ---------------------------------------------------------------------------
# PUT /workout-sheets/{id} — Atualizar Ficha
# ---------------------------------------------------------------------------


@router.put(
    "/{sheet_id}",
    response_model=WorkoutSheetResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Atualizar ficha de treino",
    responses={
        200: {"description": "Ficha atualizada"},
        403: {"description": "Aluno não pode editar fichas"},
        404: {"description": "Ficha não encontrada"},
        409: {"description": "Conflito de dia da semana"},
        422: {"description": "Dados inválidos"},
    },
)
async def update_workout_sheet(
    sheet_id: UUID,
    dto: UpdateWorkoutSheetDTO,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WorkoutSheetResponseDTO:
    """
    Atualiza uma ficha de treino.

    **Todos os campos são opcionais.** Se `exercises` for fornecido,
    **substitui completamente** os exercícios existentes.

    - **Aluno (client)** recebe `403 Forbidden`.
    - **Personal/Admin** podem editar qualquer ficha.
    """
    controller = WorkoutSheetController(db)
    try:
        return await controller.update_workout_sheet(
            sheet_id=sheet_id,
            requester_id=current_user.id,
            role=current_user.role,
            dto=dto,
        )
    except WorkoutSheetForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except WorkoutSheetNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except WorkoutSheetValidationError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao atualizar ficha de treino.",
        )


# ---------------------------------------------------------------------------
# DELETE /workout-sheets/{id} — Soft Delete
# ---------------------------------------------------------------------------


@router.delete(
    "/{sheet_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Deletar ficha de treino (soft delete)",
    responses={
        204: {"description": "Ficha desativada"},
        403: {"description": "Aluno não pode deletar fichas"},
        404: {"description": "Ficha não encontrada"},
    },
)
async def delete_workout_sheet(
    sheet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Remove uma ficha via **soft delete** (`is_active = False`).

    A ficha permanece no banco para auditoria e histórico.
    Apenas **personal/admin** podem deletar fichas.
    """
    controller = WorkoutSheetController(db)
    try:
        await controller.delete_workout_sheet(
            sheet_id=sheet_id,
            requester_id=current_user.id,
            role=current_user.role,
        )
    except WorkoutSheetForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except WorkoutSheetNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao deletar ficha de treino.",
        )


# ---------------------------------------------------------------------------
# POST /workout-sheets/{id}/duplicate — Duplicar Ficha
# ---------------------------------------------------------------------------


@router.post(
    "/{sheet_id}/duplicate",
    response_model=WorkoutSheetResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Duplicar ficha de treino",
    responses={
        201: {"description": "Ficha duplicada com sucesso"},
        403: {"description": "Sem permissão para duplicar fichas"},
        404: {"description": "Ficha original não encontrada"},
        409: {"description": "Aluno já tem ficha ativa para esse dia"},
    },
)
async def duplicate_workout_sheet(
    sheet_id: UUID,
    dto: DuplicateWorkoutSheetDTO,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> WorkoutSheetResponseDTO:
    """
    Cria uma cópia de uma ficha existente com os mesmos exercícios.

    Opcionalmente pode ter **novo nome** e ser atribuída a um **aluno diferente**.
    O original não é afetado.
    """
    controller = WorkoutSheetController(db)
    try:
        return await controller.duplicate_workout_sheet(
            sheet_id=sheet_id,
            requester_id=current_user.id,
            role=current_user.role,
            dto=dto,
        )
    except WorkoutSheetForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except WorkoutSheetNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except WorkoutSheetValidationError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao duplicar ficha de treino.",
        )


# ---------------------------------------------------------------------------
# GET /exercise-catalog — Catálogo de Exercícios (router separado)
# ---------------------------------------------------------------------------


@catalog_router.get(
    "",
    response_model=PaginatedCatalogDTO,
    status_code=status.HTTP_200_OK,
    summary="Buscar exercícios no catálogo",
    responses={
        200: {"description": "Resultados do catálogo"},
    },
)
async def search_exercise_catalog(
    search: Optional[str] = Query(None, description="Busca por nome (parcial, case-insensitive)"),
    muscle_group: Optional[str] = Query(None, description="Filtrar por grupo muscular mapeado"),
    equipment: Optional[str] = Query(None, description="Filtrar por equipamento (ex: peso-do-corpo, maquina)"),
    page: int = Query(1, ge=1, description="Número da página"),
    limit: int = Query(20, ge=1, le=100, description="Itens por página (máx. 100)"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PaginatedCatalogDTO:
    """
    Busca exercícios no catálogo pré-carregado (800+ exercícios em PT-BR).

    Útil para **autocompletar** ao montar fichas. Qualquer usuário autenticado pode consultar.
    """
    controller = WorkoutSheetController(db)
    try:
        return await controller.search_exercise_catalog(
            search=search,
            muscle_group=muscle_group,
            equipment=equipment,
            page=page,
            limit=limit,
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao buscar catálogo de exercícios.",
        )
