"""
Testes da Fase 3 do PRD de Notificações
(`docs/PRD_NOTIFICACOES_FASE_3_QUALIDADE_SEGURANCA.md`).

Cobre:
- RN05: rename do query param `type` → `notification_type` em `GET /history`.
- RN04: rate limit 60/minute em `PUT /api/v1/notifications/token`.
"""

from datetime import datetime, timezone
from uuid import uuid4

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import NotificationLog
from app.models.user import User


@pytest.fixture(autouse=True)
def reset_rate_limiter():
    """Zera contadores do rate limiter antes de cada teste (mesmo padrão de
    `tests/test_password_recovery.py`)."""
    from app.config.limiter import limiter

    limiter._limiter.storage.reset()
    yield


def _make_user(user_id, *, role: str = "client", fcm_token: str = "tok") -> User:
    return User(
        id=user_id,
        email=f"{user_id}@test.com",
        name="Test User",
        password="hash",
        role=role,
        fcm_token=fcm_token,
    )


@pytest.mark.asyncio
class TestRenameQueryParam:
    """RN05: query param renomeado de `type` para `notification_type`."""

    async def test_get_history_aceita_query_notification_type(
        self, async_client_as, test_db_session: AsyncSession
    ):
        user = _make_user(uuid4())
        test_db_session.add(user)
        await test_db_session.commit()

        # Cria um log de cada tipo
        for ntype in ("workout_reminder", "achievement"):
            log = NotificationLog(
                user_id=user.id,
                notification_type=ntype,
                title="x",
                body="x",
                status="sent",
                sent_at=datetime.now(timezone.utc),
            )
            test_db_session.add(log)
        await test_db_session.commit()

        client = await async_client_as(user)
        try:
            resp = await client.get(
                "/api/v1/notifications/history",
                params={"notification_type": "workout_reminder"},
            )
            assert resp.status_code == 200, resp.text
            data = resp.json()
            assert data["total"] == 1
            assert data["data"][0]["notification_type"] == "workout_reminder"
        finally:
            await client.aclose()


@pytest.mark.asyncio
class TestTokenRateLimit:
    """RN04: PUT /notifications/token bloqueia acima de 60/minute."""

    async def test_token_endpoint_rate_limit_60_por_min(
        self, async_client_as, test_db_session: AsyncSession
    ):
        user = _make_user(uuid4())
        test_db_session.add(user)
        await test_db_session.commit()

        client = await async_client_as(user)
        try:
            # Primeiras 60 chamadas devem passar (200)
            for i in range(60):
                resp = await client.put(
                    "/api/v1/notifications/token",
                    json={"fcm_token": f"token_{i}"},
                )
                assert resp.status_code == 200, (
                    f"Chamada #{i + 1} retornou {resp.status_code}: {resp.text}"
                )

            # 61ª chamada DEVE retornar 429
            resp = await client.put(
                "/api/v1/notifications/token",
                json={"fcm_token": "token_61"},
            )
            assert resp.status_code == 429, (
                f"RN04: 61ª chamada deveria ser bloqueada (429); "
                f"recebeu {resp.status_code}."
            )
        finally:
            await client.aclose()
