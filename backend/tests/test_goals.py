"""Testes de integração para o módulo de metas."""

import pytest
from datetime import date, timedelta


def future_date(days: int = 60) -> str:
    """Retorna data futura no formato ISO."""
    return (date.today() + timedelta(days=days)).isoformat()


def past_date(days: int = 1) -> str:
    """Retorna data passada no formato ISO."""
    return (date.today() - timedelta(days=days)).isoformat()


@pytest.fixture
def goal_data(sample_user):
    """Dados válidos para criar uma meta."""
    return {
        "user_id": str(sample_user.id),
        "title": "Aumentar supino em 10kg",
        "description": "Do 80kg para 90kg",
        "category": "strength",
        "target_value": 90.0,
        "current_value": 80.0,
        "unit": "kg",
        "target_date": future_date(60),
    }


class TestGoalsIntegration:
    """Testes de integração dos endpoints de metas."""

    @pytest.mark.asyncio
    async def test_create_goal_success(self, async_client, goal_data):
        """Teste 1: Criar meta com dados válidos → 201."""
        response = await async_client.post("/api/v1/goals", json=goal_data)

        assert response.status_code == 201
        data = response.json()
        assert data["id"] is not None
        assert data["title"] == goal_data["title"]
        assert data["category"] == "strength"
        assert data["progress_percentage"] == 0.0
        assert data["status"] == "active"
        assert data["current_value"] == 80.0
        assert data["initial_value"] == 80.0
        assert data["target_value"] == 90.0
        assert data["days_remaining"] > 0

    @pytest.mark.asyncio
    async def test_list_goals_active(self, async_client, goal_data):
        """Teste 2: Listar metas ativas → 200 com paginação."""
        # Criar duas metas
        await async_client.post("/api/v1/goals", json=goal_data)
        second = {**goal_data, "title": "Correr 5km"}
        await async_client.post("/api/v1/goals", json=second)

        response = await async_client.get("/api/v1/goals", params={"status": "active"})

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 2
        assert data["page"] == 1
        assert len(data["data"]) == 2
        for goal in data["data"]:
            assert goal["status"] == "active"

    @pytest.mark.asyncio
    async def test_update_progress_and_calculate_percentage(self, async_client, goal_data):
        """Teste 3: Atualizar current_value e verificar cálculo de percentual."""
        create_resp = await async_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        # Atualizar: 80 → 85 em um range de 80–90 = 50%
        response = await async_client.put(
            f"/api/v1/goals/{goal_id}",
            json={"current_value": 85.0, "notes": "Progresso parcial"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["current_value"] == 85.0
        assert data["progress_percentage"] == 50.0
        assert data["status"] == "active"

    @pytest.mark.asyncio
    async def test_complete_goal_automatically(self, async_client, goal_data):
        """Teste 4: Ao atingir target_value, status muda para 'completed'."""
        create_resp = await async_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        # Atualizar para target_value → 100%
        response = await async_client.put(
            f"/api/v1/goals/{goal_id}",
            json={"current_value": 90.0},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["progress_percentage"] == 100.0
        assert data["status"] == "completed"
        assert data["completed_at"] is not None

    @pytest.mark.asyncio
    async def test_cannot_create_goal_with_past_date(self, async_client, goal_data):
        """Teste 5: Data alvo no passado deve falhar com 422."""
        invalid_goal = {**goal_data, "target_date": past_date(1)}

        response = await async_client.post("/api/v1/goals", json=invalid_goal)

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_filter_goals_by_user_id(self, async_client, goal_data, sample_user_data):
        """Teste 6: Filtrar metas por user_id retorna apenas as do usuário."""
        # Criar outro usuário
        second_user_data = {
            **sample_user_data,
            "email": "second@example.com",
        }
        create_user_resp = await async_client.post("/api/v1/users", json=second_user_data)
        second_user_id = create_user_resp.json()["id"]

        # Meta do usuário principal
        await async_client.post("/api/v1/goals", json=goal_data)

        # Meta do segundo usuário
        second_goal = {**goal_data, "user_id": second_user_id, "title": "Meta do segundo"}
        await async_client.post("/api/v1/goals", json=second_goal)

        # Filtrar apenas pelo usuário principal
        response = await async_client.get(
            "/api/v1/goals",
            params={"user_id": goal_data["user_id"]},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 1
        assert data["data"][0]["title"] == goal_data["title"]

    @pytest.mark.asyncio
    async def test_get_goal_with_progress_history(self, async_client, goal_data):
        """Teste 7: Detalhe da meta inclui histórico de entradas de progresso."""
        create_resp = await async_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        # Atualizar progresso duas vezes
        await async_client.put(f"/api/v1/goals/{goal_id}", json={"current_value": 83.0, "notes": "Primeira atualização"})
        await async_client.put(f"/api/v1/goals/{goal_id}", json={"current_value": 85.0, "notes": "Segunda atualização"})

        response = await async_client.get(f"/api/v1/goals/{goal_id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == goal_id
        # Deve ter: 1 entrada inicial + 2 atualizações = 3 entradas
        assert len(data["progress_entries"]) == 3
        assert data["progress_entries"][0]["notes"] == "Meta criada"
        assert data["current_value"] == 85.0

    @pytest.mark.asyncio
    async def test_delete_goal_success(self, async_client, goal_data):
        """Teste 8: Deletar meta → 204, depois GET → 404."""
        create_resp = await async_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        delete_resp = await async_client.delete(f"/api/v1/goals/{goal_id}")
        assert delete_resp.status_code == 204

        get_resp = await async_client.get(f"/api/v1/goals/{goal_id}")
        assert get_resp.status_code == 404

    @pytest.mark.asyncio
    async def test_get_goal_not_found(self, async_client):
        """Teste extra: Buscar meta inexistente → 404."""
        fake_id = "550e8400-e29b-41d4-a716-446655440000"
        response = await async_client.get(f"/api/v1/goals/{fake_id}")

        assert response.status_code == 404
        assert "não encontrada" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_cannot_create_goal_with_invalid_category(self, async_client, goal_data):
        """Teste extra: Categoria inválida deve falhar com 422."""
        invalid = {**goal_data, "category": "invalid_category"}
        response = await async_client.post("/api/v1/goals", json=invalid)

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_update_goal_status_to_paused(self, async_client, goal_data):
        """Teste extra: Pausar meta via campo status."""
        create_resp = await async_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        response = await async_client.put(
            f"/api/v1/goals/{goal_id}",
            json={"status": "paused"},
        )

        assert response.status_code == 200
        assert response.json()["status"] == "paused"

    @pytest.mark.asyncio
    async def test_exceed_target_value_also_completes(self, async_client, goal_data):
        """Teste extra: Ultrapassar target_value também conclui a meta."""
        create_resp = await async_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        # Atualizar para além do target_value
        response = await async_client.put(
            f"/api/v1/goals/{goal_id}",
            json={"current_value": 95.0},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["progress_percentage"] == 100.0
        assert data["status"] == "completed"
