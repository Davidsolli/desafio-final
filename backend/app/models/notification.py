from datetime import datetime, time, timezone
from typing import Any, Dict
from uuid import uuid4
from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Time, JSON, Date
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import relationship

from app.models.user import Base

def utc_now():
    return datetime.now(timezone.utc)


class NotificationPreference(Base):
    """Preferências de notificação do aluno"""
    
    __tablename__ = "notification_preferences"
    
    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)
    user_id = Column(PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, unique=True, index=True)
    
    # Configurações gerais
    notifications_enabled = Column(Boolean, default=True, nullable=False)
    
    # Tipos de notificação
    workout_reminder_enabled = Column(Boolean, default=True, nullable=False)
    workout_reminder_time = Column(Time, nullable=True) # Ex: 17:00
    
    meal_reminder_enabled = Column(Boolean, default=False, nullable=False)
    meal_reminder_time = Column(Time, nullable=True) # Ex: 12:00
    
    new_workout_sheet_enabled = Column(Boolean, default=True, nullable=False)
    achievement_enabled = Column(Boolean, default=True, nullable=False)
    performance_report_enabled = Column(Boolean, default=True, nullable=False)
    
    # Preferências
    quiet_hours_start = Column(Time, nullable=True) # Ex: 22:00
    quiet_hours_end = Column(Time, nullable=True) # Ex: 07:00
    
    # Silent days (0=Monday, 1=Tuesday, ..., 6=Sunday)
    silent_days = Column(JSON, nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
    updated_at = Column(DateTime(timezone=True), nullable=False, default=utc_now, onupdate=utc_now)


class NotificationLog(Base):
    """Registro de cada notificação enviada"""
    
    __tablename__ = "notification_logs"
    
    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)
    user_id = Column(PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    
    notification_type = Column(String(50), nullable=False) # "workout_reminder", "meal_reminder", "achievement"
    title = Column(String(255), nullable=False)
    body = Column(String(1000), nullable=False)
    data = Column(JSON, nullable=True) # Dados adicionais (ex: workout_sheet_id)
    
    sent_at = Column(DateTime(timezone=True), nullable=True)
    read_at = Column(DateTime(timezone=True), nullable=True)
    clicked_at = Column(DateTime(timezone=True), nullable=True)

    status = Column(String(50), nullable=False, default="pending")
    error = Column(String(1000), nullable=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)


class WorkoutReminderSchedule(Base):
    """Agendamento de lembrete de treino"""
    
    __tablename__ = "workout_reminder_schedules"
    
    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)
    user_id = Column(PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    
    # Qual ficha/dia
    workout_sheet_id = Column(PG_UUID(as_uuid=True), ForeignKey("workout_sheets.id"), nullable=False, index=True)
    scheduled_date = Column(Date, nullable=False) # 2026-04-21
    scheduled_time = Column(Time, nullable=False) # 17:00
    
    # Status
    sent = Column(Boolean, default=False, nullable=False)
    sent_at = Column(DateTime(timezone=True), nullable=True)
    delivery_status = Column(String(50), nullable=False, default="pending")

    created_at = Column(DateTime(timezone=True), nullable=False, default=utc_now)
