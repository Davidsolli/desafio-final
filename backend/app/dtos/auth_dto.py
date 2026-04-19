"""DTOs (Data Transfer Objects) para o módulo de autenticação."""

from pydantic import BaseModel, EmailStr, Field, ConfigDict


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
