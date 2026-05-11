import asyncio
import logging
from uuid import UUID
from typing import Any, Dict, List, Optional, Tuple
from datetime import datetime, date, time, timezone, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status

# Default usado quando o User não tem timezone configurado (RN03 da Fase 2)
DEFAULT_USER_TIMEZONE = "America/Sao_Paulo"

from app.repositories.notification_repository import NotificationRepository
from app.services.fcm_service import FCMService
from app.models.notification import (
    NotificationPreference,
    NotificationLog,
    WorkoutReminderSchedule,
)
from app.models.workout_sheet import WorkoutSheet, WorkoutProgram
from app.dtos.notification_dto import UpdateNotificationPreferenceDTO, NotificationPreferenceResponseDTO

from app.models.user import User
from sqlalchemy import select, and_, delete

logger = logging.getLogger(__name__)

# Notificações essenciais que nunca podem ser desativadas (Card 15.16)
_ESSENTIAL_FIELDS = frozenset({"new_workout_sheet_enabled"})

# Mapeamento de tipo de notificação para o campo de preferência correspondente
_TYPE_TO_PREF_FIELD: Dict[str, str] = {
    "workout_reminder": "workout_reminder_enabled",
    "meal_reminder": "meal_reminder_enabled",
    "new_workout_sheet": "new_workout_sheet_enabled",
    "achievement": "achievement_enabled",
    "performance_report": "performance_report_enabled",
}


class NotificationService:
    def __init__(self, session: AsyncSession):
        self.repository = NotificationRepository(session)
        self.session = session
        self.fcm_service = FCMService()

    async def get_or_create_preferences(self, user_id: UUID) -> NotificationPreference:
        pref, _ = await self.get_or_create_preferences_with_status(user_id)
        return pref

    async def get_or_create_preferences_with_status(
        self, user_id: UUID
    ) -> Tuple[NotificationPreference, bool]:
        """Retorna (preference, created_now). created_now=True se foi criada agora."""
        pref = await self.repository.get_preferences(user_id)
        if pref:
            return pref, False
        pref = NotificationPreference(user_id=user_id)
        await self.repository.create_preferences(pref)
        return pref, True

    async def update_preferences(self, user_id: UUID, dto: UpdateNotificationPreferenceDTO) -> NotificationPreference:
        update_data = dto.model_dump(exclude_unset=True)

        # Guard Card 15.16: impedir desativação de notificações essenciais
        for field in _ESSENTIAL_FIELDS:
            if field in update_data and update_data[field] is False:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"A notificação '{field}' é essencial e não pode ser desativada.",
                )

        pref = await self.get_or_create_preferences(user_id)
        for key, value in update_data.items():
            setattr(pref, key, value)

        updated = await self.repository.update_preferences(pref)

        # RN05/RN06: regenerar schedules quando workout_reminder_time ou silent_days mudam
        if (
            "workout_reminder_time" in update_data
            or "silent_days" in update_data
        ):
            if updated.workout_reminder_enabled and updated.workout_reminder_time:
                await self.regenerate_workout_schedules(
                    user_id=user_id,
                    workout_reminder_time=updated.workout_reminder_time,
                    silent_days=updated.silent_days or [],
                )

        return updated

    async def update_fcm_token(self, user_id: UUID, token: str) -> None:
        query = select(User).where(User.id == user_id)
        result = await self.session.execute(query)
        user = result.scalars().first()
        if user:
            user.fcm_token = token
            await self.session.flush()
        else:
            raise HTTPException(status_code=404, detail="Usuário não encontrado")

    @staticmethod
    def _user_zone(user: Optional[User]) -> ZoneInfo:
        """Retorna o ZoneInfo do usuário, com fallback para o default da Fase 2."""
        tz_name = (getattr(user, "timezone", None) if user else None) or DEFAULT_USER_TIMEZONE
        try:
            return ZoneInfo(tz_name)
        except ZoneInfoNotFoundError:
            return ZoneInfo(DEFAULT_USER_TIMEZONE)

    @classmethod
    def _user_local_now(cls, user: Optional[User]) -> datetime:
        """`datetime.now` no fuso do usuário (Fase 2 — RN01/RN02)."""
        return datetime.now(cls._user_zone(user))

    async def send_notification(
        self,
        user_id: UUID,
        type: str,
        title: str,
        body: str,
        data: Optional[Dict[str, Any]] = None,
    ) -> NotificationLog:
        """
        Envia push notification via FCM e registra o log.
        Aplica todos os guards de preferência antes de chamar o Firebase:
        - notifications_enabled
        - tipo específico (workout_reminder_enabled, meal_reminder_enabled, etc.)
        - quiet hours (no fuso local do usuário)
        - silent days (no weekday local do usuário)
        """
        log = NotificationLog(
            user_id=user_id,
            notification_type=type,
            title=title,
            body=body,
            data=data,
            status="pending",
        )

        pref = await self.repository.get_preferences(user_id)

        # Guard 1: master switch
        if pref and not pref.notifications_enabled:
            log.status = "cancelled_by_preference"
            return await self.repository.create_log(log)

        # Guard 2: tipo específico
        pref_field = _TYPE_TO_PREF_FIELD.get(type)
        if pref and pref_field and not getattr(pref, pref_field, True):
            log.status = "cancelled_by_preference"
            return await self.repository.create_log(log)

        # Carrega o User uma vez — usado pelos guards locais e pelo envio FCM
        query = select(User).where(User.id == user_id)
        result = await self.session.execute(query)
        user = result.scalars().first()

        # Guard 3: quiet hours (RN01 - Fase 2: avaliado no fuso do usuário)
        if pref and pref.quiet_hours_start and pref.quiet_hours_end:
            current_time = self._user_local_now(user).time().replace(tzinfo=None)
            start = pref.quiet_hours_start
            end = pref.quiet_hours_end
            # overnight (ex: 22:00-07:00): start > end
            # same-day  (ex: 12:00-14:00): start <= end
            if start > end:
                in_quiet = current_time >= start or current_time <= end
            else:
                in_quiet = start <= current_time <= end
            if in_quiet:
                log.status = "cancelled_by_quiet_hours"
                return await self.repository.create_log(log)

        # Guard 4: silent days (RN01 - Fase 2: weekday no fuso do usuário)
        if pref and pref.silent_days:
            if self._user_local_now(user).weekday() in pref.silent_days:
                log.status = "cancelled_by_silent_day"
                return await self.repository.create_log(log)

        if not user or not user.fcm_token:
            log.status = "failed"
            log.error = "FCM token not found for user"
            return await self.repository.create_log(log)

        # Enviar via Firebase em thread separada para não bloquear o event loop
        success = await asyncio.to_thread(
            self.fcm_service.send_notification,
            token=user.fcm_token,
            title=title,
            body=body,
            data=data,
        )

        if success:
            log.status = "sent"
            log.sent_at = datetime.now(timezone.utc)
        else:
            log.status = "failed"
            log.error = "Firebase error"

        return await self.repository.create_log(log)

    async def get_history(self, user_id: UUID, notification_type: Optional[str] = None, limit: int = 20) -> List[NotificationLog]:
        return await self.repository.get_logs(user_id, notification_type, limit)

    async def mark_as_read(self, user_id: UUID, notification_id: UUID) -> None:
        log = await self.repository.mark_log_as_read(notification_id, user_id)
        if not log:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")

    # ------------------------------------------------------------------
    # Workout reminder schedules — Fase 1, BUG-3 (RN05, RN06, RN07)
    # ------------------------------------------------------------------

    async def regenerate_workout_schedules(
        self,
        user_id: UUID,
        workout_reminder_time: time,
        silent_days: Optional[List[int]] = None,
    ) -> int:
        """
        Regenera o horizonte de 7 dias de WorkoutReminderSchedule para o usuário.

        - Deleta schedules pendentes (sent=False, scheduled_date >= hoje).
        - Para cada dia em [hoje, hoje+6] cuja weekday() não está em silent_days,
          insere um schedule. Procura uma WorkoutSheet ativa do usuário no
          dia da semana correspondente; se não houver, escolhe qualquer ficha
          ativa do usuário; se ainda não houver ficha ativa, pula o dia.

        WorkoutSheet pertence a um WorkoutProgram (que detém o user_id);
        a query faz JOIN para filtrar por aluno e considera apenas programas
        e fichas ativos.

        Retorna o número de schedules criados.
        """
        silent_set = set(silent_days or [])
        today = date.today()

        # 1. Deleta pendentes futuros
        del_stmt = delete(WorkoutReminderSchedule).where(
            and_(
                WorkoutReminderSchedule.user_id == user_id,
                WorkoutReminderSchedule.sent == False,  # noqa: E712
                WorkoutReminderSchedule.scheduled_date >= today,
            )
        )
        await self.session.execute(del_stmt)

        # 2. Lista fichas ativas do usuário (via WorkoutProgram)
        ws_stmt = (
            select(WorkoutSheet)
            .join(
                WorkoutProgram,
                WorkoutSheet.workout_program_id == WorkoutProgram.id,
            )
            .where(
                and_(
                    WorkoutProgram.user_id == user_id,
                    WorkoutProgram.is_active.is_(True),
                    WorkoutSheet.is_active.is_(True),
                )
            )
        )
        ws_result = await self.session.execute(ws_stmt)
        sheets = list(ws_result.scalars().all())
        if not sheets:
            await self.session.flush()
            return 0

        sheets_by_dow = {s.day_of_week: s for s in sheets}
        default_sheet = sheets[0]

        created = 0
        for offset in range(7):
            target_date = today + timedelta(days=offset)
            dow = target_date.weekday()
            if dow in silent_set:
                continue
            sheet = sheets_by_dow.get(dow, default_sheet)
            schedule = WorkoutReminderSchedule(
                user_id=user_id,
                workout_sheet_id=sheet.id,
                scheduled_date=target_date,
                scheduled_time=workout_reminder_time,
                sent=False,
                delivery_status="pending",
            )
            self.session.add(schedule)
            created += 1

        await self.session.flush()
        return created

    # ------------------------------------------------------------------
    # Notify methods — Fase 1, BUG-4 (RN08, RN09, RN10)
    # ------------------------------------------------------------------

    async def notify_new_workout_sheet(
        self,
        user_id: UUID,
        sheet_id: UUID,
        sheet_name: str,
    ) -> Optional[NotificationLog]:
        """
        RN08: dispara notificação 'new_workout_sheet' ao aluno.
        RN10: falha em FCM/banco loga e segue (não propaga).
        """
        try:
            return await self.send_notification(
                user_id=user_id,
                type="new_workout_sheet",
                title="Nova ficha de treino! 💪",
                body=f"Sua ficha '{sheet_name}' foi criada.",
                data={"workout_sheet_id": str(sheet_id)},
            )
        except Exception as exc:
            logger.warning(
                "notify_new_workout_sheet falhou para user_id=%s sheet_id=%s: %s",
                user_id,
                sheet_id,
                exc,
            )
            return None

    async def notify_achievement(
        self,
        user_id: UUID,
        goal_id: UUID,
        goal_title: str,
    ) -> Optional[NotificationLog]:
        """
        RN09: dispara notificação 'achievement' ao usuário ao completar meta.
        RN10: falha silenciosa.
        """
        try:
            return await self.send_notification(
                user_id=user_id,
                type="achievement",
                title="Meta concluída! 🏆",
                body=f"Parabéns, você completou a meta '{goal_title}'.",
                data={"goal_id": str(goal_id)},
            )
        except Exception as exc:
            logger.warning(
                "notify_achievement falhou para user_id=%s goal_id=%s: %s",
                user_id,
                goal_id,
                exc,
            )
            return None
