"""Model SQLAlchemy para o registro diário de passos."""

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, Integer, Float, DateTime, Date, ForeignKey, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.models.user import Base


class StepLog(Base):
    """Registro diário de passos de um usuário (1 linha por usuário/dia)."""

    __tablename__ = "step_logs"
    __table_args__ = (
        UniqueConstraint("user_id", "date", name="uq_step_logs_user_date"),
    )

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)
    user_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    date = Column(Date, nullable=False, index=True)
    steps = Column(Integer, nullable=False, default=0)
    distance_meters = Column(Float, nullable=False, default=0.0)
    # Nível de proteção da sequência (1-3); NULL = dia normal sem desconto de meta
    handicap_level = Column(Integer, nullable=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    def __repr__(self) -> str:
        return f"<StepLog(user_id={self.user_id}, date={self.date}, steps={self.steps})>"
