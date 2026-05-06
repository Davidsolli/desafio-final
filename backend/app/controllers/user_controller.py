"""
Controller de Usuários.

Orquestra as chamadas entre routes e services.
Concentra a lógica de erro e validação de entrada/saída.
"""

from typing import List, Tuple
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.user_dto import (
    CreateUserDTO,
    UpdateUserDTO,
    UserResponseDTO,
    PaginatedUsersResponseDTO,
)
from app.services.user_service import (
    UserService,
    UserAlreadyExistsError,
    UserNotFoundError,
)


class UserController:
    """Controller para operações de usuário."""

    def __init__(self, session: AsyncSession):
        """Inicializar controller com sessão async."""
        self.service = UserService(session)

    async def create_user(self, dto: CreateUserDTO) -> UserResponseDTO:
        """
        Criar novo usuário.

        Args:
            dto: CreateUserDTO

        Returns:
            UserResponseDTO

        Raises:
            UserAlreadyExistsError: Se email duplicado
        """
        return await self.service.create(dto)

    async def get_user_by_id(self, user_id: UUID) -> UserResponseDTO:
        """
        Buscar usuário por ID.

        Args:
            user_id: UUID do usuário

        Returns:
            UserResponseDTO

        Raises:
            UserNotFoundError: Se não encontrado
        """
        return await self.service.get_by_id(user_id)

    async def list_users(
        self,
        page: int = 1,
        limit: int = 10,
    ) -> PaginatedUsersResponseDTO:
        """
        Listar usuários com paginação.

        Args:
            page: Página
            limit: Itens por página

        Returns:
            PaginatedUsersResponseDTO
        """
        users, total = await self.service.list_all(page, limit)
        return PaginatedUsersResponseDTO(
            total=total,
            page=page,
            limit=limit,
            data=users,
        )

    async def update_user(
        self,
        user_id: UUID,
        dto: UpdateUserDTO,
    ) -> UserResponseDTO:
        """
        Atualizar usuário.

        Args:
            user_id: UUID do usuário
            dto: UpdateUserDTO

        Returns:
            UserResponseDTO

        Raises:
            UserNotFoundError: Se não encontrado
        """
        return await self.service.update(user_id, dto)

    async def delete_user(self, user_id: UUID) -> bool:
        """
        Deletar usuário (soft delete).

        Args:
            user_id: UUID do usuário

        Returns:
            bool

        Raises:
            UserNotFoundError: Se não encontrado
        """
        return await self.service.delete(user_id)

    async def get_students(
        self,
        trainer_id: UUID,
        page: int = 1,
        limit: int = 10,
    ) -> PaginatedUsersResponseDTO:
        """
        Listar alunos de um personal trainer.

        Args:
            trainer_id: UUID do personal trainer
            page: Página
            limit: Itens por página

        Returns:
            PaginatedUsersResponseDTO
        """
        students, total = await self.service.list_students_for_trainer(trainer_id, page, limit)
        return PaginatedUsersResponseDTO(
            total=total,
            page=page,
            limit=limit,
            data=students,
        )
