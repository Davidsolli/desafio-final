"""Testes de integração para o módulo de alunos (estudiantes) do personal trainer."""

import pytest


class TestListStudentsEndpoint:
    """Testes da rota GET /api/v1/users/students."""

    @pytest.mark.asyncio
    async def test_list_students_success_personal_trainer(
        self, async_client, sample_personal_trainer, sample_students
    ):
        """Teste 1: Personal trainer lista seus alunos (200)."""
        # Login usando objeto User
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": sample_personal_trainer.email,
                "password": "SenhaForte123!",
            },
        )
        assert response.status_code == 200
        token = response.json()["access_token"]

        headers = {"Authorization": f"Bearer {token}"}
        response = await async_client.get(
            "/api/v1/users/students",
            headers=headers,
        )

        assert response.status_code == 200
        data = response.json()
        assert "total" in data
        assert "page" in data
        assert "limit" in data
        assert "data" in data
        assert data["total"] == 3  # 3 students foram criados

        # Validar que retorna apenas clientes (students)
        for user in data["data"]:
            assert user["role"] == "client"

    @pytest.mark.asyncio
    async def test_list_students_pagination(
        self, async_client, sample_personal_trainer, sample_students
    ):
        """Teste 2: Paginação funciona corretamente."""
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": sample_personal_trainer.email,
                "password": "SenhaForte123!",
            },
        )
        token = response.json()["access_token"]

        headers = {"Authorization": f"Bearer {token}"}
        response = await async_client.get(
            "/api/v1/users/students?page=1&limit=2",
            headers=headers,
        )

        assert response.status_code == 200
        data = response.json()
        assert data["page"] == 1
        assert data["limit"] == 2
        assert data["total"] == 3
        assert len(data["data"]) == 2

    @pytest.mark.asyncio
    async def test_list_students_requires_authentication(self, async_client):
        """Teste 3: Sem token, retorna 401."""
        response = await async_client.get("/api/v1/users/students")

        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_list_students_forbidden_for_client(
        self, async_client, sample_user, sample_user_data
    ):
        """Teste 4: Aluno (client) não pode listar alunos (403)."""
        # Login como client
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": sample_user_data["email"],
                "password": sample_user_data["password"],
            },
        )
        assert response.status_code == 200
        token = response.json()["access_token"]

        headers = {"Authorization": f"Bearer {token}"}
        response = await async_client.get(
            "/api/v1/users/students",
            headers=headers,
        )

        assert response.status_code == 403
        assert "personal_trainer ou admin" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_list_students_empty_list(self, async_client, sample_personal_trainer_no_students):
        """Teste 5: Personal trainer sem alunos retorna lista vazia."""
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": sample_personal_trainer_no_students.email,
                "password": "SenhaForte123!",
            },
        )
        token = response.json()["access_token"]

        headers = {"Authorization": f"Bearer {token}"}
        response = await async_client.get(
            "/api/v1/users/students",
            headers=headers,
        )

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 0
        assert data["data"] == []

    @pytest.mark.asyncio
    async def test_get_student_detail_personal_trainer(
        self, async_client, sample_personal_trainer, sample_students
    ):
        """Teste 6: Personal trainer vê detalhes de seu aluno."""
        # Login como personal trainer
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": sample_personal_trainer.email,
                "password": "SenhaForte123!",
            },
        )
        token = response.json()["access_token"]

        # Listar students para pegar um ID
        headers = {"Authorization": f"Bearer {token}"}
        list_response = await async_client.get(
            "/api/v1/users/students",
            headers=headers,
        )
        assert list_response.status_code == 200
        students = list_response.json()["data"]
        assert len(students) > 0

        student_id = students[0]["id"]

        # Buscar detalhes do aluno
        response = await async_client.get(
            f"/api/v1/users/{student_id}",
            headers=headers,
        )

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == student_id
        assert data["role"] == "client"

    @pytest.mark.asyncio
    async def test_get_student_detail_blocked_for_other_trainer(
        self, async_client, sample_personal_trainer, sample_students, test_db_session
    ):
        """Teste 7: Personal trainer NÃO vê alunos de outro trainer (403)."""
        from app.services.user_service import UserService
        from app.dtos.user_dto import CreateUserDTO

        # Criar outro personal trainer
        service = UserService(test_db_session)
        other_trainer_dto = CreateUserDTO(
            name="Outro Trainer",
            email="outro.trainer@test.com",
            password="SenhaForte123!",
            role="personal_trainer",
        )
        await service.create(other_trainer_dto)

        # Pegar aluno do primeiro trainer
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": sample_personal_trainer.email,
                "password": "SenhaForte123!",
            },
        )
        token1 = response.json()["access_token"]

        response = await async_client.get(
            "/api/v1/users/students",
            headers={"Authorization": f"Bearer {token1}"},
        )
        students = response.json()["data"]
        assert len(students) > 0
        student_id = students[0]["id"]

        # Tentar acessar com outro trainer
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": "outro.trainer@test.com",
                "password": "SenhaForte123!",
            },
        )
        token2 = response.json()["access_token"]

        response = await async_client.get(
            f"/api/v1/users/{student_id}",
            headers={"Authorization": f"Bearer {token2}"},
        )

        assert response.status_code == 403
        assert "não está vinculado" in response.json()["detail"]

    @pytest.mark.asyncio
    async def test_list_students_invalid_page(self, async_client, sample_personal_trainer):
        """Teste 8: Página inválida (< 1) retorna 422."""
        response = await async_client.post(
            "/api/v1/auth/login",
            json={
                "email": sample_personal_trainer.email,
                "password": "SenhaForte123!",
            },
        )
        token = response.json()["access_token"]

        headers = {"Authorization": f"Bearer {token}"}
        response = await async_client.get(
            "/api/v1/users/students?page=0",
            headers=headers,
        )

        assert response.status_code == 422  # Validation error
