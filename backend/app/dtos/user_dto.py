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
VALID_THEMES = {"light", "dark", "system"}
PASSWORD_REGEX = r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@!#$%^&*])[a-zA-Z0-9@!#$%^&*]{8,}$"


class CreateUserDTO(BaseModel):
    """DTO para criação de novo usuário."""

    name: str = Field(
        min_length=3,
        max_length=255,
        description="Nome completo do usuário",
    )
    email: EmailStr = Field(
        description="Email único do usuário",
    )
    password: str = Field(
        min_length=8,
        description="Senha (mín. 8 chars, maiúscula, minúscula, número, caractere especial)",
    )
    role: str = Field(
        default="client",
        description="Papel do usuário: admin, personal_trainer ou client",
    )
    weight_kg: Optional[float] = Field(
        default=None,
        gt=0,
        description="Peso do usuário em kg (opcional)",
    )
    height_cm: Optional[float] = Field(
        default=None,
        gt=0,
        description="Altura do usuário em cm (opcional)",
    )
    age: Optional[int] = Field(
        default=None,
        ge=1,
        le=150,
        description="Idade do usuário em anos (opcional)",
    )
    goal_type: Optional[str] = Field(
        default=None,
        description="Objetivo de treino: gain_mass, lose_weight, maintain, endurance (opcional)",
    )
    invitation_code: Optional[str] = Field(
        default=None,
        description="Código de convite (obrigatório para clientes, opcional para personal trainers e admins)",
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

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "João Silva",
                "email": "joao@example.com",
                "password": "SenhaForte123!",
                "role": "client",
                "weight_kg": 78,
                "height_cm": 175,
                "age": 27,
                "goal_type": "gain_mass",
                "invitation_code": "AB3X7KP2QR",
            },
            "example_personal_trainer": {
                "name": "Maria Treinadora",
                "email": "maria@example.com",
                "password": "SenhaForte123!",
                "role": "personal_trainer",
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
    is_active: Optional[bool] = Field(
        None,
        description="Status ativo/inativo do usuário",
    )
    weight: Optional[float] = Field(
        None,
        gt=0,
        description="Peso do usuário em kg",
    )
    height: Optional[float] = Field(
        None,
        gt=0,
        description="Altura do usuário em cm",
    )
    age: Optional[int] = Field(
        None,
        ge=1,
        le=150,
        description="Idade do usuário em anos",
    )
    gender: Optional[str] = Field(
        None,
        description="Gênero: male ou female",
    )
    phone_whatsapp: Optional[str] = Field(
        None,
        description="Telefone WhatsApp do usuário",
    )
    goal_type: Optional[str] = Field(
        None,
        description="Objetivo de treino: gain_mass, lose_weight, maintain, endurance",
    )
    theme_preference: Optional[str] = Field(
        None,
        description="Preferência de tema: light, dark ou system",
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

    @field_validator("theme_preference")
    @classmethod
    def validate_theme_preference(cls, v: Optional[str]) -> Optional[str]:
        """Validar tema: deve ser um dos valores válidos ou None."""
        if v is None:
            return v
        if v not in VALID_THEMES:
            raise ValueError(
                f"Tema deve ser um de: {', '.join(VALID_THEMES)}"
            )
        return v

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "João Silva Santos",
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
    is_active: bool
    created_at: datetime
    updated_at: datetime
    weight: Optional[float] = None
    height: Optional[float] = None
    age: Optional[int] = None
    gender: Optional[str] = None
    phone_whatsapp: Optional[str] = None
    goal_type: Optional[str] = None
    trainer_id: Optional[UUID] = None
    theme_preference: Optional[str] = None

    model_config = ConfigDict(
        from_attributes=True,
        json_schema_extra={
            "example": {
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "name": "João Silva",
                "email": "joao@example.com",
                "role": "client",
                "is_active": True,
                "created_at": "2026-04-14T10:30:00Z",
                "updated_at": "2026-04-14T10:30:00Z",
                "weight": 78.5,
                "height": 175.0,
                "age": 27,
                "gender": "male",
                "phone_whatsapp": "+55 11 99999-9999",
                "goal_type": "gain_mass",
            }
        }
    )


class UpdateThemePreferenceDTO(BaseModel):
    """DTO para atualizar preferência de tema do usuário."""

    theme_preference: str = Field(
        ...,
        description="Preferência de tema: light, dark ou system",
    )

    @field_validator("theme_preference")
    @classmethod
    def validate_theme_preference(cls, v: str) -> str:
        """Validar tema: deve ser um dos valores válidos."""
        if v not in VALID_THEMES:
            raise ValueError(
                f"Tema deve ser um de: {', '.join(VALID_THEMES)}"
            )
        return v

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "theme_preference": "dark",
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
                        "is_active": True,
                        "created_at": "2026-04-14T10:30:00Z",
                        "updated_at": "2026-04-14T10:30:00Z",
                    }
                ],
            }
        }
    )
