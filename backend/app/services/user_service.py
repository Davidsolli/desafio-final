"""
Serviço de Usuários.

Camada de negócio que orquestra operações com usuários.
Inclui: criação, atualização, validação, hash de senhas e lógica de negócio.
"""

import bcrypt
from typing import Optional, List, Tuple
from uuid import UUID

from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User
from app.models.user_profile import UserProfile
from app.dtos.user_dto import CreateUserDTO, UpdateUserDTO, UserResponseDTO
from app.repositories.user_repository import UserRepository


class UserAlreadyExistsError(Exception):
    """Exceção quando email já existe no banco."""

    pass


class UserNotFoundError(Exception):
    """Exceção quando usuário não é encontrado."""

    pass


class UserService:
    """Serviço de negócio para usuários."""

    def __init__(self, session: AsyncSession):
        """Inicializar serviço com sessão async."""
        self.session = session
        self.repository = UserRepository(session)

    @staticmethod
    def hash_password(password: str) -> str:
        """
        Hash de senha com bcrypt.

        Args:
            password: Senha em texto plano

        Returns:
            str: Senha hasheada
        """
        salt = bcrypt.gensalt(rounds=12)
        return bcrypt.hashpw(password.encode(), salt).decode()

    @staticmethod
    def verify_password(password: str, hashed: str) -> bool:
        """
        Verificar senha contra hash bcrypt.

        Args:
            password: Senha em texto plano
            hashed: Hash bcrypt armazenado

        Returns:
            bool: True se correspondem, False caso contrário
        """
        return bcrypt.checkpw(password.encode(), hashed.encode())

    async def create(self, dto: CreateUserDTO) -> UserResponseDTO:
        """
        Criar novo usuário.

        Args:
            dto: CreateUserDTO com dados do novo usuário

        Returns:
            UserResponseDTO: Usuário criado

        Raises:
            UserAlreadyExistsError: Se email já existe
        """
        # Validar se email já existe
        existing_user = await self.repository.get_by_email_all_states(dto.email)
        if existing_user:
            raise UserAlreadyExistsError(f"Email '{dto.email}' já está cadastrado")

        # Criar instância de User
        user = User(
            name=dto.name,
            email=dto.email,
            password=self.hash_password(dto.password),
            role=dto.role,
            is_active=True,
        )

        try:
            # Salvar no banco
            created_user = await self.repository.create(user)
            await self.repository.commit()

            # Se houver dados de perfil, criar UserProfile
            if any([dto.weight_kg, dto.height_cm, dto.age, dto.goal_type]):
                profile = UserProfile(
                    user_id=created_user.id,
                    weight_kg=dto.weight_kg,
                    height_cm=dto.height_cm,
                    age=dto.age,
                    goal_type=dto.goal_type,
                )
                self.session.add(profile)
                await self.session.commit()

            return UserResponseDTO.model_validate(created_user)
        except IntegrityError as e:
            await self.repository.rollback()
            raise UserAlreadyExistsError(
                f"Erro de integridade ao criar usuário: {str(e)}"
            )

    async def get_by_id(self, user_id: UUID) -> UserResponseDTO:
        """
        Buscar usuário por ID.

        Args:
            user_id: UUID do usuário

        Returns:
            UserResponseDTO: Dados do usuário

        Raises:
            UserNotFoundError: Se usuário não encontrado
        """
        user = await self.repository.get_by_id(user_id)
        if not user:
            raise UserNotFoundError(f"Usuário com ID {user_id} não encontrado")

        return UserResponseDTO.model_validate(user)

    async def list_all(
        self,
        page: int = 1,
        limit: int = 10,
    ) -> Tuple[List[UserResponseDTO], int]:
        """
        Listar usuários com paginação.

        Args:
            page: Número da página
            limit: Itens por página

        Returns:
            Tuple[List[UserResponseDTO], int]: Lista de usuários e total
        """
        users, total = await self.repository.list_all(page, limit)
        user_dtos = [UserResponseDTO.model_validate(user) for user in users]
        return user_dtos, total

    async def update(self, user_id: UUID, dto: UpdateUserDTO) -> UserResponseDTO:
        """
        Atualizar dados de usuário.

        Args:
            user_id: UUID do usuário
            dto: UpdateUserDTO com campos a atualizar

        Returns:
            UserResponseDTO: Usuário atualizado

        Raises:
            UserNotFoundError: Se usuário não encontrado
        """
        user = await self.repository.get_by_id(user_id)
        if not user:
            raise UserNotFoundError(f"Usuário com ID {user_id} não encontrado")

        # Atualizar apenas campos fornecidos
        if dto.name is not None:
            user.name = dto.name
        if dto.role is not None:
            user.role = dto.role
        if dto.is_active is not None:
            user.is_active = dto.is_active

        try:
            updated_user = await self.repository.update(user)
            await self.repository.commit()

            return UserResponseDTO.model_validate(updated_user)
        except IntegrityError as e:
            await self.repository.rollback()
            raise Exception(f"Erro ao atualizar usuário: {str(e)}")

    async def delete(self, user_id: UUID) -> bool:
        """
        Deletar usuário (soft delete).

        Args:
            user_id: UUID do usuário

        Returns:
            bool: True se deletado

        Raises:
            UserNotFoundError: Se usuário não encontrado
        """
        deleted = await self.repository.delete(user_id)
        if not deleted:
            raise UserNotFoundError(f"Usuário com ID {user_id} não encontrado")

        await self.repository.commit()
        return True

    async def get_by_email(self, email: str) -> Optional[UserResponseDTO]:
        """
        Buscar usuário por email (apenas ativos).

        Args:
            email: Email do usuário

        Returns:
            UserResponseDTO ou None
        """
        user = await self.repository.get_by_email(email)
        if not user:
            return None
        return UserResponseDTO.model_validate(user)
