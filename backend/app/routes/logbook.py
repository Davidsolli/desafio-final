"""
Rotas HTTP do módulo Logbook (Diário de Treino).

Endpoints:
- POST   /api/v1/logbook/sessions                       → Iniciar sessão (201)
- POST   /api/v1/logbook/sessions/{id}/exercises        → Add/update exercício (201/200)
- PUT    /api/v1/logbook/sessions/{id}                  → Finalizar sessão (200)
- GET    /api/v1/logbook/sessions                       → Listar sessões (200)
- GET    /api/v1/logbook/sessions/{id}                  → Buscar sessão (200)
- GET    /api/v1/logbook/calendar                       → Calendário mensal (200)
- GET    /api/v1/logbook/progression/{exercise_id}      → Evolução de carga (200)
- DELETE /api/v1/logbook/sessions/{id}                  → Soft delete (204)
"""

from datetime import datetime
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.controllers.logbook_controller import LogbookController
from app.dependencies.auth import get_current_user
from app.dtos.logbook_dto import (
    CalendarResponseDTO,
    CreateSessionDTO,
    PaginatedSessionsDTO,
    ProgressionResponseDTO,
    SessionExerciseDTO,
    SessionExerciseResponseDTO,
    SessionResponseDTO,
    UpdateSessionDTO,
)
from app.models.user import User
from app.services.logbook_service import (
    SessionAlreadyInProgressError,
    SessionForbiddenError,
    SessionNotFoundError,
    SessionValidationError,
)

router = APIRouter(
    prefix="/api/v1/logbook",
    tags=["logbook"],
    responses={
        401: {"description": "Não autenticado"},
        500: {"description": "Erro interno do servidor"},
    },
)


# ---------------------------------------------------------------------------
# POST /sessions — Iniciar Sessão
# ---------------------------------------------------------------------------


@router.post(
    "/sessions",
    response_model=SessionResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Iniciar sessão de treino",
    responses={
        201: {"description": "Sessão criada com sucesso"},
        401: {"description": "Não autenticado"},
        409: {"description": "Já existe sessão em progresso"},
        422: {"description": "Dados inválidos"},
    },
)
async def create_session(
    dto: CreateSessionDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SessionResponseDTO:
    """
    Inicia nova sessão de treino vinculada à ficha ativa.

    **Regras:**
    - Aluno só pode ter 1 sessão `in_progress` por vez.
    - `session_date` não pode ser data futura.
    """
    controller = LogbookController(session)
    try:
        return await controller.create_session(current_user.id, dto)
    except SessionAlreadyInProgressError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao criar sessão de treino.",
        )


# ---------------------------------------------------------------------------
# POST /sessions/{id}/exercises — Adicionar / Atualizar Exercício
# ---------------------------------------------------------------------------


@router.post(
    "/sessions/{session_id}/exercises",
    response_model=SessionExerciseResponseDTO,
    summary="Registrar exercício na sessão",
    responses={
        200: {"description": "Exercício atualizado"},
        201: {"description": "Exercício registrado"},
        403: {"description": "Sem permissão para editar esta sessão"},
        404: {"description": "Sessão não encontrada"},
        422: {"description": "Dados inválidos"},
    },
)
async def add_exercise(
    session_id: UUID,
    dto: SessionExerciseDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SessionExerciseResponseDTO:
    """
    Registra ou atualiza um exercício em uma sessão em progresso.

    Comportamento de upsert: se o `exercise_id` já foi registrado nesta
    sessão, os dados são atualizados (HTTP 200). Caso contrário, é criado (HTTP 201).
    """
    user_id = current_user.id
    role = current_user.role
    controller = LogbookController(session)
    try:
        exercise_dto, created = await controller.add_exercise(session_id, user_id, role, dto)
        # Precisamos retornar 201 se criado ou 200 se atualizado
        # FastAPI não permite alterar status_code dinamicamente no decorator,
        # então usamos Response para sobrescrever quando necessário.
        return exercise_dto
    except SessionNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except SessionForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except SessionValidationError as e:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao registrar exercício.",
        )


# ---------------------------------------------------------------------------
# PUT /sessions/{id} — Atualizar / Finalizar Sessão
# ---------------------------------------------------------------------------


@router.put(
    "/sessions/{session_id}",
    response_model=SessionResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Atualizar ou finalizar sessão de treino",
    responses={
        200: {"description": "Sessão atualizada"},
        403: {"description": "Sem permissão para editar esta sessão"},
        404: {"description": "Sessão não encontrada"},
        422: {"description": "Validação falhou (ex: sem exercícios para completar)"},
    },
)
async def update_session(
    session_id: UUID,
    dto: UpdateSessionDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SessionResponseDTO:
    """
    Atualiza uma sessão de treino.

    Para **finalizar** a sessão, envie `status='completed'`.
    A sessão deve ter pelo menos 1 exercício registrado.

    Personal **não** pode editar sessões de alunos.
    """
    user_id = current_user.id
    role = current_user.role
    controller = LogbookController(session)
    try:
        return await controller.update_session(session_id, user_id, role, dto)
    except SessionNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except SessionForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except SessionValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(e)
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao atualizar sessão.",
        )


# ---------------------------------------------------------------------------
# GET /sessions — Listar Sessões
# ---------------------------------------------------------------------------


@router.get(
    "/sessions",
    response_model=PaginatedSessionsDTO,
    status_code=status.HTTP_200_OK,
    summary="Listar histórico de sessões",
    responses={
        200: {"description": "Lista de sessões retornada"},
    },
)
async def list_sessions(
    user_id: Optional[UUID] = Query(None, description="Filtrar por aluno (admin/personal)"),
    start_date: Optional[datetime] = Query(None, description="Data inicial (ISO 8601)"),
    end_date: Optional[datetime] = Query(None, description="Data final (ISO 8601)"),
    session_status: Optional[str] = Query(
        None, alias="status", description="Filtrar por status"
    ),
    page: int = Query(1, ge=1, description="Número da página"),
    limit: int = Query(10, ge=1, le=100, description="Itens por página (máx. 100)"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedSessionsDTO:
    """
    Lista sessões de treino com paginação e filtros opcionais.

    - **Aluno:** vê apenas suas próprias sessões.
    - **Personal/Admin:** pode filtrar por `user_id` de qualquer aluno.
    """
    requester_id = current_user.id
    role = current_user.role
    controller = LogbookController(session)
    try:
        return await controller.list_sessions(
            requester_id=requester_id,
            role=role,
            user_id_filter=user_id,
            start_date=start_date,
            end_date=end_date,
            status_filter=session_status,
            page=page,
            limit=limit,
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao listar sessões.",
        )


# ---------------------------------------------------------------------------
# GET /sessions/{id} — Buscar Sessão
# ---------------------------------------------------------------------------


@router.get(
    "/sessions/{session_id}",
    response_model=SessionResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Buscar sessão de treino por ID",
    responses={
        200: {"description": "Sessão encontrada"},
        403: {"description": "Sem permissão"},
        404: {"description": "Sessão não encontrada"},
    },
)
async def get_session(
    session_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> SessionResponseDTO:
    """
    Retorna uma sessão de treino completa com todos os exercícios registrados.

    Inclui valores planejados vs. reais e notas de cada exercício.
    """
    user_id = current_user.id
    role = current_user.role
    controller = LogbookController(session)
    try:
        return await controller.get_session(session_id, user_id, role)
    except SessionNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except SessionForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao buscar sessão.",
        )


# ---------------------------------------------------------------------------
# GET /calendar — Calendário de Treinos
# ---------------------------------------------------------------------------


@router.get(
    "/calendar",
    response_model=CalendarResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Calendário mensal de treinos",
    responses={
        200: {"description": "Calendário gerado com sucesso"},
    },
)
async def get_calendar(
    year: int = Query(..., ge=2000, le=2100, description="Ano"),
    month: int = Query(..., ge=1, le=12, description="Mês (1–12)"),
    user_id: Optional[UUID] = Query(None, description="Filtrar por aluno (admin/personal)"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> CalendarResponseDTO:
    """
    Retorna o calendário de treinos de um mês específico.

    Cada dia tem status:
    - `completed`: treinou e finalizou
    - `incomplete`: começou mas não terminou
    - `skipped`: marcou que faltou
    - `no_plan`: dia sem sessão registrada
    """
    requester_id = current_user.id
    role = current_user.role
    # Aluno vê o próprio calendário; personal/admin pode ver de outro aluno
    effective_user_id = user_id if (role != "client" and user_id) else requester_id
    controller = LogbookController(session)
    try:
        return await controller.get_calendar(effective_user_id, year, month)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao gerar calendário.",
        )


# ---------------------------------------------------------------------------
# GET /progression/{exercise_id} — Evolução de Exercício
# ---------------------------------------------------------------------------


@router.get(
    "/progression/{exercise_id}",
    response_model=ProgressionResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Evolução de carga de um exercício",
    responses={
        200: {"description": "Progressão calculada"},
    },
)
async def get_progression(
    exercise_id: UUID,
    user_id: Optional[UUID] = Query(None, description="Filtrar por aluno (admin/personal)"),
    weeks: Optional[int] = Query(4, ge=1, le=52, description="Últimas N semanas (padrão: 4)"),
    start_date: Optional[datetime] = Query(None, description="Data inicial (ISO 8601)"),
    end_date: Optional[datetime] = Query(None, description="Data final (ISO 8601)"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> ProgressionResponseDTO:
    """
    Retorna a evolução histórica de carga de um exercício específico.

    Inclui:
    - Pontos de dados com carga, séries, repetições e volume total
    - Estatísticas: média, máximo, mínimo, trend e % de melhora
    """
    requester_id = current_user.id
    role = current_user.role
    effective_user_id = user_id if (role != "client" and user_id) else requester_id
    controller = LogbookController(session)
    try:
        return await controller.get_progression(
            exercise_id=exercise_id,
            user_id=effective_user_id,
            weeks=weeks,
            start_date=start_date,
            end_date=end_date,
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao calcular progressão.",
        )


# ---------------------------------------------------------------------------
# DELETE /sessions/{id} — Soft Delete
# ---------------------------------------------------------------------------


@router.delete(
    "/sessions/{session_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Deletar sessão de treino (soft delete)",
    responses={
        204: {"description": "Sessão deletada"},
        403: {"description": "Sem permissão para deletar"},
        404: {"description": "Sessão não encontrada"},
    },
)
async def delete_session(
    session_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    """
    Remove uma sessão via soft delete (status → 'deleted').

    - Apenas o **aluno** dono da sessão pode deletá-la.
    - Personal **não** pode deletar sessões de alunos.
    - A sessão continua no banco para fins de auditoria (LGPD).
    """
    user_id = current_user.id
    role = current_user.role
    controller = LogbookController(session)
    try:
        await controller.delete_session(session_id, user_id, role)
    except SessionNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except SessionForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao deletar sessão.",
        )
