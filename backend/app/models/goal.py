"""Models SQLAlchemy para o módulo de metas."""

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import relationship

from app.models.user import Base


class Goal(Base):
    """Meta de um aluno."""

    __tablename__ = "goals"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)
    user_id = Column(PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)
    created_by_id = Column(PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    category = Column(String(50), nullable=False, index=True)

    target_value = Column(Float, nullable=False)
    current_value = Column(Float, nullable=False)
    initial_value = Column(Float, nullable=False)
    unit = Column(String(50), nullable=False)

    start_date = Column(DateTime, nullable=False, default=datetime.utcnow)
    target_date = Column(DateTime, nullable=False)
    completed_at = Column(DateTime, nullable=True)

    status = Column(String(20), nullable=False, default="active", index=True)
    progress_percentage = Column(Float, nullable=False, default=0.0)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )

    progress_entries = relationship(
        "GoalProgressEntry",
        back_populates="goal",
        lazy="selectin",
        order_by="GoalProgressEntry.recorded_at",
        cascade="all, delete-orphan",
    )

    @property
    def days_remaining(self) -> int:
        if self.target_date is None:
            return 0
        delta = self.target_date - datetime.utcnow()
        return max(0, delta.days)

    def __repr__(self) -> str:
        return f"<Goal(id={self.id}, title={self.title}, status={self.status})>"


class GoalProgressEntry(Base):
    """Registro de progresso de uma meta."""

    __tablename__ = "goal_progress_entries"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)
    goal_id = Column(PG_UUID(as_uuid=True), ForeignKey("goals.id"), nullable=False, index=True)
    current_value = Column(Float, nullable=False)
    session_id = Column(PG_UUID(as_uuid=True), nullable=True)
    recorded_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    goal = relationship("Goal", back_populates="progress_entries")

    def __repr__(self) -> str:
        return f"<GoalProgressEntry(goal_id={self.goal_id}, current_value={self.current_value})>"
