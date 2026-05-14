"""Models SQLAlchemy para registros de saúde: frequência cardíaca e calorias."""

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, Integer, Float, DateTime, Date, ForeignKey, UniqueConstraint, Boolean, String
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.models.user import Base


class HeartRateLog(Base):
    """Amostra individual de frequência cardíaca (N registros por usuário/dia)."""

    __tablename__ = "heart_rate_logs"
    __table_args__ = (
        UniqueConstraint("user_id", "measured_at", name="uq_heart_rate_logs_user_measured_at"),
    )

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)
    user_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    measured_at = Column(DateTime, nullable=False, index=True)
    bpm = Column(Integer, nullable=False)
    is_from_smartwatch = Column(Boolean, nullable=False, default=False)
    source_name = Column(String(120), nullable=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    def __repr__(self) -> str:
        return f"<HeartRateLog(user_id={self.user_id}, measured_at={self.measured_at}, bpm={self.bpm})>"


class CalorieLog(Base):
    """Registro diário de calorias (1 linha por usuário/dia)."""

    __tablename__ = "calorie_logs"
    __table_args__ = (
        UniqueConstraint("user_id", "date", name="uq_calorie_logs_user_date"),
    )

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)
    user_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    date = Column(Date, nullable=False, index=True)
    active_calories = Column(Float, nullable=False, default=0.0)
    total_calories = Column(Float, nullable=False, default=0.0)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    def __repr__(self) -> str:
        return f"<CalorieLog(user_id={self.user_id}, date={self.date}, active={self.active_calories})>"
