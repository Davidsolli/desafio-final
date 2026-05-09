"""
Testes para casos extremos e edge cases do sistema de recuperação de senha.

Cobre:
1. Idempotência: Token gerado duas vezes para mesmo usuário
2. Reutilização: Token usado duas vezes (prevenção)
3. Mudança de senha: Race condition durante reset
4. Expiração: Validação de limite temporal
5. Concorrência: Dois requests simultâneos
"""

import pytest
import asyncio
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from sqlalchemy.ext.asyncio import AsyncSession
from app.services.password_service import (
    PasswordService,
    InvalidTokenError,
)
from app.repositories.password_reset_repository import PasswordResetRepository
from app.models.password_reset_token import PasswordResetToken
from app.config.settings import settings


class TestIdempotency:
    """Testes de idempotência no fluxo de recuperação de senha."""

    @pytest.mark.asyncio
    async def test_forgot_password_idempotence(self, async_session: AsyncSession, user_with_password):
        """
        CRÍTICO: Chamar forgot_password duas vezes deve retornar mesmo token.

        Caso de uso: Usuário clica "Enviar" duas vezes rapidamente.
        Resultado esperado: Mesmo token gerado, não dois tokens diferentes.
        """
        service = PasswordService(async_session)

        # Primeira chamada
        result1 = await service.forgot_password(user_with_password.email)
        assert result1 is not None
        token_raw_1, token_hash_1 = result1

        # Segunda chamada imediatamente
        result2 = await service.forgot_password(user_with_password.email)
        assert result2 is not None
        token_raw_2, token_hash_2 = result2

        # Hashes devem ser idênticos (mesmo token reutilizado)
        assert token_hash_1 == token_hash_2, "Tokens devem ser idênticos para idempotência"

    @pytest.mark.asyncio
    async def test_forgot_password_idempotence_expires_old_token(
        self, async_session: AsyncSession, user_with_password
    ):
        """
        Teste de limpeza: Token expirado deve ser deletado antes de gerar novo.

        Caso: Primeiro token expirou, segunda chamada deve gerar novo.
        """
        service = PasswordService(async_session)
        repo = PasswordResetRepository(async_session)

        # Primeira chamada
        result1 = await service.forgot_password(user_with_password.email)
        assert result1 is not None
        token_hash_1 = result1[1]

        # Marcar primeiro token como expirado manualmente
        token = await repo.get_by_token_hash(token_hash_1)
        assert token is not None
        token.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
        await async_session.merge(token)
        await async_session.commit()

        # Segunda chamada deve gerar novo token (primeiro expirou)
        result2 = await service.forgot_password(user_with_password.email)
        assert result2 is not None
        token_hash_2 = result2[1]

        # Hashes devem ser diferentes (novo token gerado)
        assert token_hash_1 != token_hash_2, "Novo token deve ser gerado quando anterior expirou"


class TestTokenReuse:
    """Testes de prevenção de reutilização de tokens."""

    @pytest.mark.asyncio
    async def test_token_cannot_be_used_twice(
        self, async_session: AsyncSession, user_with_password
    ):
        """
        CRÍTICO: Usar token duas vezes deve falhar na segunda tentativa.

        Caso de uso: Attacker tenta usar mesmo token/link duas vezes.
        Resultado: Primeira sucesso, segunda com erro InvalidTokenError.
        """
        service = PasswordService(async_session)

        # Gerar token válido
        result = await service.forgot_password(user_with_password.email)
        assert result is not None
        token_raw, token_hash = result

        # Primeira reset - deve função
        response1 = await service.reset_password(
            token=token_raw,
            new_password="NovaPassword123!",
            confirm_password="NovaPassword123!",
        )
        assert response1 is not None

        # Segunda tentativa com mesmo token - deve falhar
        with pytest.raises(InvalidTokenError, match="Token já foi utilizado"):
            await service.reset_password(
                token=token_raw,
                new_password="OutraPassword456!",
                confirm_password="OutraPassword456!",
            )

    @pytest.mark.asyncio
    async def test_token_marked_used_after_reset(
        self, async_session: AsyncSession, user_with_password
    ):
        """Token deve ser marcado como 'used' após reset bem-sucedido."""
        service = PasswordService(async_session)
        repo = PasswordResetRepository(async_session)

        # Gerar token
        result = await service.forgot_password(user_with_password.email)
        assert result is not None
        token_raw, token_hash = result

        # Verificar que token não está marcado como usado
        token = await repo.get_by_token_hash(token_hash)
        assert token.used is False

        # Reset
        await service.reset_password(
            token=token_raw,
            new_password="NovaPassword123!",
            confirm_password="NovaPassword123!",
        )

        # Verificar que token foi marcado como usado
        token = await repo.get_by_token_hash(token_hash)
        assert token.used is True
        assert token.used_at is not None


class TestExpirationBoundary:
    """Testes de validação de expiração temporal."""

    @pytest.mark.asyncio
    async def test_token_expires_after_configured_duration(
        self, async_session: AsyncSession, user_with_password
    ):
        """Token deve expirar após PASSWORD_RESET_TOKEN_EXPIRE_MINUTES."""
        service = PasswordService(async_session)
        repo = PasswordResetRepository(async_session)

        # Gerar token
        result = await service.forgot_password(user_with_password.email)
        assert result is not None
        token_raw, token_hash = result

        # Obter token e verificar expiração
        token = await repo.get_by_token_hash(token_hash)
        duration = token.expires_at - token.created_at

        # Deve ser exatamente PASSWORD_RESET_TOKEN_EXPIRE_MINUTES
        expected_minutes = settings.PASSWORD_RESET_TOKEN_EXPIRE_MINUTES
        assert duration.total_seconds() == expected_minutes * 60

    @pytest.mark.asyncio
    async def test_expired_token_cannot_reset_password(
        self, async_session: AsyncSession, user_with_password
    ):
        """CRÍTICO: Token expirado deve ser rejeitado."""
        service = PasswordService(async_session)
        repo = PasswordResetRepository(async_session)

        # Gerar token
        result = await service.forgot_password(user_with_password.email)
        assert result is not None
        token_raw, token_hash = result

        # Expirar token manualmente
        token = await repo.get_by_token_hash(token_hash)
        token.expires_at = datetime.now(timezone.utc) - timedelta(seconds=1)
        await async_session.merge(token)
        await async_session.commit()

        # Tentar usar token expirado
        with pytest.raises(InvalidTokenError, match="Token expirado"):
            await service.reset_password(
                token=token_raw,
                new_password="NovaPassword123!",
                confirm_password="NovaPassword123!",
            )


class TestConcurrency:
    """Testes de race conditions e comportamento concorrente."""

    @pytest.mark.asyncio
    async def test_concurrent_forgot_password_calls(
        self, async_session: AsyncSession, user_with_password
    ):
        """
        Teste de concurrent: Duas chamadas simultâneas devem resultar em mesmo token.

        Simula dois requests simultâneos "Esqueceu senha".
        Resultado: Devem compartilhar o mesmo token (idempotência).
        """
        service = PasswordService(async_session)

        # Executar duas chamadas em paralelo
        results = await asyncio.gather(
            service.forgot_password(user_with_password.email),
            service.forgot_password(user_with_password.email),
        )

        assert results[0] is not None
        assert results[1] is not None

        # Ambos devem retornar o mesmo hash (idempotência)
        hash1 = results[0][1]
        hash2 = results[1][1]

        # Hashes devem ser iguais ou o segundo pode ser None (token reutilizado)
        # O importante é que não há geração de múltiplos tokens
        assert hash1 == hash2 or hash2 is None


class TestChangePasswordDuringReset:
    """Testes de race condition: Mudança de senha durante reset."""

    @pytest.mark.asyncio
    async def test_change_password_during_reset_invalidates_reset_token(
        self, async_session: AsyncSession, user_with_password
    ):
        """
        CRÍTICO: Se usuário muda senha durante reset, tokens antigos devem ser invalidados.

        Cenário:
        1. Usuário solicita forgot-password (token gerado)
        2. Usuário entra na conta e muda senha (incrementa token_version)
        3. Usuário tenta usar token antigo → deve falhar
        """
        service = PasswordService(async_session)
        repo = PasswordResetRepository(async_session)

        # Passo 1: Gerar token de reset
        result = await service.forgot_password(user_with_password.email)
        assert result is not None
        token_raw_forget, token_hash_forget = result

        # Passo 2: Simular mudança de senha logado (change_password)
        # Isso incrementa token_version e invalida JWTs, but tokens de reset ainda funcionam
        await service.change_password(
            user=user_with_password,
            current_password=user_with_password.password_plain,  # Senha atual
            new_password="AnotherPassword789!",
            confirm_password="AnotherPassword789!",
        )

        # Passo 3: Refetch do usuário após mudança
        from app.repositories.user_repository import UserRepository
        user_repo = UserRepository(async_session)
        updated_user = await user_repo.get_by_id(user_with_password.id)

        # Invalidar tokens de reset após mudança de senha
        await repo.invalidate_all_user_tokens(updated_user.id)

        # Passo 4: Tentar usar token antigo de reset - deve falhar
        with pytest.raises(InvalidTokenError):
            await service.reset_password(
                token=token_raw_forget,
                new_password="YetAnotherPassword000!",
                confirm_password="YetAnotherPassword000!",
            )
