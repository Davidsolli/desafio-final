"""Modelo para pré-cadastro via WhatsApp."""

from datetime import datetime
from uuid import uuid4

from sqlalchemy import Column, DateTime, String, Text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID

from app.models.user import Base


class WhatsAppPreRegistration(Base):
    """
    Armazena o estado da conversa de pré-cadastro via WhatsApp.

    States:
        awaiting_name      → aguardando o usuário enviar o nome
        awaiting_email     → aguardando o email
        awaiting_plan      → aguardando escolha de plano
        awaiting_payment   → link de pagamento enviado, aguardando webhook
        pending_approval   → pagamento confirmado, aguardando aprovação do admin
        approved           → admin aprovou, código de convite enviado

    payment_status:
        not_required       → pré-cadastros antigos (sem fluxo de pagamento)
        pending            → plano selecionado, aguardando confirmação
        confirmed          → pagamento confirmado via webhook
        expired            → link de pagamento expirou
    """

    __tablename__ = "whatsapp_pre_registrations"

    id = Column(PG_UUID(as_uuid=True), primary_key=True, default=uuid4, nullable=False)

    phone = Column(String(20), unique=True, nullable=False, index=True)

    state = Column(String(30), nullable=False, default="awaiting_name")

    name = Column(String(255), nullable=True)
    email = Column(String(255), nullable=True)
    invitation_code = Column(String(50), nullable=True, index=True)

    # Seleção de plano e pagamento (adicionado na migração 005)
    selected_plan_id = Column(PG_UUID(as_uuid=True), nullable=True)
    payment_status = Column(String(30), nullable=False, default="not_required")
    pre_reg_payment_id = Column(String(100), nullable=True, unique=True)
    checkout_url = Column(Text, nullable=True)

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
