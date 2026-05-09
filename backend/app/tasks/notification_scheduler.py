import logging
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, date, timezone, time, timedelta

from app.config.database import SessionLocal
from app.models.notification import WorkoutReminderSchedule, NotificationPreference
from app.models.user import User
from app.models.logbook import WorkoutSession
from app.services.notification_service import NotificationService
from app.models.workout_sheet import WorkoutSheet

logger = logging.getLogger(__name__)

# Aluno considerado inativo após N dias sem WorkoutSession registrada
_INACTIVITY_DAYS = 7


class NotificationScheduler:
    _scheduler = None

    @classmethod
    def start(cls):
        if cls._scheduler is None:
            cls._scheduler = AsyncIOScheduler()

            cls._scheduler.add_job(
                cls.check_and_send_reminders,
                CronTrigger(minute="*/5"),
                id="check_workout_reminders_job",
                replace_existing=True,
            )

            cls._scheduler.add_job(
                cls.check_and_send_meal_reminders,
                CronTrigger(minute="*/5"),
                id="check_meal_reminders_job",
                replace_existing=True,
            )

            cls._scheduler.add_job(
                cls.check_student_inactivity,
                CronTrigger(hour=9, minute=0),
                id="check_inactivity_job",
                replace_existing=True,
            )

            cls._scheduler.start()
            logger.info("Notification Scheduler started (3 jobs registrados).")

    @classmethod
    def stop(cls):
        if cls._scheduler is not None:
            cls._scheduler.shutdown()
            logger.info("Notification Scheduler stopped.")

    @staticmethod
    async def check_and_send_reminders():
        """
        Job a cada 5 min: envia WorkoutReminderSchedules pendentes do dia.
        Guards de preferência (notifications_enabled, quiet hours, silent days)
        são aplicados pelo NotificationService.send_notification.
        """
        now = datetime.now(timezone.utc)
        current_date = now.date()
        current_time = now.time().replace(tzinfo=None)

        async with SessionLocal() as session:
            try:
                query = select(WorkoutReminderSchedule).where(
                    and_(
                        WorkoutReminderSchedule.sent == False,
                        WorkoutReminderSchedule.scheduled_date == current_date,
                        WorkoutReminderSchedule.scheduled_time <= current_time,
                        WorkoutReminderSchedule.delivery_status == "pending",
                    )
                )
                result = await session.execute(query)
                schedules = result.scalars().all()

                if not schedules:
                    return

                logger.info(f"Encontrados {len(schedules)} lembretes de treino para enviar.")
                notification_service = NotificationService(session)

                for schedule in schedules:
                    ws_query = select(WorkoutSheet).where(WorkoutSheet.id == schedule.workout_sheet_id)
                    ws_result = await session.execute(ws_query)
                    ws = ws_result.scalars().first()
                    treino_nome = ws.name if ws else "seu treino"

                    log = await notification_service.send_notification(
                        user_id=schedule.user_id,
                        type="workout_reminder",
                        title="Hora do treino! 💪",
                        body=f"Não esqueça de registrar o {treino_nome} hoje.",
                        data={"workout_sheet_id": str(schedule.workout_sheet_id)},
                    )

                    schedule.sent = True
                    schedule.sent_at = datetime.now(timezone.utc) if log.status == "sent" else None
                    schedule.delivery_status = log.status

                await session.commit()

            except Exception as e:
                logger.error(f"Erro no check_and_send_reminders: {e}")
                await session.rollback()

    @staticmethod
    async def check_and_send_meal_reminders():
        """
        Job a cada 5 min: dispara lembretes de refeição com base em
        NotificationPreference.meal_reminder_time.
        Janela de ±3 min ao redor do horário definido.

        NOTA DE TIMEZONE: meal_reminder_time é comparado com UTC.
        O frontend deve converter o horário local do aluno para UTC ao salvar.
        """
        now = datetime.now(timezone.utc)
        current_minutes = now.hour * 60 + now.minute
        WINDOW_MINUTES = 3

        async with SessionLocal() as session:
            try:
                query = select(NotificationPreference).where(
                    and_(
                        NotificationPreference.notifications_enabled == True,
                        NotificationPreference.meal_reminder_enabled == True,
                        NotificationPreference.meal_reminder_time != None,
                    )
                )
                result = await session.execute(query)
                prefs = result.scalars().all()

                if not prefs:
                    return

                logger.info(f"Verificando {len(prefs)} preferências de lembrete de refeição.")
                notification_service = NotificationService(session)

                for pref in prefs:
                    meal_time = pref.meal_reminder_time
                    target_minutes = meal_time.hour * 60 + meal_time.minute

                    if abs(current_minutes - target_minutes) > WINDOW_MINUTES:
                        continue

                    # send_notification aplica os demais guards (quiet hours, silent days)
                    await notification_service.send_notification(
                        user_id=pref.user_id,
                        type="meal_reminder",
                        title="Hora da refeição! 🥗",
                        body="Não se esqueça de seguir sua dieta.",
                    )

                await session.commit()

            except Exception as e:
                logger.error(f"Erro no check_and_send_meal_reminders: {e}")
                await session.rollback()

    @staticmethod
    async def check_student_inactivity():
        """
        Job diário (09:00 UTC): notifica o Personal Trainer quando um aluno
        está sem registrar WorkoutSession por _INACTIVITY_DAYS dias.
        """
        now = datetime.now(timezone.utc)
        cutoff = now - timedelta(days=_INACTIVITY_DAYS)

        async with SessionLocal() as session:
            try:
                students_query = select(User).where(
                    and_(
                        User.role == "client",
                        User.trainer_id != None,
                        User.is_active == True,
                    )
                )
                result = await session.execute(students_query)
                students = result.scalars().all()

                if not students:
                    return

                logger.info(f"Verificando inatividade de {len(students)} alunos.")
                notification_service = NotificationService(session)

                for student in students:
                    last_session_query = select(WorkoutSession).where(
                        and_(
                            WorkoutSession.user_id == student.id,
                            WorkoutSession.session_date >= cutoff,
                        )
                    ).limit(1)
                    last_session_result = await session.execute(last_session_query)
                    if last_session_result.scalars().first():
                        continue  # aluno ativo

                    trainer_query = select(User).where(User.id == student.trainer_id)
                    trainer_result = await session.execute(trainer_query)
                    trainer = trainer_result.scalars().first()

                    if not trainer or not trainer.fcm_token:
                        continue

                    await notification_service.send_notification(
                        user_id=trainer.id,
                        type="student_inactivity",
                        title="Aluno inativo ⚠️",
                        body=f"{student.name} está sem treinar há {_INACTIVITY_DAYS}+ dias.",
                        data={"student_id": str(student.id), "student_name": student.name},
                    )

                await session.commit()

            except Exception as e:
                logger.error(f"Erro no check_student_inactivity: {e}")
                await session.rollback()
