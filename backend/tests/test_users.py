"""
Testes de integração para o módulo de usuários.

Testa os 5 endpoints completos com dados válidos e casos de erro.
"""

import pytest
from fastapi.testclient import TestClient


class TestUserIntegration:
    """Testes de integração da API de usuários."""

    @pytest.mark.asyncio
    async def test_create_user_success(self, async_client, sample_user_data):
        """Teste 1: Criar usuário com dados válidos (201)."""
        response = await async_client.post(
            "/api/v1/users",
            json=sample_user_data,
        )

        assert response.status_code == 201
        data = response.json()
        assert data["id"] is not None
        assert data["email"] == sample_user_data["email"]
        assert data["name"] == sample_user_data["name"]
        assert data["role"] == sample_user_data["role"]
        assert "password" not in data
        assert data["is_active"] is True

    @pytest.mark.asyncio
    async def test_create_user_duplicate_email(self, async_client, sample_user_data):
        """Teste 2: Criar usuário com email duplicado (409)."""
        # Criar primeiro usuário
        await async_client.post(
            "/api/v1/users",
            json=sample_user_data,
        )

        # Tentar criar outro com mesmo email
        response = await async_client.post(
            "/api/v1/users",
            json=sample_user_data,
        )

        assert response.status_code == 409
        assert "Email" in response.json()["detail"] or "já" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_create_user_weak_password(self, async_client, sample_user_data):
        """Teste 3: Criar usuário com senha fraca (400)."""
        weak_user = {**sample_user_data, "password": "123"}

        response = await async_client.post(
            "/api/v1/users",
            json=weak_user,
        )

        assert response.status_code == 422  # Validation error
        assert "password" in response.json()["detail"][0]["loc"]

    @pytest.mark.asyncio
    async def test_create_user_invalid_email(self, async_client, sample_user_data):
        """Teste 3b: Criar usuário com email inválido (422)."""
        invalid_user = {**sample_user_data, "email": "invalid-email"}

        response = await async_client.post(
            "/api/v1/users",
            json=invalid_user,
        )

        assert response.status_code == 422
        assert "email" in response.json()["detail"][0]["loc"]

    @pytest.mark.asyncio
    async def test_list_users_pagination(self, async_client, sample_user_data):
        """Teste 4: Listar usuários com paginação (200)."""
        # Criar alguns usuários
        for i in range(3):
            user_data = {
                **sample_user_data,
                "email": f"user{i}@example.com",
            }
            await async_client.post("/api/v1/users", json=user_data)

        # Listar primeira página
        response = await async_client.get(
            "/api/v1/users",
            params={"page": 1, "limit": 10},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 3
        assert data["page"] == 1
        assert data["limit"] == 10
        assert len(data["data"]) == 3
        for user in data["data"]:
            assert "password" not in user

    @pytest.mark.asyncio
    async def test_get_user_by_id_success(self, async_client, sample_user_data):
        """Teste 5: Buscar usuário por ID (200)."""
        # Criar usuário
        create_response = await async_client.post(
            "/api/v1/users",
            json=sample_user_data,
        )
        user_id = create_response.json()["id"]

        # Buscar por ID
        response = await async_client.get(f"/api/v1/users/{user_id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == user_id
        assert data["email"] == sample_user_data["email"]
        assert "password" not in data

    @pytest.mark.asyncio
    async def test_get_user_not_found(self, async_client):
        """Teste 6: Buscar usuário inexistente (404)."""
        fake_id = "550e8400-e29b-41d4-a716-446655440000"

        response = await async_client.get(f"/api/v1/users/{fake_id}")

        assert response.status_code == 404
        assert "não encontrado" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_update_user_success(self, async_client, sample_user_data):
        """Teste 7: Atualizar usuário (200)."""
        # Criar usuário
        create_response = await async_client.post(
            "/api/v1/users",
            json=sample_user_data,
        )
        user_id = create_response.json()["id"]
        created_at = create_response.json()["created_at"]

        # Atualizar
        update_data = {
            "name": "João Silva Santos",
            "phone_whatsapp": "+55 11 98888-8888",
        }
        response = await async_client.put(
            f"/api/v1/users/{user_id}",
            json=update_data,
        )

        assert response.status_code == 200
        data = response.json()
        assert data["name"] == "João Silva Santos"
        assert data["phone_whatsapp"] == "+55 11 98888-8888"
        assert data["email"] == sample_user_data["email"]
        assert data["created_at"] == created_at
        assert data["updated_at"] > created_at

    @pytest.mark.asyncio
    async def test_delete_user_success(self, async_client, sample_user_data):
        """Teste 8: Deletar usuário (204)."""
        # Criar usuário
        create_response = await async_client.post(
            "/api/v1/users",
            json=sample_user_data,
        )
        user_id = create_response.json()["id"]

        # Deletar
        response = await async_client.delete(f"/api/v1/users/{user_id}")
        assert response.status_code == 204

        # Verificar que não existe mais
        response_get = await async_client.get(f"/api/v1/users/{user_id}")
        assert response_get.status_code == 404

    @pytest.mark.asyncio
    async def test_create_user_invalid_role(self, async_client, sample_user_data):
        """Teste 8b: Criar usuário com role inválido (422)."""
        invalid_user = {**sample_user_data, "role": "superadmin"}

        response = await async_client.post(
            "/api/v1/users",
            json=invalid_user,
        )

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_create_user_invalid_phone(self, async_client, sample_user_data):
        """Teste 8c: Criar usuário com telefone inválido (422)."""
        invalid_user = {**sample_user_data, "phone_whatsapp": "1199999999"}

        response = await async_client.post(
            "/api/v1/users",
            json=invalid_user,
        )

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_password_not_returned_in_list(self, async_client, sample_user_data):
        """Teste: Verificar que senha não é retornada em listagem."""
        # Criar usuário
        await async_client.post(
            "/api/v1/users",
            json=sample_user_data,
        )

        # Listar
        response = await async_client.get("/api/v1/users")

        assert response.status_code == 200
        for user in response.json()["data"]:
            assert "password" not in user

    @pytest.mark.asyncio
    async def test_create_user_name_with_numbers(self, async_client, sample_user_data):
        """Teste: Nome não pode conter números."""
        invalid_user = {**sample_user_data, "name": "João Silva 123"}

        response = await async_client.post(
            "/api/v1/users",
            json=invalid_user,
        )

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_list_users_max_limit(self, async_client, sample_user_data):
        """Teste: Limitar máximo de 100 itens por página."""
        # Criar usuário primeiro
        await async_client.post("/api/v1/users", json=sample_user_data)

        # Solicitar com limit 100 (máximo permitido)
        response = await async_client.get(
            "/api/v1/users",
            params={"page": 1, "limit": 100},
        )

        # Deve retornar 200
        assert response.status_code == 200
        data = response.json()
        assert len(data["data"]) <= 100
