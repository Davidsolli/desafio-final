"""
Repositório de Usuários.

Camada de acesso aos dados com CRUD operations usando SQLAlchemy ORM.
Todos os métodos são async e usam apenas ORM queries, sem SQL bruto.
"""

from typing import Optional, List, Tuple
from uuid import UUID

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import User


class UserRepository:
    """Repositório para operações CRUD de usuários."""

    def __init__(self, session: AsyncSession):
        """Inicializar repositório com sessão async."""
        self.session = session

    async def create(self, user: User) -> User:
        """
        Criar novo usuário no banco.

        Args:
            user: Instância de User com dados preenchidos

        Returns:
            User: Usuário criado com ID gerado

        Raises:
            sqlalchemy.exc.IntegrityError: Se email duplicado ou erro de constraint
        """
        self.session.add(user)
        await self.session.flush()
        await self.session.refresh(user)
        return user

    async def get_by_id(self, user_id: UUID) -> Optional[User]:
        """
        Buscar usuário por ID (apenas ativos).

        Args:
            user_id: UUID do usuário

        Returns:
            User ou None se não encontrado
        """
        query = select(User).where(
            User.id == user_id,
            User.is_active == True,
        )
        result = await self.session.execute(query)
        return result.scalars().first()

    async def get_by_email(self, email: str) -> Optional[User]:
        """
        Buscar usuário por email (apenas ativos).

        Args:
            email: Email do usuário

        Returns:
            User ou None se não encontrado
        """
        from sqlalchemy import func
        query = select(User).where(
            func.lower(User.email) == email.lower(),
            User.is_active == True,
        )
        result = await self.session.execute(query)
        return result.scalars().first()

    async def get_by_id_all_states(self, user_id: UUID) -> Optional[User]:
        """
        Buscar usuário por ID (ativo ou inativo).

        Útil para atualizar usuários inativos (ex: reativar).

        Args:
            user_id: UUID do usuário

        Returns:
            User ou None se não encontrado
        """
        query = select(User).where(User.id == user_id)
        result = await self.session.execute(query)
        return result.scalars().first()

    async def get_by_email_all_states(self, email: str) -> Optional[User]:
        """
        Buscar usuário por email (ativo ou inativo).

        Útil para validar se email existe antes de criar novo usuário.

        Args:
            email: Email do usuário

        Returns:
            User ou None se não encontrado
        """
        from sqlalchemy import func
        query = select(User).where(func.lower(User.email) == email.lower())
        result = await self.session.execute(query)
        return result.scalars().first()

    async def list_all(
        self,
        page: int = 1,
        limit: int = 10,
        role: Optional[str] = None,
        trainer_id: Optional[UUID] = None,
        include_inactive: bool = False,
    ) -> Tuple[List[User], int]:
        """
        Listar usuários com paginação.

        Args:
            page: Número da página (começa em 1)
            limit: Itens por página
            role: Filtrar por role (admin, personal_trainer, client)
            trainer_id: Filtrar alunos de um trainer específico
            include_inactive: Se True, inclui usuários inativos (padrão: False, apenas ativos)

        Returns:
            Tuple[List[User], int]: Lista de usuários e total de registros
        """
        # Validar limites
        if limit > 100:
            limit = 100
        if page < 1:
            page = 1

        offset = (page - 1) * limit

        # Construir where clause com filtros opcionais
        where_conditions = []
        if not include_inactive:
            where_conditions.append(User.is_active == True)
        if role:
            where_conditions.append(User.role == role)
        if trainer_id:
            where_conditions.append(User.trainer_id == trainer_id)

        # Query para contar total
        count_query = select(func.count(User.id)).where(*where_conditions)
        count_result = await self.session.execute(count_query)
        total = count_result.scalar()

        # Query para buscar registros
        query = (
            select(User)
            .where(*where_conditions)
            .order_by(User.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        result = await self.session.execute(query)
        users = result.scalars().all()

        return users, total

    async def update(self, user: User) -> User:
        """
        Atualizar usuário no banco.

        Args:
            user: Instância de User com dados atualizados

        Returns:
            User: Usuário atualizado
        """
        await self.session.merge(user)
        await self.session.flush()
        await self.session.refresh(user)
        return user

    async def delete(self, user_id: UUID) -> bool:
        """
        Deletar usuário (soft delete - marcar como inativo).

        Args:
            user_id: UUID do usuário

        Returns:
            bool: True se deletado, False se não encontrado
        """
        user = await self.get_by_id(user_id)
        if not user:
            return False

        user.is_active = False
        await self.session.merge(user)
        await self.session.flush()
        return True

    async def hard_delete(self, user_id: UUID) -> bool:
        """
        Hard delete: remover usuário permanentemente do banco.

        USAR COM CUIDADO! Apenas em testes ou casos específicos.

        Args:
            user_id: UUID do usuário

        Returns:
            bool: True se removido, False se não encontrado
        """
        query = select(User).where(User.id == user_id)
        result = await self.session.execute(query)
        user = result.scalars().first()

        if not user:
            return False

        await self.session.delete(user)
        await self.session.flush()
        return True

    async def list_by_trainer(
        self,
        trainer_id: UUID = None,
        page: int = 1,
        limit: int = 10,
    ) -> Tuple[List[User], int]:
        """
        Listar usuários (alunos) de um personal trainer específico ou todos.

        Args:
            trainer_id: UUID do personal trainer. Se None, retorna todos os alunos
            page: Número da página (começa em 1)
            limit: Itens por página

        Returns:
            Tuple[List[User], int]: Lista de alunos e total de registros
        """
        if limit > 100:
            limit = 100
        if page < 1:
            page = 1

        offset = (page - 1) * limit

        # Construir condição dinamicamente
        conditions = [
            User.role == "client",
            User.is_active == True,
        ]
        if trainer_id is not None:
            conditions.append(User.trainer_id == trainer_id)

        # Query para contar total
        count_query = select(func.count(User.id)).where(*conditions)
        count_result = await self.session.execute(count_query)
        total = count_result.scalar()

        # Query para buscar registros
        query = (
            select(User)
            .where(*conditions)
            .order_by(User.created_at.desc())
            .offset(offset)
            .limit(limit)
        )
        result = await self.session.execute(query)
        users = result.scalars().all()

        return users, total

    async def commit(self) -> None:
        """Commitar transação."""
        await self.session.commit()

    async def rollback(self) -> None:
        """Reverter transação."""
        await self.session.rollback()
