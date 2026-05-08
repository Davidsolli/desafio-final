"""
Testes de integração para sistema de recuperação de senha.

Cobre:
- Fluxo completo forgot -> reset
- Fluxo change password autenticado
- Segurança: tokens expirados, já usados, inválidos
- Mudança de senha com invalidação de JWT
- Força de senha
"""

import pytest
import hashlib
from datetime import datetime, timedelta
from uuid import uuid4
from unittest.mock import AsyncMock, patch, MagicMock

from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker

from app.models.user import User
from app.models.password_reset_token import PasswordResetToken
from app.services.password_service import (
    PasswordService,
    PasswordValidationError,
    PasswordMismatchError,
    InvalidTokenError,
)
from app.services.email_service import EmailService, EmailSendError
from app.repositories.user_repository import UserRepository
from app.repositories.password_reset_repository import PasswordResetRepository
from app.config.settings import settings


@pytest.fixture
async def test_user(async_session):
    """Criar usuário de teste."""
    import bcrypt

    user = User(
        id=uuid4(),
        name="Test User",
        email="test@example.com",
        password=bcrypt.hashpw(b"CurrentPass123!", bcrypt.gensalt(rounds=12)).decode(),
        role="client",
        is_active=True,
        token_version=0,
    )

    async_session.add(user)
    await async_session.flush()
    await async_session.refresh(user)

    return user


@pytest.mark.asyncio
class TestForgotPasswordFlow:
    """Testes do fluxo de esqueci minha senha."""

    async def test_forgot_password_creates_token(self, async_session, test_user):
        """Forgot password deve criar token no banco."""
        service = PasswordService(async_session)

        # Gerar token
        token_raw, token_hash = PasswordService.generate_token()

        # Salvar no banco
        reset_token = PasswordResetToken(
            user_id=test_user.id,
            token_hash=token_hash,
            expires_at=datetime.utcnow() + timedelta(minutes=60),
        )

        repo = PasswordResetRepository(async_session)
        saved_token = await repo.create(reset_token)

        assert saved_token.user_id == test_user.id
        assert saved_token.token_hash == token_hash
        assert saved_token.used is False

    async def test_forgot_password_never_stores_raw_token(self, async_session, test_user):
        """Token bruto NUNCA deve ser armazenado no banco."""
        token_raw, token_hash = PasswordService.generate_token()

        # Verificar que token_raw não está no banco
        repo = PasswordResetRepository(async_session)
        saved_token = await repo.get_by_token_hash(token_hash)

        # Token raw não deve estar em nenhum lugar do objeto salvo
        assert token_raw not in str(saved_token.__dict__)


@pytest.mark.asyncio
class TestResetPasswordFlow:
    """Testes do fluxo de redefinir senha."""

    async def test_reset_password_with_valid_token(self, async_session, test_user):
        """Reset password com token válido deve funcionar."""
        service = PasswordService(async_session)

        # Gerar token
        token_raw, token_hash = PasswordService.generate_token()

        # Salvar token
        reset_token = PasswordResetToken(
            user_id=test_user.id,
            token_hash=token_hash,
            expires_at=datetime.utcnow() + timedelta(minutes=60),
        )

        repo = PasswordResetRepository(async_session)
        await repo.create(reset_token)

        # Redefinir senha
        new_password = "NewPassword123!"

        try:
            updated_user = await service.reset_password(
                token=token_raw,
                new_password=new_password,
                confirm_password=new_password,
            )

            assert updated_user.id == test_user.id
            # Token deve estar marcado como usado
            used_token = await repo.get_by_token_hash(token_hash)
            assert used_token.used is True
        except Exception as e:
            pytest.fail(f"Reset password falhou: {str(e)}")

    async def test_reset_password_with_expired_token(self, async_session, test_user):
        """Reset password com token expirado deve falhar."""
        service = PasswordService(async_session)

        # Gerar token expirado
        token_raw, token_hash = PasswordService.generate_token()
        expires_at = datetime.utcnow() - timedelta(minutes=1)  # Já expirou

        reset_token = PasswordResetToken(
            user_id=test_user.id,
            token_hash=token_hash,
            expires_at=expires_at,
        )

        repo = PasswordResetRepository(async_session)
        await repo.create(reset_token)

        # Tentar redefinir deve falhar
        with pytest.raises(InvalidTokenError, match="expirado"):
            await service.reset_password(
                token=token_raw,
                new_password="NewPassword123!",
                confirm_password="NewPassword123!",
            )

    async def test_reset_password_with_used_token(self, async_session, test_user):
        """Reset password com token já usado deve falhar."""
        service = PasswordService(async_session)

        # Gerar token
        token_raw, token_hash = PasswordService.generate_token()

        reset_token = PasswordResetToken(
            user_id=test_user.id,
            token_hash=token_hash,
            expires_at=datetime.utcnow() + timedelta(minutes=60),
            used=True,  # Já usado
            used_at=datetime.utcnow(),
        )

        repo = PasswordResetRepository(async_session)
        await repo.create(reset_token)

        # Tentar reutilizar deve falhar
        with pytest.raises(InvalidTokenError, match="já foi"):
            await service.reset_password(
                token=token_raw,
                new_password="NewPassword123!",
                confirm_password="NewPassword123!",
            )

    async def test_reset_password_with_invalid_token(self, async_session, test_user):
        """Reset password com token não existente deve falhar."""
        service = PasswordService(async_session)

        with pytest.raises(InvalidTokenError, match="inválido"):
            await service.reset_password(
                token="invalid_token_that_does_not_exist",
                new_password="NewPassword123!",
                confirm_password="NewPassword123!",
            )

    async def test_reset_password_passwords_must_match(self, async_session, test_user):
        """Reset password com senhas não conferindo deve falhar."""
        service = PasswordService(async_session)

        token_raw, token_hash = PasswordService.generate_token()

        reset_token = PasswordResetToken(
            user_id=test_user.id,
            token_hash=token_hash,
            expires_at=datetime.utcnow() + timedelta(minutes=60),
        )

        repo = PasswordResetRepository(async_session)
        await repo.create(reset_token)

        # Senhas não conferem
        with pytest.raises(PasswordMismatchError, match="não conferem"):
            await service.reset_password(
                token=token_raw,
                new_password="NewPassword123!",
                confirm_password="DifferentPassword123!",
            )

    async def test_reset_password_weak_password_rejected(self, async_session, test_user):
        """Reset password com senha fraca deve falhar."""
        service = PasswordService(async_session)

        token_raw, token_hash = PasswordService.generate_token()

        reset_token = PasswordResetToken(
            user_id=test_user.id,
            token_hash=token_hash,
            expires_at=datetime.utcnow() + timedelta(minutes=60),
        )

        repo = PasswordResetRepository(async_session)
        await repo.create(reset_token)

        # Senha fraca
        with pytest.raises(PasswordValidationError):
            await service.reset_password(
                token=token_raw,
                new_password="weakpass",
                confirm_password="weakpass",
            )


@pytest.mark.asyncio
class TestChangePasswordFlow:
    """Testes do fluxo de troca de senha autenticada."""

    async def test_change_password_valid(self, async_session, test_user):
        """Change password com dados válidos deve funcionar."""
        service = PasswordService(async_session)

        current_password = "CurrentPass123!"
        new_password = "NewPassword123!"

        updated_user = await service.change_password(
            user=test_user,
            current_password=current_password,
            new_password=new_password,
            confirm_password=new_password,
        )

        # Verificar que token_version foi incrementado
        assert updated_user.token_version == 1

    async def test_change_password_wrong_current(self, async_session, test_user):
        """Change password com senha atual errada deve falhar."""
        service = PasswordService(async_session)

        with pytest.raises(InvalidTokenError, match="incorreta"):
            await service.change_password(
                user=test_user,
                current_password="WrongPassword123!",
                new_password="NewPassword123!",
                confirm_password="NewPassword123!",
            )

    async def test_change_password_new_same_as_current(self, async_session, test_user):
        """Change password com nova igual à atual deve falhar."""
        service = PasswordService(async_session)

        with pytest.raises(PasswordMismatchError, match="diferente"):
            await service.change_password(
                user=test_user,
                current_password="CurrentPass123!",
                new_password="CurrentPass123!",  # Mesma
                confirm_password="CurrentPass123!",
            )

    async def test_change_password_passwords_not_matching(self, async_session, test_user):
        """Change password com confirma não conferindo deve falhar."""
        service = PasswordService(async_session)

        with pytest.raises(PasswordMismatchError, match="não conferem"):
            await service.change_password(
                user=test_user,
                current_password="CurrentPass123!",
                new_password="NewPassword123!",
                confirm_password="DifferentPassword123!",
            )

    async def test_change_password_weak_password(self, async_session, test_user):
        """Change password com senha fraca deve falhar."""
        service = PasswordService(async_session)

        with pytest.raises(PasswordValidationError):
            await service.change_password(
                user=test_user,
                current_password="CurrentPass123!",
                new_password="weakpass",
                confirm_password="weakpass",
            )

    async def test_change_password_increments_token_version(self, async_session, test_user):
        """Change password deve incrementar token_version."""
        service = PasswordService(async_session)

        initial_version = test_user.token_version
        new_password = "NewPassword123!"

        updated_user = await service.change_password(
            user=test_user,
            current_password="CurrentPass123!",
            new_password=new_password,
            confirm_password=new_password,
        )

        # Token version deve ter incrementado
        assert updated_user.token_version == initial_version + 1


@pytest.mark.asyncio
class TestSecurityFeatures:
    """Testes de recursos de segurança."""

    async def test_forgot_password_no_indication_user_exists(self, async_session):
        """Forgot password não deve indicar se email existe."""
        service = PasswordService(async_session)

        # Não há exceção, sempre retorna com sucesso (silenciosamente)
        await service.forgot_password(email="nonexistent@example.com")
        # Se chegou aqui, passou no teste

    async def test_token_uniqueness(self):
        """Tokens gerados devem ser únicos."""
        tokens = set()

        for _ in range(100):
            token_raw, token_hash = PasswordService.generate_token()
            tokens.add(token_hash)

        # Todos os 100 tokens devem ser únicos
        assert len(tokens) == 100

    async def test_token_cannot_be_reused(self, async_session, test_user):
        """Token deve ser marcado como usado após primeira utilização."""
        service = PasswordService(async_session)

        token_raw, token_hash = PasswordService.generate_token()

        reset_token = PasswordResetToken(
            user_id=test_user.id,
            token_hash=token_hash,
            expires_at=datetime.utcnow() + timedelta(minutes=60),
        )

        repo = PasswordResetRepository(async_session)
        await repo.create(reset_token)

        # Usar o token
        new_password = "NewPassword123!"
        await service.reset_password(
            token=token_raw,
            new_password=new_password,
            confirm_password=new_password,
        )

        # Tentar reutilizar
        with pytest.raises(InvalidTokenError):
            await service.reset_password(
                token=token_raw,
                new_password="AnotherPassword123!",
                confirm_password="AnotherPassword123!",
            )

    def test_password_strength_regex_security(self):
        """Validar que regex de força de senha é conforme especificação."""
        # Deve rejeitar senhas comuns
        weak_passwords = [
            "password",
            "123456",
            "admin",
            "qwerty",
            "abc123",
        ]

        for pwd in weak_passwords:
            assert not PasswordService.validate_password_strength(pwd)

        # Deve aceitar senhas fortes
        strong_passwords = [
            "SecurePass123!",
            "MyP@ssw0rd",
            "Test#Secure2025",
        ]

        for pwd in strong_passwords:
            assert PasswordService.validate_password_strength(pwd)
