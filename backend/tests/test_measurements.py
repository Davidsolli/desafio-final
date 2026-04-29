"""
Testes de integração para o módulo de Cálculo de Composição Corporal.
"""

from datetime import date, datetime, timedelta
from uuid import uuid4

import pytest
import pytest_asyncio
import httpx
from httpx import ASGITransport

from main import app as fastapi_app
from app.config.database import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.services.user_service import UserService
from app.dtos.user_dto import CreateUserDTO, UpdateUserDTO


# ---------------------------------------------------------------------------
# Helpers / fixtures locais
# ---------------------------------------------------------------------------

MEASUREMENT_URL = "/api/v1/measurements"

VALID_PAYLOAD = {
    "weight_kg": 85.5,
    "height_cm": 175.0,
    "waist_cm": 82.0,
    "activity_level": "moderate",
}


async def _set_gender_birth(session, user: User, gender: str, birth_date: date) -> User:
    """Atualiza gender e birth_date diretamente na sessão."""
    user.gender = gender
    user.birth_date = birth_date
    await session.flush()
    await session.refresh(user)
    return user


def _make_auth_transport(session, user: User):
    async def override_get_db():
        yield session

    async def override_get_current_user():
        return user

    fastapi_app.dependency_overrides[get_db] = override_get_db
    fastapi_app.dependency_overrides[get_current_user] = override_get_current_user
    return ASGITransport(app=fastapi_app)


@pytest_asyncio.fixture
async def user_with_profile(test_db_session):
    """Usuário com gender e birth_date preenchidos (necessário para TMB)."""
    service = UserService(test_db_session)
    dto = CreateUserDTO(
        name="Ana Fitness",
        email="ana@fitness.com",
        password="SenhaForte123!",
        role="client",
        phone_whatsapp="+55 11 91111-1111",
    )
    resp = await service.create(dto)
    user = await test_db_session.get(User, resp.id)
    await _set_gender_birth(test_db_session, user, "female", date(1990, 6, 15))
    await test_db_session.commit()
    await test_db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def other_user(test_db_session):
    """Segundo usuário (client) sem perfil completo."""
    service = UserService(test_db_session)
    dto = CreateUserDTO(
        name="Carlos Outro",
        email="carlos@outro.com",
        password="SenhaForte123!",
        role="client",
        phone_whatsapp="+55 11 92222-2222",
    )
    resp = await service.create(dto)
    user = await test_db_session.get(User, resp.id)
    await _set_gender_birth(test_db_session, user, "male", date(1985, 3, 10))
    await test_db_session.commit()
    await test_db_session.refresh(user)
    return user


# ---------------------------------------------------------------------------
# Teste 1 — Criar medida com sucesso
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_create_measurement_success(test_db_session, user_with_profile):
    transport = _make_auth_transport(test_db_session, user_with_profile)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.post(MEASUREMENT_URL, json=VALID_PAYLOAD)
    fastapi_app.dependency_overrides.clear()

    assert response.status_code == 201
    data = response.json()
    assert "bmi" in data
    assert "bmr_kcal" in data
    assert "tdee_kcal" in data
    assert data["weight_kg"] == 85.5
    assert data["bmi"] > 0
    assert data["bmr_kcal"] > 0
    assert data["tdee_kcal"] > 0


# ---------------------------------------------------------------------------
# Teste 2 — Usuário sem gender/birth_date recebe 400
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_create_measurement_incomplete_profile_returns_400(test_db_session):
    service = UserService(test_db_session)
    dto = CreateUserDTO(
        name="Sem Perfil",
        email="semperfil@test.com",
        password="SenhaForte123!",
        role="client",
        phone_whatsapp="+55 11 93333-3333",
    )
    resp = await service.create(dto)
    incomplete_user = await test_db_session.get(User, resp.id)
    await test_db_session.commit()

    transport = _make_auth_transport(test_db_session, incomplete_user)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.post(MEASUREMENT_URL, json=VALID_PAYLOAD)
    fastapi_app.dependency_overrides.clear()

    assert response.status_code == 400
    assert "gender" in response.json()["detail"].lower() or "perfil" in response.json()["detail"].lower()


# ---------------------------------------------------------------------------
# Teste 3 — Listar medidas com paginação
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_measurements_pagination(test_db_session, user_with_profile):
    transport = _make_auth_transport(test_db_session, user_with_profile)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        # Criar 3 medidas
        for w in [80.0, 82.0, 84.0]:
            payload = {**VALID_PAYLOAD, "weight_kg": w}
            await ac.post(MEASUREMENT_URL, json=payload)

        response = await ac.get(MEASUREMENT_URL, params={"page": 1, "limit": 2})
    fastapi_app.dependency_overrides.clear()

    assert response.status_code == 200
    data = response.json()
    assert data["total"] == 3
    assert data["page"] == 1
    assert data["limit"] == 2
    assert len(data["data"]) == 2


# ---------------------------------------------------------------------------
# Teste 4 — Obter última medida
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_latest_measurement(test_db_session, user_with_profile):
    transport = _make_auth_transport(test_db_session, user_with_profile)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        await ac.post(MEASUREMENT_URL, json={**VALID_PAYLOAD, "weight_kg": 90.0})
        await ac.post(MEASUREMENT_URL, json={**VALID_PAYLOAD, "weight_kg": 88.0})
        response = await ac.get(f"{MEASUREMENT_URL}/latest")
    fastapi_app.dependency_overrides.clear()

    assert response.status_code == 200
    assert response.json()["weight_kg"] == 88.0


# ---------------------------------------------------------------------------
# Teste 5 — 404 quando não há medidas
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_get_latest_no_measurements_returns_404(test_db_session, user_with_profile):
    transport = _make_auth_transport(test_db_session, user_with_profile)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.get(f"{MEASUREMENT_URL}/latest")
    fastapi_app.dependency_overrides.clear()

    assert response.status_code == 404


# ---------------------------------------------------------------------------
# Teste 6 — Evolução de peso com estatísticas
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_evolution_weight_statistics(test_db_session, user_with_profile):
    transport = _make_auth_transport(test_db_session, user_with_profile)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        for w in [90.0, 88.0, 86.0]:
            payload = {**VALID_PAYLOAD, "weight_kg": w}
            await ac.post(MEASUREMENT_URL, json=payload)

        response = await ac.get(f"{MEASUREMENT_URL}/evolution", params={"metric": "weight", "days": 365})
    fastapi_app.dependency_overrides.clear()

    assert response.status_code == 200
    data = response.json()
    assert data["metric"] == "weight"
    assert len(data["data"]) == 3
    stats = data["statistics"]
    assert stats["initial"] == 90.0
    assert stats["current"] == 86.0
    assert stats["change"] == -4.0
    assert stats["change_percentage"] < 0


# ---------------------------------------------------------------------------
# Teste 7 — Client não pode ver medidas de outro usuário
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_client_cannot_see_other_user_measurements(test_db_session, user_with_profile, other_user):
    # Criar medida como user_with_profile
    transport_owner = _make_auth_transport(test_db_session, user_with_profile)
    async with httpx.AsyncClient(transport=transport_owner, base_url="http://test") as ac:
        await ac.post(MEASUREMENT_URL, json=VALID_PAYLOAD)
    fastapi_app.dependency_overrides.clear()

    # Tentar listar as medidas do user_with_profile como other_user
    transport_other = _make_auth_transport(test_db_session, other_user)
    async with httpx.AsyncClient(transport=transport_other, base_url="http://test") as ac:
        response = await ac.get(
            MEASUREMENT_URL,
            params={"user_id": str(user_with_profile.id)},
        )
    fastapi_app.dependency_overrides.clear()

    assert response.status_code == 403


# ---------------------------------------------------------------------------
# Teste 8 — Sem token retorna 401
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_list_without_token_returns_401(test_db_session):
    async def override_get_db():
        yield test_db_session

    fastapi_app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=fastapi_app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        response = await ac.get(MEASUREMENT_URL)
    fastapi_app.dependency_overrides.clear()

    assert response.status_code == 401
