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

from main import app
from app.config.database import get_db
from app.models.user import Base, User
from app.models.goal import Goal as _Goal, GoalProgressEntry as _GoalProgressEntry  # noqa: F401 — registra tabelas no metadata
from app.services.user_service import UserService


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

    app.dependency_overrides[get_db] = override_get_db

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()


@pytest_asyncio.fixture
async def async_client(test_db_session):
    """Cliente HTTP assíncrono para testes async."""

    async def override_get_db():
        yield test_db_session

    app.dependency_overrides[get_db] = override_get_db

    transport = ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac

    app.dependency_overrides.clear()


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
