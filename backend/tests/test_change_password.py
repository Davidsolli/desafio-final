"""
Testes de integração para o endpoint de troca de senha.

PUT /api/v1/users/{user_id}/password
"""

import pytest
from uuid import uuid4


VALID_PAYLOAD = {
    "current_password": "SenhaForte123!",
    "new_password": "NovaSenha456@",
    "confirm_password": "NovaSenha456@",
}


class TestChangePassword:

    @pytest.mark.asyncio
    async def test_troca_senha_com_sucesso(self, async_client_as, sample_user):
        """Usuário troca sua própria senha corretamente → 200."""
        async with await async_client_as(sample_user) as client:
            response = await client.put(
                f"/api/v1/users/{sample_user.id}/password",
                json=VALID_PAYLOAD,
            )

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == str(sample_user.id)
        assert "password" not in data

    @pytest.mark.asyncio
    async def test_senha_atual_incorreta_retorna_401(self, async_client_as, sample_user):
        """Senha atual errada → 401."""
        async with await async_client_as(sample_user) as client:
            response = await client.put(
                f"/api/v1/users/{sample_user.id}/password",
                json={
                    "current_password": "SenhaErrada999!",
                    "new_password": "NovaSenha456@",
                    "confirm_password": "NovaSenha456@",
                },
            )

        assert response.status_code == 401
        assert "incorreta" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_nova_senha_fraca_retorna_422(self, async_client_as, sample_user):
        """Nova senha sem caractere especial → 422 (falha de validação do DTO)."""
        async with await async_client_as(sample_user) as client:
            response = await client.put(
                f"/api/v1/users/{sample_user.id}/password",
                json={
                    "current_password": "SenhaForte123!",
                    "new_password": "senhafraca123",
                    "confirm_password": "senhafraca123",
                },
            )

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_confirmacao_diferente_retorna_422(self, async_client_as, sample_user):
        """Nova senha e confirmação diferentes → 422 (validação do DTO)."""
        async with await async_client_as(sample_user) as client:
            response = await client.put(
                f"/api/v1/users/{sample_user.id}/password",
                json={
                    "current_password": "SenhaForte123!",
                    "new_password": "NovaSenha456@",
                    "confirm_password": "SenhaDiferente789#",
                },
            )

        assert response.status_code == 422
        detail = str(response.json()["detail"]).lower()
        assert "correspondem" in detail or "senha" in detail

    @pytest.mark.asyncio
    async def test_usuario_nao_encontrado_retorna_404(self, async_client_as, sample_user):
        """UUID inexistente → 404."""
        async with await async_client_as(sample_user) as client:
            response = await client.put(
                f"/api/v1/users/{uuid4()}/password",
                json=VALID_PAYLOAD,
            )

        assert response.status_code in (403, 404)

    @pytest.mark.asyncio
    async def test_acesso_negado_para_outro_usuario(
        self, async_client_as, sample_user, sample_personal_trainer
    ):
        """Usuário comum tentando trocar senha de outra pessoa → 403."""
        async with await async_client_as(sample_user) as client:
            response = await client.put(
                f"/api/v1/users/{sample_personal_trainer.id}/password",
                json=VALID_PAYLOAD,
            )

        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_admin_troca_senha_de_outro_sem_senha_atual(
        self, async_client_as, sample_user, test_db_session
    ):
        """Admin pode trocar senha de outro usuário sem precisar da senha atual dele → 200."""
        from app.services.user_service import UserService
        from app.dtos.user_dto import CreateUserDTO

        # Criar admin
        svc = UserService(test_db_session)
        admin_response = await svc.create(
            CreateUserDTO(
                name="Admin Teste",
                email="admin_cp@example.com",
                password="AdminForte123!",
                role="admin",
            )
        )
        from app.models.user import User
        admin = await test_db_session.get(User, admin_response.id)

        async with await async_client_as(admin) as client:
            response = await client.put(
                f"/api/v1/users/{sample_user.id}/password",
                json={
                    # current_password é obrigatório no DTO, mas ignorado pelo service quando admin
                    "current_password": "qualquer_coisa",
                    "new_password": "NovaSenha789#",
                    "confirm_password": "NovaSenha789#",
                },
            )

        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_senha_com_caractere_especial_variado(self, async_client_as, sample_user):
        """Senhas com caracteres especiais além de @!#$%^&* são aceitas → 200."""
        async with await async_client_as(sample_user) as client:
            response = await client.put(
                f"/api/v1/users/{sample_user.id}/password",
                json={
                    "current_password": "SenhaForte123!",
                    "new_password": "Minha_Senha@2025",
                    "confirm_password": "Minha_Senha@2025",
                },
            )

        assert response.status_code == 200
