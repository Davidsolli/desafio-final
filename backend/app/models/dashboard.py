"""
Modelo SQLAlchemy para a tabela de analytics do Dashboard Profissional.

Define a tabela student_analytics, atualizada periodicamente pelo APScheduler,
evitando queries pesadas em tempo real nas tabelas de sessões e logbook.
"""

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.models.user import Base


class StudentAnalytics(Base):
    """
    Cache de métricas por aluno, atualizado a cada 15 minutos.

    Atributos:
        user_id: Aluno (FK users.id, único — 1 linha por aluno)
        personal_trainer_id: Personal responsável (derivado de workout_sheets)
        total_workouts_30d: Sessões completadas nos últimos 30 dias
        workouts_planned_30d: Sessões esperadas com base nas fichas ativas
        adherence_percentage: (total_workouts_30d / workouts_planned_30d) * 100
        last_workout_date: Data da última sessão completada
        status: "engaged" (≤7d) | "at_risk" (7–14d) | "inactive" (>14d)
        updated_at: Última vez que esse registro foi recalculado
    """

    __tablename__ = "student_analytics"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)

    user_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,
        index=True,
    )

    personal_trainer_id = Column(
        PG_UUID(as_uuid=True),
        nullable=True,
        index=True,
    )

    total_workouts_30d = Column(Integer, nullable=False, default=0)
    workouts_planned_30d = Column(Integer, nullable=False, default=0)
    adherence_percentage = Column(Float, nullable=False, default=0.0)

    last_workout_date = Column(DateTime, nullable=True)

    status = Column(String(20), nullable=False, default="inactive", index=True)

    updated_at = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    def __repr__(self) -> str:
        return (
            f"<StudentAnalytics(user_id={self.user_id}, "
            f"status={self.status}, adherence={self.adherence_percentage:.1f}%)>"
        )
