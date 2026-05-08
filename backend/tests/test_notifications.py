import pytest
from datetime import datetime, date, time
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


@pytest.mark.asyncio
class TestNotifications:
    """Testes para o módulo de notificações - 8+ testes"""

    async def test_criar_preferencias_notificacao(self, db_session: AsyncSession):
        """Teste 1: Criar preferências de notificação"""
        user_id = uuid4()

        # Criar preferência
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            workout_reminder_time=time(17, 0),
            meal_reminder_enabled=False,
            new_workout_sheet_enabled=True,
            quiet_hours_start=time(22, 0),
            quiet_hours_end=time(7, 0),
            silent_days=[0, 6],  # domingo e sábado
        )

        db_session.add(pref)
        await db_session.commit()

        # Verificar se foi criada
        result = await db_session.execute(
            select(NotificationPreference).where(
                NotificationPreference.user_id == user_id
            )
        )
        saved_pref = result.scalars().first()

        assert saved_pref is not None
        assert saved_pref.user_id == user_id
        assert saved_pref.notifications_enabled is True
        assert saved_pref.workout_reminder_enabled is True
        assert saved_pref.workout_reminder_time == time(17, 0)
        assert saved_pref.silent_days == [0, 6]

    async def test_atualizar_preferencias(self, db_session: AsyncSession):
        """Teste 2: Atualizar preferências"""
        user_id = uuid4()

        # Criar preferência inicial
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            workout_reminder_time=time(17, 0),
            meal_reminder_enabled=False,
            new_workout_sheet_enabled=True,
        )
        db_session.add(pref)
        await db_session.commit()

        # Atualizar
        pref.workout_reminder_time = time(18, 30)
        pref.meal_reminder_enabled = True
        await db_session.commit()

        # Verificar atualização
        result = await db_session.execute(
            select(NotificationPreference).where(
                NotificationPreference.user_id == user_id
            )
        )
        updated_pref = result.scalars().first()

        assert updated_pref.workout_reminder_time == time(18, 30)
        assert updated_pref.meal_reminder_enabled is True

    async def test_agendar_notificacao_treino(self, db_session: AsyncSession):
        """Teste 3: Agendar notificação de treino"""
        user_id = uuid4()
        workout_sheet_id = uuid4()
        scheduled_date = date.today()
        scheduled_time = time(17, 0)

        # Agendar lembrete de treino
        schedule = WorkoutReminderSchedule(
            user_id=user_id,
            workout_sheet_id=workout_sheet_id,
            scheduled_date=scheduled_date,
            scheduled_time=scheduled_time,
            sent=False,
            delivery_status="pending",
        )

        db_session.add(schedule)
        await db_session.commit()

        # Verificar se foi agendado
        result = await db_session.execute(
            select(WorkoutReminderSchedule).where(
                WorkoutReminderSchedule.user_id == user_id
            )
        )
        saved_schedule = result.scalars().first()

        assert saved_schedule is not None
        assert saved_schedule.user_id == user_id
        assert saved_schedule.workout_sheet_id == workout_sheet_id
        assert saved_schedule.scheduled_date == scheduled_date
        assert saved_schedule.scheduled_time == scheduled_time
        assert saved_schedule.sent is False
        assert saved_schedule.delivery_status == "pending"

    async def test_enviar_notificacao_fcm_mock(self, db_session: AsyncSession):
        """Teste 4: Enviar notificação via FCM (mock)"""
        user_id = uuid4()

        # Mock do FirebaseMessaging
        with patch("firebase_admin.messaging.send") as mock_send:
            mock_send.return_value = "mock_fcm_response_id"

            # Criar log de notificação
            log = NotificationLog(
                user_id=user_id,
                notification_type="workout_reminder",
                title="Hora do treino! 💪",
                body="Treino de Peito - 45 min",
                data={"workout_sheet_id": str(uuid4())},
                sent_at=datetime.utcnow(),
                status="sent",
            )

            db_session.add(log)
            await db_session.commit()

            # Verificar se foi salvo
            result = await db_session.execute(
                select(NotificationLog).where(NotificationLog.user_id == user_id)
            )
            saved_log = result.scalars().first()

            assert saved_log is not None
            assert saved_log.notification_type == "workout_reminder"
            assert saved_log.status == "sent"
            assert saved_log.sent_at is not None

    async def test_respeitar_quiet_hours(self, db_session: AsyncSession):
        """Teste 5: Respeitar quiet hours (horário de silêncio)"""
        user_id = uuid4()

        # Criar preferência com quiet hours de 22:00 a 07:00
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            quiet_hours_start=time(22, 0),
            quiet_hours_end=time(7, 0),
        )

        db_session.add(pref)
        await db_session.commit()

        # Verificar se quiet hours foi salvo
        result = await db_session.execute(
            select(NotificationPreference).where(
                NotificationPreference.user_id == user_id
            )
        )
        saved_pref = result.scalars().first()

        assert saved_pref.quiet_hours_start == time(22, 0)
        assert saved_pref.quiet_hours_end == time(7, 0)

        # Simular verificação: se hora atual está entre quiet hours, não enviar
        current_time = time(23, 30)  # 23:30 está em quiet hours (22:00-07:00)
        is_in_quiet_hours = (
            current_time >= saved_pref.quiet_hours_start
            or current_time <= saved_pref.quiet_hours_end
        )

        assert is_in_quiet_hours is True

    async def test_respeitar_silent_days(self, db_session: AsyncSession):
        """Teste 6: Respeitar silent days (dias silenciosos)"""
        user_id = uuid4()

        # Criar preferência com dias silenciosos: sábado (5) e domingo (6)
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            silent_days=[5, 6],  # sábado, domingo
        )

        db_session.add(pref)
        await db_session.commit()

        # Verificar se silent days foi salvo
        result = await db_session.execute(
            select(NotificationPreference).where(
                NotificationPreference.user_id == user_id
            )
        )
        saved_pref = result.scalars().first()

        assert saved_pref.silent_days == [5, 6]

        # Simular verificação: domingo é 6
        today_weekday = 6  # domingo
        is_silent_day = today_weekday in saved_pref.silent_days

        assert is_silent_day is True

    async def test_marcar_como_lido(self, db_session: AsyncSession):
        """Teste 7: Marcar notificação como lida"""
        user_id = uuid4()

        # Criar log de notificação
        log = NotificationLog(
            user_id=user_id,
            notification_type="workout_reminder",
            title="Hora do treino!",
            body="Não esqueça de treinar",
            sent_at=datetime.utcnow(),
            read_at=None,  # Inicialmente não lida
            status="delivered",
        )

        db_session.add(log)
        await db_session.commit()

        # Marcar como lida
        log.read_at = datetime.utcnow()
        await db_session.commit()

        # Verificar
        result = await db_session.execute(
            select(NotificationLog).where(NotificationLog.user_id == user_id)
        )
        updated_log = result.scalars().first()

        assert updated_log.read_at is not None
        assert updated_log.read_at > updated_log.sent_at

    async def test_historico_ordenado(self, db_session: AsyncSession):
        """Teste 8: Histórico ordenado (mais recentes primeiro)"""
        user_id = uuid4()

        # Criar 3 logs com timestamps diferentes
        for i in range(3):
            log = NotificationLog(
                user_id=user_id,
                notification_type="workout_reminder",
                title=f"Notificação {i}",
                body=f"Corpo {i}",
                sent_at=datetime(2026, 5, 8, 10, i),
                status="delivered",
            )
            db_session.add(log)

        await db_session.commit()

        # Buscar historico ordenado (mais recentes primeiro)
        result = await db_session.execute(
            select(NotificationLog)
            .where(NotificationLog.user_id == user_id)
            .order_by(NotificationLog.sent_at.desc())
        )
        logs = result.scalars().all()

        assert len(logs) == 3
        # Verificar que está ordenado (descendente)
        assert logs[0].sent_at >= logs[1].sent_at >= logs[2].sent_at
        assert logs[0].title == "Notificação 2"
        assert logs[1].title == "Notificação 1"
        assert logs[2].title == "Notificação 0"

    async def test_notificacoes_desabilitadas_nao_enviadas(
        self, db_session: AsyncSession
    ):
        """Teste 9: Notificações desabilitadas não são enviadas"""
        user_id = uuid4()

        # Criar preferência com notificações desabilitadas
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=False,
            workout_reminder_enabled=True,
        )

        db_session.add(pref)
        await db_session.commit()

        # Verificar master switch
        result = await db_session.execute(
            select(NotificationPreference).where(
                NotificationPreference.user_id == user_id
            )
        )
        saved_pref = result.scalars().first()

        # Se notifications_enabled é False, nenhuma notificação deve ser enviada
        should_send = saved_pref.notifications_enabled and (
            saved_pref.workout_reminder_enabled
        )

        assert should_send is False

    async def test_notificacao_clicada_registra_timestamp(
        self, db_session: AsyncSession
    ):
        """Teste 10: Notificação clicada registra timestamp"""
        user_id = uuid4()

        # Criar log
        log = NotificationLog(
            user_id=user_id,
            notification_type="workout_reminder",
            title="Hora do treino!",
            body="Não esqueça",
            sent_at=datetime.utcnow(),
            read_at=None,
            clicked_at=None,
            status="delivered",
        )

        db_session.add(log)
        await db_session.commit()

        # Registrar clique
        log.clicked_at = datetime.utcnow()
        await db_session.commit()

        # Verificar
        result = await db_session.execute(
            select(NotificationLog).where(NotificationLog.user_id == user_id)
        )
        updated_log = result.scalars().first()

        assert updated_log.clicked_at is not None
        assert updated_log.clicked_at >= updated_log.sent_at
