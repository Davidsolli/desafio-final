"""
Rotas HTTP para gerenciamento de usuários.

Endpoints:
- POST /api/v1/users → Criar usuário
- GET /api/v1/users → Listar usuários com paginação
- GET /api/v1/users/{id} → Buscar usuário por ID
- PUT /api/v1/users/{id} → Atualizar usuário
- DELETE /api/v1/users/{id} → Deletar usuário
"""

from uuid import UUID

from fastapi import APIRouter, HTTPException, Depends, Query, status
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
    - weight_kg: Peso em kg (opcional)
    - height_cm: Altura em cm (opcional)
    - age: Idade em anos (opcional)
    - goal_type: Objetivo de treino (opcional)

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
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedUsersResponseDTO:
    """
    Listar todos os usuários com suporte a paginação.

    **Requer autenticação:** Apenas admin ou personal_trainer.

    **Query parameters:**
    - page: Página (padrão: 1)
    - limit: Itens por página (padrão: 10, máximo: 100)

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
        return await controller.list_users(page=page, limit=limit)
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
