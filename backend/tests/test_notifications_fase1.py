"""
Testes da Fase 1 do PRD de Notificações (`docs/PRD_NOTIFICACOES_FASE_1_CRITICOS.md`).

Cada teste corresponde a uma RN ou bug catalogado no PRD:
- BUG-5 / RN04: get_preferences commita a row criada
- BUG-3 / RN05, RN06: regenerate_workout_schedules
- BUG-3 / RN07: job replenish_workout_schedules
- BUG-4 / RN08, RN10: notify_new_workout_sheet ao criar ficha
- BUG-4 / RN09: notify_achievement ao completar meta
"""

from datetime import date, datetime, time, timedelta, timezone
from unittest.mock import patch
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.goal_dto import UpdateGoalDTO
from app.dtos.notification_dto import UpdateNotificationPreferenceDTO
from app.dtos.workout_sheet_dto import CreateWorkoutSheetDTO, ExerciseCreateDTO
from app.models.goal import Goal
from app.models.notification import (
    NotificationLog,
    NotificationPreference,
    WorkoutReminderSchedule,
)
from app.models.user import User
from app.models.workout_sheet import WorkoutProgram, WorkoutSheet
from app.services.goal_service import GoalService
from app.services.notification_service import NotificationService
from app.services.workout_sheet_service import WorkoutSheetService


def _make_user(user_id, *, role: str = "client", fcm_token: str = "tok") -> User:
    return User(
        id=user_id,
        email=f"{user_id}@test.com",
        name="Test User",
        password="hash",
        role=role,
        fcm_token=fcm_token,
    )


async def _create_program_with_sheets(
    session: AsyncSession,
    user_id,
    *,
    days_of_week=(0,),
    program_active: bool = True,
    sheet_active: bool = True,
    personal_trainer_id=None,
) -> WorkoutProgram:
    """
    Helper: cria um WorkoutProgram para o aluno com fichas em cada day_of_week
    informado. Persiste via session e devolve o programa com sheets carregados.
    """
    program = WorkoutProgram(
        user_id=user_id,
        personal_trainer_id=personal_trainer_id or user_id,
        name="Programa de Teste",
        is_active=program_active,
        workout_sheets=[
            WorkoutSheet(
                name=f"Treino dia {dow}",
                day_of_week=dow,
                order=i + 1,
                is_active=sheet_active,
            )
            for i, dow in enumerate(days_of_week)
        ],
    )
    session.add(program)
    await session.commit()
    await session.refresh(program)
    return program


# ---------------------------------------------------------------------------
# BUG-5 / RN04: get_preferences cria + commita
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestGetPreferencesCommit:
    """RN04: GET /preferences cria a preferência na primeira chamada e commita."""

    async def test_get_preferences_commits_new_row(
        self, async_client_as, test_db_session: AsyncSession
    ):
        """
        BUG-5: após GET /preferences pela 1ª vez, o controller DEVE chamar
        db.commit() para persistir a preferência criada. Em testes, a session
        é compartilhada (flush é visível); o ponto verificado aqui é o
        contrato: commit chamado pelo menos uma vez no fluxo do request.
        """
        user = _make_user(uuid4())
        test_db_session.add(user)
        await test_db_session.commit()

        # Spy no commit da session de teste
        original_commit = test_db_session.commit
        call_count = {"n": 0}

        async def counted_commit():
            call_count["n"] += 1
            return await original_commit()

        test_db_session.commit = counted_commit  # type: ignore[assignment]

        client = await async_client_as(user)

        try:
            resp = await client.get("/api/v1/notifications/preferences")
            assert resp.status_code == 200

            assert call_count["n"] >= 1, (
                "BUG-5: get_preferences deveria chamar db.commit() ao criar "
                "uma nova preferência; nenhuma chamada de commit foi observada."
            )

            # Sanity: a row deve estar visível na session
            result = await test_db_session.execute(
                select(NotificationPreference).where(
                    NotificationPreference.user_id == user.id
                )
            )
            pref = result.scalars().first()
            assert pref is not None
            assert pref.user_id == user.id
        finally:
            test_db_session.commit = original_commit  # type: ignore[assignment]
            await client.aclose()


# ---------------------------------------------------------------------------
# BUG-3 / RN05, RN06: regenerate_workout_schedules
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestRegenerateWorkoutSchedules:
    """RN05/RN06: schedule de 7 dias respeitando silent_days, idempotente."""

    async def test_regenerate_schedules_create_7_days(
        self, test_db_session: AsyncSession
    ):
        """RN05: atualizar workout_reminder_time gera 7 schedules futuros."""
        user_id = uuid4()

        # Programa do aluno com uma ficha — regenerate precisa de pelo menos
        # uma sheet ativa associada via WorkoutProgram.
        await _create_program_with_sheets(
            test_db_session, user_id, days_of_week=(0,)
        )

        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            workout_reminder_time=None,
            silent_days=[],
        )
        test_db_session.add(pref)
        await test_db_session.commit()

        service = NotificationService(test_db_session)
        await service.regenerate_workout_schedules(
            user_id=user_id,
            workout_reminder_time=time(17, 0),
            silent_days=[],
        )
        await test_db_session.commit()

        result = await test_db_session.execute(
            select(WorkoutReminderSchedule).where(
                WorkoutReminderSchedule.user_id == user_id
            )
        )
        schedules = result.scalars().all()

        assert len(schedules) == 7, (
            f"RN05: esperado 7 schedules para os 7 dias futuros; "
            f"encontrado {len(schedules)}."
        )
        for s in schedules:
            assert s.scheduled_time == time(17, 0)
            assert s.sent is False

    async def test_regenerate_schedules_respeita_silent_days(
        self, test_db_session: AsyncSession
    ):
        """RN06: dias em silent_days NÃO geram schedule."""
        user_id = uuid4()
        await _create_program_with_sheets(
            test_db_session, user_id, days_of_week=(0,)
        )

        # Silent: segunda (0) e domingo (6). Sobram 5 dias.
        service = NotificationService(test_db_session)
        await service.regenerate_workout_schedules(
            user_id=user_id,
            workout_reminder_time=time(8, 30),
            silent_days=[0, 6],
        )
        await test_db_session.commit()

        result = await test_db_session.execute(
            select(WorkoutReminderSchedule).where(
                WorkoutReminderSchedule.user_id == user_id
            )
        )
        schedules = result.scalars().all()

        # Janela de 7 dias: today..today+6.
        # Conta quantos dias dessa janela NÃO caem em [0, 6].
        today = date.today()
        expected = sum(
            1 for i in range(7) if (today + timedelta(days=i)).weekday() not in (0, 6)
        )
        assert len(schedules) == expected, (
            f"RN06: silent_days [0,6] deveria pular esses dias; "
            f"esperado {expected} schedules, encontrado {len(schedules)}."
        )
        for s in schedules:
            assert s.scheduled_date.weekday() not in (0, 6)

    async def test_regenerate_schedules_deleta_pendentes_anteriores(
        self, test_db_session: AsyncSession
    ):
        """RN05 idempotência: segunda chamada NÃO duplica schedules pendentes."""
        user_id = uuid4()
        await _create_program_with_sheets(
            test_db_session, user_id, days_of_week=(0,)
        )

        service = NotificationService(test_db_session)

        # Primeira geração
        await service.regenerate_workout_schedules(
            user_id=user_id,
            workout_reminder_time=time(17, 0),
            silent_days=[],
        )
        await test_db_session.commit()

        # Segunda geração — não deve duplicar
        await service.regenerate_workout_schedules(
            user_id=user_id,
            workout_reminder_time=time(18, 0),
            silent_days=[],
        )
        await test_db_session.commit()

        result = await test_db_session.execute(
            select(WorkoutReminderSchedule).where(
                WorkoutReminderSchedule.user_id == user_id,
                WorkoutReminderSchedule.sent == False,
            )
        )
        schedules = result.scalars().all()

        assert len(schedules) == 7, (
            f"RN05: regenerate idempotente deveria manter 7 schedules pendentes "
            f"(não duplicar); encontrado {len(schedules)}."
        )
        # Deve refletir o NOVO horário
        assert all(s.scheduled_time == time(18, 0) for s in schedules)


# ---------------------------------------------------------------------------
# BUG-3 / RN07: job replenish_workout_schedules
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestReplenishJob:
    """RN07: job 00:30 UTC mantém horizonte de 7 dias."""

    async def test_replenish_job_mantem_horizonte(
        self, test_db_session: AsyncSession, monkeypatch
    ):
        """
        Após o job rodar, deve haver 7 schedules pendentes para o usuário
        (assumindo que ele tinha menos por já ter passado dias do horizonte
        gerado anteriormente).
        """
        user_id = uuid4()
        await _create_program_with_sheets(
            test_db_session, user_id, days_of_week=(0,)
        )

        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
            workout_reminder_time=time(17, 0),
            silent_days=[],
        )
        test_db_session.add(pref)
        await test_db_session.commit()

        # Patch do SessionLocal usado pelo job para reaproveitar a session de teste
        from app.tasks import notification_scheduler

        monkeypatch.setattr(
            notification_scheduler,
            "SessionLocal",
            lambda: _FakeSessionFactory(test_db_session),
        )

        await notification_scheduler.NotificationScheduler.replenish_workout_schedules()

        result = await test_db_session.execute(
            select(WorkoutReminderSchedule).where(
                WorkoutReminderSchedule.user_id == user_id,
                WorkoutReminderSchedule.sent == False,
            )
        )
        schedules = result.scalars().all()

        assert len(schedules) == 7, (
            f"RN07: replenish job deveria manter horizonte de 7 dias; "
            f"encontrado {len(schedules)} schedules pendentes."
        )


class _FakeSessionFactory:
    """Context manager que devolve a session de teste sem fechá-la."""

    def __init__(self, session):
        self._session = session

    async def __aenter__(self):
        return self._session

    async def __aexit__(self, exc_type, exc, tb):
        # Não fecha a session — o fixture cuida disso
        return False


# ---------------------------------------------------------------------------
# BUG-4 / RN08, RN10: notify_new_workout_sheet
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestNotifyNewWorkoutSheet:
    """RN08: criar WorkoutSheet com student_id dispara notificação."""

    async def test_notify_new_workout_sheet_dispara_send(
        self, test_db_session: AsyncSession
    ):
        """RN08: o service deve chamar send_notification('new_workout_sheet')."""
        student_id = uuid4()
        trainer_id = uuid4()

        student = _make_user(student_id, fcm_token="student_tok")
        trainer = _make_user(trainer_id, role="personal_trainer", fcm_token=None)
        test_db_session.add_all([student, trainer])
        await test_db_session.commit()

        # Programa do aluno (a ficha é criada dentro dele)
        program = await _create_program_with_sheets(
            test_db_session,
            student_id,
            days_of_week=(),  # programa sem fichas iniciais
            personal_trainer_id=trainer_id,
        )

        dto = CreateWorkoutSheetDTO(
            workout_program_id=program.id,
            name="Treino A - Peito",
            description=None,
            day_of_week=0,
            exercises=[
                ExerciseCreateDTO(
                    name="Supino Reto",
                    muscle_group="peito",
                    series=4,
                    repetitions=8,
                    load_kg=80.0,
                    rest_seconds=60,
                    order=1,
                )
            ],
        )

        service = WorkoutSheetService(test_db_session)

        with patch.object(
            NotificationService, "notify_new_workout_sheet"
        ) as mock_notify:
            mock_notify.return_value = None
            await service.create_workout_sheet(
                requester_id=trainer_id, role="personal_trainer", dto=dto
            )

            assert mock_notify.called, (
                "RN08: criar WorkoutSheet deveria disparar "
                "NotificationService.notify_new_workout_sheet."
            )
            call_kwargs = mock_notify.call_args.kwargs or {}
            call_args = mock_notify.call_args.args

            # Aceita tanto kwargs quanto positionals — o importante é student_id
            student_in_call = call_kwargs.get("user_id") or (
                call_args[0] if call_args else None
            )
            assert student_in_call == student_id

    async def test_notify_new_workout_sheet_falha_silenciosa(
        self, test_db_session: AsyncSession
    ):
        """
        RN10: se a notificação levantar exceção, a criação da ficha
        DEVE persistir mesmo assim (não rollback).
        """
        student_id = uuid4()
        trainer_id = uuid4()

        student = _make_user(student_id, fcm_token="student_tok")
        trainer = _make_user(trainer_id, role="personal_trainer", fcm_token=None)
        test_db_session.add_all([student, trainer])
        await test_db_session.commit()

        program = await _create_program_with_sheets(
            test_db_session,
            student_id,
            days_of_week=(),
            personal_trainer_id=trainer_id,
        )

        dto = CreateWorkoutSheetDTO(
            workout_program_id=program.id,
            name="Treino X",
            description=None,
            day_of_week=1,
            exercises=[
                ExerciseCreateDTO(
                    name="Remada",
                    muscle_group="costa",
                    series=3,
                    repetitions=10,
                    load_kg=40.0,
                    rest_seconds=60,
                    order=1,
                )
            ],
        )

        service = WorkoutSheetService(test_db_session)

        with patch.object(
            NotificationService,
            "notify_new_workout_sheet",
            side_effect=Exception("FCM down"),
        ):
            response = await service.create_workout_sheet(
                requester_id=trainer_id, role="personal_trainer", dto=dto
            )

        assert response.id is not None, (
            "RN10: falha na notificação não deve rollbackar a criação da ficha."
        )

        from app.models.workout_sheet import WorkoutSheet

        result = await test_db_session.execute(
            select(WorkoutSheet).where(WorkoutSheet.id == response.id)
        )
        saved = result.scalars().first()
        assert saved is not None


# ---------------------------------------------------------------------------
# BUG-4 / RN09: notify_achievement em Goal completed
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestNotifyAchievement:
    """RN09: completar Goal dispara notify_achievement."""

    async def test_notify_achievement_dispara_send(
        self, test_db_session: AsyncSession
    ):
        """Marcar uma Goal como completed deve chamar notify_achievement."""
        user_id = uuid4()
        user = _make_user(user_id, fcm_token="tok")
        test_db_session.add(user)
        await test_db_session.commit()

        # Cria meta diretamente para evitar dependência de DTOs externos
        goal = Goal(
            user_id=user_id,
            created_by_id=user_id,
            title="Supino 100kg",
            description="Atingir 100kg",
            category="strength",
            target_value=100.0,
            current_value=99.0,
            initial_value=80.0,
            unit="kg",
            start_date=datetime.utcnow(),
            target_date=datetime.utcnow() + timedelta(days=60),
            status="active",
            progress_percentage=95.0,
        )
        test_db_session.add(goal)
        await test_db_session.commit()

        service = GoalService(test_db_session)

        with patch.object(
            NotificationService, "notify_achievement"
        ) as mock_notify:
            mock_notify.return_value = None
            # Atualiza para o target — Goal completa
            await service.update_goal(
                goal_id=goal.id,
                dto=UpdateGoalDTO(current_value=100.0, notes="Atingi"),
                requesting_user_id=user_id,
                user_role="client",
            )

            assert mock_notify.called, (
                "RN09: completar Goal deveria disparar notify_achievement."
            )


# ---------------------------------------------------------------------------
# Cobertura direta dos métodos notify_* (caminhos de sucesso e exceção)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
class TestNotifyMethodsDirect:
    """Testes unitários cobrindo notify_new_workout_sheet/notify_achievement."""

    async def test_notify_new_workout_sheet_chama_send_notification(
        self, test_db_session: AsyncSession
    ):
        user_id = uuid4()
        user = _make_user(user_id, fcm_token="tok")
        test_db_session.add(user)
        await test_db_session.commit()

        service = NotificationService(test_db_session)
        sheet_id = uuid4()

        with patch.object(
            NotificationService, "send_notification"
        ) as mock_send:
            mock_send.return_value = None
            result = await service.notify_new_workout_sheet(
                user_id=user_id, sheet_id=sheet_id, sheet_name="Treino A"
            )

            mock_send.assert_called_once()
            kwargs = mock_send.call_args.kwargs
            assert kwargs["type"] == "new_workout_sheet"
            assert kwargs["user_id"] == user_id
            assert "Treino A" in kwargs["body"]

    async def test_notify_new_workout_sheet_exception_retorna_none(
        self, test_db_session: AsyncSession
    ):
        service = NotificationService(test_db_session)

        with patch.object(
            NotificationService,
            "send_notification",
            side_effect=Exception("FCM falhou"),
        ):
            result = await service.notify_new_workout_sheet(
                user_id=uuid4(), sheet_id=uuid4(), sheet_name="X"
            )
        assert result is None

    async def test_notify_achievement_chama_send_notification(
        self, test_db_session: AsyncSession
    ):
        user_id = uuid4()
        user = _make_user(user_id, fcm_token="tok")
        test_db_session.add(user)
        await test_db_session.commit()

        service = NotificationService(test_db_session)
        goal_id = uuid4()

        with patch.object(
            NotificationService, "send_notification"
        ) as mock_send:
            mock_send.return_value = None
            await service.notify_achievement(
                user_id=user_id, goal_id=goal_id, goal_title="Supino 100kg"
            )

            mock_send.assert_called_once()
            kwargs = mock_send.call_args.kwargs
            assert kwargs["type"] == "achievement"
            assert kwargs["user_id"] == user_id
            assert "Supino 100kg" in kwargs["body"]

    async def test_notify_achievement_exception_retorna_none(
        self, test_db_session: AsyncSession
    ):
        service = NotificationService(test_db_session)

        with patch.object(
            NotificationService,
            "send_notification",
            side_effect=Exception("FCM falhou"),
        ):
            result = await service.notify_achievement(
                user_id=uuid4(), goal_id=uuid4(), goal_title="meta"
            )
        assert result is None

    async def test_regenerate_schedules_sem_fichas_retorna_zero(
        self, test_db_session: AsyncSession
    ):
        """Sem nenhuma WorkoutSheet ativa, regenerate retorna 0."""
        user_id = uuid4()
        service = NotificationService(test_db_session)
        created = await service.regenerate_workout_schedules(
            user_id=user_id,
            workout_reminder_time=time(17, 0),
            silent_days=[],
        )
        assert created == 0

    async def test_update_preferences_regenera_quando_muda_horario(
        self, test_db_session: AsyncSession
    ):
        """update_preferences chama regenerate quando workout_reminder_time muda."""
        user_id = uuid4()
        await _create_program_with_sheets(
            test_db_session, user_id, days_of_week=(0,)
        )
        pref = NotificationPreference(
            user_id=user_id,
            notifications_enabled=True,
            workout_reminder_enabled=True,
        )
        test_db_session.add(pref)
        await test_db_session.commit()

        service = NotificationService(test_db_session)
        from app.dtos.notification_dto import UpdateNotificationPreferenceDTO

        await service.update_preferences(
            user_id,
            UpdateNotificationPreferenceDTO(
                workout_reminder_time=time(7, 30),
                silent_days=[],
            ),
        )
        await test_db_session.commit()

        result = await test_db_session.execute(
            select(WorkoutReminderSchedule).where(
                WorkoutReminderSchedule.user_id == user_id
            )
        )
        schedules = result.scalars().all()
        assert len(schedules) == 7
        assert all(s.scheduled_time == time(7, 30) for s in schedules)
