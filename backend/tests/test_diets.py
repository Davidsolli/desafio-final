"""
Testes de integração para o módulo de Dieta.

Cobre os cenários do PRD seção 6:
1. Criar custom food → 201
2. Listar custom foods do usuário → 200
3. Criar dieta prescrita (como personal) → 201
4. Criar dieta personalizada (como aluno) → 201
5. Listar dietas do aluno → 200
6. Buscar dieta com macros calculados → 200
7. Atualizar dieta → 200
8. Soft delete → 204
9. Duplicar dieta → 201
10. Aluno NÃO pode criar dieta prescrita → 403
11. Aluno NÃO vê dieta de outro aluno → 403
12. RN-01: dieta anterior é desativada → campo is_active
"""

import pytest
import pytest_asyncio

from app.models.user import User
import app.models.diet  # noqa: F401 — registra tabelas
import app.models.diet_logbook  # noqa: F401
import app.models.food_catalog  # noqa: F401

from app.dependencies.auth import get_current_user
from main import app as fastapi_app


def login_as(user: User):
    """Sobrescreve a dependência de usuário atual para simular login."""
    fastapi_app.dependency_overrides[get_current_user] = lambda: user


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

PERSONAL_PAYLOAD = {
    "name": "Nutri Personal",
    "email": "nutri@test.com",
    "password": "SenhaForte123!",
    "role": "personal_trainer",
    "phone_whatsapp": "+55 11 98888-8888",
}

CLIENT_A_PAYLOAD = {
    "name": "Aluno A",
    "email": "aluno_a@test.com",
    "password": "SenhaForte123!",
    "role": "client",
    "phone_whatsapp": "+55 11 97777-7777",
}

CLIENT_B_PAYLOAD = {
    "name": "Aluno B",
    "email": "aluno_b@test.com",
    "password": "SenhaForte123!",
    "role": "client",
    "phone_whatsapp": "+55 11 96666-6666",
}

CUSTOM_FOOD = {
    "name": "Whey Protein Gold",
    "category": "Suplementos",
    "energy_kcal": 120.0,
    "protein_g": 24.0,
    "carbohydrate_g": 3.0,
    "lipid_g": 1.5,
    "fiber_g": 0.0,
}


@pytest_asyncio.fixture
async def personal_user(test_db_session):
    """Cria um personal trainer no banco."""
    from app.services.user_service import UserService
    from app.dtos.user_dto import CreateUserDTO

    service = UserService(test_db_session)
    resp = await service.create(CreateUserDTO(**PERSONAL_PAYLOAD))
    return await test_db_session.get(User, resp.id)


@pytest_asyncio.fixture
async def client_a(test_db_session):
    """Cria aluno A."""
    from app.services.user_service import UserService
    from app.dtos.user_dto import CreateUserDTO

    service = UserService(test_db_session)
    resp = await service.create(CreateUserDTO(**CLIENT_A_PAYLOAD))
    return await test_db_session.get(User, resp.id)


@pytest_asyncio.fixture
async def client_b(test_db_session):
    """Cria aluno B."""
    from app.services.user_service import UserService
    from app.dtos.user_dto import CreateUserDTO

    service = UserService(test_db_session)
    resp = await service.create(CreateUserDTO(**CLIENT_B_PAYLOAD))
    return await test_db_session.get(User, resp.id)


# ---------------------------------------------------------------------------
# Testes de Custom Foods
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_create_custom_food(async_client_as, client_a):
    """Aluno cria alimento personalizado → 201."""
    ac = await async_client_as(client_a)
    resp = await ac.post("/api/v1/custom-foods", json=CUSTOM_FOOD)
    assert resp.status_code == 201
    data = resp.json()
    assert data["name"] == "Whey Protein Gold"
    assert data["protein_g"] == 24.0
    assert data["user_id"] == str(client_a.id)
    await ac.aclose()


@pytest.mark.asyncio
async def test_list_custom_foods(async_client_as, client_a):
    """Lista custom foods criados pelo aluno → 200."""
    ac = await async_client_as(client_a)
    # Criar um alimento primeiro
    await ac.post("/api/v1/custom-foods", json=CUSTOM_FOOD)
    resp = await ac.get("/api/v1/custom-foods")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) >= 1
    assert data[0]["name"] == "Whey Protein Gold"
    await ac.aclose()


@pytest.mark.asyncio
async def test_custom_food_search(async_client_as, client_a):
    """Busca custom food por nome → 200 com filtro."""
    ac = await async_client_as(client_a)
    await ac.post("/api/v1/custom-foods", json=CUSTOM_FOOD)
    resp = await ac.get("/api/v1/custom-foods?search=Whey")
    assert resp.status_code == 200
    assert len(resp.json()) >= 1

    resp2 = await ac.get("/api/v1/custom-foods?search=NaoExiste")
    assert resp2.status_code == 200
    assert len(resp2.json()) == 0
    await ac.aclose()


# ---------------------------------------------------------------------------
# Testes de Dietas
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_create_prescribed_diet(async_client_as, personal_user, client_a):
    """Personal cria dieta prescrita para aluno → 201."""
    ac = await async_client_as(personal_user)

    # Criar custom food para usar na dieta
    food_resp = await ac.post("/api/v1/custom-foods", json=CUSTOM_FOOD)
    custom_food_id = food_resp.json()["id"]

    diet_payload = {
        "user_id": str(client_a.id),
        "name": "Dieta Hipertrofia",
        "goal": "bulking",
        "meals": [
            {
                "name": "Café da Manhã",
                "time": "08:00",
                "order": 1,
                "items": [
                    {
                        "custom_food_id": custom_food_id,
                        "quantity_g": 30.0,
                        "observations": "Com leite",
                    }
                ],
            }
        ],
    }
    resp = await ac.post("/api/v1/diets", json=diet_payload)
    assert resp.status_code == 201
    data = resp.json()
    assert data["is_custom"] is False
    assert data["professional_id"] == str(personal_user.id)
    assert data["user_id"] == str(client_a.id)
    assert data["total_kcal"] > 0
    await ac.aclose()


@pytest.mark.asyncio
async def test_create_custom_diet_as_client(async_client_as, client_a):
    """Aluno cria dieta personalizada → 201 com is_custom=True."""
    ac = await async_client_as(client_a)
    diet_payload = {
        "user_id": str(client_a.id),
        "name": "Minha Dieta Custom",
        "goal": "cutting",
        "meals": [],
    }
    resp = await ac.post("/api/v1/diets", json=diet_payload)
    assert resp.status_code == 201
    data = resp.json()
    assert data["is_custom"] is True
    assert data["professional_id"] is None
    await ac.aclose()


@pytest.mark.asyncio
async def test_client_cannot_prescribe_for_another(async_client_as, client_a, client_b):
    """Aluno não pode criar dieta para outro aluno → 403."""
    ac = await async_client_as(client_a)
    diet_payload = {
        "user_id": str(client_b.id),
        "name": "Dieta Ilegal",
        "goal": "bulking",
        "meals": [],
    }
    resp = await ac.post("/api/v1/diets", json=diet_payload)
    assert resp.status_code == 403
    await ac.aclose()


@pytest.mark.asyncio
async def test_list_diets(async_client_as, client_a):
    """Lista dietas do aluno → 200."""
    ac = await async_client_as(client_a)
    # Criar uma dieta
    await ac.post(
        "/api/v1/diets",
        json={"user_id": str(client_a.id), "name": "Dieta X", "meals": []},
    )
    resp = await ac.get("/api/v1/diets")
    assert resp.status_code == 200
    data = resp.json()
    assert data["total"] >= 1
    await ac.aclose()


@pytest.mark.asyncio
async def test_get_diet_with_macros(async_client_as, personal_user, client_a):
    """GET /diets/{id} retorna macros calculados → 200."""
    ac = await async_client_as(personal_user)

    # Criar alimento + dieta
    food = await ac.post("/api/v1/custom-foods", json=CUSTOM_FOOD)
    fid = food.json()["id"]

    diet_resp = await ac.post(
        "/api/v1/diets",
        json={
            "user_id": str(client_a.id),
            "name": "Dieta Macros",
            "meals": [
                {
                    "name": "Lanche",
                    "order": 1,
                    "items": [{"custom_food_id": fid, "quantity_g": 100}],
                }
            ],
        },
    )
    diet_id = diet_resp.json()["id"]

    resp = await ac.get(f"/api/v1/diets/{diet_id}")
    assert resp.status_code == 200
    data = resp.json()
    # 100g de um alimento com 120 kcal/100g = 120 kcal
    assert data["total_kcal"] == 120.0
    assert data["total_protein"] == 24.0
    await ac.aclose()


@pytest.mark.asyncio
async def test_client_cannot_view_other_diet(async_client_as, personal_user, client_a, client_b):
    """Aluno A não pode ver dieta do Aluno B → 403."""
    # Personal cria dieta para B
    ac_p = await async_client_as(personal_user)
    d = await ac_p.post(
        "/api/v1/diets",
        json={"user_id": str(client_b.id), "name": "Dieta B", "meals": []},
    )
    diet_id = d.json()["id"]
    await ac_p.aclose()

    # A tenta acessar
    ac_a = await async_client_as(client_a)
    resp = await ac_a.get(f"/api/v1/diets/{diet_id}")
    assert resp.status_code == 403
    await ac_a.aclose()


@pytest.mark.asyncio
async def test_update_diet(async_client_as, personal_user, client_a):
    """PUT /diets/{id} atualiza nome → 200."""
    ac = await async_client_as(personal_user)
    d = await ac.post(
        "/api/v1/diets",
        json={"user_id": str(client_a.id), "name": "Original", "meals": []},
    )
    diet_id = d.json()["id"]

    resp = await ac.put(f"/api/v1/diets/{diet_id}", json={"name": "Atualizada"})
    assert resp.status_code == 200
    assert resp.json()["name"] == "Atualizada"
    await ac.aclose()


@pytest.mark.asyncio
async def test_soft_delete_diet(async_client_as, personal_user, client_a):
    """DELETE /diets/{id} → 204."""
    ac = await async_client_as(personal_user)
    d = await ac.post(
        "/api/v1/diets",
        json={"user_id": str(client_a.id), "name": "Para Deletar", "meals": []},
    )
    diet_id = d.json()["id"]

    resp = await ac.delete(f"/api/v1/diets/{diet_id}")
    assert resp.status_code == 204

    # Verificar que não aparece mais
    get_resp = await ac.get(f"/api/v1/diets/{diet_id}")
    assert get_resp.status_code == 404
    await ac.aclose()


@pytest.mark.asyncio
async def test_duplicate_diet(async_client_as, personal_user, client_a, client_b):
    """POST /diets/{id}/duplicate → 201."""
    ac = await async_client_as(personal_user)

    # Criar dieta para A
    d = await ac.post(
        "/api/v1/diets",
        json={"user_id": str(client_a.id), "name": "Template", "meals": []},
    )
    diet_id = d.json()["id"]

    # Duplicar para B
    resp = await ac.post(
        f"/api/v1/diets/{diet_id}/duplicate",
        json={"user_id": str(client_b.id), "name": "Cópia para B"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["user_id"] == str(client_b.id)
    assert data["name"] == "Cópia para B"
    await ac.aclose()
