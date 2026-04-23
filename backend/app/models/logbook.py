"""
Modelos SQLAlchemy para o módulo Logbook (Diário de Treino).

Define as tabelas:
  - workout_sessions: Sessão de treino registrada pelo aluno
  - session_exercises: Exercício executado dentro de uma sessão

Nota sobre FKs externas:
  - user_id → users.id: FK declarada (tabela já existe)
  - workout_sheet_id → workout_sheets.id: UUID sem FK constraint (PRD_FICHA_TREINO pendente)
  - exercise_id → exercises.id: UUID sem FK constraint (PRD_FICHA_TREINO pendente)
"""

from datetime import datetime
from uuid import uuid4

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import JSON, UUID as PG_UUID
from sqlalchemy.orm import relationship

from app.models.user import Base


class WorkoutSession(Base):
    """
    Sessão de treino registrada pelo aluno.

    Atributos:
        id: UUID único da sessão
        user_id: Aluno que realizou (FK users.id)
        workout_sheet_id: Ficha de treino usada (UUID sem FK — PRD_FICHA_TREINO pendente)
        session_date: Data/hora em que treinou
        status: 'in_progress' | 'completed' | 'incomplete' | 'skipped' | 'deleted'
        general_notes: Notas gerais da sessão
        difficulty_level: 1–10 (percepção de esforço subjetivo)
        mood: 'great' | 'good' | 'normal' | 'bad' | 'terrible'
        created_at: Criação do registro
        updated_at: Última atualização
        completed_at: Quando finalizou (NULL se não completado)
        approved_by_personal_id: Personal que aprovou (futuro)
        approved_at: Quando foi aprovado
    """

    __tablename__ = "workout_sessions"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    # FK para users (constraint real — tabela já existe)
    user_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # UUID sem FK constraint — workout_sheets ainda não implementado
    workout_sheet_id = Column(
        PG_UUID(as_uuid=True),
        nullable=False,
        index=True,
    )

    session_date = Column(DateTime, nullable=False, index=True)

    status = Column(
        String(20),
        nullable=False,
        default="in_progress",
        index=True,
    )

    general_notes = Column(Text, nullable=True)

    difficulty_level = Column(Integer, nullable=True)  # 1–10

    mood = Column(String(20), nullable=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    completed_at = Column(DateTime, nullable=True)

    # Auditoria — personal que aprovou (futuro)
    approved_by_personal_id = Column(PG_UUID(as_uuid=True), nullable=True)
    approved_at = Column(DateTime, nullable=True)

    # Relação com exercícios da sessão
    session_exercises = relationship(
        "SessionExercise",
        back_populates="session",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    def __repr__(self) -> str:
        return (
            f"<WorkoutSession(id={self.id}, user_id={self.user_id}, "
            f"status={self.status}, session_date={self.session_date})>"
        )


class SessionExercise(Base):
    """
    Um exercício dentro de uma sessão de treino registrada.

    Atributos:
        id: UUID único
        session_id: Sessão a que pertence (FK workout_sessions.id)
        exercise_id: Exercício (UUID sem FK — PRD_FICHA_TREINO pendente)
        planned_series / planned_repetitions / planned_load_kg: Valores planejados
        actual_series / actual_repetitions / actual_load_kg: Valores reais executados
        series_details: JSON com detalhes por série [{series, reps, load}]
        exercise_notes: Observações do aluno sobre este exercício
        pain_or_discomfort: Sentiu dor/desconforto?
        pain_description: Descrição da dor (obrigatório se pain_or_discomfort=True)
        modification: Como adaptou o exercício
        status: 'completed' | 'partial' | 'skipped'
    """

    __tablename__ = "session_exercises"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    # FK para workout_sessions (constraint real)
    session_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("workout_sessions.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # UUID sem FK constraint — exercises ainda não implementado
    exercise_id = Column(
        PG_UUID(as_uuid=True),
        nullable=False,
        index=True,
    )

    # Valores planejados (podem ser NULL se exercício não estava na ficha)
    planned_series = Column(Integer, nullable=True)
    planned_repetitions = Column(Integer, nullable=True)
    planned_load_kg = Column(Float, nullable=True)

    # Valores reais executados
    actual_series = Column(Integer, nullable=True)
    actual_repetitions = Column(Integer, nullable=True)
    actual_load_kg = Column(Float, nullable=True)

    # Detalhes por série (JSON)
    series_details = Column(JSON, nullable=True)

    # Observações
    exercise_notes = Column(Text, nullable=True)
    pain_or_discomfort = Column(Boolean, nullable=False, default=False)
    pain_description = Column(Text, nullable=True)
    modification = Column(Text, nullable=True)

    # Status do exercício
    status = Column(String(20), nullable=False, default="completed")

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    # Relação reversa com a sessão
    session = relationship("WorkoutSession", back_populates="session_exercises")

    def __repr__(self) -> str:
        return (
            f"<SessionExercise(id={self.id}, session_id={self.session_id}, "
            f"exercise_id={self.exercise_id}, status={self.status})>"
        )
