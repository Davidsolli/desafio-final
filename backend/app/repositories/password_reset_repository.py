"""
Repositório para gerenciar tokens de recuperação de senha.

Camada de acesso a dados para tokens temporários.
"""

from datetime import datetime, timezone
from typing import Optional
from uuid import UUID

from sqlalchemy import select, delete, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.password_reset_token import PasswordResetToken


class PasswordResetRepository:
    """Repositório para tokens de recuperação de senha."""

    def __init__(self, session: AsyncSession):
        """Inicializar repositório com sessão async."""
        self.session = session

    async def create(self, token: PasswordResetToken) -> PasswordResetToken:
        """
        Criar novo token de reset.

        Args:
            token: Objeto PasswordResetToken

        Returns:
            PasswordResetToken criado com id populado

        Raises:
            IntegrityError: Se token_hash já existe (único)
        """
        self.session.add(token)
        await self.session.flush()
        await self.session.refresh(token)
        return token

    async def get_by_token_hash(self, token_hash: str) -> Optional[PasswordResetToken]:
        """
        Buscar token por hash.

        Args:
            token_hash: Hash SHA256 do token

        Returns:
            PasswordResetToken ou None se não encontrado
        """
        query = select(PasswordResetToken).where(
            PasswordResetToken.token_hash == token_hash
        )
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def get_by_id(self, token_id: UUID) -> Optional[PasswordResetToken]:
        """
        Buscar token por ID.

        Args:
            token_id: UUID do token

        Returns:
            PasswordResetToken ou None se não encontrado
        """
        return await self.session.get(PasswordResetToken, token_id)

    async def mark_as_used(self, token: PasswordResetToken) -> PasswordResetToken:
        """
        Marcar token como utilizado.

        Args:
            token: Token a ser marcado

        Returns:
            Token atualizado
        """
        token.used = True
        token.used_at = datetime.now(timezone.utc)
        merged = await self.session.merge(token)
        await self.session.flush()
        await self.session.refresh(merged)
        return merged

    async def delete_expired(self) -> int:
        """
        Deletar tokens expirados.

        Returns:
            Número de tokens deletados
        """
        query = delete(PasswordResetToken).where(
            PasswordResetToken.expires_at <= datetime.now(timezone.utc)
        )
        result = await self.session.execute(query)
        return result.rowcount

    async def get_by_user_id(self, user_id: UUID) -> list[PasswordResetToken]:
        """
        Buscar todos os tokens de um usuário.

        Args:
            user_id: UUID do usuário

        Returns:
            Lista de tokens (ativos e inativos)
        """
        query = select(PasswordResetToken).where(
            PasswordResetToken.user_id == user_id
        ).order_by(PasswordResetToken.created_at.desc())
        result = await self.session.execute(query)
        return result.scalars().all()

    async def get_active_by_user(self, user_id: UUID) -> Optional[PasswordResetToken]:
        """
        Buscar token ativo (não usado e não expirado) de um usuário.

        Garante idempotência: se houver token válido para o mesmo usuário,
        reutilizar em vez de gerar novo.

        Args:
            user_id: UUID do usuário

        Returns:
            PasswordResetToken ativo ou None se não há
        """
        query = select(PasswordResetToken).where(
            and_(
                PasswordResetToken.user_id == user_id,
                PasswordResetToken.used == False,
                PasswordResetToken.expires_at > datetime.now(timezone.utc),
            )
        ).order_by(PasswordResetToken.created_at.desc())
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def delete_by_token_hash(self, token_hash: str) -> bool:
        """
        Deletar token específico por hash.

        Args:
            token_hash: Hash SHA256 do token

        Returns:
            True se deletou, False se não encontrou
        """
        query = delete(PasswordResetToken).where(
            PasswordResetToken.token_hash == token_hash
        )
        result = await self.session.execute(query)
        return result.rowcount > 0

    async def invalidate_all_user_tokens(self, user_id: UUID) -> int:
        """
        Invalidar todos os tokens de um usuário (marcar como usado).

        Args:
            user_id: UUID do usuário

        Returns:
            Número de tokens invalidados
        """
        query = delete(PasswordResetToken).where(
            and_(
                PasswordResetToken.user_id == user_id,
                PasswordResetToken.used == False,
            )
        )
        result = await self.session.execute(query)
        return result.rowcount

    async def commit(self) -> None:
        """Fazer commit da transação."""
        await self.session.commit()

    async def rollback(self) -> None:
        """Fazer rollback da transação."""
        await self.session.rollback()
