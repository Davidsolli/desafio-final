"""Repositório para tokens de recuperação de senha."""

from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import delete, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.password_reset_token import PasswordResetToken


class PasswordResetRepository:
    """CRUD para a tabela password_reset_tokens."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def create(self, token: PasswordResetToken) -> PasswordResetToken:
        self.session.add(token)
        await self.session.flush()
        return token

    async def get_by_hash(self, token_hash: str) -> PasswordResetToken | None:
        result = await self.session.execute(
            select(PasswordResetToken).where(PasswordResetToken.token_hash == token_hash)
        )
        return result.scalar_one_or_none()

    async def invalidate_previous(self, user_id: UUID) -> None:
        """Marca como usados todos os tokens ativos do usuário."""
        await self.session.execute(
            update(PasswordResetToken)
            .where(
                PasswordResetToken.user_id == user_id,
                PasswordResetToken.used == False,  # noqa: E712
            )
            .values(used=True, used_at=datetime.now(timezone.utc))
        )

    async def mark_as_used(self, token: PasswordResetToken) -> None:
        token.used = True
        token.used_at = datetime.now(timezone.utc)

    async def delete_expired(self) -> None:
        """Remove tokens expirados para manter a tabela limpa."""
        await self.session.execute(
            delete(PasswordResetToken).where(
                PasswordResetToken.expires_at < datetime.now(timezone.utc)
            )
        )

    async def commit(self) -> None:
        await self.session.commit()

    async def rollback(self) -> None:
        await self.session.rollback()
