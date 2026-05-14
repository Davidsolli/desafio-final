"""Rotas HTTP para o módulo de dados de saúde.

Endpoints:
- POST /api/v1/health/sync    → Sincroniza FC e calorias do dia
- GET  /api/v1/health/summary → Resumo do dia (FC média, calorias)
"""

from datetime import date as date_type, datetime

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.controllers.health_controller import HealthController
from app.dependencies.auth import get_current_user
from app.dtos.health_dto import (
    HealthSyncRequestDTO,
    HealthSyncResponseDTO,
    HealthSummaryResponseDTO,
)
from app.models.user import User


router = APIRouter(
    prefix="/api/v1/health",
    tags=["health"],
    responses={
        401: {"description": "Não autenticado"},
        500: {"description": "Erro interno do servidor"},
    },
)


@router.post(
    "/sync",
    response_model=HealthSyncResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Sincronizar frequência cardíaca e calorias do dia",
    responses={
        200: {"description": "Dados de saúde sincronizados"},
        422: {"description": "Validação falhou"},
    },
)
async def sync_health_data(
    dto: HealthSyncRequestDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> HealthSyncResponseDTO:
    """Sincroniza amostras de frequência cardíaca e o total de calorias do dia.
    A operação é idempotente: amostras duplicadas (mesmo user + timestamp) são ignoradas.
    """
    controller = HealthController(session)
    return await controller.sync_health_data(current_user.id, dto)


@router.get(
    "/summary",
    response_model=HealthSummaryResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Resumo de saúde do dia",
)
async def get_health_summary(
    date: date_type = Query(
        default=None,
        description="Data no formato YYYY-MM-DD (padrão: hoje)",
    ),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> HealthSummaryResponseDTO:
    """Retorna FC média, mínima, máxima e calorias do dia solicitado."""
    day = date or datetime.utcnow().date()
    controller = HealthController(session)
    return await controller.get_summary(current_user.id, day)
