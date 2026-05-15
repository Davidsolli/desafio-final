"""
Rotas HTTP para o dashboard de métricas administrativas.

Endpoints (todos exigem role=admin):
- GET /api/v1/admin/metrics/students    → métricas de alunos
- GET /api/v1/admin/metrics/trainers    → métricas de trainers
- GET /api/v1/admin/metrics/system      → saúde do sistema
- GET /api/v1/admin/metrics/ai          → analytics de IA
"""

from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.controllers.admin_metrics_controller import AdminMetricsController
from app.dependencies.auth import get_current_user
from app.dtos.admin_metrics_dto import (
    AIAnalyticsDTO,
    PaginatedStudentMetricsDTO,
    PaginatedTrainerMetricsDTO,
    SystemMetricsDTO,
)
from app.models.user import User

router = APIRouter(
    prefix="/api/v1/admin/metrics",
    tags=["admin-metrics"],
    responses={
        401: {"description": "Não autenticado"},
        403: {"description": "Acesso negado (requer admin)"},
        500: {"description": "Erro interno do servidor"},
    },
)


def _require_admin(current_user: User) -> None:
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas administradores podem acessar métricas",
        )


@router.get(
    "/students",
    response_model=PaginatedStudentMetricsDTO,
    status_code=status.HTTP_200_OK,
    summary="Métricas de alunos com adherence_rate e risk_level",
    responses={200: {"description": "Métricas paginadas de alunos"}},
)
async def get_student_metrics(
    days: int = Query(30, ge=1, le=365, description="Janela temporal em dias"),
    trainer_id: Optional[UUID] = Query(None, description="Filtrar por trainer (admin only)"),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedStudentMetricsDTO:
    """
    Métricas de alunos com adherence_rate, risco de churn e progresso de metas.

    **Filtros:**
    - `days`: janela temporal (padrão 30 dias)
    - `trainer_id`: filtrar alunos de um trainer específico

    **adherence_rate:** % de sessões completadas no período
    **risk_level:** critical | high | medium | low (score de churn baseado em aderência + inatividade)
    **adherence_category:** high (>80%) | medium (50-80%) | low (<50%)
    """
    _require_admin(current_user)

    controller = AdminMetricsController(session)
    try:
        return await controller.get_student_metrics(trainer_id, days, page, limit)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao calcular métricas de alunos",
        )


@router.get(
    "/trainers",
    response_model=PaginatedTrainerMetricsDTO,
    status_code=status.HTTP_200_OK,
    summary="Métricas de trainers com portfolio_health e taxa de conversão",
    responses={200: {"description": "Métricas paginadas de trainers"}},
)
async def get_trainer_metrics(
    days: int = Query(30, ge=1, le=365, description="Janela temporal em dias"),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedTrainerMetricsDTO:
    """
    Métricas de trainers com saúde do portfolio, funil de vendas e aderência média de alunos.

    **portfolio_health:** % de alunos ativos (atividade nos últimos 14 dias) vs total
    **conversion_rate:** % de convites gerados que foram resgatados por alunos
    **at_risk_students:** alunos com aderência < 50% no período
    """
    _require_admin(current_user)

    controller = AdminMetricsController(session)
    try:
        return await controller.get_trainer_metrics(days, page, limit)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao calcular métricas de trainers",
        )


@router.get(
    "/system",
    response_model=SystemMetricsDTO,
    status_code=status.HTTP_200_OK,
    summary="Métricas globais do sistema (DAU, MAU, chatbot, crescimento)",
    responses={200: {"description": "Métricas do sistema"}},
)
async def get_system_metrics(
    days: int = Query(30, ge=1, le=365, description="Janela temporal em dias"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SystemMetricsDTO:
    """
    Visão geral da saúde da plataforma.

    **dau:** Daily Active Users (usuários com ≥1 ação hoje)
    **mau:** Monthly Active Users (usuários com ≥1 ação nos últimos 30 dias)
    **dau_mau_ratio:** Indicador de engajamento. >0.5 = excelente; <0.3 = em risco
    **chatbot_adoption_rate:** % de usuários ativos que usaram o chatbot
    **chatbot_quality_score:** % de respostas marcadas como úteis
    """
    _require_admin(current_user)

    controller = AdminMetricsController(session)
    try:
        return await controller.get_system_metrics(days)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao calcular métricas do sistema",
        )


@router.get(
    "/ai",
    response_model=AIAnalyticsDTO,
    status_code=status.HTTP_200_OK,
    summary="Analytics de uso e qualidade de IA (tokens, latência, modelo)",
    responses={200: {"description": "Analytics de IA"}},
)
async def get_ai_analytics(
    days: int = Query(30, ge=1, le=365, description="Janela temporal em dias"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> AIAnalyticsDTO:
    """
    Rastreamento detalhado de uso de IA: tokens consumidos, latência e qualidade por modelo.

    **total_tokens:** Total de tokens consumidos no período
    **avg_latency_ms:** Latência média de resposta em milissegundos
    **quality_score:** % de respostas com feedback positivo
    **by_model:** Breakdown por modelo de IA (tokens, latência, % do total)
    """
    _require_admin(current_user)

    controller = AdminMetricsController(session)
    try:
        return await controller.get_ai_analytics(days)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao calcular analytics de IA",
        )
