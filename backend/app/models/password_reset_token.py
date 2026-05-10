"""Modelo SQLAlchemy para tokens de recuperação de senha."""

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.models.user import Base


class PasswordResetToken(Base):
    """
    Token temporário para recuperação de senha.

    O token em texto plano é enviado por email; apenas o hash SHA256
    é armazenado no banco para evitar exposição em caso de vazamento.
    """

    __tablename__ = "password_reset_tokens"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)

    user_id = Column(PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)

    token_hash = Column(String(255), nullable=False, unique=True, index=True)

    expires_at = Column(DateTime, nullable=False)

    used = Column(Boolean, nullable=False, default=False)

    used_at = Column(DateTime, nullable=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)

    def __repr__(self) -> str:
        return f"<PasswordResetToken(id={self.id}, user_id={self.user_id}, used={self.used})>"
