"""
Rotas do Dashboard Profissional (RF-43 a RF-48).

Endpoints:
- GET /api/v1/dashboard/personal/students          → Lista alunos do personal (RF-43, RF-47)
- GET /api/v1/dashboard/students/{id}/360          → Visão detalhada do aluno (RF-44)
- GET /api/v1/dashboard/admin/overview             → Métricas globais (RF-46)
- GET /api/v1/dashboard/export/pdf                 → Exportação em PDF (RF-48)
"""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import StreamingResponse
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.controllers.dashboard_controller import DashboardController
from app.dependencies.auth import get_current_user
from app.dtos.dashboard_dto import (
    AdminOverviewDTO,
    DashboardFiltersDTO,
    PaginatedStudentsDTO,
    Student360DTO,
)
from app.models.user import User
from app.services.dashboard_service import DashboardForbiddenError, DashboardNotFoundError

router = APIRouter(
    prefix="/api/v1/dashboard",
    tags=["dashboard"],
    responses={
        401: {"description": "Não autenticado"},
        403: {"description": "Acesso negado"},
        500: {"description": "Erro interno do servidor"},
    },
)

_ALLOWED_ROLES = {"admin", "personal_trainer", "gestor"}


def _require_professional(current_user: User) -> None:
    """Guard: bloqueia role 'client' em todas as rotas do dashboard."""
    if current_user.role not in _ALLOWED_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso exclusivo para personal trainers e administradores.",
        )


# ---------------------------------------------------------------------------
# RF-43 + RF-47: Lista de alunos com indicadores e filtros
# ---------------------------------------------------------------------------


@router.get(
    "/personal/students",
    response_model=PaginatedStudentsDTO,
    status_code=status.HTTP_200_OK,
    summary="Listar alunos com indicadores (RF-43)",
    responses={
        200: {"description": "Lista de alunos retornada com sucesso"},
        403: {"description": "Apenas personal trainers e admins"},
    },
)
async def list_students(
    period: str = Query("month", description="week | month | year"),
    student_status: str | None = Query(
        None, alias="status", description="engaged | at_risk | inactive"
    ),
    page: int = Query(1, ge=1),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedStudentsDTO:
    """
    Retorna a lista de alunos vinculados ao personal logado, com indicadores resumidos.

    - **Personal Trainer:** vê apenas seus alunos (vinculados via fichas de treino).
    - **Admin/Gestor:** vê todos os alunos ativos da academia.
    - Filtros disponíveis: `status` (semáforo) e `period` (janela temporal).
    """
    _require_professional(current_user)

    filters = DashboardFiltersDTO(period=period, status=student_status, page=page, limit=limit)
    controller = DashboardController(session)
    try:
        return await controller.list_students(current_user.id, current_user.role, filters)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao carregar lista de alunos.",
        )


# ---------------------------------------------------------------------------
# RF-44: Visão 360° do aluno
# ---------------------------------------------------------------------------


@router.get(
    "/students/{student_id}/360",
    response_model=Student360DTO,
    status_code=status.HTTP_200_OK,
    summary="Visão 360° do aluno (RF-44)",
    responses={
        200: {"description": "Visão detalhada retornada"},
        403: {"description": "Aluno não vinculado ao personal"},
        404: {"description": "Aluno não encontrado"},
    },
)
async def get_student_360(
    student_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> Student360DTO:
    """
    Retorna o perfil detalhado de um aluno com:
    - Últimos 5 treinos (logbook)
    - Metas ativas e progresso
    - Adesão alimentar dos últimos 7 dias
    - Frequência por grupo muscular nos últimos 30 dias

    **LGPD:** Personal só acessa alunos com ficha ativa atribuída a ele.
    """
    _require_professional(current_user)
    controller = DashboardController(session)
    try:
        return await controller.get_student_360(current_user.id, student_id, current_user.role)
    except DashboardNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except DashboardForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao carregar visão 360° do aluno.",
        )


# ---------------------------------------------------------------------------
# RF-46: Visão do Gestor (Admin only)
# ---------------------------------------------------------------------------


@router.get(
    "/admin/overview",
    response_model=AdminOverviewDTO,
    status_code=status.HTTP_200_OK,
    summary="Métricas globais da academia (RF-46)",
    responses={
        200: {"description": "Overview retornado"},
        403: {"description": "Acesso exclusivo para administradores"},
    },
)
async def admin_overview(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> AdminOverviewDTO:
    """
    Retorna métricas macro da academia visíveis apenas ao Gestor/Admin:
    - Total de matrículas ativas
    - DAU e MAU (Daily/Monthly Active Users)
    - Taxa de adesão global
    - Distribuição de alunos por status (semáforo)
    """
    if current_user.role not in ("admin", "gestor"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Acesso exclusivo para administradores.",
        )
    controller = DashboardController(session)
    try:
        return await controller.get_admin_overview(current_user.role)
    except DashboardForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao carregar overview administrativo.",
        )


# ---------------------------------------------------------------------------
# RF-48: Exportação de Relatório em PDF
# ---------------------------------------------------------------------------


@router.get(
    "/export/pdf",
    status_code=status.HTTP_200_OK,
    summary="Exportar relatório do aluno em PDF (RF-48)",
    responses={
        200: {"description": "PDF gerado e retornado como stream"},
        403: {"description": "Aluno não vinculado ao personal"},
        404: {"description": "Aluno não encontrado"},
    },
)
async def export_pdf(
    student_id: UUID = Query(..., description="UUID do aluno"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> StreamingResponse:
    """
    Gera e retorna o relatório executivo do aluno em PDF.

    O PDF inclui: dados do aluno, métricas de adesão, últimos treinos,
    metas ativas, frequência muscular e resumo nutricional.

    **LGPD:** Acesso auditado — personal só exporta dados de seus alunos.
    """
    _require_professional(current_user)
    controller = DashboardController(session)
    try:
        pdf_buffer = await controller.generate_pdf(
            current_user.id, student_id, current_user.role
        )
        filename = f"relatorio_{student_id}.pdf"
        return StreamingResponse(
            pdf_buffer,
            media_type="application/pdf",
            headers={"Content-Disposition": f"attachment; filename={filename}"},
        )
    except DashboardNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except DashboardForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(e)
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao gerar PDF.",
        )
