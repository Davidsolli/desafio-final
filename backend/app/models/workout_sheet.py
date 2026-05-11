"""
Modelos SQLAlchemy para o módulo Ficha de Treino.

Define as tabelas:
  - workout_sheets: Ficha de treino criada pelo personal para um aluno
  - exercises: Exercício dentro de uma ficha de treino
  - exercise_catalog: Catálogo de exercícios pré-carregados (somente leitura)
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
from sqlalchemy.dialects.postgresql import ARRAY, UUID as PG_UUID
from sqlalchemy.orm import relationship

from app.models.user import Base

class WorkoutProgram(Base):
    """
    Programa de treino (Divisão) associado a um aluno.
    Exemplo: "Divisão ABC - Hipertrofia".
    """

    __tablename__ = "workout_programs"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    user_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    personal_trainer_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    name = Column(String(255), nullable=False)

    description = Column(Text, nullable=True)

    goal = Column(String(255), nullable=True)

    is_active = Column(Boolean, nullable=False, default=True, index=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    # Relação 1:N com as fichas/rotinas desse programa
    workout_sheets = relationship(
        "WorkoutSheet",
        back_populates="workout_program",
        cascade="all, delete-orphan",
        order_by="WorkoutSheet.order",
        lazy="selectin",
    )

    def __repr__(self) -> str:
        return (
            f"<WorkoutProgram(id={self.id}, name={self.name!r}, "
            f"user_id={self.user_id}, is_active={self.is_active})>"
        )


class WorkoutSheet(Base):
    """
    Ficha de treino (Rotina), pertencente a um Programa (WorkoutProgram).

    Atributos:
        id: UUID único da ficha
        workout_program_id: FK para WorkoutProgram
        name: Nome descritivo da ficha (ex: "Treino A - Peito")
        description: Descrição opcional
        day_of_week: Dia da semana opcional (0=seg … 6=dom)
        order: Ordem da ficha no programa (1, 2, 3...)
        is_active: True se a ficha está ativa (soft delete via False)
        created_at: Data de criação
        updated_at: Última atualização
        exercises: Relação 1:N com Exercise (ordem por 'order')
    """

    __tablename__ = "workout_sheets"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    workout_program_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("workout_programs.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    name = Column(String(255), nullable=False)

    description = Column(Text, nullable=True)

    day_of_week = Column(Integer, nullable=True, index=True)  # 0=seg … 6=dom

    order = Column(Integer, nullable=False, default=1)

    is_active = Column(Boolean, nullable=False, default=True, index=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    # Relação 1:N com exercícios da ficha
    exercises = relationship(
        "Exercise",
        back_populates="workout_sheet",
        cascade="all, delete-orphan",
        order_by="Exercise.order",
        lazy="selectin",
    )

    # Relação reversa com o programa
    workout_program = relationship("WorkoutProgram", back_populates="workout_sheets")

    def __repr__(self) -> str:
        return (
            f"<WorkoutSheet(id={self.id}, name={self.name!r}, "
            f"workout_program_id={self.workout_program_id}, order={self.order})>"
        )


class Exercise(Base):
    """
    Exercício dentro de uma ficha de treino.

    Atributos:
        id: UUID único do exercício
        workout_sheet_id: Ficha a que pertence (FK workout_sheets.id)
        name: Nome do exercício (ex: "Supino Reto")
        muscle_group: Grupo muscular — valor do conjunto VALID_MUSCLE_GROUPS
        series: Número de séries (> 0)
        repetitions: Número de repetições (> 0)
        load_kg: Carga sugerida em kg (> 0)
        rest_seconds: Descanso entre séries em segundos (>= 0)
        observations: Observações técnicas (opcional)
        image_url: URL de imagem estática demonstrativa (opcional)
        gif_url: URL de GIF demonstrativo (opcional)
        order: Ordem de execução na ficha (1, 2, 3…)
        created_at / updated_at: Timestamps
    """

    __tablename__ = "exercises"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    workout_sheet_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("workout_sheets.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    name = Column(String(255), nullable=False)

    muscle_group = Column(String(50), nullable=False, index=True)

    series = Column(Integer, nullable=False)

    repetitions = Column(Integer, nullable=False)

    load_kg = Column(Float, nullable=False)

    rest_seconds = Column(Integer, nullable=False, default=60)

    observations = Column(Text, nullable=True)

    image_url = Column(String(2048), nullable=True)

    gif_url = Column(String(2048), nullable=True)

    order = Column(Integer, nullable=False, default=1)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    # Relação reversa com a ficha
    workout_sheet = relationship("WorkoutSheet", back_populates="exercises")

    def __repr__(self) -> str:
        return (
            f"<Exercise(id={self.id}, name={self.name!r}, "
            f"muscle_group={self.muscle_group}, order={self.order})>"
        )
