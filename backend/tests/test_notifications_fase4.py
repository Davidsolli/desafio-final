"""
Testes da Fase 4 do PRD de Notificações
(`docs/PRD_NOTIFICACOES_FASE_4_SEGREGACAO_ROLES.md`).

Cobre:
- RN05: `NotificationPreference.student_inactivity_enabled` default True.
- RN04: trainer pode desativar `student_inactivity_enabled` para silenciar
  o tipo `student_inactivity` mantendo outros tipos ligados.
- O campo NÃO é essential (DTO update aceita False sem 400).
"""

from unittest.mock import patch
from uuid import uuid4

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.notification_dto import UpdateNotificationPreferenceDTO
from app.models.notification import NotificationPreference
from app.models.user import User
from app.services.notification_service import NotificationService


def _make_user(user_id, *, role: str = "personal_trainer", fcm_token: str = "tok") -> User:
    return User(
        id=user_id,
        email=f"{user_id}@test.com",
        name="Test User",
        password="hash",
        role=role,
        fcm_token=fcm_token,
    )


@pytest.mark.asyncio
class TestStudentInactivityEnabled:
    """RN04/RN05 — campo `student_inactivity_enabled` em NotificationPreference."""

    async def test_student_inactivity_enabled_default_true(
        self, test_db_session: AsyncSession
    ):
        """RN05: pref criada sem args explícitos tem o flag = True."""
        pref = NotificationPreference(user_id=uuid4())
        test_db_session.add(pref)
        await test_db_session.commit()
        await test_db_session.refresh(pref)

        assert pref.student_inactivity_enabled is True, (
            "RN05: NotificationPreference.student_inactivity_enabled deveria "
            "ter default True (trainer recebe inactivity até desligar)."
        )

    async def test_student_inactivity_pode_ser_desativado(
        self, test_db_session: AsyncSession
    ):
        """
        RN04: trainer com `student_inactivity_enabled=False` NÃO recebe
        notificação do tipo `student_inactivity`, mesmo com master switch
        ligado e fora de quiet hours.
        """
        trainer_id = uuid4()
        trainer = _make_user(trainer_id, role="personal_trainer")
        pref = NotificationPreference(
            user_id=trainer_id,
            notifications_enabled=True,
            student_inactivity_enabled=False,
        )
        test_db_session.add_all([trainer, pref])
        await test_db_session.commit()

        with patch("firebase_admin.messaging.send") as mock_send:
            service = NotificationService(test_db_session)
            log = await service.send_notification(
                user_id=trainer_id,
                type="student_inactivity",
                title="Aluno inativo",
                body="...",
            )

            mock_send.assert_not_called()
            assert log.status == "cancelled_by_preference", (
                "RN04: send_notification(type='student_inactivity') deve ser "
                f"bloqueado quando student_inactivity_enabled=False. "
                f"Status atual: {log.status}"
            )

    async def test_student_inactivity_nao_e_essential(
        self, test_db_session: AsyncSession
    ):
        """
        Update com `student_inactivity_enabled=False` NÃO deve levantar
        HTTPException 400 (não é campo essencial).
        """
        trainer_id = uuid4()
        pref = NotificationPreference(
            user_id=trainer_id,
            notifications_enabled=True,
            student_inactivity_enabled=True,
        )
        test_db_session.add(pref)
        await test_db_session.commit()

        service = NotificationService(test_db_session)
        # Não deve levantar
        updated = await service.update_preferences(
            trainer_id,
            UpdateNotificationPreferenceDTO(student_inactivity_enabled=False),
        )
        await test_db_session.commit()

        assert updated.student_inactivity_enabled is False
