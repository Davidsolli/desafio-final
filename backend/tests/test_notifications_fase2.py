"""
Testes da Fase 2 do PRD de Notificações
(`docs/PRD_NOTIFICACOES_FASE_2_TIMEZONE.md`).

Cada teste corresponde a uma RN ou bug catalogado no PRD:
- RN01 / RN03: quiet_hours e silent_days no fuso do usuário (default SP)
- RN02: meal_reminder_time comparado em horário local
- RN04: timezone IANA inválido rejeitado pelo PUT
- RN05 / RN08: meal_reminder idempotente por dia local
- RN06: inactivity job filtra status in (completed, in_progress)
- RN07: workout_sessions.session_date é tz-aware
- Endpoint dedicado PUT /api/v1/users/me/timezone
"""

from datetime import date, datetime, time, timedelta, timezone
from unittest.mock import patch
from uuid import uuid4
from zoneinfo import ZoneInfo

import pytest
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import (
    NotificationLog,
    NotificationPreference,
)
from app.models.user import User
from app.services.notification_service import NotificationService


def _make_user(
    user_id,
    *,
    role: str = "client",
    fcm_token: str = "tok",
    user_timezone=None,
) -> User:
    user = User(
        id=user_id,
        email=f"{user_id}@test.com",
        name="Test User",
        password="hash",
        role=role,
        fcm_token=fcm_token,
    )
    if user_timezone is not None:
        # Coluna ainda não existe na Fase 1; será adicionada na Fase 2.
        # setattr permite o teste compilar antes do model migrado.
        user.timezone = user_timezone
    return user


# ---------------------------------------------------------------------------
# RN01 / RN03: quiet_hours respeita fuso do usuário
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestQuietHoursLocal:
    async def test_quiet_hours_respeita_timezone_brasil(
        self, test_db_session: AsyncSession
    ):
        """
        User em SP (UTC-3), quiet janela curta 17:00–18:00 LOCAL.
        UTC=20:30 → SP=17:30. Em UTC não estaria na janela; em LOCAL está.
        Prova que o guard usa o fuso do usuário (e não UTC).
        """
        user_id = uuid4()
        user = _make_user(user_id, fcm_token="tok", user_timezone="America/Sao_Paulo")
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            quiet_hours_start=time(17, 0),
            quiet_hours_end=time(18, 0),
        )
        test_db_session.add_all([user, pref])
        await test_db_session.commit()

        # UTC=20:30 (fora 17-18 UTC) → SP=17:30 (DENTRO 17-18 local)
        fixed_utc = datetime(2026, 5, 11, 20, 30, tzinfo=timezone.utc)

        class _FakeDateTime(datetime):
            @classmethod
            def now(cls, tz=None):
                if tz is None:
                    return fixed_utc.replace(tzinfo=None)
                return fixed_utc.astimezone(tz)

        with patch("app.services.notification_service.datetime", _FakeDateTime), patch(
            "firebase_admin.messaging.send"
        ) as mock_send:
            service = NotificationService(test_db_session)
            log = await service.send_notification(
                user_id=user_id,
                type="workout_reminder",
                title="Silenciado",
                body="Não deve chegar",
            )

            mock_send.assert_not_called()
            assert log.status == "cancelled_by_quiet_hours"

    async def test_quiet_hours_respeita_timezone_manaus(
        self, test_db_session: AsyncSession
    ):
        """
        User em Manaus (UTC-4) — quiet 14:00–15:00 LOCAL.
        UTC=18:30 → Manaus=14:30. Em UTC fora; em local dentro.
        """
        user_id = uuid4()
        user = _make_user(user_id, fcm_token="tok", user_timezone="America/Manaus")
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            quiet_hours_start=time(14, 0),
            quiet_hours_end=time(15, 0),
        )
        test_db_session.add_all([user, pref])
        await test_db_session.commit()

        fixed_utc = datetime(2026, 5, 11, 18, 30, tzinfo=timezone.utc)

        class _FakeDateTime(datetime):
            @classmethod
            def now(cls, tz=None):
                if tz is None:
                    return fixed_utc.replace(tzinfo=None)
                return fixed_utc.astimezone(tz)

        with patch("app.services.notification_service.datetime", _FakeDateTime), patch(
            "firebase_admin.messaging.send"
        ) as mock_send:
            service = NotificationService(test_db_session)
            log = await service.send_notification(
                user_id=user_id,
                type="workout_reminder",
                title="Silenciado",
                body="Não deve chegar",
            )

            mock_send.assert_not_called()
            assert log.status == "cancelled_by_quiet_hours"

    async def test_quiet_hours_fora_da_janela_local_envia(
        self, test_db_session: AsyncSession
    ):
        """
        User em SP, quiet 22:00–07:00. UTC=15:00 → SP=12:00 (fora da janela).
        Não deve bloquear por quiet hours.
        """
        user_id = uuid4()
        user = _make_user(user_id, fcm_token="tok", user_timezone="America/Sao_Paulo")
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            quiet_hours_start=time(22, 0),
            quiet_hours_end=time(7, 0),
        )
        test_db_session.add_all([user, pref])
        await test_db_session.commit()

        fixed_utc = datetime(2026, 5, 11, 15, 0, tzinfo=timezone.utc)

        class _FakeDateTime(datetime):
            @classmethod
            def now(cls, tz=None):
                if tz is None:
                    return fixed_utc.replace(tzinfo=None)
                return fixed_utc.astimezone(tz)

        with patch("app.services.notification_service.datetime", _FakeDateTime), patch(
            "firebase_admin.messaging.send"
        ) as mock_send:
            mock_send.return_value = "mock-msg-id"
            service = NotificationService(test_db_session)
            log = await service.send_notification(
                user_id=user_id,
                type="workout_reminder",
                title="Hora do treino",
                body="...",
            )

            assert log.status != "cancelled_by_quiet_hours"


@pytest.mark.asyncio
class TestSilentDaysLocal:
    async def test_silent_day_usa_weekday_local(
        self, test_db_session: AsyncSession
    ):
        """
        User em SP. UTC=02:00 quinta → SP=23:00 quarta.
        silent_days=[2] (quarta) deve bloquear porque o weekday LOCAL é quarta.
        """
        user_id = uuid4()
        user = _make_user(user_id, fcm_token="tok", user_timezone="America/Sao_Paulo")
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            silent_days=[2],
        )
        test_db_session.add_all([user, pref])
        await test_db_session.commit()

        # 14/05/2026 = quinta-feira UTC; 02:00 UTC → 23:00 SP do dia 13 (quarta)
        fixed_utc = datetime(2026, 5, 14, 2, 0, tzinfo=timezone.utc)

        class _FakeDateTime(datetime):
            @classmethod
            def now(cls, tz=None):
                if tz is None:
                    return fixed_utc.replace(tzinfo=None)
                return fixed_utc.astimezone(tz)

        with patch("app.services.notification_service.datetime", _FakeDateTime), patch(
            "firebase_admin.messaging.send"
        ) as mock_send:
            service = NotificationService(test_db_session)
            log = await service.send_notification(
                user_id=user_id,
                type="workout_reminder",
                title="Silenciado",
                body="...",
            )

            mock_send.assert_not_called()
            assert log.status == "cancelled_by_silent_day"


# ---------------------------------------------------------------------------
# RN03: default São Paulo quando User.timezone é NULL
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestDefaultTimezone:
    async def test_user_timezone_default_sao_paulo(
        self, test_db_session: AsyncSession
    ):
        """
        User sem timezone deve cair no default America/Sao_Paulo.
        Quiet 17:00–18:00 LOCAL; UTC=20:30 → SP=17:30 → bloqueia.
        Mesmo cenário do test_quiet_hours_respeita_timezone_brasil mas sem
        setar timezone — prova o default.
        """
        user_id = uuid4()
        user = _make_user(user_id, fcm_token="tok", user_timezone=None)
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            quiet_hours_start=time(17, 0),
            quiet_hours_end=time(18, 0),
        )
        test_db_session.add_all([user, pref])
        await test_db_session.commit()

        fixed_utc = datetime(2026, 5, 11, 20, 30, tzinfo=timezone.utc)

        class _FakeDateTime(datetime):
            @classmethod
            def now(cls, tz=None):
                if tz is None:
                    return fixed_utc.replace(tzinfo=None)
                return fixed_utc.astimezone(tz)

        with patch("app.services.notification_service.datetime", _FakeDateTime), patch(
            "firebase_admin.messaging.send"
        ) as mock_send:
            service = NotificationService(test_db_session)
            log = await service.send_notification(
                user_id=user_id,
                type="workout_reminder",
                title="Silenciado",
                body="...",
            )

            mock_send.assert_not_called()
            assert log.status == "cancelled_by_quiet_hours"


# ---------------------------------------------------------------------------
# RN02: meal_reminder no horário local
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestMealReminderLocal:
    async def test_meal_reminder_compara_horario_local(
        self, test_db_session: AsyncSession, monkeypatch
    ):
        """
        User em SP com meal_reminder_time=12:00. UTC=15:00 (SP=12:00).
        O job deve enviar (não em UTC=12:00, que seria SP=09:00).
        """
        user_id = uuid4()
        user = _make_user(user_id, fcm_token="tok", user_timezone="America/Sao_Paulo")
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            meal_reminder_enabled=True,
            meal_reminder_time=time(12, 0),
        )
        test_db_session.add_all([user, pref])
        await test_db_session.commit()

        from app.tasks import notification_scheduler

        class _FakeSession:
            def __init__(self, session):
                self._session = session

            async def __aenter__(self):
                return self._session

            async def __aexit__(self, *args):
                return False

        monkeypatch.setattr(
            notification_scheduler,
            "SessionLocal",
            lambda: _FakeSession(test_db_session),
        )

        # UTC=15:00 = SP=12:00
        fixed_utc = datetime(2026, 5, 11, 15, 0, tzinfo=timezone.utc)

        class _FakeDateTime(datetime):
            @classmethod
            def now(cls, tz=None):
                if tz is None:
                    return fixed_utc.replace(tzinfo=None)
                return fixed_utc.astimezone(tz)

        with patch(
            "app.tasks.notification_scheduler.datetime", _FakeDateTime
        ), patch.object(NotificationService, "send_notification") as mock_send:
            mock_send.return_value = NotificationLog(
                user_id=user_id,
                notification_type="meal_reminder",
                title="x",
                body="x",
                status="sent",
            )
            await notification_scheduler.NotificationScheduler.check_and_send_meal_reminders()

            assert mock_send.called, (
                "RN02: às 15:00 UTC (12:00 SP) com meal_reminder_time=12:00, "
                "o job deveria enviar — comparou em UTC?"
            )

    async def test_meal_reminder_nao_dispara_se_horario_local_diferente(
        self, test_db_session: AsyncSession, monkeypatch
    ):
        """
        User em SP, meal_reminder_time=12:00. UTC=12:00 (SP=09:00).
        NÃO deve disparar (em UTC bateria, em local não).
        """
        user_id = uuid4()
        user = _make_user(user_id, fcm_token="tok", user_timezone="America/Sao_Paulo")
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            meal_reminder_enabled=True,
            meal_reminder_time=time(12, 0),
        )
        test_db_session.add_all([user, pref])
        await test_db_session.commit()

        from app.tasks import notification_scheduler

        class _FakeSession:
            def __init__(self, session):
                self._session = session

            async def __aenter__(self):
                return self._session

            async def __aexit__(self, *args):
                return False

        monkeypatch.setattr(
            notification_scheduler,
            "SessionLocal",
            lambda: _FakeSession(test_db_session),
        )

        fixed_utc = datetime(2026, 5, 11, 12, 0, tzinfo=timezone.utc)

        class _FakeDateTime(datetime):
            @classmethod
            def now(cls, tz=None):
                if tz is None:
                    return fixed_utc.replace(tzinfo=None)
                return fixed_utc.astimezone(tz)

        with patch(
            "app.tasks.notification_scheduler.datetime", _FakeDateTime
        ), patch.object(NotificationService, "send_notification") as mock_send:
            await notification_scheduler.NotificationScheduler.check_and_send_meal_reminders()

            mock_send.assert_not_called()


# ---------------------------------------------------------------------------
# RN05 / RN08: idempotência diária do meal_reminder
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestMealReminderIdempotente:
    async def test_meal_reminder_dispara_uma_vez_por_dia(
        self, test_db_session: AsyncSession, monkeypatch
    ):
        """
        User em SP com meal_reminder. Dois ticks no mesmo dia local:
        primeiro envia, segundo é skipped.
        """
        user_id = uuid4()
        user = _make_user(user_id, fcm_token="tok", user_timezone="America/Sao_Paulo")
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            meal_reminder_enabled=True,
            meal_reminder_time=time(12, 0),
        )
        test_db_session.add_all([user, pref])
        await test_db_session.commit()

        from app.tasks import notification_scheduler

        class _FakeSession:
            def __init__(self, session):
                self._session = session

            async def __aenter__(self):
                return self._session

            async def __aexit__(self, *args):
                return False

        monkeypatch.setattr(
            notification_scheduler,
            "SessionLocal",
            lambda: _FakeSession(test_db_session),
        )

        # Primeiro tick: UTC=15:00 → SP=12:00
        fixed_utc_first = datetime(2026, 5, 11, 15, 0, tzinfo=timezone.utc)

        class _FakeDateTime1(datetime):
            @classmethod
            def now(cls, tz=None):
                if tz is None:
                    return fixed_utc_first.replace(tzinfo=None)
                return fixed_utc_first.astimezone(tz)

        with patch(
            "app.tasks.notification_scheduler.datetime", _FakeDateTime1
        ):
            # Primeiro tick — registra um log real (precisamos do log no banco)
            with patch.object(
                NotificationService, "send_notification"
            ) as mock_send:
                async def _create_log(*a, **kw):
                    log = NotificationLog(
                        user_id=user_id,
                        notification_type="meal_reminder",
                        title="x",
                        body="x",
                        status="sent",
                    )
                    test_db_session.add(log)
                    await test_db_session.flush()
                    return log

                mock_send.side_effect = _create_log
                await notification_scheduler.NotificationScheduler.check_and_send_meal_reminders()
                assert mock_send.call_count == 1

        # Segundo tick: UTC=15:03 → SP=12:03 (mesmo dia local)
        fixed_utc_second = datetime(2026, 5, 11, 15, 3, tzinfo=timezone.utc)

        class _FakeDateTime2(datetime):
            @classmethod
            def now(cls, tz=None):
                if tz is None:
                    return fixed_utc_second.replace(tzinfo=None)
                return fixed_utc_second.astimezone(tz)

        with patch(
            "app.tasks.notification_scheduler.datetime", _FakeDateTime2
        ), patch.object(NotificationService, "send_notification") as mock_send:
            await notification_scheduler.NotificationScheduler.check_and_send_meal_reminders()
            assert mock_send.call_count == 0, (
                "RN05/RN08: já enviou hoje no mesmo dia local — não deveria reenviar."
            )


# ---------------------------------------------------------------------------
# RN06: inactivity job filtra status
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestInactivityStatusFilter:
    async def test_inactivity_ignora_sessoes_deleted(
        self, test_db_session: AsyncSession, monkeypatch
    ):
        """
        Aluno cuja única sessão recente está com status='deleted'
        deve ser considerado inativo e gerar notificação para o trainer.
        """
        from app.models.logbook import WorkoutSession

        trainer_id = uuid4()
        student_id = uuid4()

        trainer = _make_user(
            trainer_id, role="personal_trainer", fcm_token="trainer_tok"
        )
        student = User(
            id=student_id,
            email=f"{student_id}@test.com",
            name="Aluno X",
            password="hash",
            role="client",
            fcm_token="student_tok",
            trainer_id=trainer_id,
            is_active=True,
        )
        test_db_session.add_all([trainer, student])
        await test_db_session.commit()

        # Sessão recente, mas deletada
        recent = datetime.now(timezone.utc) - timedelta(days=1)
        session_deleted = WorkoutSession(
            user_id=student_id,
            workout_sheet_id=uuid4(),
            session_date=recent,
            status="deleted",
        )
        test_db_session.add(session_deleted)
        await test_db_session.commit()

        from app.tasks import notification_scheduler

        class _FakeSession:
            def __init__(self, session):
                self._session = session

            async def __aenter__(self):
                return self._session

            async def __aexit__(self, *args):
                return False

        monkeypatch.setattr(
            notification_scheduler,
            "SessionLocal",
            lambda: _FakeSession(test_db_session),
        )

        with patch.object(NotificationService, "send_notification") as mock_send:
            mock_send.return_value = NotificationLog(
                user_id=trainer_id,
                notification_type="student_inactivity",
                title="x",
                body="x",
                status="sent",
            )
            await notification_scheduler.NotificationScheduler.check_student_inactivity()

            assert mock_send.called, (
                "RN06: sessão 'deleted' não deveria contar como atividade — "
                "trainer deveria receber notificação de inatividade."
            )

    async def test_inactivity_considera_sessao_in_progress(
        self, test_db_session: AsyncSession, monkeypatch
    ):
        """
        Aluno com sessão recente status='in_progress' é considerado ATIVO —
        trainer NÃO recebe notificação.
        """
        from app.models.logbook import WorkoutSession

        trainer_id = uuid4()
        student_id = uuid4()

        trainer = _make_user(
            trainer_id, role="personal_trainer", fcm_token="trainer_tok"
        )
        student = User(
            id=student_id,
            email=f"{student_id}@test.com",
            name="Aluno Y",
            password="hash",
            role="client",
            fcm_token="student_tok",
            trainer_id=trainer_id,
            is_active=True,
        )
        test_db_session.add_all([trainer, student])
        await test_db_session.commit()

        recent = datetime.now(timezone.utc) - timedelta(days=1)
        session_in_progress = WorkoutSession(
            user_id=student_id,
            workout_sheet_id=uuid4(),
            session_date=recent,
            status="in_progress",
        )
        test_db_session.add(session_in_progress)
        await test_db_session.commit()

        from app.tasks import notification_scheduler

        class _FakeSession:
            def __init__(self, session):
                self._session = session

            async def __aenter__(self):
                return self._session

            async def __aexit__(self, *args):
                return False

        monkeypatch.setattr(
            notification_scheduler,
            "SessionLocal",
            lambda: _FakeSession(test_db_session),
        )

        with patch.object(NotificationService, "send_notification") as mock_send:
            await notification_scheduler.NotificationScheduler.check_student_inactivity()

            mock_send.assert_not_called()


# ---------------------------------------------------------------------------
# Endpoint PUT /api/v1/users/me/timezone
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestPutMeTimezone:
    async def test_put_me_timezone_atualiza(
        self, async_client_as, test_db_session: AsyncSession
    ):
        user = _make_user(uuid4(), fcm_token="tok", user_timezone=None)
        test_db_session.add(user)
        await test_db_session.commit()

        client = await async_client_as(user)
        try:
            resp = await client.put(
                "/api/v1/users/me/timezone",
                json={"timezone": "America/Manaus"},
            )
            assert resp.status_code == 200, resp.text
            data = resp.json()
            assert data["timezone"] == "America/Manaus"
        finally:
            await client.aclose()

    async def test_put_me_timezone_invalido_retorna_422(
        self, async_client_as, test_db_session: AsyncSession
    ):
        """RN04: timezone IANA inválido — Pydantic rejeita com 422."""
        user = _make_user(uuid4(), fcm_token="tok", user_timezone=None)
        test_db_session.add(user)
        await test_db_session.commit()

        client = await async_client_as(user)
        try:
            resp = await client.put(
                "/api/v1/users/me/timezone",
                json={"timezone": "Mars/Olympus"},
            )
            assert resp.status_code in (400, 422), resp.text
        finally:
            await client.aclose()
