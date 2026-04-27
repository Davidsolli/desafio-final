"""Rotas HTTP para o módulo de metas.

Endpoints:
- POST /api/v1/goals → Criar meta
- GET /api/v1/goals → Listar metas (filtros: user_id, status, paginação)
- GET /api/v1/goals/{id} → Detalhe da meta com histórico
- PUT /api/v1/goals/{id} → Atualizar progresso
- DELETE /api/v1/goals/{id} → Deletar meta
"""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, HTTPException, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.goal_dto import (
    CreateGoalDTO,
    UpdateGoalDTO,
    GoalResponseDTO,
    GoalDetailResponseDTO,
    PaginatedGoalsResponseDTO,
)
from app.controllers.goal_controller import GoalController
from app.services.goal_service import GoalNotFoundError, GoalAccessDeniedError, BusinessRuleError
from app.config.database import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User

router = APIRouter(
    prefix="/api/v1/goals",
    tags=["goals"],
    responses={
        404: {"description": "Meta não encontrada"},
        500: {"description": "Erro interno do servidor"},
    },
)


@router.post(
    "",
    response_model=GoalResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Criar nova meta",
    responses={
        201: {"description": "Meta criada com sucesso"},
        400: {"description": "Regra de negócio violada"},
        401: {"description": "Não autenticado"},
        422: {"description": "Validação falhou"},
    },
)
async def create_goal(
    dto: CreateGoalDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> GoalResponseDTO:
    """
    Criar uma nova meta com data-alvo e valor inicial.

    Ao criar, o progresso é automaticamente 0% e uma entrada inicial
    de progresso é registrada no histórico.
    """
    controller = GoalController(session)
    return await controller.create_goal(dto)


@router.get(
    "",
    response_model=PaginatedGoalsResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Listar metas com paginação",
    responses={
        200: {"description": "Lista de metas retornada"},
    },
)
async def list_goals(
    current_user: User = Depends(get_current_user),
    user_id: Optional[UUID] = Query(None, description="Filtrar por aluno"),
    status_filter: Optional[str] = Query(None, alias="status", description="Filtrar por status: active, completed, failed, paused"),
    page: int = Query(1, ge=1, description="Número da página"),
    limit: int = Query(10, ge=1, le=100, description="Itens por página"),
    session: AsyncSession = Depends(get_db),
) -> PaginatedGoalsResponseDTO:
    """
    Listar metas com filtros opcionais por usuário e status.
    """
    controller = GoalController(session)
    return await controller.list_goals(user_id, status_filter, page, limit)


@router.get(
    "/{goal_id}",
    response_model=GoalDetailResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Detalhe da meta com histórico de progresso",
    responses={
        200: {"description": "Meta encontrada"},
        404: {"description": "Meta não encontrada"},
    },
)
async def get_goal(
    goal_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> GoalDetailResponseDTO:
    """
    Buscar detalhes de uma meta específica, incluindo todo o histórico de progresso.
    """
    controller = GoalController(session)
    try:
        return await controller.get_goal_by_id(goal_id)
    except GoalNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))


@router.put(
    "/{goal_id}",
    response_model=GoalResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Atualizar progresso da meta",
    responses={
        200: {"description": "Meta atualizada"},
        400: {"description": "Regra de negócio violada"},
        403: {"description": "Acesso negado"},
        404: {"description": "Meta não encontrada"},
        422: {"description": "Validação falhou"},
    },
)
async def update_goal(
    goal_id: UUID,
    dto: UpdateGoalDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> GoalResponseDTO:
    """
    Atualizar o progresso de uma meta. Requer autenticação via Bearer token.

    Se `current_value >= target_value`, o status muda automaticamente para "completed".
    Cada atualização de `current_value` gera uma nova entrada no histórico.

    **Regras de negócio:**
    - current_value não pode retroceder (só avançar em direção ao target)
    - Meta já concluída não pode ser alterada
    - Apenas o dono ou criador pode atualizar
    """
    controller = GoalController(session)
    try:
        return await controller.update_goal(goal_id, dto, current_user)
    except GoalNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except GoalAccessDeniedError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except BusinessRuleError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.delete(
    "/{goal_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Deletar meta",
    responses={
        204: {"description": "Meta deletada com sucesso"},
        403: {"description": "Acesso negado"},
        404: {"description": "Meta não encontrada"},
    },
)
async def delete_goal(
    goal_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    """
    Deletar uma meta e todo o seu histórico de progresso. Requer autenticação.
    Apenas o dono ou criador da meta pode excluí-la.
    """
    controller = GoalController(session)
    try:
        await controller.delete_goal(goal_id, current_user)
    except GoalNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except GoalAccessDeniedError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
