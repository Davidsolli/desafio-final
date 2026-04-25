"""Testes de integração para o módulo de metas."""

import pytest
import httpx
from httpx import ASGITransport
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
    async def test_create_goal_success(self, auth_client, goal_data):
        """Teste 1: Criar meta com dados válidos → 201."""
        response = await auth_client.post("/api/v1/goals", json=goal_data)

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
    async def test_list_goals_active(self, auth_client, goal_data):
        """Teste 2: Listar metas ativas → 200 com paginação."""
        # Criar duas metas
        await auth_client.post("/api/v1/goals", json=goal_data)
        second = {**goal_data, "title": "Correr 5km"}
        await auth_client.post("/api/v1/goals", json=second)

        response = await auth_client.get("/api/v1/goals", params={"status": "active"})

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 2
        assert data["page"] == 1
        assert len(data["data"]) == 2
        for goal in data["data"]:
            assert goal["status"] == "active"

    @pytest.mark.asyncio
    async def test_update_progress_and_calculate_percentage(self, auth_client, goal_data):
        """Teste 3: Atualizar current_value e verificar cálculo de percentual."""
        create_resp = await auth_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        # Atualizar: 80 → 85 em um range de 80–90 = 50%
        response = await auth_client.put(
            f"/api/v1/goals/{goal_id}",
            json={"current_value": 85.0, "notes": "Progresso parcial"},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["current_value"] == 85.0
        assert data["progress_percentage"] == 50.0
        assert data["status"] == "active"

    @pytest.mark.asyncio
    async def test_complete_goal_automatically(self, auth_client, goal_data):
        """Teste 4: Ao atingir target_value, status muda para 'completed'."""
        create_resp = await auth_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        # Atualizar para target_value → 100%
        response = await auth_client.put(
            f"/api/v1/goals/{goal_id}",
            json={"current_value": 90.0},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["progress_percentage"] == 100.0
        assert data["status"] == "completed"
        assert data["completed_at"] is not None

    @pytest.mark.asyncio
    async def test_cannot_create_goal_with_past_date(self, auth_client, goal_data):
        """Teste 5: Data alvo no passado deve falhar com 422."""
        invalid_goal = {**goal_data, "target_date": past_date(1)}

        response = await auth_client.post("/api/v1/goals", json=invalid_goal)

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_filter_goals_by_user_id(self, auth_client, goal_data, sample_user_data):
        """Teste 6: Filtrar metas por user_id retorna apenas as do usuário."""
        # Criar outro usuário
        second_user_data = {
            **sample_user_data,
            "email": "second@example.com",
        }
        create_user_resp = await auth_client.post("/api/v1/users", json=second_user_data)
        second_user_id = create_user_resp.json()["id"]

        # Meta do usuário principal
        await auth_client.post("/api/v1/goals", json=goal_data)

        # Meta do segundo usuário
        second_goal = {**goal_data, "user_id": second_user_id, "title": "Meta do segundo"}
        await auth_client.post("/api/v1/goals", json=second_goal)

        # Filtrar apenas pelo usuário principal
        response = await auth_client.get(
            "/api/v1/goals",
            params={"user_id": goal_data["user_id"]},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["total"] == 1
        assert data["data"][0]["title"] == goal_data["title"]

    @pytest.mark.asyncio
    async def test_get_goal_with_progress_history(self, auth_client, goal_data):
        """Teste 7: Detalhe da meta inclui histórico de entradas de progresso."""
        create_resp = await auth_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        # Atualizar progresso duas vezes
        await auth_client.put(f"/api/v1/goals/{goal_id}", json={"current_value": 83.0, "notes": "Primeira atualização"})
        await auth_client.put(f"/api/v1/goals/{goal_id}", json={"current_value": 85.0, "notes": "Segunda atualização"})

        response = await auth_client.get(f"/api/v1/goals/{goal_id}")

        assert response.status_code == 200
        data = response.json()
        assert data["id"] == goal_id
        # Deve ter: 1 entrada inicial + 2 atualizações = 3 entradas
        assert len(data["progress_entries"]) == 3
        assert data["progress_entries"][0]["notes"] == "Meta criada"
        assert data["current_value"] == 85.0

    @pytest.mark.asyncio
    async def test_delete_goal_success(self, auth_client, goal_data):
        """Teste 8: Deletar meta → 204, depois GET → 404."""
        create_resp = await auth_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        delete_resp = await auth_client.delete(f"/api/v1/goals/{goal_id}")
        assert delete_resp.status_code == 204

        get_resp = await auth_client.get(f"/api/v1/goals/{goal_id}")
        assert get_resp.status_code == 404

    @pytest.mark.asyncio
    async def test_get_goal_not_found(self, auth_client):
        """Teste extra: Buscar meta inexistente → 404."""
        fake_id = "550e8400-e29b-41d4-a716-446655440000"
        response = await auth_client.get(f"/api/v1/goals/{fake_id}")

        assert response.status_code == 404
        assert "não encontrada" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_cannot_create_goal_with_invalid_category(self, auth_client, goal_data):
        """Teste extra: Categoria inválida deve falhar com 422."""
        invalid = {**goal_data, "category": "invalid_category"}
        response = await auth_client.post("/api/v1/goals", json=invalid)

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_update_goal_status_to_paused(self, auth_client, goal_data):
        """Teste extra: Pausar meta via campo status."""
        create_resp = await auth_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        response = await auth_client.put(
            f"/api/v1/goals/{goal_id}",
            json={"status": "paused"},
        )

        assert response.status_code == 200
        assert response.json()["status"] == "paused"

    @pytest.mark.asyncio
    async def test_exceed_target_value_also_completes(self, auth_client, goal_data):
        """Teste extra: Ultrapassar target_value também conclui a meta."""
        create_resp = await auth_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        # Atualizar para além do target_value
        response = await auth_client.put(
            f"/api/v1/goals/{goal_id}",
            json={"current_value": 95.0},
        )

        assert response.status_code == 200
        data = response.json()
        assert data["progress_percentage"] == 100.0
        assert data["status"] == "completed"


class TestGoalsBusinessRules:
    """Testes das regras de negócio implementadas nas melhorias."""

    @pytest.mark.asyncio
    async def test_target_equal_current_rejected(self, auth_client, goal_data):
        """Melhoria 1: target_value == current_value deve retornar 422."""
        invalid = {**goal_data, "target_value": 80.0, "current_value": 80.0}

        response = await auth_client.post("/api/v1/goals", json=invalid)

        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_reduction_goal_creation_allowed(self, auth_client, goal_data):
        """Melhoria 1: Meta de redução (target < current) deve ser criada com sucesso."""
        reduction_goal = {
            **goal_data,
            "title": "Perder 5kg",
            "current_value": 90.0,
            "target_value": 85.0,
            "unit": "kg",
        }

        response = await auth_client.post("/api/v1/goals", json=reduction_goal)

        assert response.status_code == 201
        data = response.json()
        assert data["target_value"] == 85.0
        assert data["current_value"] == 90.0

    @pytest.mark.asyncio
    async def test_cannot_decrease_current_value(self, auth_client, goal_data):
        """Melhoria 2: current_value não pode diminuir em meta de aumento → 400."""
        create_resp = await auth_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        # Primeiro avançar para 85
        await auth_client.put(f"/api/v1/goals/{goal_id}", json={"current_value": 85.0})

        # Tentar retroceder para 82 deve falhar
        response = await auth_client.put(
            f"/api/v1/goals/{goal_id}",
            json={"current_value": 82.0},
        )

        assert response.status_code == 400
        assert "não pode diminuir" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_reduction_goal_cannot_increase(self, auth_client, goal_data):
        """Melhoria 2: Em meta de redução, current_value não pode aumentar → 400."""
        reduction_goal = {**goal_data, "current_value": 90.0, "target_value": 85.0}
        create_resp = await auth_client.post("/api/v1/goals", json=reduction_goal)
        goal_id = create_resp.json()["id"]

        # Primeiro avançar (reduzir) para 88
        await auth_client.put(f"/api/v1/goals/{goal_id}", json={"current_value": 88.0})

        # Tentar aumentar para 92 deve falhar (retrocesso em meta de redução)
        response = await auth_client.put(
            f"/api/v1/goals/{goal_id}",
            json={"current_value": 92.0},
        )

        assert response.status_code == 400
        assert "redução" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_completed_goal_cannot_be_updated(self, auth_client, goal_data):
        """Melhoria 3: Meta já concluída não pode ser alterada → 400."""
        create_resp = await auth_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        # Completar a meta
        await auth_client.put(f"/api/v1/goals/{goal_id}", json={"current_value": 90.0})

        # Tentar atualizar meta já concluída
        response = await auth_client.put(
            f"/api/v1/goals/{goal_id}",
            json={"current_value": 95.0},
        )

        assert response.status_code == 400
        assert "concluída" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_wrong_user_cannot_update(self, async_client_as, goal_data, sample_user, sample_user_data, test_db_session):
        """Melhoria 4: Usuário que não é dono nem criador recebe 403."""
        # Criar segundo usuário no banco
        second_data = {**sample_user_data, "email": "stranger@example.com"}
        from app.services.user_service import UserService
        from app.dtos.user_dto import CreateUserDTO
        service = UserService(test_db_session)
        stranger_resp = await service.create(CreateUserDTO(**second_data))
        from app.models.user import User as UserModel
        stranger = await test_db_session.get(UserModel, stranger_resp.id)

        # Criar meta como sample_user
        owner_client = await async_client_as(sample_user)
        async with owner_client as c:
            create_resp = await c.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        # Tentar atualizar como stranger → 403
        stranger_client = await async_client_as(stranger)
        async with stranger_client as c:
            response = await c.put(f"/api/v1/goals/{goal_id}", json={"current_value": 85.0})

        assert response.status_code == 403
        assert "acesso negado" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_wrong_user_cannot_delete(self, async_client_as, goal_data, sample_user, sample_user_data, test_db_session):
        """Melhoria 4: Usuário que não é dono não pode deletar → 403."""
        second_data = {**sample_user_data, "email": "stranger2@example.com"}
        from app.services.user_service import UserService
        from app.dtos.user_dto import CreateUserDTO
        service = UserService(test_db_session)
        stranger_resp = await service.create(CreateUserDTO(**second_data))
        from app.models.user import User as UserModel
        stranger = await test_db_session.get(UserModel, stranger_resp.id)

        owner_client = await async_client_as(sample_user)
        async with owner_client as c:
            create_resp = await c.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        stranger_client = await async_client_as(stranger)
        async with stranger_client as c:
            response = await c.delete(f"/api/v1/goals/{goal_id}")

        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_owner_can_update_authenticated(self, auth_client, goal_data):
        """Melhoria 4: Dono da meta (via token no override) pode atualizar."""
        create_resp = await auth_client.post("/api/v1/goals", json=goal_data)
        goal_id = create_resp.json()["id"]

        response = await auth_client.put(
            f"/api/v1/goals/{goal_id}",
            json={"current_value": 85.0},
        )

        assert response.status_code == 200
        assert response.json()["current_value"] == 85.0

    @pytest.mark.asyncio
    async def test_update_without_token_returns_401(self, test_db_session, goal_data, sample_user):
        """Segurança: PUT sem Bearer token deve retornar 401."""
        from main import app as fastapi_app
        from app.config.database import get_db

        # Cliente sem nenhum override — a dependency real exige Bearer token
        async def override_get_db():
            yield test_db_session

        fastapi_app.dependency_overrides[get_db] = override_get_db

        transport = ASGITransport(app=fastapi_app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as c:
            # Primeiro cria a meta com override de auth (via fixture de goal_data usa sample_user)
            # Aqui apenas testamos o endpoint de update sem token
            fake_id = "550e8400-e29b-41d4-a716-446655440000"
            response = await c.put(f"/api/v1/goals/{fake_id}", json={"current_value": 85.0})

        fastapi_app.dependency_overrides.clear()

        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_delete_without_token_returns_401(self, test_db_session):
        """Segurança: DELETE sem Bearer token deve retornar 401."""
        from main import app as fastapi_app
        from app.config.database import get_db

        async def override_get_db():
            yield test_db_session

        fastapi_app.dependency_overrides[get_db] = override_get_db

        transport = ASGITransport(app=fastapi_app)
        async with httpx.AsyncClient(transport=transport, base_url="http://test") as c:
            fake_id = "550e8400-e29b-41d4-a716-446655440000"
            response = await c.delete(f"/api/v1/goals/{fake_id}")

        fastapi_app.dependency_overrides.clear()

        assert response.status_code == 401
