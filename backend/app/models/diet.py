"""
Modelos SQLAlchemy para o módulo de Dieta.

Define as tabelas:
  - custom_foods: Alimentos personalizados criados por usuários
  - diets: Dieta prescrita pelo personal ou personalizada pelo aluno
  - diet_meals: Refeição dentro de uma dieta
  - diet_items: Alimento dentro de uma refeição
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
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import relationship

from app.models.user import Base


class CustomFood(Base):
    """
    Alimento personalizado criado por um aluno ou personal.

    Fica isolado da base global (FoodCatalog/TACO). Apenas o criador
    e seus profissionais vinculados podem visualizar e usar.

    Atributos:
        id: UUID único
        user_id: Quem criou (FK users.id)
        name: Nome do alimento (ex: "Whey Protein Max Titanium")
        category: Categoria livre (ex: "Suplementos")
        energy_kcal: Calorias por 100g
        protein_g / carbohydrate_g / lipid_g / fiber_g: Macros por 100g
        created_at: Timestamp de criação
    """

    __tablename__ = "custom_foods"

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

    name = Column(String(255), nullable=False, index=True)

    category = Column(String(100), nullable=True)

    energy_kcal = Column(Float, nullable=False, default=0.0)

    protein_g = Column(Float, nullable=False, default=0.0)

    carbohydrate_g = Column(Float, nullable=False, default=0.0)

    lipid_g = Column(Float, nullable=False, default=0.0)

    fiber_g = Column(Float, nullable=False, default=0.0)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    def __repr__(self) -> str:
        return f"<CustomFood(id={self.id}, name={self.name!r}, user_id={self.user_id})>"


class Diet(Base):
    """
    Dieta atribuída a um aluno.

    Pode ser:
      - Prescrita (is_custom=False): criada por um personal/professor.
      - Personalizada (is_custom=True): criada pelo próprio aluno.

    Cada aluno pode ter no máximo uma dieta prescrita ativa e uma
    dieta personalizada ativa por vez (RN-01).

    Atributos:
        id: UUID único
        user_id: Aluno dono da dieta (FK users.id)
        professional_id: Personal que prescreveu (nullable para dieta custom)
        is_custom: True se criada pelo aluno, False se pelo personal
        name: Nome descritivo (ex: "Dieta Hipertrofia 3000kcal")
        goal: Objetivo (bulking, cutting, maintenance)
        is_active: Apenas uma ativa por tipo (prescrita/custom)
        created_at / updated_at: Timestamps
        meals: Relação 1:N com DietMeal
    """

    __tablename__ = "diets"

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

    professional_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="SET NULL"),
        nullable=True,
        index=True,
    )

    is_custom = Column(Boolean, nullable=False, default=False, index=True)

    name = Column(String(255), nullable=False)

    goal = Column(String(50), nullable=True)  # bulking, cutting, maintenance

    is_active = Column(Boolean, nullable=False, default=True, index=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    water_target_ml = Column(Integer, nullable=True, default=None)

    # Relação 1:N com refeições
    meals = relationship(
        "DietMeal",
        back_populates="diet",
        cascade="all, delete-orphan",
        order_by="DietMeal.order",
        lazy="selectin",
    )

    def __repr__(self) -> str:
        return (
            f"<Diet(id={self.id}, name={self.name!r}, "
            f"user_id={self.user_id}, is_custom={self.is_custom})>"
        )


class DietMeal(Base):
    """
    Refeição dentro de uma dieta.

    Atributos:
        id: UUID único
        diet_id: Dieta a que pertence (FK diets.id)
        name: Nome da refeição (ex: "Café da Manhã", "Almoço")
        time: Horário sugerido "HH:MM" (usado para notificações FCM)
        order: Ordem no dia (1, 2, 3…)
        items: Relação 1:N com DietItem
    """

    __tablename__ = "diet_meals"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    diet_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("diets.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    name = Column(String(255), nullable=False)

    time = Column(String(5), nullable=True)  # "HH:MM"

    order = Column(Integer, nullable=False, default=1)

    # Relação 1:N com itens da refeição
    items = relationship(
        "DietItem",
        back_populates="meal",
        cascade="all, delete-orphan",
        lazy="selectin",
    )

    # Relação reversa com Diet
    diet = relationship("Diet", back_populates="meals")

    def __repr__(self) -> str:
        return f"<DietMeal(id={self.id}, name={self.name!r}, order={self.order})>"


class DietItem(Base):
    """
    Alimento específico dentro de uma refeição da dieta.

    Pode referenciar um alimento da TACO (food_id) OU um alimento
    personalizado (custom_food_id). Pelo menos um deve estar preenchido.

    Atributos:
        id: UUID único
        meal_id: Refeição a que pertence (FK diet_meals.id)
        food_id: ID do alimento na TACO (nullable)
        custom_food_id: UUID do alimento personalizado (nullable)
        quantity_g: Quantidade em gramas
        observations: Notas livres (ex: "Grelhado com azeite")
    """

    __tablename__ = "diet_items"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    meal_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("diet_meals.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

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

    observations = Column(Text, nullable=True)

    # Relação reversa com DietMeal
    meal = relationship("DietMeal", back_populates="items")

    def __repr__(self) -> str:
        source = f"food_id={self.food_id}" if self.food_id else f"custom={self.custom_food_id}"
        return f"<DietItem(id={self.id}, {source}, qty={self.quantity_g}g)>"
