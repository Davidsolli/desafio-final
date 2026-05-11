"""DTOs para recuperação e redefinição de senha."""

from pydantic import BaseModel, EmailStr, Field, ConfigDict


class ForgotPasswordDTO(BaseModel):
    """DTO para solicitar recuperação de senha."""

    email: EmailStr = Field(..., description="Email do usuário cadastrado")

    model_config = ConfigDict(
        json_schema_extra={"example": {"email": "usuario@example.com"}}
    )


class ResetPasswordDTO(BaseModel):
    """DTO para redefinir senha com token recebido por email."""

    token: str = Field(..., min_length=1, description="Token recebido por email")
    new_password: str = Field(..., min_length=8, description="Nova senha")
    confirm_password: str = Field(..., min_length=8, description="Confirmação da nova senha")

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "token": "abc123xyz...",
                "new_password": "NovaSenha123!",
                "confirm_password": "NovaSenha123!",
            }
        }
    )


class MessageResponseDTO(BaseModel):
    """DTO genérico para respostas com mensagem."""

    message: str
