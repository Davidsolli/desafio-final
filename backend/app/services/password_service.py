"""Serviço de recuperação e redefinição de senha."""

import hashlib
import logging
import re
import secrets
from datetime import datetime, timedelta

from sqlalchemy.ext.asyncio import AsyncSession

from app.config.settings import settings
from app.models.password_reset_token import PasswordResetToken
from app.repositories.password_reset_repository import PasswordResetRepository
from app.repositories.user_repository import UserRepository
from app.services.email_service import send_password_reset_email
from app.services.user_service import UserService

logger = logging.getLogger(__name__)

_PASSWORD_REGEX = re.compile(r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&_\-]).{8,}$")


class InvalidTokenError(Exception):
    """Token inválido, expirado ou já utilizado."""


class WeakPasswordError(Exception):
    """Senha não atende aos requisitos mínimos de força."""


class PasswordMismatchError(Exception):
    """Nova senha e confirmação não conferem."""


class PasswordService:
    """Lógica de negócio para recuperação de senha."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.user_repo = UserRepository(session)
        self.token_repo = PasswordResetRepository(session)

    async def request_reset(self, email: str) -> None:
        """
        Solicita recuperação de senha.

        Nunca revela se o email existe (anti-enumeração — RN01).
        Invalida tokens anteriores e gera um novo (RN04).
        """
        user = await self.user_repo.get_by_email(email)
        if not user:
            logger.info("Solicitação de reset para email inexistente: %s", email)
            return

        plain_token, token_hash = self._generate_token()

        await self.token_repo.invalidate_previous(user.id)

        expires_at = datetime.utcnow() + timedelta(
            minutes=settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES
        )
        reset_token = PasswordResetToken(
            user_id=user.id,
            token_hash=token_hash,
            expires_at=expires_at,
        )
        await self.token_repo.create(reset_token)
        await self.token_repo.commit()

        reset_link = (
            f"{settings.FRONTEND_URL}"
            f"{settings.FRONTEND_RESET_PASSWORD_ROUTE}"
            f"?token={plain_token}"
        )

        try:
            await send_password_reset_email(
                to_email=user.email,
                to_name=user.name,
                reset_link=reset_link,
            )
        except Exception:
            logger.error("Falha ao enviar email de reset para user_id=%s", user.id)

    async def reset_password(
        self, token: str, new_password: str, confirm_password: str
    ) -> None:
        """
        Redefine a senha usando o token recebido por email.

        Raises:
            PasswordMismatchError: Senhas não conferem.
            WeakPasswordError: Senha fraca.
            InvalidTokenError: Token inválido, expirado ou já usado.
        """
        if new_password != confirm_password:
            raise PasswordMismatchError("Nova senha e confirmação não conferem")

        if not _PASSWORD_REGEX.match(new_password):
            raise WeakPasswordError(
                "A senha deve ter no mínimo 8 caracteres, letra maiúscula, "
                "minúscula, número e caractere especial (@$!%*?&_-)"
            )

        token_hash = hashlib.sha256(token.encode()).hexdigest()
        reset_token = await self.token_repo.get_by_hash(token_hash)

        if not reset_token:
            raise InvalidTokenError("Token inválido ou expirado")

        if reset_token.used:
            raise InvalidTokenError("Este token já foi utilizado")

        if reset_token.expires_at.replace(tzinfo=None) < datetime.utcnow():
            raise InvalidTokenError("Token expirado. Solicite um novo link de recuperação")

        user = await self.user_repo.get_by_id(reset_token.user_id)
        if not user:
            raise InvalidTokenError("Token inválido ou expirado")

        user.password = UserService.hash_password(new_password)
        user.token_version = (user.token_version or 0) + 1

        await self.token_repo.mark_as_used(reset_token)
        await self.token_repo.commit()

        logger.info("Senha redefinida com sucesso para user_id=%s", user.id)

    @staticmethod
    def _generate_token() -> tuple[str, str]:
        """Gera (plain_token, sha256_hash). Apenas o hash vai ao banco."""
        plain_token = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(plain_token.encode()).hexdigest()
        return plain_token, token_hash
