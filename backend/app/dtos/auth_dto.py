"""DTOs (Data Transfer Objects) para o módulo de autenticação."""

import re
from pydantic import BaseModel, EmailStr, Field, ConfigDict, field_validator, model_validator

PASSWORD_REGEX = r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@!#$%^&*])[a-zA-Z0-9@!#$%^&*]{8,}$"


class LoginDTO(BaseModel):
    """DTO para login (email + senha)."""

    email: EmailStr = Field(
        ...,
        description="Email do usuário",
    )
    password: str = Field(
        ...,
        min_length=1,
        description="Senha do usuário",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "email": "joao@example.com",
                "password": "SenhaForte123!",
            }
        }
    )


class ChangePasswordDTO(BaseModel):
    """DTO para troca de senha do usuário."""

    current_password: str = Field(..., min_length=1, description="Senha atual")
    new_password: str = Field(..., description="Nova senha")
    confirm_password: str = Field(..., description="Confirmação da nova senha")

    @field_validator("new_password")
    @classmethod
    def validate_new_password(cls, v: str) -> str:
        if not re.match(PASSWORD_REGEX, v):
            raise ValueError(
                "Senha deve ter mínimo 8 caracteres, "
                "uma maiúscula, uma minúscula, um número e um caractere especial (@!#$%^&*)"
            )
        return v

    @model_validator(mode="after")
    def validate_passwords_match(self) -> "ChangePasswordDTO":
        if self.new_password != self.confirm_password:
            raise ValueError("A nova senha e a confirmação não correspondem")
        return self

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "current_password": "SenhaAtual123!",
                "new_password": "NovaSenha123!",
                "confirm_password": "NovaSenha123!",
            }
        }
    )


class TokenResponseDTO(BaseModel):
    """DTO para resposta de token JWT."""

    access_token: str = Field(
        ...,
        description="Token JWT para autenticação",
    )
    token_type: str = Field(
        default="bearer",
        description="Tipo de token (sempre 'bearer' para JWT)",
    )
    expires_in: int = Field(
        ...,
        description="Tempo de expiração do token em segundos",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "token_type": "bearer",
                "expires_in": 86400,
            }
        }
    )
