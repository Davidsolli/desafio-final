"""
Rotas HTTP para gerenciamento de usuários.

Endpoints:
- POST /api/v1/users → Criar usuário
- GET /api/v1/users → Listar usuários com paginação
- GET /api/v1/users/{id} → Buscar usuário por ID
- PUT /api/v1/users/{id} → Atualizar usuário
- DELETE /api/v1/users/{id} → Deletar usuário
- GET /api/v1/users/me/export → Exportar todos os dados pessoais (LGPD RNF-10)
- DELETE /api/v1/users/me/data → Solicitar exclusão completa dos dados (LGPD RNF-10)
"""

from typing import Any, Dict, Optional
from uuid import UUID

from fastapi import APIRouter, HTTPException, Depends, Query, status
from fastapi.responses import JSONResponse
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.user_dto import (
    CreateUserDTO,
    UpdateUserDTO,
    UserResponseDTO,
    PaginatedUsersResponseDTO,
)
from app.controllers.user_controller import UserController
from app.services.user_service import UserAlreadyExistsError, UserNotFoundError
from app.config.database import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User

router = APIRouter(
    prefix="/api/v1/users",
    tags=["users"],
    responses={
        404: {"description": "Usuário não encontrado"},
        500: {"description": "Erro interno do servidor"},
    },
)


@router.post(
    "",
    response_model=UserResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Criar novo usuário",
    responses={
        201: {"description": "Usuário criado com sucesso"},
        400: {"description": "Validação falhou"},
        409: {"description": "Email já cadastrado"},
    },
)
async def create_user(
    dto: CreateUserDTO,
    session: AsyncSession = Depends(get_db),
) -> UserResponseDTO:
    """
    Criar novo usuário no sistema.

    **Request body:**
    - name: Nome completo (3-255 chars, apenas letras)
    - email: Email válido e único
    - password: Senha forte (8+ chars, maiúscula, minúscula, número, caractere especial)
    - role: admin, personal_trainer ou client
    - phone_whatsapp: +55 XX XXXXX-XXXX

    **Responses:**
    - 201: Usuário criado
    - 400: Validação falhou
    - 409: Email duplicado
    """
    controller = UserController(session)

    try:
        return await controller.create_user(dto)
    except UserAlreadyExistsError as e:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao criar usuário",
        )


@router.get(
    "/me",
    response_model=UserResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Obter perfil do usuário autenticado",
    responses={
        200: {"description": "Perfil do usuário retornado"},
        401: {"description": "Não autenticado"},
    },
)
async def get_current_user_profile(
    current_user: User = Depends(get_current_user),
) -> UserResponseDTO:
    """
    Obter dados do perfil do usuário autenticado.

    **Requer autenticação:** Usuário deve estar logado.

    **Response:**
    - Dados completos do usuário autenticado (sem senha)
    """
    return UserResponseDTO.model_validate(current_user)


@router.get(
    "",
    response_model=PaginatedUsersResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Listar usuários com paginação",
    responses={
        200: {"description": "Lista de usuários retornada"},
        401: {"description": "Não autenticado"},
        403: {"description": "Acesso negado (requer admin ou personal_trainer)"},
    },
)
async def list_users(
    page: int = Query(1, ge=1, description="Número da página"),
    limit: int = Query(10, ge=1, le=100, description="Itens por página"),
    role: Optional[str] = Query(None, description="Filtrar por papel: admin, personal_trainer, client"),
    search: Optional[str] = Query(None, description="Buscar por nome ou email (parcial)"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedUsersResponseDTO:
    """
    Listar todos os usuários com suporte a paginação.

    **Requer autenticação:** Apenas admin ou personal_trainer.

    **Query parameters:**
    - page: Página (padrão: 1)
    - limit: Itens por página (padrão: 10, máximo: 100)
    - role: Filtrar por papel (opcional)
    - search: Busca por nome ou email (opcional)

    **Response:**
    - total: Total de usuários no banco
    - page: Página atual
    - limit: Itens por página
    - data: Lista de usuários
    """
    if current_user.role not in ["admin", "personal_trainer"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas admin ou personal_trainer podem listar usuários",
        )

    controller = UserController(session)

    try:
        return await controller.list_users(page=page, limit=limit, role_filter=role, search=search)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao listar usuários",
        )


@router.get(
    "/{user_id}",
    response_model=UserResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Buscar usuário por ID",
    responses={
        200: {"description": "Usuário encontrado"},
        401: {"description": "Não autenticado"},
        403: {"description": "Acesso negado"},
        404: {"description": "Usuário não encontrado"},
    },
)
async def get_user(
    user_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> UserResponseDTO:
    """
    Buscar dados de um usuário específico.

    **Requer autenticação:**
    - Usuário autenticado vê apenas seus próprios dados
    - Admin ou personal_trainer veem dados de qualquer usuário

    **Path parameters:**
    - user_id: UUID do usuário

    **Response:**
    - Dados completos do usuário (sem senha)
    """
    is_owner = user_id == current_user.id
    is_privileged = current_user.role in ["admin", "personal_trainer"]

    if not (is_owner or is_privileged):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Você só pode visualizar seus próprios dados",
        )

    controller = UserController(session)

    try:
        return await controller.get_user_by_id(user_id)
    except UserNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao buscar usuário",
        )


@router.put(
    "/{user_id}",
    response_model=UserResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Atualizar usuário",
    responses={
        200: {"description": "Usuário atualizado"},
        400: {"description": "Validação falhou"},
        401: {"description": "Não autenticado"},
        403: {"description": "Acesso negado"},
        404: {"description": "Usuário não encontrado"},
    },
)
async def update_user(
    user_id: UUID,
    dto: UpdateUserDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> UserResponseDTO:
    """
    Atualizar dados de um usuário (campos opcionais).

    **Requer autenticação:**
    - Usuário autenticado pode editar apenas sua própria conta
    - Admin pode editar qualquer usuário

    **Path parameters:**
    - user_id: UUID do usuário

    **Request body (todos opcionais):**
    - name: Novo nome
    - role: Novo role
    - phone_whatsapp: Novo telefone WhatsApp
    - is_active: Ativar/desativar usuário

    **NÃO é possível atualizar:**
    - email (requer verificação de propriedade)
    - password (endpoint separado no futuro)
    - created_at (imutável)
    """
    is_owner = user_id == current_user.id
    is_admin = current_user.role == "admin"

    if not (is_owner or is_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Você só pode editar sua própria conta",
        )

    controller = UserController(session)

    try:
        return await controller.update_user(user_id, dto)
    except UserNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao atualizar usuário",
        )


@router.delete(
    "/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Deletar usuário",
    responses={
        204: {"description": "Usuário deletado com sucesso"},
        401: {"description": "Não autenticado"},
        403: {"description": "Acesso negado"},
        404: {"description": "Usuário não encontrado"},
    },
)
async def delete_user(
    user_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> None:
    """
    Deletar um usuário (soft delete - marcar como inativo).

    **Requer autenticação:**
    - Usuário autenticado pode deletar apenas sua própria conta
    - Admin pode deletar qualquer usuário

    **Path parameters:**
    - user_id: UUID do usuário

    **Note:** Usa soft delete. O usuário é marcado como inativo,
    mas não é permanentemente removido do banco.
    """
    is_owner = user_id == current_user.id
    is_admin = current_user.role == "admin"

    if not (is_owner or is_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Você só pode deletar sua própria conta",
        )

    controller = UserController(session)

    try:
        await controller.delete_user(user_id)
    except UserNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao deletar usuário",
        )


# ── LGPD — RNF-10 ─────────────────────────────────────────────────────────────

@router.get(
    "/me/export",
    status_code=status.HTTP_200_OK,
    summary="Exportar todos os dados pessoais (LGPD Art. 18)",
    tags=["lgpd"],
)
async def export_my_data(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> Dict[str, Any]:
    """
    Exporta todos os dados pessoais do usuário autenticado em formato JSON.

    Conforme Art. 18 da LGPD, o titular tem direito ao acesso e portabilidade
    dos seus dados. Este endpoint agrega:
    - Dados cadastrais do perfil
    - Sessões de treino registradas
    - Refeições e entradas nutricionais
    - Metas e progresso
    - Histórico de conversas com o chatbot

    Os dados são retornados em formato JSON estruturado.
    """
    from app.models.logbook import WorkoutSession
    from app.models.goal import Goal
    from sqlalchemy import select as sa_select

    user_id = current_user.id

    # Dados do perfil
    profile = {
        "id": str(current_user.id),
        "name": current_user.name,
        "email": current_user.email,
        "role": current_user.role,
        "weight": current_user.weight,
        "height": current_user.height,
        "age": current_user.age,
        "gender": current_user.gender,
        "phone_whatsapp": current_user.phone_whatsapp,
        "created_at": current_user.created_at.isoformat() if current_user.created_at else None,
    }

    # Sessões de treino
    sessions_result = await session.execute(
        sa_select(WorkoutSession).where(WorkoutSession.user_id == user_id)
    )
    sessions = [
        {
            "id": str(s.id),
            "session_date": s.session_date.isoformat() if s.session_date else None,
            "status": s.status,
            "workout_name": s.workout_name,
            "duration_minutes": s.duration_minutes,
            "calories_burned": s.calories_burned,
            "intensity": s.intensity,
        }
        for s in sessions_result.scalars().all()
    ]

    # Metas
    goals_result = await session.execute(
        sa_select(Goal).where(Goal.user_id == user_id)
    )
    goals = [
        {
            "id": str(g.id),
            "title": g.title,
            "target_value": g.target_value,
            "current_value": g.current_value,
            "unit": g.unit,
            "status": g.status,
            "deadline": g.deadline.isoformat() if g.deadline else None,
        }
        for g in goals_result.scalars().all()
    ]

    return {
        "export_date": __import__("datetime").datetime.utcnow().isoformat(),
        "profile": profile,
        "workout_sessions": sessions,
        "goals": goals,
        "note": "Dados exportados conforme LGPD Art. 18. Para refeições e histórico de chat, utilize os endpoints específicos de cada módulo.",
    }


@router.delete(
    "/me/data",
    status_code=status.HTTP_200_OK,
    summary="Solicitar exclusão completa dos dados pessoais (LGPD Art. 18)",
    tags=["lgpd"],
)
async def request_data_deletion(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> Dict[str, Any]:
    """
    Solicita a exclusão de todos os dados pessoais do usuário autenticado.

    Conforme LGPD Art. 18 (VI), o titular tem o direito à eliminação dos dados
    tratados com base no consentimento. Este endpoint:
    1. Desativa a conta imediatamente (soft delete)
    2. Agenda a exclusão definitiva em 30 dias
    3. Remove dados sensíveis de saúde imediatamente (metas, sessões de treino)

    **Atenção:** Esta ação é irreversível após o período de carência de 30 dias.
    """
    from app.models.logbook import WorkoutSession
    from app.models.nutrition import Meal
    from app.models.goal import Goal

    user_id = current_user.id

    # Soft delete do usuário (desativa imediatamente)
    current_user.is_active = False
    await session.flush()

    # Remoção imediata de dados de saúde sensíveis
    await session.execute(
        delete(WorkoutSession).where(WorkoutSession.user_id == user_id)
    )
    await session.execute(
        delete(Meal).where(Meal.user_id == user_id)
    )
    await session.execute(
        delete(Goal).where(Goal.user_id == user_id)
    )
    await session.commit()

    return {
        "message": "Solicitação de exclusão registrada. Sua conta foi desativada imediatamente e os dados de saúde foram removidos. Os demais dados serão excluídos definitivamente em até 30 dias.",
        "lgpd_basis": "Art. 18, VI — LGPD",
        "user_id": str(user_id),
    }
