"""
Modelos SQLAlchemy para o Diário Alimentar (Diet Logbook).

Define as tabelas:
  - diet_logbooks: Resumo do dia alimentar do aluno
  - diet_logbook_entries: Item efetivamente consumido pelo aluno
"""

from datetime import date, datetime
from uuid import uuid4

from sqlalchemy import (
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import relationship

from app.models.user import Base


class DietLogbook(Base):
    """
    Resumo do dia alimentar do aluno.

    Um registro por aluno por dia. Os totais de macros são atualizados
    automaticamente pelo Service a cada inserção/remoção de entry.

    Atributos:
        id: UUID único
        user_id: Aluno (FK users.id)
        date: Data do diário (ex: 2026-05-03)
        total_kcal: Somatório de calorias consumidas no dia
        total_protein: Somatório de proteínas
        total_carbs: Somatório de carboidratos
        total_fats: Somatório de gorduras
        created_at: Timestamp de criação
        entries: Relação 1:N com DietLogbookEntry
    """

    __tablename__ = "diet_logbooks"

    # Constraint: um registro por aluno por dia
    __table_args__ = (
        UniqueConstraint("user_id", "date", name="uq_diet_logbook_user_date"),
    )

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

    date = Column(Date, nullable=False, index=True)

    total_kcal = Column(Float, nullable=False, default=0.0)

    total_protein = Column(Float, nullable=False, default=0.0)

    total_carbs = Column(Float, nullable=False, default=0.0)

    total_fats = Column(Float, nullable=False, default=0.0)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    # Relação 1:N com entradas do diário
    entries = relationship(
        "DietLogbookEntry",
        back_populates="logbook",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    def __repr__(self) -> str:
        return (
            f"<DietLogbook(id={self.id}, user_id={self.user_id}, "
            f"date={self.date}, kcal={self.total_kcal})>"
        )


class DietLogbookEntry(Base):
    """
    Item efetivamente consumido pelo aluno no dia.

    Os macros são gravados como snapshot no momento da inserção
    (calculados com base no FoodCatalog/CustomFood × quantity_g).
    Isso garante que uma alteração futura nos dados do catálogo
    não altere os registros históricos do aluno.

    Atributos:
        id: UUID único
        logbook_id: Diário do dia (FK diet_logbooks.id)
        meal_name: Label da refeição (ex: "Café da Manhã")
        food_id: ID do alimento na TACO (nullable)
        custom_food_id: UUID do alimento personalizado (nullable)
        quantity_g: Quantidade efetivamente consumida em gramas
        kcal / protein / carbs / fats: Snapshot dos macros calculados
    """

    __tablename__ = "diet_logbook_entries"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    logbook_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("diet_logbooks.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    meal_name = Column(String(255), nullable=False)

    food_name = Column(String(255), nullable=False, default="")

    food_id = Column(
        Integer,
        ForeignKey("food_catalog.id", ondelete="SET NULL"),
        nullable=True,
    )

    custom_food_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("custom_foods.id", ondelete="SET NULL"),
        nullable=True,
    )

    quantity_g = Column(Float, nullable=False)

    # Snapshot dos macros (calculados na inserção)
    kcal = Column(Float, nullable=False, default=0.0)

    protein = Column(Float, nullable=False, default=0.0)

    carbs = Column(Float, nullable=False, default=0.0)

    fats = Column(Float, nullable=False, default=0.0)

    # Relação reversa com DietLogbook
    logbook = relationship("DietLogbook", back_populates="entries")

    def __repr__(self) -> str:
        source = f"food_id={self.food_id}" if self.food_id else f"custom={self.custom_food_id}"
        return f"<DietLogbookEntry(id={self.id}, {source}, qty={self.quantity_g}g)>"
