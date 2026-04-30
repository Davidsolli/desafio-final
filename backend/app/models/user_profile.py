"""
Modelo SQLAlchemy para perfil de usuário.

Define a tabela 'user_profiles' com dados corporais e objetivos do usuário.
Campos: weight_kg, height_cm, age, goal_type.
"""

from datetime import datetime
from uuid import uuid4
from sqlalchemy import Column, String, Float, Integer, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.models.user import Base


class UserProfile(Base):
    """
    Modelo de Perfil de Usuário do OmniConnect Fitness.

    Armazena dados corporais e objetivos de treino do usuário.

    Atributos:
        id: UUID única gerada automaticamente
        user_id: FK para users.id (relacionamento 1:1)
        weight_kg: Peso do usuário em kg
        height_cm: Altura do usuário em cm
        age: Idade do usuário em anos
        goal_type: Objetivo: gain_mass, lose_weight, maintain, endurance
        created_at: Data de criação (imutável)
        updated_at: Data da última atualização
    """

    __tablename__ = "user_profiles"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    user_id = Column(
        PG_UUID(as_uuid=True),
        ForeignKey("users.id"),
        nullable=False,
        unique=True,
        index=True,
    )

    weight_kg = Column(Float, nullable=True)

    height_cm = Column(Float, nullable=True)

    age = Column(Integer, nullable=True)

    goal_type = Column(String(50), nullable=True, index=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    def __repr__(self) -> str:
        return f"<UserProfile(user_id={self.user_id}, weight={self.weight_kg}, goal={self.goal_type})>"
