"""Testes de integração para o módulo de Nutrição (RF-59 a RF-66)."""

import pytest
import app.models.nutrition  # noqa: F401 — garante que tabelas de nutrição entram no Base.metadata


class TestNutritionMeals:
    """Testes de integração das rotas de refeições."""

    @pytest.mark.asyncio
    async def test_create_meal_success(self, auth_client, sample_user):
        """Cria uma refeição com alimentos e verifica totais calculados."""
        payload = {
            "meal_type": "lunch",
            "meal_date": "2026-05-04",
            "notes": "Almoço saudável",
            "foods": [
                {
                    "food_name": "Arroz cozido",
                    "quantity_grams": 150,
                    "calories": 180.0,
                    "protein": 3.5,
                    "carbs": 39.0,
                    "fat": 0.3,
                }
            ],
        }
        response = await auth_client.post("/api/v1/nutrition/meals", json=payload)
        assert response.status_code == 201
        data = response.json()
        assert data["meal_type"] == "lunch"
        assert data["calories"] > 0
        assert len(data["foods"]) == 1

    @pytest.mark.asyncio
    async def test_list_meals_empty(self, auth_client, sample_user):
        """Listagem de refeições sem dados retorna lista vazia."""
        response = await auth_client.get("/api/v1/nutrition/meals")
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_create_meal_invalid_type(self, auth_client, sample_user):
        """Tipo de refeição inválido retorna 422."""
        payload = {
            "meal_type": "midnight_snack",
            "meal_date": "2026-05-04",
            "foods": [],
        }
        response = await auth_client.post("/api/v1/nutrition/meals", json=payload)
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_create_and_get_meal(self, auth_client, sample_user):
        """Cria e depois recupera a refeição por ID."""
        payload = {
            "meal_type": "breakfast",
            "meal_date": "2026-05-04",
            "foods": [
                {
                    "food_name": "Pão integral",
                    "quantity_grams": 50,
                    "calories": 130.0,
                    "protein": 5.0,
                    "carbs": 24.0,
                    "fat": 1.5,
                }
            ],
        }
        create_resp = await auth_client.post("/api/v1/nutrition/meals", json=payload)
        assert create_resp.status_code == 201
        meal_id = create_resp.json()["id"]

        get_resp = await auth_client.get(f"/api/v1/nutrition/meals/{meal_id}")
        assert get_resp.status_code == 200
        assert get_resp.json()["id"] == meal_id

    @pytest.mark.asyncio
    async def test_delete_meal(self, auth_client, sample_user):
        """Soft delete de refeição retorna 204."""
        payload = {
            "meal_type": "snack",
            "meal_date": "2026-05-04",
            "foods": [],
        }
        create_resp = await auth_client.post("/api/v1/nutrition/meals", json=payload)
        assert create_resp.status_code == 201
        meal_id = create_resp.json()["id"]

        del_resp = await auth_client.delete(f"/api/v1/nutrition/meals/{meal_id}")
        assert del_resp.status_code == 204

    @pytest.mark.asyncio
    async def test_daily_summary(self, auth_client, sample_user):
        """Resumo diário de nutrição retorna estrutura correta."""
        response = await auth_client.get(
            "/api/v1/nutrition/daily-summary",
            params={"summary_date": "2026-05-04"},
        )
        assert response.status_code == 200
        data = response.json()
        assert "date" in data
        assert "total_calories" in data
        assert "meals" in data

    @pytest.mark.asyncio
    async def test_unauthenticated_request_rejected(self, async_client):
        """Requisição sem token retorna 401 ou 403."""
        response = await async_client.get("/api/v1/nutrition/meals")
        assert response.status_code in (401, 403)

    @pytest.mark.asyncio
    async def test_food_catalog_search(self, auth_client, sample_user):
        """Busca no catálogo de alimentos retorna lista."""
        response = await auth_client.get(
            "/api/v1/nutrition/foods/search",
            params={"q": "arroz"},
        )
        assert response.status_code == 200
        data = response.json()
        assert isinstance(data, list)

    @pytest.mark.asyncio
    async def test_create_meal_calories_aggregated(self, auth_client, sample_user):
        """Total de calorias é soma dos alimentos incluídos."""
        payload = {
            "meal_type": "dinner",
            "meal_date": "2026-05-04",
            "foods": [
                {
                    "food_name": "Frango grelhado",
                    "quantity_grams": 100,
                    "calories": 165.0,
                    "protein": 31.0,
                    "carbs": 0.0,
                    "fat": 3.6,
                },
                {
                    "food_name": "Batata doce",
                    "quantity_grams": 150,
                    "calories": 129.0,
                    "protein": 2.3,
                    "carbs": 30.0,
                    "fat": 0.1,
                },
            ],
        }
        response = await auth_client.post("/api/v1/nutrition/meals", json=payload)
        assert response.status_code == 201
        data = response.json()
        assert abs(data["calories"] - (165.0 + 129.0)) < 0.01

    @pytest.mark.asyncio
    async def test_update_meal_notes(self, auth_client, sample_user):
        """Atualização de notas de uma refeição existente."""
        payload = {
            "meal_type": "snack",
            "meal_date": "2026-05-04",
            "foods": [],
            "notes": "Notas originais",
        }
        create_resp = await auth_client.post("/api/v1/nutrition/meals", json=payload)
        assert create_resp.status_code == 201
        meal_id = create_resp.json()["id"]

        update_resp = await auth_client.put(
            f"/api/v1/nutrition/meals/{meal_id}",
            json={"notes": "Notas atualizadas", "foods": []},
        )
        assert update_resp.status_code == 200
        assert update_resp.json()["notes"] == "Notas atualizadas"
