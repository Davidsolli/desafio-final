"""Modelo para pré-cadastro via WhatsApp."""

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, DateTime, String
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.models.user import Base


class WhatsAppPreRegistration(Base):
    """
    Armazena o estado da conversa de pré-cadastro via WhatsApp.

    States:
        awaiting_name      → aguardando o usuário enviar o nome
        awaiting_email     → aguardando o email
        awaiting_code      → aguardando o código de convite
        completed          → dados coletados, aguardando finalizar no app
    """

    __tablename__ = "whatsapp_pre_registrations"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)

    phone = Column(String(20), unique=True, nullable=False, index=True)

    state = Column(String(30), nullable=False, default="awaiting_name")

    name = Column(String(255), nullable=True)
    email = Column(String(255), nullable=True)
    invitation_code = Column(String(50), nullable=True, index=True)

    created_at = Column(DateTime, nullable=False, default=datetime.utcnow)
    updated_at = Column(
        DateTime,
        nullable=False,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
    )

    def __repr__(self) -> str:
        return (
            f"<WhatsAppPreRegistration(phone={self.phone!r}, "
            f"state={self.state!r}, name={self.name!r})>"
        )
