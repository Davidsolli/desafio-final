"""
Repository para operações de banco de dados relacionadas a convites.

Fornece métodos para CRUD de invitations de forma assíncrona.
"""

from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.invitation import Invitation


class InvitationRepository:
    """Repository para gerenciar convites no banco de dados."""

    def __init__(self, session: AsyncSession):
        """Inicializar repository com sessão async."""
        self.session = session

    async def create(self, invitation: Invitation) -> Invitation:
        """
        Criar novo convite.

        Args:
            invitation: Objeto Invitation a ser salvo

        Returns:
            Invitation: Convite criado com ID gerado
        """
        self.session.add(invitation)
        await self.session.flush()
        return invitation

    async def get_by_code(self, code: str) -> Invitation | None:
        """
        Buscar convite por código.

        Args:
            code: Código do convite

        Returns:
            Invitation ou None se não encontrado
        """
        stmt = select(Invitation).where(Invitation.code == code)
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def get_by_id(self, invitation_id: UUID) -> Invitation | None:
        """
        Buscar convite por ID.

        Args:
            invitation_id: UUID do convite

        Returns:
            Invitation ou None se não encontrado
        """
        return await self.session.get(Invitation, invitation_id)

    async def get_by_trainer(self, trainer_id: UUID) -> list[Invitation]:
        """
        Listar todos os convites de um personal trainer.

        Args:
            trainer_id: UUID do personal trainer

        Returns:
            Lista de Invitations ordenadas por data de criação (mais recentes primeiro)
        """
        stmt = (
            select(Invitation)
            .where(Invitation.trainer_id == trainer_id)
            .order_by(Invitation.created_at.desc())
        )
        result = await self.session.execute(stmt)
        return result.scalars().all()

    async def update(self, invitation: Invitation) -> Invitation:
        """
        Atualizar convite existente.

        Args:
            invitation: Objeto Invitation com dados atualizados

        Returns:
            Invitation: Convite atualizado
        """
        await self.session.merge(invitation)
        return invitation

    async def commit(self) -> None:
        """Confirmar transação."""
        await self.session.commit()

    async def rollback(self) -> None:
        """Reverter transação."""
        await self.session.rollback()
