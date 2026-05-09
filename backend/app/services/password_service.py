"""
Serviço de gerenciamento de recuperação e troca de senha.

Responsável por:
- Geração segura de tokens
- Validação de força de senha
- Lógica de reset e change password
- Incremento de token_version para invalidar JWTs
"""

import secrets
import hashlib
import re
import bcrypt
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.config.settings import settings
from app.models.user import User
from app.models.password_reset_token import PasswordResetToken
from app.repositories.user_repository import UserRepository
from app.repositories.password_reset_repository import PasswordResetRepository


class PasswordValidationError(Exception):
    """Exceção quando senha não atende requisitos de força."""

    pass


class PasswordMismatchError(Exception):
    """Exceção quando senhas não conferem."""

    pass


class InvalidTokenError(Exception):
    """Exceção quando token é inválido, expirado ou já usado."""

    pass


class PasswordService:
    """Serviço de gerenciamento de senhas."""

    # Regex para validar força de senha: 8+ chars, maiúscula, minúscula, número, especial
    PASSWORD_STRENGTH_REGEX = re.compile(
        r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&_\-])[a-zA-Z\d@$!%*?&_\-]{8,}$"
    )

    def __init__(self, session: AsyncSession):
        """Inicializar serviço com sessão async."""
        self.session = session
        self.user_repo = UserRepository(session)
        self.token_repo = PasswordResetRepository(session)

    @staticmethod
    def generate_token() -> Tuple[str, str]:
        """
        Gerar token seguro e seu hash SHA256.

        Returns:
            Tupla (token_raw, token_hash):
            - token_raw: Token aleatório (enviado por email)
            - token_hash: Hash SHA256 (salvo no banco)
        """
        token_raw = secrets.token_urlsafe(32)
        token_hash = hashlib.sha256(token_raw.encode()).hexdigest()
        return token_raw, token_hash

    @staticmethod
    def validate_password_strength(password: str) -> bool:
        """
        Validar força de senha.

        Requisitos:
        - Mínimo 8 caracteres
        - Pelo menos uma letra maiúscula
        - Pelo menos uma letra minúscula
        - Pelo menos um número
        - Pelo menos um caractere especial (@$!%*?&_-)

        Args:
            password: Senha a validar

        Returns:
            True se válida, False caso contrário
        """
        return bool(PasswordService.PASSWORD_STRENGTH_REGEX.match(password))

    @staticmethod
    def is_different_from_current(new_password: str, current_hash: str) -> bool:
        """
        Verificar se nova senha é diferente da atual.

        Args:
            new_password: Nova senha em texto plano
            current_hash: Hash bcrypt da senha atual

        Returns:
            True se diferente, False se igual
        """
        return not bcrypt.checkpw(new_password.encode(), current_hash.encode())

    async def forgot_password(self, email: str) -> Tuple[str, str] | None:
        """
        Iniciar recuperação de senha por email.

        IMPORTANTE: Sempre retorna sucesso (HTTP 200) sem indicar se email existe.
        Isso previne enumeração de emails.

        Se houver token ativo, ele é invalidado e um novo é gerado para garantir
        que o token_raw sempre esteja disponível para envio no email.

        Args:
            email: Email do usuário

        Returns:
            Tupla (token_raw, token_hash) se email existe, None caso contrário

        Raises:
            Nunca lança exceções (proteção contra enumeração)
        """
        try:
            user = await self.user_repo.get_by_email(email)
            if not user:
                return None

            # Invalidar token ativo anterior, se existir, antes de gerar novo.
            # Não é possível reutilizá-lo pois o token_raw (enviado ao usuário)
            # não é armazenado no banco — apenas o hash SHA256.
            existing_token = await self.token_repo.get_active_by_user(user.id)
            if existing_token:
                await self.token_repo.invalidate_all_user_tokens(user.id)
                await self.token_repo.commit()

            # Gerar novo token
            token_raw, token_hash = self.generate_token()
            expires_at = datetime.now(timezone.utc) + timedelta(
                minutes=settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES
            )

            # Criar registro no banco
            reset_token = PasswordResetToken(
                user_id=user.id,
                token_hash=token_hash,
                expires_at=expires_at,
            )
            await self.token_repo.create(reset_token)
            await self.token_repo.commit()

            # Retornar token para o controller enviar
            return token_raw, token_hash
        except Exception:
            return None

    async def reset_password(
        self,
        token: str,
        new_password: str,
        confirm_password: str,
    ) -> User:
        """
        Redefinir senha usando token de recuperação.

        Args:
            token: Token temporário (enviado por email)
            new_password: Nova senha
            confirm_password: Confirmação da nova senha

        Returns:
            Usuário com senha atualizada

        Raises:
            PasswordMismatchError: Senhas não conferem
            PasswordValidationError: Senha não atende requisitos
            InvalidTokenError: Token inválido, expirado ou já usado
        """
        if new_password != confirm_password:
            raise PasswordMismatchError("As senhas não conferem")

        if not self.validate_password_strength(new_password):
            raise PasswordValidationError(
                "Senha deve ter 8+ caracteres, maiúscula, minúscula, número e caractere especial"
            )

        # Hash do token recebido
        token_hash = hashlib.sha256(token.encode()).hexdigest()

        # Buscar token no banco
        reset_token = await self.token_repo.get_by_token_hash(token_hash)
        if not reset_token:
            raise InvalidTokenError("Token inválido")

        # Validar expiração
        if reset_token.expires_at <= datetime.now(timezone.utc):
            raise InvalidTokenError("Token expirado")

        # Validar uso único
        if reset_token.used:
            raise InvalidTokenError("Token já foi utilizado")

        # Buscar usuário
        user = await self.user_repo.get_by_id(reset_token.user_id)
        if not user:
            raise InvalidTokenError("Usuário não encontrado")

        # Hash da nova senha com bcrypt
        salt = bcrypt.gensalt(rounds=12)
        new_password_hash = bcrypt.hashpw(new_password.encode(), salt).decode()

        # Atualizar senha e incrementar token_version
        user.password = new_password_hash
        user.token_version += 1

        # Marcar token como usado
        await self.token_repo.mark_as_used(reset_token)

        # Salvar alterações
        updated_user = await self.user_repo.update(user)
        await self.user_repo.commit()

        return updated_user

    async def change_password(
        self,
        user: User,
        current_password: str,
        new_password: str,
        confirm_password: str,
    ) -> User:
        """
        Trocar senha para usuário autenticado.

        Args:
            user: Usuário autenticado
            current_password: Senha atual (validação)
            new_password: Nova senha
            confirm_password: Confirmação da nova senha

        Returns:
            Usuário com senha atualizada

        Raises:
            PasswordMismatchError: Passwords não conferem ou nova igual à atual
            PasswordValidationError: Senha não atende requisitos
            InvalidTokenError: Senha atual incorreta
        """
        # Validar senha atual
        if not bcrypt.checkpw(current_password.encode(), user.password.encode()):
            raise InvalidTokenError("Senha atual incorreta")

        # Validar que nova não é igual à atual
        if not self.is_different_from_current(new_password, user.password):
            raise PasswordMismatchError("Nova senha deve ser diferente da atual")

        # Validar confirmação
        if new_password != confirm_password:
            raise PasswordMismatchError("As senhas não conferem")

        # Validar força
        if not self.validate_password_strength(new_password):
            raise PasswordValidationError(
                "Senha deve ter 8+ caracteres, maiúscula, minúscula, número e caractere especial"
            )

        # Hash da nova senha com bcrypt
        salt = bcrypt.gensalt(rounds=12)
        new_password_hash = bcrypt.hashpw(new_password.encode(), salt).decode()

        # Atualizar senha e incrementar token_version
        user.password = new_password_hash
        user.token_version += 1

        # Invalidar todos os tokens de reset pendentes (opcional, melhora segurança)
        await self.token_repo.invalidate_all_user_tokens(user.id)

        # Salvar alterações
        updated_user = await self.user_repo.update(user)
        await self.user_repo.commit()

        return updated_user

    async def cleanup_expired_tokens(self) -> int:
        """
        Limpar tokens expirados do banco de dados.

        Pode ser executado periodicamente via background task.

        Returns:
            Número de tokens deletados
        """
        deleted_count = await self.token_repo.delete_expired()
        await self.token_repo.commit()
        return deleted_count
