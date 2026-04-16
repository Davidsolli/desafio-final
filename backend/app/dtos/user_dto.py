"""
DTOs (Data Transfer Objects) para o módulo de usuários.

Define validações com Pydantic para:
- CreateUserDTO: dados de entrada para criar usuário
- UpdateUserDTO: dados para atualizar usuário
- UserResponseDTO: dados retornados pela API (sem senha)
"""

import re
from datetime import datetime
from typing import Optional
from uuid import UUID

from pydantic import BaseModel, Field, EmailStr, field_validator, ConfigDict


VALID_ROLES = {"admin", "personal_trainer", "client"}
PHONE_REGEX = r"^\+55\s\d{2}\s\d{5}-\d{4}$"
PASSWORD_REGEX = r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@!#$%^&*])[a-zA-Z0-9@!#$%^&*]{8,}$"


class CreateUserDTO(BaseModel):
    """DTO para criação de novo usuário."""

    name: str = Field(
        ...,
        min_length=3,
        max_length=255,
        description="Nome completo do usuário",
    )
    email: EmailStr = Field(
        ...,
        description="Email único do usuário",
    )
    password: str = Field(
        ...,
        min_length=8,
        description="Senha (mín. 8 chars, maiúscula, minúscula, número, caractere especial)",
    )
    role: str = Field(
        default="client",
        description="Papel do usuário: admin, personal_trainer ou client",
    )
    phone_whatsapp: str = Field(
        ...,
        description="Número WhatsApp no formato +55 XX XXXXX-XXXX",
    )

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: str) -> str:
        """Validar nome: sem números, apenas letras e espaços."""
        if not re.match(r"^[a-zA-Zá-ýÁ-Ý\s]+$", v):
            raise ValueError("Nome deve conter apenas letras e espaços")
        return v.strip()

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        """Validar senha: mínimo 8 chars, maiúscula, minúscula, número, caractere especial."""
        if not re.match(PASSWORD_REGEX, v):
            raise ValueError(
                "Senha deve ter: mínimo 8 caracteres, pelo menos uma maiúscula, "
                "uma minúscula, um número e um caractere especial (@!#$%^&*)"
            )
        return v

    @field_validator("role")
    @classmethod
    def validate_role(cls, v: str) -> str:
        """Validar role: deve ser um dos valores válidos."""
        if v not in VALID_ROLES:
            raise ValueError(
                f"Role deve ser um de: {', '.join(VALID_ROLES)}"
            )
        return v

    @field_validator("phone_whatsapp")
    @classmethod
    def validate_phone(cls, v: str) -> str:
        """Validar telefone: formato +55 XX XXXXX-XXXX."""
        if not re.match(PHONE_REGEX, v):
            raise ValueError(
                "Telefone WhatsApp deve estar no formato +55 XX XXXXX-XXXX"
            )
        return v

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "João Silva",
                "email": "joao@example.com",
                "password": "SenhaForte123!",
                "role": "client",
                "phone_whatsapp": "+55 11 99999-9999",
            }
        }
    )


class UpdateUserDTO(BaseModel):
    """DTO para atualizar usuário (todos os campos opcionais)."""

    name: Optional[str] = Field(
        None,
        min_length=3,
        max_length=255,
        description="Nome completo do usuário",
    )
    role: Optional[str] = Field(
        None,
        description="Papel do usuário: admin, personal_trainer ou client",
    )
    phone_whatsapp: Optional[str] = Field(
        None,
        description="Número WhatsApp no formato +55 XX XXXXX-XXXX",
    )
    is_active: Optional[bool] = Field(
        None,
        description="Status ativo/inativo do usuário",
    )

    @field_validator("name")
    @classmethod
    def validate_name(cls, v: Optional[str]) -> Optional[str]:
        """Validar nome: sem números, apenas letras e espaços."""
        if v is None:
            return v
        if not re.match(r"^[a-zA-Zá-ýÁ-Ý\s]+$", v):
            raise ValueError("Nome deve conter apenas letras e espaços")
        return v.strip()

    @field_validator("role")
    @classmethod
    def validate_role(cls, v: Optional[str]) -> Optional[str]:
        """Validar role: deve ser um dos valores válidos."""
        if v is None:
            return v
        if v not in VALID_ROLES:
            raise ValueError(
                f"Role deve ser um de: {', '.join(VALID_ROLES)}"
            )
        return v

    @field_validator("phone_whatsapp")
    @classmethod
    def validate_phone(cls, v: Optional[str]) -> Optional[str]:
        """Validar telefone: formato +55 XX XXXXX-XXXX."""
        if v is None:
            return v
        if not re.match(PHONE_REGEX, v):
            raise ValueError(
                "Telefone WhatsApp deve estar no formato +55 XX XXXXX-XXXX"
            )
        return v

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "João Silva Santos",
                "phone_whatsapp": "+55 11 98888-8888",
                "role": "personal_trainer",
                "is_active": True,
            }
        }
    )


class UserResponseDTO(BaseModel):
    """DTO para resposta da API (sem senha)."""

    id: UUID
    name: str
    email: str
    role: str
    phone_whatsapp: str
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "example": {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "name": "João Silva",
                "email": "joao@example.com",
                "role": "client",
                "phone_whatsapp": "+55 11 99999-9999",
                "is_active": True,
                "created_at": "2026-04-14T10:30:00Z",
                "updated_at": "2026-04-14T10:30:00Z",
            }
        }
    )


class PaginatedUsersResponseDTO(BaseModel):
    """DTO para resposta paginada de usuários."""

    total: int = Field(..., description="Total de usuários no banco")
    page: int = Field(..., description="Página atual")
    limit: int = Field(..., description="Itens por página")
    data: list[UserResponseDTO] = Field(..., description="Lista de usuários")

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "total": 150,
                "page": 1,
                "limit": 10,
                "data": [
                    {
                        "id": "550e8400-e29b-41d4-a716-446655440000",
                        "name": "João Silva",
                        "email": "joao@example.com",
                        "role": "client",
                        "phone_whatsapp": "+55 11 99999-9999",
                        "is_active": True,
                        "created_at": "2026-04-14T10:30:00Z",
                        "updated_at": "2026-04-14T10:30:00Z",
                    }
                ],
            }
        }
    )
