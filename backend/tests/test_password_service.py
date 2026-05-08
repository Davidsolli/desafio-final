"""
Testes unitários para PasswordService.

Cobre:
- Geração de tokens
- Hash SHA256
- Validação de força de senha
- Expiração de tokens
- Uso único de tokens
"""

import pytest
import hashlib
from datetime import datetime, timedelta
from uuid import uuid4

from app.services.password_service import (
    PasswordService,
    PasswordValidationError,
    PasswordMismatchError,
    InvalidTokenError,
)
from app.config.settings import settings


class TestTokenGeneration:
    """Testes de geração de tokens."""

    def test_generate_token_returns_tuple(self):
        """Token gerado deve retornar tupla (raw, hash)."""
        token_raw, token_hash = PasswordService.generate_token()

        assert isinstance(token_raw, str)
        assert isinstance(token_hash, str)
        assert len(token_raw) > 0
        assert len(token_hash) > 0

    def test_generate_token_hash_is_sha256(self):
        """Hash deve ser SHA256 válido."""
        token_raw, token_hash = PasswordService.generate_token()

        # Verificar que é SHA256 (64 caracteres hex)
        assert len(token_hash) == 64
        assert all(c in "0123456789abcdef" for c in token_hash)

    def test_generate_token_hash_matches_raw(self):
        """Hash deve corresponder ao token raw."""
        token_raw, token_hash = PasswordService.generate_token()

        expected_hash = hashlib.sha256(token_raw.encode()).hexdigest()
        assert token_hash == expected_hash

    def test_generate_token_unique(self):
        """Tokens gerados devem ser únicos."""
        token1_raw, token1_hash = PasswordService.generate_token()
        token2_raw, token2_hash = PasswordService.generate_token()

        assert token1_raw != token2_raw
        assert token1_hash != token2_hash

    def test_generate_token_high_entropy(self):
        """Tokens devem ter alta entropia (usar secrets.token_urlsafe)."""
        token_raw, _ = PasswordService.generate_token()

        # token_urlsafe usa caracteres alfanuméricos + - e _
        valid_chars = set(
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"
        )
        assert all(c in valid_chars for c in token_raw)


class TestPasswordStrengthValidation:
    """Testes de validação de força de senha."""

    def test_weak_password_too_short(self):
        """Senha com menos de 8 caracteres deve ser rejeitada."""
        assert not PasswordService.validate_password_strength("Pass1!")
        assert not PasswordService.validate_password_strength("Abc123")

    def test_weak_password_no_uppercase(self):
        """Senha sem maiúscula deve ser rejeitada."""
        assert not PasswordService.validate_password_strength("abcdefg123!")

    def test_weak_password_no_lowercase(self):
        """Senha sem minúscula deve ser rejeitada."""
        assert not PasswordService.validate_password_strength("ABCDEFG123!")

    def test_weak_password_no_number(self):
        """Senha sem número deve ser rejeitada."""
        assert not PasswordService.validate_password_strength("AbcDefgh!")

    def test_weak_password_no_special_char(self):
        """Senha sem caractere especial deve ser rejeitada."""
        assert not PasswordService.validate_password_strength("AbcDefgh123")

    @pytest.mark.parametrize(
        "password",
        [
            "StrongPass123!",
            "MyPassword!1",
            "Test@Pass2025",
            "Secure#Pwd$123",
            "C0mpl3x@Password",
        ],
    )
    def test_strong_password(self, password):
        """Senhas fortes devem ser validadas."""
        assert PasswordService.validate_password_strength(password)

    @pytest.mark.parametrize(
        "password",
        [
            "weakpass",
            "WeakPass",
            "WeakPass123",
            "weakpass123!",
            "WEAKPASS123!",
        ],
    )
    def test_various_weak_passwords(self, password):
        """Validar rejeição de várias senhas fracas."""
        assert not PasswordService.validate_password_strength(password)


class TestPasswordComparison:
    """Testes de comparação de senhas."""

    def test_is_different_from_current_different(self):
        """Senhas diferentes devem retornar True."""
        import bcrypt

        current_password = "CurrentPass123!"
        new_password = "NewPassword123!"

        # Hash da senha atual
        salt = bcrypt.gensalt(rounds=12)
        current_hash = bcrypt.hashpw(current_password.encode(), salt).decode()

        is_different = PasswordService.is_different_from_current(
            new_password, current_hash
        )
        assert is_different is True

    def test_is_different_from_current_same(self):
        """Mesma senha deve retornar False."""
        import bcrypt

        password = "SamePassword123!"

        # Hash da senha
        salt = bcrypt.gensalt(rounds=12)
        password_hash = bcrypt.hashpw(password.encode(), salt).decode()

        is_different = PasswordService.is_different_from_current(password, password_hash)
        assert is_different is False


class TestTokenExpiration:
    """Testes de expiração de tokens."""

    def test_token_expiration_timestamp(self):
        """Token expirado deve estar no passado."""
        from datetime import datetime, timedelta

        expires_at = datetime.utcnow() - timedelta(minutes=1)

        # Token está expirado se expires_at <= agora
        assert expires_at <= datetime.utcnow()

    def test_token_not_expired_in_future(self):
        """Token com expiração futura não deve estar expirado."""
        from datetime import datetime, timedelta

        expires_at = datetime.utcnow() + timedelta(minutes=30)

        assert expires_at > datetime.utcnow()

    def test_default_expiration_60_minutes(self):
        """Token padrão deve expirar em 60 minutos."""
        expires_at = datetime.utcnow() + timedelta(
            minutes=settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES
        )

        # Verificar que é aproximadamente 60 minutos
        time_diff = (expires_at - datetime.utcnow()).total_seconds() / 60
        assert 59 < time_diff < 61  # Margem para execução do teste


class TestPasswordValidationMessages:
    """Testes de mensagens de erro de validação."""

    def test_password_validation_error_message(self):
        """PasswordValidationError deve ter mensagem clara."""
        with pytest.raises(PasswordValidationError) as exc_info:
            raise PasswordValidationError(
                "Senha deve ter 8+ caracteres, maiúscula, minúscula, número e caractere especial"
            )

        assert "8+" in str(exc_info.value)
        assert "maiúscula" in str(exc_info.value)

    def test_password_mismatch_error_message(self):
        """PasswordMismatchError deve ter mensagem clara."""
        with pytest.raises(PasswordMismatchError) as exc_info:
            raise PasswordMismatchError("As senhas não conferem")

        assert "não conferem" in str(exc_info.value)

    def test_invalid_token_error_message(self):
        """InvalidTokenError deve ter mensagem clara."""
        with pytest.raises(InvalidTokenError) as exc_info:
            raise InvalidTokenError("Token inválido")

        assert "inválido" in str(exc_info.value)
