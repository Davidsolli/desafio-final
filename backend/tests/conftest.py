"""
Fixtures compartilhadas para testes.

Define banco de dados de teste, cliente HTTP, e dados de exemplo.
"""

import os
import asyncio
from typing import AsyncGenerator

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from fastapi.testclient import TestClient
import httpx
from httpx import ASGITransport

from main import app as fastapi_app
from app.config.database import get_db
from app.models.user import Base, User
import app.models.logbook  # noqa: F401 — garante que workout_sessions/session_exercises entram no Base.metadata
import app.models.body_measurement  # noqa: F401
from app.models.goal import Goal as _Goal, GoalProgressEntry as _GoalProgressEntry  # noqa: F401
from app.models import workout_sheet  # noqa: F401 — registra workout_sheets/exercises no Base.metadata
from app.models import exercise_catalog  # noqa: F401 — registra exercise_catalog no Base.metadata
from app.services.user_service import UserService
from app.dependencies.auth import get_current_user


# Usar banco em memória para testes
TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


@pytest_asyncio.fixture
async def test_engine():
    """Criar engine de teste (em memória)."""
    engine = create_async_engine(
        TEST_DATABASE_URL,
        echo=False,
        connect_args={"check_same_thread": False},
    )

    # Criar tabelas
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    yield engine

    # Cleanup
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def test_db_session(test_engine):
    """Criar sessão de teste."""
    async_session_local = async_sessionmaker(
        test_engine,
        class_=AsyncSession,
        expire_on_commit=False,
        future=True,
    )

    async with async_session_local() as session:
        yield session


@pytest.fixture
def client(test_db_session):
    """Cliente HTTP de teste (sincronizado com FastAPI TestClient)."""

    async def override_get_db():
        yield test_db_session

    fastapi_app.dependency_overrides[get_db] = override_get_db

    with TestClient(fastapi_app) as test_client:
        yield test_client

    fastapi_app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def async_client(test_db_session):
    """Cliente HTTP assíncrono para testes que não precisam de autenticação."""

    async def override_get_db():
        yield test_db_session

    fastapi_app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=fastapi_app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    fastapi_app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def auth_client(test_db_session, sample_user):
    """Cliente HTTP assíncrono autenticado como sample_user (para testes de goals)."""

    async def override_get_db():
        yield test_db_session

    # Sobrescreve get_current_user para retornar sample_user sem validar token JWT.
    # Isso isola os testes de regras de negócio da infraestrutura de autenticação.
    async def override_get_current_user():
        return sample_user

    fastapi_app.dependency_overrides[get_db] = override_get_db
    fastapi_app.dependency_overrides[get_current_user] = override_get_current_user

    transport = ASGITransport(app=fastapi_app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    fastapi_app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def async_client_as(test_db_session):
    """Fábrica: retorna função que cria async_client autenticado como um usuário específico."""

    async def _make_client(user: User):
        async def override_get_db():
            yield test_db_session

        async def override_get_current_user():
            return user

        fastapi_app.dependency_overrides[get_db] = override_get_db
        fastapi_app.dependency_overrides[get_current_user] = override_get_current_user

        transport = ASGITransport(app=fastapi_app)
        return httpx.AsyncClient(transport=transport, base_url="http://test")

    yield _make_client
    fastapi_app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def sample_user_data():
    """Dados de exemplo de usuário válido."""
    return {
        "name": "João Silva",
        "email": "joao@example.com",
        "password": "SenhaForte123!",
        "role": "client",
        "phone_whatsapp": "+55 11 99999-9999",
    }


@pytest_asyncio.fixture
async def sample_user(test_db_session, sample_user_data):
    """Criar usuário de exemplo no banco."""
    service = UserService(test_db_session)
    from app.dtos.user_dto import CreateUserDTO

    dto = CreateUserDTO(**sample_user_data)
    user_response = await service.create(dto)

    # Buscar o usuário criado para retornar a instância completa
    user = await test_db_session.get(User, user_response.id)
    return user


@pytest.fixture(scope="session")
def event_loop():
    """Event loop para testes async."""
    loop = asyncio.get_event_loop_policy().new_event_loop()
    yield loop
    loop.close()
