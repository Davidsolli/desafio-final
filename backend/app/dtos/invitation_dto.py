"""
DTOs (Data Transfer Objects) para o módulo de convites.

Define validações com Pydantic para:
- GenerateInvitationDTO: dados para gerar novo convite
- ValidateInvitationDTO: dados para validar código
- InvitationResponseDTO: dados retornados pela API
"""

from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, ConfigDict


class GenerateInvitationDTO(BaseModel):
    """DTO para geração de novo convite pelo personal trainer."""

    pass


class ValidateInvitationDTO(BaseModel):
    """DTO para validar um código de convite."""

    code: str = Field(
        min_length=1,
        max_length=20,
        description="Código de convite a ser validado",
    )


class InvitationResponseDTO(BaseModel):
    """DTO para resposta da API (convite gerado)."""

    id: UUID
    code: str
    trainer_id: UUID
    used: bool
    used_by_id: Optional[UUID] = None
    created_at: datetime
    used_at: Optional[datetime] = None

    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "example": {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "code": "AB3X7KP2QR",
                "trainer_id": "660e8400-e29b-41d4-a716-446655440111",
                "used": False,
                "used_by_id": None,
                "created_at": "2026-05-05T10:30:00Z",
                "used_at": None,
            }
        },
    )


class ValidateInvitationResponseDTO(BaseModel):
    """DTO para resposta da validação de código."""

    valid: bool = Field(description="Se o código é válido e pode ser usado")
    code: Optional[str] = Field(
        None,
        description="Código validado (retornado se válido)",
    )
    message: str = Field(
        description="Mensagem de status (válido, expirado, já usado, etc)"
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "valid": True,
                "code": "AB3X7KP2QR",
                "message": "Código válido e pronto para usar",
            }
        }
    )


class ApproveWhatsAppDTO(BaseModel):
    """DTO para aprovar pré-cadastro WhatsApp e enviar código ao usuário."""

    phone: str = Field(
        description="Número do WhatsApp do usuário a aprovar (ex: 5511999999999)",
    )


class WhatsAppPendingItemDTO(BaseModel):
    """Item de pré-cadastro WhatsApp pendente de aprovação."""

    phone: str
    name: Optional[str]
    email: Optional[str]
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class WhatsAppPendingListDTO(BaseModel):
    """Lista de pré-cadastros WhatsApp aguardando aprovação."""

    total: int
    items: list[WhatsAppPendingItemDTO]


class ListInvitationsResponseDTO(BaseModel):
    """DTO para resposta de listagem de convites."""

    total: int = Field(description="Total de convites gerados")
    pending: int = Field(description="Total de convites não utilizados")
    used: int = Field(description="Total de convites já utilizados")
    invitations: list[InvitationResponseDTO] = Field(
        description="Lista de convites"
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "total": 5,
                "pending": 3,
                "used": 2,
                "invitations": [
                    {
                        "id": "550e8400-e29b-41d4-a716-446655440000",
                        "code": "AB3X7KP2QR",
                        "trainer_id": "660e8400-e29b-41d4-a716-446655440111",
                        "used": False,
                        "used_by_id": None,
                        "created_at": "2026-05-05T10:30:00Z",
                        "used_at": None,
                    }
                ],
            }
        }
    )
