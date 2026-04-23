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
from app.services.goal_service import GoalNotFoundError
from app.config.database import get_db

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
        422: {"description": "Validação falhou"},
    },
)
async def create_goal(
    dto: CreateGoalDTO,
    session: AsyncSession = Depends(get_db),
) -> GoalResponseDTO:
    """
    Criar uma nova meta com data-alvo e valor inicial.

    Ao criar, o progresso é automaticamente 0% e uma entrada inicial
    de progresso é registrada no histórico.
    """
    controller = GoalController(session)
    try:
        return await controller.create_goal(dto)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao criar meta",
        )


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
    try:
        return await controller.list_goals(user_id, status_filter, page, limit)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao listar metas",
        )


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
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao buscar meta",
        )


@router.put(
    "/{goal_id}",
    response_model=GoalResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Atualizar progresso da meta",
    responses={
        200: {"description": "Meta atualizada"},
        404: {"description": "Meta não encontrada"},
        422: {"description": "Validação falhou"},
    },
)
async def update_goal(
    goal_id: UUID,
    dto: UpdateGoalDTO,
    session: AsyncSession = Depends(get_db),
) -> GoalResponseDTO:
    """
    Atualizar o progresso de uma meta.

    Se `current_value >= target_value`, o status muda automaticamente para "completed".
    Cada atualização de `current_value` gera uma nova entrada no histórico.
    """
    controller = GoalController(session)
    try:
        return await controller.update_goal(goal_id, dto)
    except GoalNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao atualizar meta",
        )


@router.delete(
    "/{goal_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Deletar meta",
    responses={
        204: {"description": "Meta deletada com sucesso"},
        404: {"description": "Meta não encontrada"},
    },
)
async def delete_goal(
    goal_id: UUID,
    session: AsyncSession = Depends(get_db),
) -> None:
    """
    Deletar uma meta e todo o seu histórico de progresso.
    """
    controller = GoalController(session)
    try:
        await controller.delete_goal(goal_id)
    except GoalNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao deletar meta",
        )
