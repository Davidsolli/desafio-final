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
    """DTO para resposta de token JWT (RNF-05)."""

    access_token: str = Field(
        ...,
        description="Token JWT de acesso (24 horas)",
    )
    refresh_token: str = Field(
        ...,
        description="Token de renovação (30 dias)",
    )
    token_type: str = Field(
        default="bearer",
        description="Tipo de token (sempre 'bearer')",
    )
    expires_in: int = Field(
        ...,
        description="Tempo de expiração do access_token em segundos",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "refresh_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
                "token_type": "bearer",
                "expires_in": 86400,
            }
        }
    )


class RefreshTokenDTO(BaseModel):
    """DTO para renovação de token via refresh_token (RNF-05)."""

    refresh_token: str = Field(..., description="Token de renovação emitido no login")
