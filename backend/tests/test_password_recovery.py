"""Testes de integração para recuperação e redefinição de senha."""

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, patch

import pytest
import pytest_asyncio
from sqlalchemy import select

from app.models.password_reset_token import PasswordResetToken


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def reset_rate_limiter():
    """Zera contadores do rate limiter antes de cada teste."""
    from app.config.limiter import limiter
    limiter._limiter.storage.reset()
    yield


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_token() -> tuple[str, str]:
    """Gera (plain_token, token_hash) para uso direto nos testes."""
    plain = secrets.token_urlsafe(32)
    token_hash = hashlib.sha256(plain.encode()).hexdigest()
    return plain, token_hash


async def _insert_token(
    session,
    user_id,
    *,
    used: bool = False,
    expired: bool = False,
) -> str:
    """Insere token no banco e retorna o plain token."""
    plain, token_hash = _make_token()
    now = datetime.now(timezone.utc)
    expires_at = now - timedelta(hours=1) if expired else now + timedelta(hours=1)
    token = PasswordResetToken(
        user_id=user_id,
        token_hash=token_hash,
        expires_at=expires_at,
        used=used,
    )
    session.add(token)
    await session.commit()
    return plain


# ---------------------------------------------------------------------------
# Testes de POST /api/v1/auth/forgot-password
# ---------------------------------------------------------------------------

class TestForgotPassword:
    """11 cenários para o endpoint de solicitação de recuperação."""

    @pytest.mark.asyncio
    async def test_email_valido_retorna_200(self, async_client, sample_user):
        """Teste 1: Email cadastrado → 200 com mensagem genérica."""
        with patch(
            "app.services.password_service.send_password_reset_email",
            new_callable=AsyncMock,
        ):
            response = await async_client.post(
                "/api/v1/auth/forgot-password",
                json={"email": sample_user.email},
            )
        assert response.status_code == 200
        assert "Se existir uma conta" in response.json()["message"]

    @pytest.mark.asyncio
    async def test_email_inexistente_retorna_mesmo_200(self, async_client):
        """Teste 2: Email não cadastrado → mesmo 200 (anti-enumeração RN01)."""
        with patch(
            "app.services.password_service.send_password_reset_email",
            new_callable=AsyncMock,
        ):
            response = await async_client.post(
                "/api/v1/auth/forgot-password",
                json={"email": "usuario.inexistente@example.com"},
            )
        assert response.status_code == 200
        assert "Se existir uma conta" in response.json()["message"]

    @pytest.mark.asyncio
    async def test_email_formato_invalido_retorna_422(self, async_client):
        """Teste 3: Email em formato inválido → 422."""
        response = await async_client.post(
            "/api/v1/auth/forgot-password",
            json={"email": "nao-e-um-email"},
        )
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_body_vazio_retorna_422(self, async_client):
        """Teste 4: Body ausente → 422."""
        response = await async_client.post("/api/v1/auth/forgot-password", json={})
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_requisicao_cria_token_no_banco(
        self, async_client, sample_user, test_db_session
    ):
        """Teste 5: Requisição com email válido cria token quando email é enviado."""
        with patch(
            "app.services.password_service.send_password_reset_email",
            new_callable=AsyncMock,
        ):
            await async_client.post(
                "/api/v1/auth/forgot-password",
                json={"email": sample_user.email},
            )

        result = await test_db_session.execute(
            select(PasswordResetToken).where(
                PasswordResetToken.user_id == sample_user.id,
                PasswordResetToken.used == False,  # noqa: E712
            )
        )
        token = result.scalar_one_or_none()
        assert token is not None

    @pytest.mark.asyncio
    async def test_segundo_pedido_invalida_primeiro_token(
        self, async_client, sample_user, test_db_session
    ):
        """Teste 6: Segundo pedido invalida tokens anteriores (RN04)."""
        with patch(
            "app.services.password_service.send_password_reset_email",
            new_callable=AsyncMock,
        ):
            await async_client.post(
                "/api/v1/auth/forgot-password",
                json={"email": sample_user.email},
            )
            await async_client.post(
                "/api/v1/auth/forgot-password",
                json={"email": sample_user.email},
            )

        result = await test_db_session.execute(
            select(PasswordResetToken).where(
                PasswordResetToken.user_id == sample_user.id,
                PasswordResetToken.used == False,  # noqa: E712
            )
        )
        # Apenas 1 token ativo — o mais recente
        active = result.scalars().all()
        assert len(active) == 1

    @pytest.mark.asyncio
    async def test_falha_no_email_nao_deixa_token_orfao(
        self, async_client, sample_user, test_db_session
    ):
        """Teste 7: Se o email falha, o token não fica salvo no banco."""
        # Cache antes do request: o rollback interno expira o objeto ORM,
        # causando MissingGreenlet se acessado depois via lazy-load.
        user_id = sample_user.id

        with patch(
            "app.services.password_service.send_password_reset_email",
            new_callable=AsyncMock,
            side_effect=Exception("Resend indisponível"),
        ):
            response = await async_client.post(
                "/api/v1/auth/forgot-password",
                json={"email": sample_user.email},
            )

        # API continua retornando 200 (anti-enumeração)
        assert response.status_code == 200

        result = await test_db_session.execute(
            select(PasswordResetToken).where(
                PasswordResetToken.user_id == user_id,
                PasswordResetToken.used == False,  # noqa: E712
            )
        )
        # Nenhum token órfão — rollback foi executado
        assert result.scalar_one_or_none() is None


# ---------------------------------------------------------------------------
# Testes de POST /api/v1/auth/reset-password
# ---------------------------------------------------------------------------

class TestResetPassword:
    """Testes para o endpoint de redefinição de senha."""

    @pytest.mark.asyncio
    async def test_token_valido_senha_forte_retorna_200(
        self, async_client, sample_user, test_db_session
    ):
        """Teste 1: Token válido + senha forte → 200."""
        plain = await _insert_token(test_db_session, sample_user.id)
        response = await async_client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": plain,
                "new_password": "NovaSenha456!",
                "confirm_password": "NovaSenha456!",
            },
        )
        assert response.status_code == 200
        assert "Senha redefinida" in response.json()["message"]

    @pytest.mark.asyncio
    async def test_token_marcado_como_usado_apos_reset(
        self, async_client, sample_user, test_db_session
    ):
        """Teste 2: Após reset bem-sucedido, token.used == True."""
        plain = await _insert_token(test_db_session, sample_user.id)
        await async_client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": plain,
                "new_password": "NovaSenha456!",
                "confirm_password": "NovaSenha456!",
            },
        )
        token_hash = hashlib.sha256(plain.encode()).hexdigest()
        result = await test_db_session.execute(
            select(PasswordResetToken).where(PasswordResetToken.token_hash == token_hash)
        )
        token = result.scalar_one()
        assert token.used is True
        assert token.used_at is not None

    @pytest.mark.asyncio
    async def test_token_expirado_retorna_400(
        self, async_client, sample_user, test_db_session
    ):
        """Teste 3: Token expirado → 400 com mensagem de expiração (RN02)."""
        plain = await _insert_token(test_db_session, sample_user.id, expired=True)
        response = await async_client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": plain,
                "new_password": "NovaSenha456!",
                "confirm_password": "NovaSenha456!",
            },
        )
        assert response.status_code == 400
        assert "xpirado" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_token_ja_utilizado_retorna_400(
        self, async_client, sample_user, test_db_session
    ):
        """Teste 4: Token já utilizado → 400 (RN03)."""
        plain = await _insert_token(test_db_session, sample_user.id, used=True)
        response = await async_client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": plain,
                "new_password": "NovaSenha456!",
                "confirm_password": "NovaSenha456!",
            },
        )
        assert response.status_code == 400
        assert "utilizado" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_token_inventado_retorna_400(self, async_client):
        """Teste 5: Token adulterado ou inventado → 400."""
        response = await async_client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": "token-completamente-invalido-abc123xyz",
                "new_password": "NovaSenha456!",
                "confirm_password": "NovaSenha456!",
            },
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_senha_fraca_retorna_400(
        self, async_client, sample_user, test_db_session
    ):
        """Teste 6: Senha sem requisitos mínimos → 400 (RN05)."""
        plain = await _insert_token(test_db_session, sample_user.id)
        response = await async_client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": plain,
                "new_password": "senhafraca",
                "confirm_password": "senhafraca",
            },
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_senhas_divergentes_retornam_400(
        self, async_client, sample_user, test_db_session
    ):
        """Teste 7: Senha e confirmação diferentes → 400."""
        plain = await _insert_token(test_db_session, sample_user.id)
        response = await async_client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": plain,
                "new_password": "NovaSenha456!",
                "confirm_password": "SenhaDiferente789@",
            },
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_reset_incrementa_token_version(
        self, async_client, sample_user, test_db_session
    ):
        """Teste 8: Após reset, token_version do usuário é incrementado (RN06)."""
        from app.models.user import User

        version_antes = sample_user.token_version or 0
        plain = await _insert_token(test_db_session, sample_user.id)
        await async_client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": plain,
                "new_password": "NovaSenha456!",
                "confirm_password": "NovaSenha456!",
            },
        )
        await test_db_session.refresh(sample_user)
        assert sample_user.token_version == version_antes + 1

    @pytest.mark.asyncio
    async def test_segundo_uso_do_mesmo_token_falha(
        self, async_client, sample_user, test_db_session
    ):
        """Teste 9: Reutilizar token após reset bem-sucedido → 400."""
        plain = await _insert_token(test_db_session, sample_user.id)
        # Primeiro uso — sucesso
        await async_client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": plain,
                "new_password": "NovaSenha456!",
                "confirm_password": "NovaSenha456!",
            },
        )
        # Segundo uso — deve falhar
        response = await async_client.post(
            "/api/v1/auth/reset-password",
            json={
                "token": plain,
                "new_password": "OutraSenha789@",
                "confirm_password": "OutraSenha789@",
            },
        )
        assert response.status_code == 400

    @pytest.mark.asyncio
    async def test_body_vazio_retorna_422(self, async_client):
        """Teste 10: Body ausente → 422."""
        response = await async_client.post("/api/v1/auth/reset-password", json={})
        assert response.status_code == 422
