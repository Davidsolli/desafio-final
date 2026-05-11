"""Rotas HTTP para o módulo de contador de passos.

Endpoints:
- POST /api/v1/steps/sync                          → Sincronizar passos do dia (próprio usuário)
- GET  /api/v1/steps/history                       → Histórico próprio (default: últimos 30 dias)
- GET  /api/v1/steps/student/{user_id}/history     → Histórico de aluno (trainer/admin)
"""

from datetime import date as date_type
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, HTTPException, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.controllers.step_controller import StepController
from app.dependencies.auth import get_current_user
from app.dtos.step_dto import (
    SyncStepsDTO,
    StepLogResponseDTO,
    StepHistoryResponseDTO,
)
from app.models.user import User
from app.services.step_service import (
    StepAccessDeniedError,
    StepBusinessRuleError,
)


router = APIRouter(
    prefix="/api/v1/steps",
    tags=["steps"],
    responses={
        401: {"description": "Não autenticado"},
        500: {"description": "Erro interno do servidor"},
    },
)


@router.post(
    "/sync",
    response_model=StepLogResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Sincronizar passos do dia",
    responses={
        200: {"description": "Passos registrados/atualizados"},
        400: {"description": "Regra de negócio violada"},
        422: {"description": "Validação falhou"},
    },
)
async def sync_steps(
    dto: SyncStepsDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> StepLogResponseDTO:
    """
    Sincronizar a contagem de passos do dia para o usuário autenticado.

    O cliente envia o total acumulado do dia (calculado a partir do sensor
    nativo). O servidor faz upsert do registro do dia, mantendo o maior valor
    entre o já registrado e o novo (sensor é monotônico crescente).
    """
    controller = StepController(session)
    try:
        return await controller.sync_steps(current_user.id, dto)
    except StepBusinessRuleError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get(
    "/history",
    response_model=StepHistoryResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Histórico de passos do próprio usuário",
)
async def get_my_history(
    current_user: User = Depends(get_current_user),
    start_date: Optional[date_type] = Query(
        None, description="Data inicial (default: 30 dias atrás)"
    ),
    end_date: Optional[date_type] = Query(
        None, description="Data final (default: hoje)"
    ),
    session: AsyncSession = Depends(get_db),
) -> StepHistoryResponseDTO:
    """
    Retorna o histórico de passos do usuário autenticado no intervalo informado,
    além de estatísticas: melhor semana, total da semana atual e flag de novo recorde.
    """
    controller = StepController(session)
    try:
        return await controller.get_history(current_user.id, start_date, end_date)
    except StepBusinessRuleError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.get(
    "/student/{user_id}/history",
    response_model=StepHistoryResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Histórico de passos de um aluno (personal trainer/admin)",
    responses={
        403: {"description": "Acesso negado"},
        404: {"description": "Aluno não encontrado"},
    },
)
async def get_student_history(
    user_id: UUID,
    current_user: User = Depends(get_current_user),
    start_date: Optional[date_type] = Query(
        None, description="Data inicial (default: 30 dias atrás)"
    ),
    end_date: Optional[date_type] = Query(
        None, description="Data final (default: hoje)"
    ),
    session: AsyncSession = Depends(get_db),
) -> StepHistoryResponseDTO:
    """
    Histórico de passos de um aluno. Apenas o personal trainer vinculado
    ou um admin podem acessar.
    """
    controller = StepController(session)
    try:
        return await controller.get_student_history(
            user_id, current_user, start_date, end_date
        )
    except StepAccessDeniedError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except StepBusinessRuleError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
