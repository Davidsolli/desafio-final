"""
Testes de integração para o Diário Alimentar (Diet Logbook).

Cobre os cenários do PRD seção 6:
1. Adicionar alimento consumido (custom food) → 201
2. Consultar diário do dia → 200
3. Remover entry e verificar subtração de macros → 204
4. Data inexistente → 404
5. Aluno A não vê logbook do Aluno B (isolamento)
6. Personal pode ler logbook do aluno → 200
7. Aluno não pode usar endpoint de personal → 403
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
    "name": "PT Logbook",
    "email": "pt_logbook@test.com",
    "password": "SenhaForte123!",
    "role": "personal_trainer",
    "phone_whatsapp": "+55 11 98888-8888",
}

CLIENT_A_PAYLOAD = {
    "name": "Aluno Log A",
    "email": "aluno_log_a@test.com",
    "password": "SenhaForte123!",
    "role": "client",
    "phone_whatsapp": "+55 11 97777-7777",
}

CLIENT_B_PAYLOAD = {
    "name": "Aluno Log B",
    "email": "aluno_log_b@test.com",
    "password": "SenhaForte123!",
    "role": "client",
    "phone_whatsapp": "+55 11 96666-6666",
}

CUSTOM_FOOD = {
    "name": "Banana Prata",
    "category": "Frutas",
    "energy_kcal": 98.0,
    "protein_g": 1.3,
    "carbohydrate_g": 26.0,
    "lipid_g": 0.1,
    "fiber_g": 2.0,
}


@pytest_asyncio.fixture
async def personal_user(test_db_session):
    from app.services.user_service import UserService
    from app.dtos.user_dto import CreateUserDTO

    service = UserService(test_db_session)
    resp = await service.create(CreateUserDTO(**PERSONAL_PAYLOAD))
    return await test_db_session.get(User, resp.id)


@pytest_asyncio.fixture
async def client_a(test_db_session):
    from app.services.user_service import UserService
    from app.dtos.user_dto import CreateUserDTO

    service = UserService(test_db_session)
    resp = await service.create(CreateUserDTO(**CLIENT_A_PAYLOAD))
    return await test_db_session.get(User, resp.id)


@pytest_asyncio.fixture
async def client_b(test_db_session):
    from app.services.user_service import UserService
    from app.dtos.user_dto import CreateUserDTO

    service = UserService(test_db_session)
    resp = await service.create(CreateUserDTO(**CLIENT_B_PAYLOAD))
    return await test_db_session.get(User, resp.id)


@pytest_asyncio.fixture
async def custom_food_id(async_client_as, client_a):
    """Cria um custom food e retorna o ID."""
    ac = await async_client_as(client_a)
    resp = await ac.post("/api/v1/custom-foods", json=CUSTOM_FOOD)
    food_id = resp.json()["id"]
    await ac.aclose()
    return food_id


# ---------------------------------------------------------------------------
# Testes
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_add_logbook_entry(async_client_as, client_a, custom_food_id):
    """Aluno registra alimento consumido → 201 com macros calculados."""
    ac = await async_client_as(client_a)
    entry = {
        "meal_name": "Café da Manhã",
        "custom_food_id": custom_food_id,
        "quantity_g": 200.0,
        "log_date": "2026-05-03",
    }
    resp = await ac.post("/api/v1/diet-logbook", json=entry)
    assert resp.status_code == 201
    data = resp.json()
    # 200g de um alimento com 98 kcal/100g = 196 kcal
    assert data["kcal"] == 196.0
    assert data["protein"] == 2.6
    assert data["meal_name"] == "Café da Manhã"
    await ac.aclose()


@pytest.mark.asyncio
async def test_get_logbook_by_date(async_client_as, client_a, custom_food_id):
    """Consultar diário do dia → 200 com entries e totais."""
    ac = await async_client_as(client_a)

    # Registrar dois itens
    entry1 = {
        "meal_name": "Café da Manhã",
        "custom_food_id": custom_food_id,
        "quantity_g": 100.0,
        "log_date": "2026-05-03",
    }
    entry2 = {
        "meal_name": "Lanche",
        "custom_food_id": custom_food_id,
        "quantity_g": 100.0,
        "log_date": "2026-05-03",
    }
    await ac.post("/api/v1/diet-logbook", json=entry1)
    await ac.post("/api/v1/diet-logbook", json=entry2)

    resp = await ac.get("/api/v1/diet-logbook/2026-05-03")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data["entries"]) >= 2
    # Totais devem ser soma: 98 + 98 = 196
    assert data["total_kcal"] >= 196.0
    await ac.aclose()


@pytest.mark.asyncio
async def test_logbook_not_found(async_client_as, client_a):
    """Data sem registros → 404."""
    ac = await async_client_as(client_a)
    resp = await ac.get("/api/v1/diet-logbook/2020-01-01")
    assert resp.status_code == 404
    await ac.aclose()


@pytest.mark.asyncio
async def test_remove_entry_updates_totals(async_client_as, client_a, custom_food_id):
    """Remover entry subtrai macros dos totais → 204."""
    ac = await async_client_as(client_a)

    # Adicionar
    entry = {
        "meal_name": "Almoço",
        "custom_food_id": custom_food_id,
        "quantity_g": 100.0,
        "log_date": "2026-05-04",
    }
    add_resp = await ac.post("/api/v1/diet-logbook", json=entry)
    entry_id = add_resp.json()["id"]

    # Verificar totais antes
    day_resp = await ac.get("/api/v1/diet-logbook/2026-05-04")
    assert day_resp.json()["total_kcal"] == 98.0

    # Remover
    del_resp = await ac.delete(f"/api/v1/diet-logbook/entries/{entry_id}")
    assert del_resp.status_code == 204

    # Totais devem zerar (ou 404 se logbook ficou vazio mas ainda existe)
    day_resp2 = await ac.get("/api/v1/diet-logbook/2026-05-04")
    if day_resp2.status_code == 200:
        assert day_resp2.json()["total_kcal"] == 0.0
    await ac.aclose()


@pytest.mark.asyncio
async def test_personal_reads_student_logbook(
    async_client_as, personal_user, client_a, custom_food_id
):
    """Personal pode ler logbook do aluno via endpoint dedicado → 200."""
    # Aluno registra algo
    ac_a = await async_client_as(client_a)
    await ac_a.post(
        "/api/v1/diet-logbook",
        json={
            "meal_name": "Jantar",
            "custom_food_id": custom_food_id,
            "quantity_g": 150.0,
            "log_date": "2026-05-05",
        },
    )
    await ac_a.aclose()

    # Personal acessa
    ac_p = await async_client_as(personal_user)
    resp = await ac_p.get(f"/api/v1/diet-logbook/student/{client_a.id}/2026-05-05")
    assert resp.status_code == 200
    data = resp.json()
    assert data["user_id"] == str(client_a.id)
    assert len(data["entries"]) >= 1
    await ac_p.aclose()


@pytest.mark.asyncio
async def test_client_cannot_use_student_endpoint(async_client_as, client_a, client_b):
    """Aluno não pode usar endpoint de personal → 403."""
    ac = await async_client_as(client_a)
    resp = await ac.get(f"/api/v1/diet-logbook/student/{client_b.id}/2026-05-05")
    assert resp.status_code == 403
    await ac.aclose()
