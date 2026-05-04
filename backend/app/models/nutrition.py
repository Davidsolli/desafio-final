"""
Modelos SQLAlchemy para o módulo de Nutrição (RF-59 a RF-66).

Tabelas:
  - foods: Catálogo de alimentos com macronutrientes
  - meals: Refeições registradas pelo usuário
  - meal_food_entries: Itens de alimentos em cada refeição
"""

from datetime import datetime, date
from uuid import uuid4

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import relationship

from app.models.user import Base


class Food(Base):
    """
    Catálogo de alimentos com informações nutricionais por 100g.

    Pode ser pré-populado com alimentos comuns ou criado pelo usuário/admin.
    """

    __tablename__ = "foods"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)
    name = Column(String(200), nullable=False, index=True)
    brand = Column(String(100), nullable=True)
    calories_per_100g = Column(Float, nullable=False, default=0.0)
    protein_per_100g = Column(Float, nullable=False, default=0.0)
    carbs_per_100g = Column(Float, nullable=False, default=0.0)
    fat_per_100g = Column(Float, nullable=False, default=0.0)
    fiber_per_100g = Column(Float, nullable=True, default=0.0)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    meal_entries = relationship(
        "MealFoodEntry",
        back_populates="food",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<Food(name={self.name}, cal={self.calories_per_100g}/100g)>"


class Meal(Base):
    """
    Refeição registrada pelo usuário.

    Agrega os totais de macronutrientes de todos os alimentos incluídos.
    """

    __tablename__ = "meals"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)
    user_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    meal_type = Column(
        String(20),
        nullable=False,
        index=True,
    )  # breakfast | lunch | dinner | snack
    meal_date = Column(Date, nullable=False, index=True)

    # Totais calculados (desnormalizados para performance)
    total_calories = Column(Float, nullable=False, default=0.0)
    total_protein = Column(Float, nullable=False, default=0.0)
    total_carbs = Column(Float, nullable=False, default=0.0)
    total_fat = Column(Float, nullable=False, default=0.0)

    notes = Column(Text, nullable=True)
    is_deleted = Column(Boolean, nullable=False, default=False)
    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    food_entries = relationship(
        "MealFoodEntry",
        back_populates="meal",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    def __repr__(self) -> str:
        return (
            f"<Meal(id={self.id}, user_id={self.user_id}, "
            f"type={self.meal_type}, date={self.meal_date})>"
        )


class MealFoodEntry(Base):
    """
    Item de alimento dentro de uma refeição.

    Armazena os valores reais consumidos (calculados a partir da quantidade).
    """

    __tablename__ = "meal_food_entries"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)
    meal_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("meals.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    food_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("foods.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    # Desnormalizado para exibição rápida
    food_name = Column(String(200), nullable=False)

    quantity_grams = Column(Float, nullable=False, default=100.0)

    # Valores reais consumidos
    calories = Column(Float, nullable=False, default=0.0)
    protein = Column(Float, nullable=False, default=0.0)
    carbs = Column(Float, nullable=False, default=0.0)
    fat = Column(Float, nullable=False, default=0.0)

    meal = relationship("Meal", back_populates="food_entries")
    food = relationship("Food", back_populates="meal_entries")

    def __repr__(self) -> str:
        return (
            f"<MealFoodEntry(food={self.food_name}, qty={self.quantity_grams}g, "
            f"cal={self.calories})>"
        )
