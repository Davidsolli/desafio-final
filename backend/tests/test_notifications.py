import pytest
from datetime import datetime, date, time, timezone, timedelta
from uuid import uuid4
from unittest.mock import AsyncMock, patch, MagicMock
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.notification import (
    NotificationPreference,
    NotificationLog,
    WorkoutReminderSchedule,
)
from app.dtos.notification_dto import (
    UpdateNotificationPreferenceDTO,
    NotificationPreferenceResponseDTO,
)
from app.services.notification_service import NotificationService
from app.repositories.notification_repository import NotificationRepository
from app.models.user import User
from fastapi import HTTPException


def _make_user(user_id, fcm_token="mock_fcm_token") -> User:
    return User(
        id=user_id,
        email=f"{user_id}@test.com",
        name="Test User",
        password="hash",
        role="client",
        fcm_token=fcm_token,
    )


@pytest.mark.asyncio
class TestNotifications:
    """Testes para o módulo de notificações — cobertura real de regras de negócio."""

    async def test_criar_preferencias_notificacao(self, test_db_session: AsyncSession):
        """Teste 1: Criar e persistir preferências de notificação."""
        user_id = uuid4()

        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            workout_reminder_time=time(17, 0),
            meal_reminder_enabled=False,
            new_workout_sheet_enabled=True,
            quiet_hours_start=time(22, 0),
            quiet_hours_end=time(7, 0),
            silent_days=[0, 6],
        )

        test_db_session.add(pref)
        await test_db_session.commit()

        result = await test_db_session.execute(
            select(NotificationPreference).where(
                NotificationPreference.user_id == user_id
            )
        )
        saved = result.scalars().first()

        assert saved is not None
        assert saved.notifications_enabled is True
        assert saved.workout_reminder_time == time(17, 0)
        assert saved.silent_days == [0, 6]

    async def test_atualizar_preferencias(self, test_db_session: AsyncSession):
        """Teste 2: Atualizar preferências persistidas."""
        user_id = uuid4()

        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            workout_reminder_time=time(17, 0),
            meal_reminder_enabled=False,
            new_workout_sheet_enabled=True,
        )
        test_db_session.add(pref)
        await test_db_session.commit()

        pref.workout_reminder_time = time(18, 30)
        pref.meal_reminder_enabled = True
        await test_db_session.commit()

        result = await test_db_session.execute(
            select(NotificationPreference).where(
                NotificationPreference.user_id == user_id
            )
        )
        updated = result.scalars().first()

        assert updated.workout_reminder_time == time(18, 30)
        assert updated.meal_reminder_enabled is True

    async def test_agendar_notificacao_treino(self, test_db_session: AsyncSession):
        """Teste 3: Agendar lembrete de treino."""
        user_id = uuid4()
        workout_sheet_id = uuid4()

        schedule = WorkoutReminderSchedule(
            user_id=user_id,
            workout_sheet_id=workout_sheet_id,
            scheduled_date=date.today(),
            scheduled_time=time(17, 0),
            sent=False,
            delivery_status="pending",
        )

        test_db_session.add(schedule)
        await test_db_session.commit()

        result = await test_db_session.execute(
            select(WorkoutReminderSchedule).where(
                WorkoutReminderSchedule.user_id == user_id
            )
        )
        saved = result.scalars().first()

        assert saved is not None
        assert saved.scheduled_time == time(17, 0)
        assert saved.sent is False
        assert saved.delivery_status == "pending"

    async def test_enviar_notificacao_fcm_mock(self, test_db_session: AsyncSession):
        """Teste 4: Enviar notificação via FCM; verifica log e payload enviado."""
        user_id = uuid4()

        user = _make_user(user_id, fcm_token="real_device_token")
        test_db_session.add(user)
        await test_db_session.commit()

        with patch("firebase_admin.messaging.send") as mock_send:
            mock_send.return_value = "projects/x/messages/abc123"

            service = NotificationService(test_db_session)
            log = await service.send_notification(
                user_id=user_id,
                type="workout_reminder",
                title="Hora do treino!",
                body="Treino de Peito",
                data={"workout_sheet_id": str(uuid4())},
            )

            # Verifica que o Firebase foi chamado com o token certo
            assert mock_send.called
            call_args = mock_send.call_args[0][0]  # primeiro arg posicional = Message
            assert call_args.token == "real_device_token"
            assert call_args.notification.title == "Hora do treino!"
            assert call_args.notification.body == "Treino de Peito"

            # Log deve registrar envio
            assert log.status == "sent"
            assert log.sent_at is not None
            assert log.notification_type == "workout_reminder"

    async def test_send_notification_bloqueada_por_master_switch(
        self, test_db_session: AsyncSession
    ):
        """
        Teste 5 (reescrito — era FP-01): notificação NÃO enviada quando
        notifications_enabled=False. Verifica o comportamento real do service,
        não reimplementa a lógica no teste.
        """
        user_id = uuid4()

        user = _make_user(user_id, fcm_token="tok")
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=False,
            workout_reminder_enabled=True,
        )
        test_db_session.add(user)
        test_db_session.add(pref)
        await test_db_session.commit()

        with patch("firebase_admin.messaging.send") as mock_send:
            service = NotificationService(test_db_session)
            log = await service.send_notification(
                user_id=user_id,
                type="workout_reminder",
                title="Ignorar",
                body="Não deve chegar",
            )

            # FCM nunca deve ser chamado
            mock_send.assert_not_called()
            assert log.status == "cancelled_by_preference"

    async def test_send_notification_bloqueada_por_quiet_hours(
        self, test_db_session: AsyncSession
    ):
        """
        Teste 6 (reescrito — era FP-02): notificação NÃO enviada em quiet hours.
        Usa quiet_hours_start=00:00 / end=23:59 para garantir bloqueio
        independente do horário de execução do teste.
        """
        user_id = uuid4()

        user = _make_user(user_id, fcm_token="tok")
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            # Janela que cobre qualquer horário do dia (always quiet)
            quiet_hours_start=time(0, 0),
            quiet_hours_end=time(23, 59),
        )
        test_db_session.add(user)
        test_db_session.add(pref)
        await test_db_session.commit()

        with patch("firebase_admin.messaging.send") as mock_send:
            service = NotificationService(test_db_session)
            log = await service.send_notification(
                user_id=user_id,
                type="workout_reminder",
                title="Silenciado",
                body="Não deve chegar",
            )

            mock_send.assert_not_called()
            assert log.status == "cancelled_by_quiet_hours"

    async def test_send_notification_bloqueada_por_silent_day(
        self, test_db_session: AsyncSession
    ):
        """
        Teste 7 (novo): notificação bloqueada em silent day.
        Define todos os dias da semana como silenciosos para evitar dependência
        do dia de execução.
        """
        user_id = uuid4()

        user = _make_user(user_id, fcm_token="tok")
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            silent_days=[0, 1, 2, 3, 4, 5, 6],  # todos os dias
        )
        test_db_session.add(user)
        test_db_session.add(pref)
        await test_db_session.commit()

        with patch("firebase_admin.messaging.send") as mock_send:
            service = NotificationService(test_db_session)
            log = await service.send_notification(
                user_id=user_id,
                type="workout_reminder",
                title="Silenciado",
                body="Não deve chegar",
            )

            mock_send.assert_not_called()
            assert log.status == "cancelled_by_silent_day"

    async def test_marcar_como_lido(self, test_db_session: AsyncSession):
        """Teste 8: Marcar notificação como lida via repository."""
        user_id = uuid4()

        log = NotificationLog(
            user_id=user_id,
            notification_type="workout_reminder",
            title="Hora do treino!",
            body="Não esqueça de treinar",
            sent_at=datetime.now(timezone.utc),
            read_at=None,
            status="sent",
        )

        test_db_session.add(log)
        await test_db_session.commit()

        repo = NotificationRepository(test_db_session)
        updated_log = await repo.mark_log_as_read(log.id, user_id)

        assert updated_log is not None
        assert updated_log.read_at is not None
        assert updated_log.read_at > updated_log.sent_at

    async def test_historico_ordenado(self, test_db_session: AsyncSession):
        """Teste 9: Histórico retornado em ordem decrescente de created_at."""
        user_id = uuid4()
        base_time = datetime(2026, 5, 8, 10, 0, tzinfo=timezone.utc)

        for i in range(3):
            log = NotificationLog(
                user_id=user_id,
                notification_type="workout_reminder",
                title=f"Notificação {i}",
                body=f"Corpo {i}",
                sent_at=base_time + timedelta(minutes=i),
                # created_at explícito para garantir ordenação determinística
                created_at=base_time + timedelta(minutes=i),
                status="sent",
            )
            test_db_session.add(log)

        await test_db_session.commit()

        service = NotificationService(test_db_session)
        logs = await service.get_history(user_id)

        assert len(logs) == 3
        # DESC: 2, 1, 0
        assert logs[0].created_at >= logs[1].created_at >= logs[2].created_at
        assert logs[0].title == "Notificação 2"
        assert logs[1].title == "Notificação 1"
        assert logs[2].title == "Notificação 0"

    async def test_notificacao_clicada_registra_timestamp(
        self, test_db_session: AsyncSession
    ):
        """Teste 11: clicked_at é registrado após interação do usuário."""
        user_id = uuid4()

        log = NotificationLog(
            user_id=user_id,
            notification_type="workout_reminder",
            title="Hora do treino!",
            body="Não esqueça",
            sent_at=datetime.now(timezone.utc),
            read_at=None,
            clicked_at=None,
            status="sent",
        )

        test_db_session.add(log)
        await test_db_session.commit()

        log.clicked_at = datetime.now(timezone.utc)
        await test_db_session.commit()

        result = await test_db_session.execute(
            select(NotificationLog).where(NotificationLog.user_id == user_id)
        )
        updated_log = result.scalars().first()

        assert updated_log.clicked_at is not None
        assert updated_log.clicked_at >= updated_log.sent_at

    async def test_bloquear_desativacao_notificacao_essencial(
        self, test_db_session: AsyncSession
    ):
        """
        Teste 12 (Card 15.16): tentar desativar new_workout_sheet_enabled deve
        lançar HTTPException 400. Notificações essenciais não podem ser desligadas.
        """
        user_id = uuid4()

        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            new_workout_sheet_enabled=True,
        )
        test_db_session.add(pref)
        await test_db_session.commit()

        service = NotificationService(test_db_session)
        dto = UpdateNotificationPreferenceDTO(new_workout_sheet_enabled=False)

        with pytest.raises(HTTPException) as exc_info:
            await service.update_preferences(user_id, dto)

        assert exc_info.value.status_code == 400

        # Preferência NÃO deve ter sido alterada
        await test_db_session.refresh(pref)
        assert pref.new_workout_sheet_enabled is True
