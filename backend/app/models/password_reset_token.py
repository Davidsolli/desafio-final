"""Modelo SQLAlchemy para tokens de recuperação de senha."""

from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy import Boolean, Column, DateTime, ForeignKey, String
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.models.user import Base


class PasswordResetToken(Base):
    """
    Token temporário para recuperação de senha.

    O token em texto plano é enviado por email; apenas o hash SHA256
    (64 chars fixos) é armazenado para evitar exposição em caso de vazamento.
    """

    __tablename__ = "password_reset_tokens"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)

    user_id = Column(PG_UUID(as_uuid=True), ForeignKey("users.id"), nullable=False, index=True)

    # SHA256 sempre produz 64 hex chars
    token_hash = Column(String(64), nullable=False, unique=True, index=True)

    # timezone=True → TIMESTAMPTZ no PostgreSQL; datetimes sempre com tzinfo
    expires_at = Column(DateTime(timezone=True), nullable=False)

    used = Column(Boolean, nullable=False, default=False)

    used_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        nullable=False,
        default=lambda: datetime.now(timezone.utc),
    )

    def __repr__(self) -> str:
        return f"<PasswordResetToken(id={self.id}, user_id={self.user_id}, used={self.used})>"
