"""
Modelos SQLAlchemy para Pagamentos e Assinaturas (MVP V1)
"""
from sqlalchemy import Column, String, Numeric, Integer, DateTime, Boolean, ForeignKey, TIMESTAMP, desc
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from datetime import datetime
import uuid

from app.models.user import Base


class Plan(Base):
    """Plano de assinatura"""
    __tablename__ = "plans"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    admin_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    name = Column(String(100), nullable=False)
    description = Column(String(500))

    price = Column(Numeric(10, 2), nullable=False)
    currency = Column(String(3), default="BRL")
    duration_months = Column(Integer, nullable=False)
    modality = Column(String(50), nullable=True)
    evaluations_included = Column(Integer, default=0)

    is_active = Column(Boolean, default=True)
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    updated_at = Column(TIMESTAMP, default=datetime.utcnow, onupdate=datetime.utcnow)
    deleted_at = Column(TIMESTAMP, nullable=True)

    # Relationships
    subscriptions = relationship("Subscription", back_populates="plan", cascade="all, delete-orphan")

    def __repr__(self):
        return f"<Plan id={self.id} name={self.name} price={self.price}>"


class Subscription(Base):
    """Assinatura de um aluno"""
    __tablename__ = "subscriptions"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    student_id = Column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    plan_id = Column(UUID(as_uuid=True), ForeignKey("plans.id"), nullable=False)
    admin_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=False)

    status = Column(String(20), default="pending")  # pending, active, expired, canceled_pending, canceled
    payment_method = Column(String(20))  # pix, credit_card
    external_payment_id = Column(String(100), unique=True)

    started_at = Column(TIMESTAMP, nullable=True)
    expires_at = Column(TIMESTAMP, nullable=True)
    canceled_at = Column(TIMESTAMP, nullable=True)

    replacement_policy = Column(String(20), nullable=True)  # immediate, on_expiry
    
    created_at = Column(TIMESTAMP, default=datetime.utcnow)
    updated_at = Column(TIMESTAMP, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relationships
    plan = relationship("Plan", back_populates="subscriptions")

    def __repr__(self):
        return f"<Subscription id={self.id} student_id={self.student_id} status={self.status}>"

    def is_active_now(self) -> bool:
        """Verifica se a assinatura está ativa agora"""
        if self.status != "active":
            return False
        if self.expires_at and self.expires_at < datetime.utcnow():
            return False
        return True
