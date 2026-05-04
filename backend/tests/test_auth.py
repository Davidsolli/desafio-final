"""Testes de integração para o módulo de autenticação."""

import pytest
from jose import jwt

from app.config.settings import settings


class TestAuthIntegration:
    """Testes de integração da API de autenticação."""

    @pytest.mark.asyncio
    async def test_login_success(self, async_client, sample_user, sample_user_data):
        """Teste 1: Login com credenciais válidas (200)."""
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": sample_user_data["email"],
                "password": sample_user_data["password"],
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert data["expires_in"] > 0

    @pytest.mark.asyncio
    async def test_login_with_valid_token(self, async_client, sample_user, sample_user_data):
        """Teste 2: Token retornado é JWT válido."""
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": sample_user_data["email"],
                "password": sample_user_data["password"],
            },
        )

        assert response.status_code == 200
        token = response.json()["access_token"]

        # Decodificar e validar token
        decoded = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        assert "sub" in decoded
        assert "exp" in decoded

    @pytest.mark.asyncio
    async def test_login_invalid_email(self, async_client):
        """Teste 3: Email não cadastrado (401)."""
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": "naoexiste@example.com",
                "password": "SenhaForte123!",
            },
        )

        assert response.status_code == 401
        assert "Email ou senha" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_login_invalid_password(self, async_client, sample_user, sample_user_data):
        """Teste 4: Senha incorreta (401)."""
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": sample_user_data["email"],
                "password": "SenhaErrada123!",
            },
        )

        assert response.status_code == 401
        assert "Email ou senha" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_login_malformed_email(self, async_client):
        """Teste 5: Email em formato inválido (422)."""
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": "nao-um-email-valido",
                "password": "SenhaForte123!",
            },
        )

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_login_missing_email(self, async_client):
        """Teste 6: Email ausente no corpo (422)."""
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "password": "SenhaForte123!",
            },
        )

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_login_missing_password(self, async_client):
        """Teste 7: Senha ausente no corpo (422)."""
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": "joao@example.com",
            },
        )

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_login_inactive_user(self, async_client, test_db_session, sample_user_data):
        """Teste 8: Usuário desativado não consegue fazer login (401)."""
        from app.services.user_service import UserService
        from app.dtos.user_dto import CreateUserDTO, UpdateUserDTO
        from uuid import UUID

        # Criar e depois desativar usuário
        service = UserService(test_db_session)
        dto = CreateUserDTO(**sample_user_data)
        user = await service.create(dto)
        user_id = user.id

        # Desativar usuário
        update_dto = UpdateUserDTO(is_active=False)
        await service.update(user_id, update_dto)

        # Tentar fazer login
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": sample_user_data["email"],
                "password": sample_user_data["password"],
            },
        )

        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_login_token_type_is_bearer(self, async_client, sample_user, sample_user_data):
        """Teste 9: token_type sempre é 'bearer'."""
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": sample_user_data["email"],
                "password": sample_user_data["password"],
            },
        )

        assert response.status_code == 200
        assert response.json()["token_type"] == "bearer"

    @pytest.mark.asyncio
    async def test_login_expires_in_is_positive(self, async_client, sample_user, sample_user_data):
        """Teste 10: expires_in sempre é positivo."""
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": sample_user_data["email"],
                "password": sample_user_data["password"],
            },
        )

        assert response.status_code == 200
        assert response.json()["expires_in"] > 0

    @pytest.mark.asyncio
    async def test_login_same_message_for_invalid_email_and_password(
        self, async_client, sample_user, sample_user_data
    ):
        """Teste 11: Mensagem igual para email inválido e senha errada (evita enumeração)."""
        response1 = await async_client.post(
            "/api/v1/auth/login",
            json={"email": "naoexiste@example.com", "password": "SenhaForte123!"},
        )
        response2 = await async_client.post(
            "/api/v1/auth/login",
            json={"email": sample_user_data["email"], "password": "SenhaErrada123!"},
        )
        assert response1.status_code == 401
        assert response2.status_code == 401
        assert response1.json()["detail"] == response2.json()["detail"]

    @pytest.mark.asyncio
    async def test_login_returns_refresh_token(self, async_client, sample_user, sample_user_data):
        """Teste 12 (RNF-05): Login retorna refresh_token além do access_token."""
        response = await async_client.post(
            "/api/v1/auth/login",
            json={"email": sample_user_data["email"], "password": sample_user_data["password"]},
        )
        assert response.status_code == 200
        data = response.json()
        assert "refresh_token" in data
        assert isinstance(data["refresh_token"], str)
        assert len(data["refresh_token"]) > 10

    @pytest.mark.asyncio
    async def test_refresh_token_generates_new_access_token(
        self, async_client, sample_user, sample_user_data
    ):
        """Teste 13 (RNF-05): Refresh token gera novo access_token."""
        login_resp = await async_client.post(
            "/api/v1/auth/login",
            json={"email": sample_user_data["email"], "password": sample_user_data["password"]},
        )
        assert login_resp.status_code == 200
        refresh_token = login_resp.json()["refresh_token"]

        refresh_resp = await async_client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": refresh_token},
        )
        assert refresh_resp.status_code == 200
        data = refresh_resp.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"

    @pytest.mark.asyncio
    async def test_refresh_token_invalid(self, async_client):
        """Teste 14 (RNF-05): Refresh token inválido retorna 401."""
        response = await async_client.post(
            "/api/v1/auth/refresh",
            json={"refresh_token": "token.invalido.aqui"},
        )
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_access_token_type_in_payload(
        self, async_client, sample_user, sample_user_data
    ):
        """Teste 15 (RNF-05): Payload do access_token tem type='access'."""
        login_resp = await async_client.post(
            "/api/v1/auth/login",
            json={"email": sample_user_data["email"], "password": sample_user_data["password"]},
        )
        assert login_resp.status_code == 200
        access_token = login_resp.json()["access_token"]

        decoded = jwt.decode(access_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        assert decoded.get("type") == "access"
