import logging
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, date, timezone, time

from app.config.database import SessionLocal
from app.models.notification import WorkoutReminderSchedule, NotificationPreference
from app.services.notification_service import NotificationService
from app.models.workout_sheet import WorkoutSheet

logger = logging.getLogger(__name__)

class NotificationScheduler:
    _scheduler = None

    @classmethod
    def start(cls):
        if cls._scheduler is None:
            cls._scheduler = AsyncIOScheduler()
            
            # Rodar a cada 5 minutos para checar lembretes agendados
            cls._scheduler.add_job(
                cls.check_and_send_reminders,
                CronTrigger(minute="*/5"),
                id="check_reminders_job",
                replace_existing=True
            )
            cls._scheduler.start()
            logger.info("Notification Scheduler started.")

    @classmethod
    def stop(cls):
        if cls._scheduler is not None:
            cls._scheduler.shutdown()
            logger.info("Notification Scheduler stopped.")

    @staticmethod
    async def check_and_send_reminders():
        """
        Job rodando em background para enviar os WorkoutReminderSchedules
        que ainda não foram enviados e estão na data/hora (ou já passou).
        Respeita quiet hours e silent days.
        """
        now = datetime.now(timezone.utc)
        current_date = now.date()
        current_time = now.time()
        current_weekday = now.weekday()

        async with SessionLocal() as session:
            try:
                # Buscar agendamentos do dia de hoje, cuja hora já passou ou é agora, que não foram enviados.
                query = select(WorkoutReminderSchedule).where(
                    and_(
                        WorkoutReminderSchedule.sent == False,
                        WorkoutReminderSchedule.scheduled_date == current_date,
                        WorkoutReminderSchedule.scheduled_time <= current_time,
                        WorkoutReminderSchedule.delivery_status == "pending"
                    )
                )
                result = await session.execute(query)
                schedules = result.scalars().all()

                if not schedules:
                    return

                logger.info(f"Encontrados {len(schedules)} lembretes para enviar.")
                notification_service = NotificationService(session)

                for schedule in schedules:
                    # Checar preferências
                    pref_query = select(NotificationPreference).where(NotificationPreference.user_id == schedule.user_id)
                    pref_result = await session.execute(pref_query)
                    pref = pref_result.scalars().first()

                    if pref and not pref.notifications_enabled:
                        schedule.sent = True
                        schedule.delivery_status = "cancelled_by_preference"
                        continue

                    if pref and not pref.workout_reminder_enabled:
                        schedule.sent = True
                        schedule.delivery_status = "cancelled_by_preference"
                        continue

                    # Respeitar quiet hours (horário de silêncio)
                    if pref and pref.quiet_hours_start and pref.quiet_hours_end:
                        is_in_quiet_hours = (
                            current_time >= pref.quiet_hours_start
                            or current_time <= pref.quiet_hours_end
                        )
                        if is_in_quiet_hours:
                            schedule.sent = True
                            schedule.delivery_status = "cancelled_by_quiet_hours"
                            continue

                    # Respeitar silent days (dias silenciosos)
                    if pref and pref.silent_days and current_weekday in pref.silent_days:
                        schedule.sent = True
                        schedule.delivery_status = "cancelled_by_silent_day"
                        continue

                    # Buscar Ficha (opcional para compor o titulo, o PRD diz que pode usar FCM_service)
                    ws_query = select(WorkoutSheet).where(WorkoutSheet.id == schedule.workout_sheet_id)
                    ws_result = await session.execute(ws_query)
                    ws = ws_result.scalars().first()
                    
                    treino_nome = ws.name if ws else "seu treino"

                    title = "Hora do treino! 💪"
                    body = f"Não esqueça de registrar o {treino_nome} hoje."

                    # Enviar Push
                    log = await notification_service.send_notification(
                        user_id=schedule.user_id,
                        type="workout_reminder",
                        title=title,
                        body=body,
                        data={"workout_sheet_id": str(schedule.workout_sheet_id)}
                    )

                    # Atualizar agendamento
                    schedule.sent = True
                    schedule.sent_at = datetime.now(timezone.utc)
                    schedule.delivery_status = log.status

                await session.commit()

            except Exception as e:
                logger.error(f"Erro no NotificationScheduler: {e}")
                await session.rollback()
