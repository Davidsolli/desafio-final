"""
Testes de integração para o módulo Ficha de Treino.

Cobre os 9+ cenários do PRD (seção 5.1):
1. Criar ficha com exercícios válidos → 201
2. Listar fichas com paginação → 200
3. Buscar ficha por ID → 200
4. Atualizar ficha (editar exercícios) → 200
5. Deletar ficha (soft delete) → 204
6. Duplicar ficha → 201
7. Validação de muscle_group inválido → 422
8. Validação de series/reps/carga <= 0 → 422
9. Aluno tentando criar/editar ficha → 403
10. Listar fichas filtrado por dia da semana → 200
11. Buscar ficha inexistente → 404
"""

import pytest
import pytest_asyncio
from uuid import uuid4

from app.models.user import User
import app.models.workout_sheet  # noqa: F401 — registra tabelas
import app.models.exercise_catalog  # noqa: F401 — registra tabela

from app.dependencies.auth import get_current_user
from main import app as fastapi_app

def login_as(user: User):
    """Sobrescreve a dependência de usuário atual para simular login."""
    fastapi_app.dependency_overrides[get_current_user] = lambda: user


# ---------------------------------------------------------------------------
# Fixtures específicas deste módulo
# ---------------------------------------------------------------------------

PERSONAL_PAYLOAD = {
    "name": "Personal Trainer",
    "email": "personal@test.com",
    "password": "SenhaForte123!",
    "role": "personal_trainer",
    "phone_whatsapp": "+55 11 98888-8888",
}

CLIENT_PAYLOAD = {
    "name": "Aluno Teste",
    "email": "aluno@test.com",
    "password": "SenhaForte123!",
    "role": "client",
    "phone_whatsapp": "+55 11 97777-7777",
}

EXERCISE_VALID = {
    "name": "Supino Reto",
    "muscle_group": "peito",
    "series": 4,
    "repetitions": 8,
    "load_kg": 80.0,
    "rest_seconds": 120,
    "observations": "Manter escápula retraída",
    "order": 1,
}

SHEET_VALID = {
    "name": "Treino A - Peito",
    "description": "Ficha de peito com foco em força",
    "day_of_week": 0,
    "exercises": [EXERCISE_VALID],
}


@pytest_asyncio.fixture
async def personal_user(test_db_session):
    """Cria um personal trainer no banco."""
    from app.services.user_service import UserService
    from app.dtos.user_dto import CreateUserDTO

    service = UserService(test_db_session)
    dto = CreateUserDTO(**PERSONAL_PAYLOAD)
    user_response = await service.create(dto)
    return await test_db_session.get(User, user_response.id)


@pytest_asyncio.fixture
async def client_user(test_db_session):
    """Cria um aluno (client) no banco."""
    from app.services.user_service import UserService
    from app.dtos.user_dto import CreateUserDTO

    service = UserService(test_db_session)
    dto = CreateUserDTO(**CLIENT_PAYLOAD)
    user_response = await service.create(dto)
    return await test_db_session.get(User, user_response.id)


@pytest_asyncio.fixture
async def personal_client(test_db_session, async_client_as, personal_user):
    """Cliente HTTP autenticado como personal_trainer."""
    return await async_client_as(personal_user)


@pytest_asyncio.fixture
async def student_client(test_db_session, async_client_as, client_user):
    """Cliente HTTP autenticado como aluno (client)."""
    return await async_client_as(client_user)


@pytest_asyncio.fixture
async def sheet_payload(client_user):
    """Payload válido de ficha, com user_id do aluno."""
    return {**SHEET_VALID, "user_id": str(client_user.id)}


# ---------------------------------------------------------------------------
# Teste 1: Criar ficha com exercícios válidos → 201
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_create_workout_sheet_success(async_client, personal_user, sheet_payload):
    """Personal cria ficha com exercícios válidos — deve retornar 201."""
    login_as(personal_user)
    client = async_client
    response = await client.post("/api/v1/workout-sheets", json=sheet_payload)

    assert response.status_code == 201
    data = response.json()
    assert data["name"] == sheet_payload["name"]
    assert data["day_of_week"] == sheet_payload["day_of_week"]
    assert data["is_active"] is True
    assert len(data["exercises"]) == 1
    assert data["exercises"][0]["name"] == "Supino Reto"
    assert data["exercises"][0]["muscle_group"] == "peito"
    assert data["exercises"][0]["series"] == 4
    assert "id" in data
    assert "personal_trainer_id" in data


# ---------------------------------------------------------------------------
# Teste 2: Listar fichas com paginação → 200
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_list_workout_sheets(async_client, personal_user, sheet_payload):
    """Listar fichas deve retornar paginação com total e data."""
    login_as(personal_user)
    client = async_client
    # Criar 2 fichas (dias diferentes para evitar conflito RN-01)
    await client.post("/api/v1/workout-sheets", json=sheet_payload)

    sheet2 = {**sheet_payload, "day_of_week": 1, "name": "Treino B - Costa"}
    await client.post("/api/v1/workout-sheets", json=sheet2)

    response = await client.get("/api/v1/workout-sheets?page=1&limit=10")

    assert response.status_code == 200
    data = response.json()
    assert "total" in data
    assert "page" in data
    assert "limit" in data
    assert "data" in data
    assert data["total"] >= 1
    # Cada item da lista tem exercise_count
    for item in data["data"]:
        assert "exercise_count" in item


# ---------------------------------------------------------------------------
# Teste 3: Buscar ficha por ID → 200
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_workout_sheet_by_id(async_client, personal_user, sheet_payload):
    """Buscar ficha por ID deve retornar 200 com exercícios em ordem."""
    login_as(personal_user)
    client = async_client
    create_resp = await client.post("/api/v1/workout-sheets", json=sheet_payload)
    sheet_id = create_resp.json()["id"]

    response = await client.get(f"/api/v1/workout-sheets/{sheet_id}")

    assert response.status_code == 200
    data = response.json()
    assert data["id"] == sheet_id
    assert len(data["exercises"]) == 1
    assert data["exercises"][0]["order"] == 1


# ---------------------------------------------------------------------------
# Teste 4: Atualizar ficha (editar exercícios) → 200
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_update_workout_sheet(async_client, personal_user, sheet_payload):
    """Atualizar ficha deve substituir exercícios e retornar 200."""
    login_as(personal_user)
    client = async_client
    create_resp = await client.post("/api/v1/workout-sheets", json=sheet_payload)
    sheet_id = create_resp.json()["id"]

    update_payload = {
        "name": "Treino A - Peito (Modificado)",
        "exercises": [
            {
                "name": "Supino Inclinado",
                "muscle_group": "peito",
                "series": 3,
                "repetitions": 10,
                "load_kg": 60.0,
                "rest_seconds": 90,
                "order": 1,
            },
            {
                "name": "Crucifixo",
                "muscle_group": "peito",
                "series": 3,
                "repetitions": 12,
                "load_kg": 20.0,
                "rest_seconds": 60,
                "order": 2,
            },
        ],
    }
    response = await client.put(f"/api/v1/workout-sheets/{sheet_id}", json=update_payload)

    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Treino A - Peito (Modificado)"
    assert len(data["exercises"]) == 2
    # Verifica que o exercício antigo foi substituído
    names = [ex["name"] for ex in data["exercises"]]
    assert "Supino Reto" not in names
    assert "Supino Inclinado" in names


# ---------------------------------------------------------------------------
# Teste 5: Deletar ficha (soft delete) → 204
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_delete_workout_sheet(async_client, personal_user, sheet_payload):
    """Deletar ficha deve retornar 204 e a ficha não deve aparecer em listagens."""
    login_as(personal_user)
    client = async_client
    create_resp = await client.post("/api/v1/workout-sheets", json=sheet_payload)
    sheet_id = create_resp.json()["id"]

    delete_resp = await client.delete(f"/api/v1/workout-sheets/{sheet_id}")
    assert delete_resp.status_code == 204

    # Ficha não deve aparecer em GET /{id}
    get_resp = await client.get(f"/api/v1/workout-sheets/{sheet_id}")
    assert get_resp.status_code == 404


# ---------------------------------------------------------------------------
# Teste 6: Duplicar ficha → 201
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_duplicate_deleted_workout_sheet_returns_404(async_client, personal_user, sheet_payload):
    """Tentar duplicar ficha deletada deve retornar 404."""
    login_as(personal_user)
    client = async_client
    
    create_resp = await client.post("/api/v1/workout-sheets", json=sheet_payload)
    assert create_resp.status_code == 201
    src_id = create_resp.json()["id"]

    await client.delete(f"/api/v1/workout-sheets/{src_id}")

    dup_payload = {"name": "Treino A - Peito (Cópia)"}
    dup_resp = await client.post(
        f"/api/v1/workout-sheets/{src_id}/duplicate",
        json=dup_payload,
    )
    
    assert dup_resp.status_code == 404


# ---------------------------------------------------------------------------
# Teste 6b: Duplicar ficha com outro aluno → 201
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_duplicate_workout_sheet_to_other_user(
    async_client, personal_user, sheet_payload, client_user, test_db_session
):
    """Duplicar ficha atribuindo a outro aluno deve funcionar."""
    from app.services.user_service import UserService
    from app.dtos.user_dto import CreateUserDTO

    # Criar segundo aluno
    service = UserService(test_db_session)
    second_dto = CreateUserDTO(
        name="Segundo Aluno",
        email="segundo@test.com",
        password="SenhaForte123!",
        role="client",
        phone_whatsapp="+55 11 96666-6666",
    )
    second_resp = await service.create(second_dto)

    login_as(personal_user)
    client = async_client
    create_resp = await client.post("/api/v1/workout-sheets", json=sheet_payload)
    src_id = create_resp.json()["id"]
    src_exercises = create_resp.json()["exercises"]

    # Duplicar para segundo aluno
    dup_resp = await client.post(
        f"/api/v1/workout-sheets/{src_id}/duplicate",
        json={"name": "Cópia para Segundo Aluno", "user_id": str(second_resp.id)},
    )

    assert dup_resp.status_code == 201
    dup_data = dup_resp.json()
    assert dup_data["id"] != str(src_id)
    assert dup_data["name"] == "Cópia para Segundo Aluno"
    assert str(dup_data["user_id"]) == str(second_resp.id)
    assert len(dup_data["exercises"]) == len(src_exercises)
    assert dup_data["exercises"][0]["name"] == src_exercises[0]["name"]


# ---------------------------------------------------------------------------
# Teste 7: Validação de muscle_group inválido → 422
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_create_sheet_invalid_muscle_group(async_client, personal_user, client_user):
    """Grupo muscular inválido deve retornar 422."""
    payload = {
        "user_id": str(client_user.id),
        "name": "Ficha Inválida",
        "day_of_week": 0,
        "exercises": [
            {
                "name": "Exercício X",
                "muscle_group": "INVALIDO",  # inválido
                "series": 3,
                "repetitions": 10,
                "load_kg": 50.0,
                "order": 1,
            }
        ],
    }
    login_as(personal_user)
    client = async_client
    response = await client.post("/api/v1/workout-sheets", json=payload)

    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Teste 8: Validação de series/reps/carga <= 0 → 422
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_create_sheet_invalid_series(async_client, personal_user, client_user):
    """Séries <= 0 deve retornar 422."""
    payload = {
        "user_id": str(client_user.id),
        "name": "Ficha Inválida 2",
        "day_of_week": 0,
        "exercises": [
            {
                "name": "Supino",
                "muscle_group": "peito",
                "series": 0,  # inválido
                "repetitions": 10,
                "load_kg": 50.0,
                "order": 1,
            }
        ],
    }
    login_as(personal_user)
    client = async_client
    response = await client.post("/api/v1/workout-sheets", json=payload)

    assert response.status_code == 422


@pytest.mark.asyncio
async def test_create_sheet_invalid_load(async_client, personal_user, client_user):
    """Carga <= 0 deve retornar 422."""
    payload = {
        "user_id": str(client_user.id),
        "name": "Ficha Inválida 3",
        "day_of_week": 0,
        "exercises": [
            {
                "name": "Supino",
                "muscle_group": "peito",
                "series": 3,
                "repetitions": 10,
                "load_kg": -5.0,  # inválido
                "order": 1,
            }
        ],
    }
    login_as(personal_user)
    client = async_client
    response = await client.post("/api/v1/workout-sheets", json=payload)

    assert response.status_code == 422


# ---------------------------------------------------------------------------
# Teste 9: Controle de acesso — aluno não pode criar/editar → 403
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_student_cannot_create_sheet(async_client, client_user):
    """Aluno não pode criar fichas — deve retornar 403."""
    payload = {
        "user_id": str(client_user.id),
        "name": "Ficha do Aluno",
        "day_of_week": 0,
        "exercises": [],
    }
    login_as(client_user)
    client = async_client
    response = await client.post("/api/v1/workout-sheets", json=payload)

    assert response.status_code == 403


@pytest.mark.asyncio
async def test_student_cannot_edit_sheet(async_client, personal_user, client_user, sheet_payload):
    """Aluno não pode editar fichas — deve retornar 403."""
    login_as(personal_user)
    client = async_client
    create_resp = await client.post("/api/v1/workout-sheets", json=sheet_payload)
    sheet_id = create_resp.json()["id"]

    login_as(client_user)
    client = async_client
    response = await client.put(
        f"/api/v1/workout-sheets/{sheet_id}",
        json={"name": "Tentativa de edição"},
    )

    assert response.status_code == 403


@pytest.mark.asyncio
async def test_student_can_view_own_sheet(async_client, personal_user, client_user, sheet_payload):
    """Aluno pode visualizar suas próprias fichas — deve retornar 200."""
    login_as(personal_user)
    client = async_client
    create_resp = await client.post("/api/v1/workout-sheets", json=sheet_payload)
    sheet_id = create_resp.json()["id"]

    login_as(client_user)
    client = async_client
    response = await client.get(f"/api/v1/workout-sheets/{sheet_id}")

    assert response.status_code == 200


# ---------------------------------------------------------------------------
# Teste 10: Filtro por dia da semana → 200
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_list_sheets_filter_by_day(async_client, personal_user, sheet_payload):
    """Listar fichas filtrado por day_of_week deve retornar apenas fichas do dia."""
    login_as(personal_user)
    client = async_client
    # Criar fichas em dias diferentes
    await client.post("/api/v1/workout-sheets", json={**sheet_payload, "day_of_week": 0})
    await client.post("/api/v1/workout-sheets", json={**sheet_payload, "day_of_week": 1, "name": "Treino B"})

    # Filtrar por segunda-feira (0)
    response = await client.get("/api/v1/workout-sheets?day_of_week=0")

    assert response.status_code == 200
    data = response.json()
    for item in data["data"]:
        assert item["day_of_week"] == 0


# ---------------------------------------------------------------------------
# Teste 11: Buscar ficha inexistente → 404
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_get_nonexistent_sheet(async_client, personal_user):
    """Buscar ficha com ID inexistente deve retornar 404."""
    fake_id = str(uuid4())
    login_as(personal_user)
    client = async_client
    response = await client.get(f"/api/v1/workout-sheets/{fake_id}")

    assert response.status_code == 404
    assert "não encontrada" in response.json()["detail"].lower()


# ---------------------------------------------------------------------------
# Teste 12: RN-01 — Não pode ter duas fichas ativas no mesmo dia
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_rn01_one_sheet_per_day(async_client, personal_user, sheet_payload):
    """RN-01: Segunda ficha no mesmo aluno+dia deve retornar 409."""
    login_as(personal_user)
    client = async_client
    first_resp = await client.post("/api/v1/workout-sheets", json=sheet_payload)
    assert first_resp.status_code == 201

    second_resp = await client.post(
        "/api/v1/workout-sheets",
        json={**sheet_payload, "name": "Segunda Ficha no Mesmo Dia"},
    )
    assert second_resp.status_code == 409
