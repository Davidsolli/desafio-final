"""
Data Transfer Objects para Pagamentos e Assinaturas (MVP V1)
"""
from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime
from uuid import UUID
from decimal import Decimal


# ============= PLANS =============

class CreatePlanDTO(BaseModel):
    name: str = Field(..., min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    price: Decimal = Field(..., gt=0, decimal_places=2)
    duration_months: int = Field(..., ge=1)
    modality: Optional[str] = Field(None, max_length=50)
    evaluations_included: int = Field(0, ge=0)

    @field_validator('duration_months')
    @classmethod
    def validate_duration(cls, v):
        if v not in [1, 3, 6, 12]:
            raise ValueError('Duração deve ser 1, 3, 6 ou 12 meses')
        return v

    model_config = {
        "json_schema_extra": {
            "example": {
                "name": "Premium",
                "description": "Treino + Dieta + IA",
                "price": 150.00,
                "duration_months": 1,
                "modality": "Online",
                "evaluations_included": 2
            }
        }
    }


class UpdatePlanDTO(BaseModel):
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    description: Optional[str] = Field(None, max_length=500)
    price: Optional[Decimal] = Field(None, gt=0)
    duration_months: Optional[int] = Field(None, ge=1)
    modality: Optional[str] = Field(None, max_length=50)
    evaluations_included: Optional[int] = Field(None, ge=0)
    is_active: Optional[bool] = None


class PlanResponseDTO(BaseModel):
    id: UUID
    admin_id: UUID
    name: str
    description: Optional[str] = None
    price: Decimal
    currency: str
    duration_months: int
    modality: Optional[str] = None
    evaluations_included: int = 0
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# ============= SUBSCRIPTIONS =============

class CreateSubscriptionDTO(BaseModel):
    plan_id: UUID
    payment_method: str = Field(..., pattern="^(credit_card|pix)$")

    model_config = {
        "json_schema_extra": {
            "example": {
                "plan_id": "550e8400-e29b-41d4-a716-446655440000",
                "payment_method": "pix"
            }
        }
    }


class SubscriptionResponseDTO(BaseModel):
    id: UUID
    student_id: UUID
    plan_id: UUID
    admin_id: UUID
    status: str
    payment_method: Optional[str] = None
    external_payment_id: Optional[str] = None
    started_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    canceled_at: Optional[datetime] = None
    created_at: datetime

    model_config = {"from_attributes": True}

    @property
    def days_until_expiry(self) -> Optional[int]:
        if not self.expires_at:
            return None
        delta = self.expires_at - datetime.utcnow()
        return max(0, delta.days)


class SubscriptionDetailDTO(SubscriptionResponseDTO):
    plan: Optional[PlanResponseDTO] = None


class CheckoutResponseDTO(BaseModel):
    subscription_id: UUID
    checkout_url: str
    external_payment_id: str
    status: str


# ============= ADMIN DASHBOARD =============

class SubscriptionSummaryDTO(BaseModel):
    total_active: int
    total_pending: int
    total_canceled: int
    total_expired: int
    revenue_this_month: Decimal
    revenue_last_month: Decimal


class AdminSubscriptionItemDTO(BaseModel):
    """Item da lista de assinaturas no dashboard do admin"""
    id: UUID
    student_id: UUID
    student_name: str
    student_email: str
    plan_name: str
    plan_price: Decimal
    status: str
    payment_method: Optional[str] = None
    started_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ============= WEBHOOK =============

class AsaasWebhookDTO(BaseModel):
    """Payload do webhook do Asaas (mantido para compatibilidade)"""
    event: str
    payment: Optional[dict] = None
    id: Optional[str] = None
    externalReference: Optional[str] = None
    status: Optional[str] = None
    value: Optional[Decimal] = None

    def get_payment_id(self) -> Optional[str]:
        if self.payment:
            return self.payment.get('id')
        return self.id

    def get_external_reference(self) -> Optional[str]:
        if self.payment:
            return self.payment.get('externalReference')
        return self.externalReference

    model_config = {"extra": "allow"}


class InfinitePayWebhookDTO(BaseModel):
    """
    Payload do webhook da InfinitePay.
    Enviado quando o pagamento é confirmado.
    order_nsu: subscription_id enviado no momento do checkout
    status: 'paid' = pago, 'failed' = falhou, 'expired' = expirado
    """
    order_nsu: Optional[str] = None
    status: Optional[str] = None
    transaction_id: Optional[str] = None
    amount: Optional[int] = None          # valor em centavos
    payment_method: Optional[str] = None  # pix, credit

    def is_paid(self) -> bool:
        return self.status in ("paid", "approved", "confirmed", "complete", "completed")

    def get_subscription_id(self) -> Optional[str]:
        return self.order_nsu

    def get_payment_id(self) -> Optional[str]:
        return self.transaction_id or self.order_nsu

    model_config = {"extra": "allow"}
