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
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.user_dto import (
    CreateUserDTO,
    UpdateUserDTO,
    UserResponseDTO,
    PaginatedUsersResponseDTO,
    UpdateThemePreferenceDTO,
)
from app.controllers.user_controller import UserController
from app.services.user_service import UserAlreadyExistsError, UserNotFoundError, InvalidInvitationError
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
    - invitation_code: Código de convite (obrigatório para clientes, opcional para personal trainers e admins)

    **Responses:**
    - 201: Usuário criado
    - 400: Validação falhou ou código de convite inválido
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
    except InvalidInvitationError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao criar usuário",
        )


@router.get(
    "/students",
    response_model=PaginatedUsersResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Listar alunos do personal trainer ou todos (admin)",
    responses={
        200: {"description": "Lista de alunos retornada"},
        401: {"description": "Não autenticado"},
        403: {"description": "Acesso negado (requer personal_trainer ou admin)"},
    },
)
async def list_students(
    trainer_id: UUID = Query(None, description="UUID do trainer (admin only)"),
    page: int = Query(1, ge=1, description="Número da página"),
    limit: int = Query(10, ge=1, le=100, description="Itens por página"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedUsersResponseDTO:
    """
    Listar alunos (clientes).

    **Requer autenticação:** Apenas personal_trainer e admin.

    **Query parameters:**
    - trainer_id: UUID do trainer (apenas admin, para filtrar alunos de um trainer específico)
    - page: Página (padrão: 1)
    - limit: Itens por página (padrão: 10, máximo: 100)

    **Comportamento:**
    - Personal trainer: Lista seus próprios alunos (ignora trainer_id)
    - Admin: Lista alunos do trainer_id especificado, ou TODOS se trainer_id not provided

    **Response:**
    - total: Total de alunos
    - page: Página atual
    - limit: Itens por página
    - data: Lista de alunos (clientes)

    **Segurança:**
    - Personal trainer só vê seus próprios alunos
    - Admin pode filtrar por trainer_id ou ver todos
    - Trainer_id ignorado para personal_trainer (sempre vê seus alunos)
    """
    if current_user.role == "personal_trainer":
        # Personal trainer sempre vê seus alunos (ignora trainer_id param)
        target_trainer_id = current_user.id
    elif current_user.role == "admin":
        # Admin pode filtrar por trainer_id ou ver todos
        target_trainer_id = trainer_id  # None = todos os alunos
    else:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas personal_trainer ou admin podem listar alunos",
        )

    controller = UserController(session)

    try:
        return await controller.get_students(target_trainer_id, page=page, limit=limit)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao listar alunos",
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
    role: Optional[str] = Query(None, description="Filtrar por role (admin, personal_trainer, client)"),
    trainer_id: Optional[UUID] = Query(None, description="Filtrar alunos de um trainer específico"),
    include_inactive: bool = Query(False, description="Incluir usuários inativos"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedUsersResponseDTO:
    """
    Listar todos os usuários com suporte a paginação e filtros.

    **Requer autenticação:** Apenas admin ou personal_trainer.

    **Query parameters:**
    - page: Página (padrão: 1)
    - limit: Itens por página (padrão: 10, máximo: 100)
    - role: Filtrar por role (admin, personal_trainer, client)
    - trainer_id: Filtrar alunos vinculados a um trainer específico
    - include_inactive: Se true, inclui usuários inativos (padrão: false)

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
        return await controller.list_users(page=page, limit=limit, role=role, trainer_id=trainer_id, include_inactive=include_inactive)
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
    - Personal trainer vê dados de seus alunos (role=client com trainer_id correspondente)
    - Admin vê dados de qualquer usuário

    **Path parameters:**
    - user_id: UUID do usuário

    **Response:**
    - Dados completos do usuário (sem senha)
    """
    is_owner = user_id == current_user.id
    is_admin = current_user.role == "admin"

    if is_owner or is_admin:
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

    # Personal trainer: validar se é seu aluno
    if current_user.role == "personal_trainer":
        controller = UserController(session)
        try:
            target_user = await controller.get_user_by_id(user_id)
            # Verificar se é aluno (client) e se belongs ao trainer
            if target_user.role != "client":
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Você só pode visualizar dados de seus alunos",
                )
            # Verificar trainer_id no banco (não disponível em DTO)
            from app.repositories.user_repository import UserRepository
            repo = UserRepository(session)
            target_db_user = await repo.get_by_id(user_id)
            if not target_db_user or target_db_user.trainer_id != current_user.id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Este aluno não está vinculado a você",
                )
            return target_user
        except HTTPException:
            raise
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

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Você só pode visualizar seus próprios dados",
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


@router.put(
    "/me/theme-preference",
    response_model=UserResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Atualizar preferência de tema do usuário autenticado",
    responses={
        200: {"description": "Preferência de tema atualizada"},
        400: {"description": "Validação falhou (tema inválido)"},
        401: {"description": "Não autenticado"},
    },
)
async def update_theme_preference(
    dto: UpdateThemePreferenceDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> UserResponseDTO:
    """
    Atualizar preferência de tema do usuário autenticado.

    **Requer autenticação:** Usuário deve estar logado.

    **Request body:**
    - theme_preference: 'light', 'dark' ou 'system'

    **Response:**
    - Dados completos do usuário com tema atualizado
    """
    controller = UserController(session)

    try:
        update_dto = UpdateUserDTO(theme_preference=dto.theme_preference)
        return await controller.update_user(current_user.id, update_dto)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao atualizar preferência de tema",
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
