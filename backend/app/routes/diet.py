"""
Rotas HTTP do módulo de Dieta e Alimentos Personalizados.

Endpoints:
- POST   /api/v1/custom-foods                  → Criar alimento personalizado (201)
- GET    /api/v1/custom-foods                  → Listar custom foods do usuário (200)
- POST   /api/v1/diets                         → Criar dieta (201)
- GET    /api/v1/diets                         → Listar dietas (200)
- GET    /api/v1/diets/{id}                    → Buscar dieta com macros (200)
- PUT    /api/v1/diets/{id}                    → Atualizar dieta (200)
- DELETE /api/v1/diets/{id}                    → Soft delete (204)
- POST   /api/v1/diets/{id}/duplicate          → Duplicar dieta (201)
"""

from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.controllers.diet_controller import DietController
from app.dependencies.auth import get_current_user
from app.dtos.diet_dto import (
    CreateCustomFoodDTO,
    CreateDietDTO,
    CustomFoodResponseDTO,
    DietResponseDTO,
    DuplicateDietDTO,
    PaginatedDietsDTO,
    UpdateDietDTO,
)
from app.models.user import User
from app.services.diet_service import (
    DietForbiddenError,
    DietNotFoundError,
    DietValidationError,
)


# ---------------------------------------------------------------------------
# Routers
# ---------------------------------------------------------------------------

custom_food_router = APIRouter(
    prefix="/api/v1/custom-foods",
    tags=["custom-foods"],
    responses={
        401: {"description": "Não autenticado"},
        500: {"description": "Erro interno do servidor"},
    },
)

diet_router = APIRouter(
    prefix="/api/v1/diets",
    tags=["diets"],
    responses={
        401: {"description": "Não autenticado"},
        500: {"description": "Erro interno do servidor"},
    },
)


# ---------------------------------------------------------------------------
# POST /custom-foods — Criar Alimento Personalizado
# ---------------------------------------------------------------------------


@custom_food_router.post(
    "",
    response_model=CustomFoodResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Criar alimento personalizado",
    responses={
        201: {"description": "Alimento criado com sucesso"},
        422: {"description": "Dados inválidos"},
    },
)
async def create_custom_food(
    dto: CreateCustomFoodDTO,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> CustomFoodResponseDTO:
    """
    Cria um alimento personalizado para o usuário.

    **Qualquer usuário autenticado** (aluno ou personal) pode criar.
    O alimento fica isolado no escopo do usuário e não afeta o catálogo global.
    """
    controller = DietController(db)
    try:
        return await controller.create_custom_food(
            user_id=current_user.id, dto=dto
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao criar alimento personalizado.",
        )


# ---------------------------------------------------------------------------
# GET /custom-foods — Listar Alimentos Personalizados
# ---------------------------------------------------------------------------


@custom_food_router.get(
    "",
    response_model=List[CustomFoodResponseDTO],
    status_code=status.HTTP_200_OK,
    summary="Listar alimentos personalizados do usuário",
    responses={
        200: {"description": "Lista de alimentos personalizados"},
    },
)
async def list_custom_foods(
    search: Optional[str] = Query(None, description="Busca por nome (case-insensitive)"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> List[CustomFoodResponseDTO]:
    """
    Lista todos os alimentos personalizados criados pelo usuário.

    Opcional: filtrar por **nome** (busca parcial, case-insensitive).
    """
    controller = DietController(db)
    try:
        return await controller.list_custom_foods(
            user_id=current_user.id, search=search
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao listar alimentos personalizados.",
        )


# ---------------------------------------------------------------------------
# POST /diets — Criar Dieta
# ---------------------------------------------------------------------------


@diet_router.post(
    "",
    response_model=DietResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Criar dieta",
    responses={
        201: {"description": "Dieta criada com sucesso"},
        403: {"description": "Sem permissão para criar dietas"},
        422: {"description": "Dados inválidos"},
    },
)
async def create_diet(
    dto: CreateDietDTO,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DietResponseDTO:
    """
    Cria uma nova dieta com refeições e itens.

    **Regras:**
    - **Personal/Admin:** Cria dieta **prescrita** (is_custom=False).
    - **Aluno:** Cria dieta **personalizada** (is_custom=True), apenas para si.
    - RN-01: Ao criar, desativa a dieta anterior do mesmo tipo.
    """
    controller = DietController(db)
    try:
        return await controller.create_diet(
            requester_id=current_user.id,
            role=current_user.role,
            dto=dto,
        )
    except DietForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except DietValidationError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao criar dieta.",
        )


# ---------------------------------------------------------------------------
# GET /diets — Listar Dietas
# ---------------------------------------------------------------------------


@diet_router.get(
    "",
    response_model=PaginatedDietsDTO,
    status_code=status.HTTP_200_OK,
    summary="Listar dietas",
    responses={
        200: {"description": "Lista de dietas retornada"},
    },
)
async def list_diets(
    user_id: Optional[UUID] = Query(None, description="Filtrar por aluno (personal/admin)"),
    is_custom: Optional[bool] = Query(None, description="Filtrar: true=personalizada, false=prescrita"),
    page: int = Query(1, ge=1, description="Número da página"),
    limit: int = Query(10, ge=1, le=100, description="Itens por página"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PaginatedDietsDTO:
    """
    Lista dietas com paginação e filtros opcionais.

    - **Aluno:** vê apenas suas próprias dietas.
    - **Personal/Admin:** pode filtrar por `user_id`.
    """
    controller = DietController(db)
    try:
        return await controller.list_diets(
            requester_id=current_user.id,
            role=current_user.role,
            user_id_filter=user_id,
            is_custom=is_custom,
            page=page,
            limit=limit,
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao listar dietas.",
        )


# ---------------------------------------------------------------------------
# GET /diets/{id} — Buscar Dieta
# ---------------------------------------------------------------------------


@diet_router.get(
    "/{diet_id}",
    response_model=DietResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Buscar dieta com macros calculados",
    responses={
        200: {"description": "Dieta encontrada"},
        403: {"description": "Sem permissão para visualizar esta dieta"},
        404: {"description": "Dieta não encontrada"},
    },
)
async def get_diet(
    diet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DietResponseDTO:
    """
    Retorna uma dieta completa com refeições, itens e **macros calculados**
    (kcal, proteína, carboidratos, gorduras) em cada nível:
    item → refeição (subtotais) → dieta (totais).
    """
    controller = DietController(db)
    try:
        return await controller.get_diet(
            diet_id=diet_id,
            requester_id=current_user.id,
            role=current_user.role,
        )
    except DietNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except DietForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao buscar dieta.",
        )


# ---------------------------------------------------------------------------
# PUT /diets/{id} — Atualizar Dieta
# ---------------------------------------------------------------------------


@diet_router.put(
    "/{diet_id}",
    response_model=DietResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Atualizar dieta",
    responses={
        200: {"description": "Dieta atualizada"},
        403: {"description": "Sem permissão para editar esta dieta"},
        404: {"description": "Dieta não encontrada"},
        422: {"description": "Dados inválidos"},
    },
)
async def update_diet(
    diet_id: UUID,
    dto: UpdateDietDTO,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DietResponseDTO:
    """
    Atualiza uma dieta existente.

    **Todos os campos são opcionais.** Se `meals` for fornecido,
    **substitui completamente** as refeições existentes.

    - **Aluno** só pode editar dietas **personalizadas** (is_custom=True).
    - **Personal/Admin** podem editar qualquer dieta.
    """
    controller = DietController(db)
    try:
        return await controller.update_diet(
            diet_id=diet_id,
            requester_id=current_user.id,
            role=current_user.role,
            dto=dto,
        )
    except DietForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except DietNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except DietValidationError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao atualizar dieta.",
        )


# ---------------------------------------------------------------------------
# DELETE /diets/{id} — Soft Delete
# ---------------------------------------------------------------------------


@diet_router.delete(
    "/{diet_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Deletar dieta (soft delete)",
    responses={
        204: {"description": "Dieta desativada"},
        403: {"description": "Sem permissão para deletar esta dieta"},
        404: {"description": "Dieta não encontrada"},
    },
)
async def delete_diet(
    diet_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Remove uma dieta via **soft delete** (is_active = False).

    - **Aluno** só pode deletar dietas **personalizadas**.
    - **Personal/Admin** podem deletar qualquer dieta.
    """
    controller = DietController(db)
    try:
        await controller.delete_diet(
            diet_id=diet_id,
            requester_id=current_user.id,
            role=current_user.role,
        )
    except DietForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except DietNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao deletar dieta.",
        )


# ---------------------------------------------------------------------------
# POST /diets/{id}/duplicate — Duplicar Dieta
# ---------------------------------------------------------------------------


@diet_router.post(
    "/{diet_id}/duplicate",
    response_model=DietResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Duplicar dieta",
    responses={
        201: {"description": "Dieta duplicada com sucesso"},
        403: {"description": "Sem permissão para duplicar"},
        404: {"description": "Dieta original não encontrada"},
    },
)
async def duplicate_diet(
    diet_id: UUID,
    dto: DuplicateDietDTO,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DietResponseDTO:
    """
    Cria uma cópia de uma dieta existente com os mesmos itens.

    Opcionalmente pode ter **novo nome** e ser atribuída a um **aluno diferente**.
    Apenas **Personal/Admin** podem duplicar.
    """
    controller = DietController(db)
    try:
        return await controller.duplicate_diet(
            diet_id=diet_id,
            requester_id=current_user.id,
            role=current_user.role,
            dto=dto,
        )
    except DietForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except DietNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except DietValidationError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao duplicar dieta.",
        )
