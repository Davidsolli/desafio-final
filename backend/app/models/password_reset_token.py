"""
Modelo SQLAlchemy para tokens de recuperação de senha.

Define a tabela 'password_reset_tokens' com campos: id, user_id, token_hash,
expires_at, used, used_at, created_at.
"""

from datetime import datetime
from uuid import uuid4
from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Index
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import declarative_base

Base = declarative_base()


class PasswordResetToken(Base):
    """
    Token temporário para recuperação de senha.

    Atributos:
        id: UUID única gerada automaticamente
        user_id: FK para users.id
        token_hash: Hash SHA256 do token (nunca armazena token bruto)
        expires_at: Data/hora de expiração
        used: Boolean indicando se token foi utilizado
        used_at: Data/hora quando foi utilizado (None se não usado)
        created_at: Data de criação
    """

    __tablename__ = "password_reset_tokens"

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

    token_hash = Column(
        String(255),
        nullable=False,
        unique=True,
        index=True,
    )

    expires_at = Column(
        DateTime,
        nullable=False,
        index=True,
    )

    used = Column(
        Boolean,
        nullable=False,
        default=False,
        index=True,
    )

    used_at = Column(
        DateTime,
        nullable=True,
    )

    created_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
    )

    __table_args__ = (
        Index("ix_password_reset_tokens_user_id_expires_at", "user_id", "expires_at"),
    )

    def __repr__(self) -> str:
        return f"<PasswordResetToken(id={self.id}, user_id={self.user_id}, used={self.used})>"
