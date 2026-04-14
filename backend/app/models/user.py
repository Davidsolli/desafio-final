"""
Modelo SQLAlchemy para usuários.

Define a tabela 'users' com campos: id, name, email, password (hash),
role, phone_whatsapp, is_active, created_at, updated_at.
"""

from datetime import datetime
from uuid import uuid4
from sqlalchemy import Column, String, Boolean, DateTime
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class User(Base):
    """
    Modelo de Usuário do OmniConnect Fitness.

    Atributos:
        id: UUID única gerada automaticamente
        name: Nome completo do usuário
        email: Email único do usuário
        password: Hash bcrypt da senha (nunca texto plano)
        role: Papel do usuário (admin, personal_trainer, client)
        phone_whatsapp: Número WhatsApp (+55 XX XXXXX-XXXX)
        is_active: Status ativo/inativo (soft delete)
        created_at: Data de criação (imutável)
        updated_at: Data da última atualização
    """

    __tablename__ = "users"

    id = Column(
        PG_UUID(as_uuid=True),
        primary_key=True,
        default=uuid4,
        nullable=False,
    )

    name = Column(String(255), nullable=False, index=True)

    email = Column(
        String(255),
        nullable=False,
        unique=True,
        index=True,
    )

    password = Column(String(255), nullable=False)

    role = Column(
        String(50),
        nullable=False,
        default="client",
        index=True,
    )

    phone_whatsapp = Column(String(20), nullable=False)

    is_active = Column(Boolean, nullable=False, default=True, index=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    def __repr__(self) -> str:
        return f"<User(id={self.id}, name={self.name}, email={self.email}, role={self.role})>"
