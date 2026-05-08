"""DTOs para operações de recuperação e troca de senha."""

from pydantic import BaseModel, EmailStr, Field, field_validator, ConfigDict


class ForgotPasswordDTO(BaseModel):
    """DTO para requisição de recuperação de senha."""

    email: EmailStr = Field(
        ...,
        description="Email do usuário",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "email": "user@example.com",
            }
        }
    )


class ResetPasswordDTO(BaseModel):
    """DTO para redefinição de senha com token."""

    token: str = Field(
        ...,
        min_length=1,
        description="Token temporário de reset",
    )

    new_password: str = Field(
        ...,
        min_length=8,
        description="Nova senha (8+ chars, maiúscula, minúscula, número, caractere especial)",
    )

    confirm_password: str = Field(
        ...,
        min_length=8,
        description="Confirmação da nova senha",
    )

    @field_validator("new_password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        """Validar força de senha."""
        import re

        if not re.match(
            r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&_\-])[a-zA-Z\d@$!%*?&_\-]{8,}$",
            v,
        ):
            raise ValueError(
                "Senha deve ter 8+ caracteres, maiúscula, minúscula, número e caractere especial"
            )
        return v

    @field_validator("confirm_password")
    @classmethod
    def validate_passwords_match(cls, v: str, info) -> str:
        """Validar que senhas conferem."""
        if "new_password" in info.data and v != info.data["new_password"]:
            raise ValueError("As senhas não conferem")
        return v

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "token": "g2wgeyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
                "new_password": "NovaSenha123!",
                "confirm_password": "NovaSenha123!",
            }
        }
    )


class ChangePasswordDTO(BaseModel):
    """DTO para mudança de senha de usuário autenticado."""

    current_password: str = Field(
        ...,
        min_length=1,
        description="Senha atual para validação",
    )

    new_password: str = Field(
        ...,
        min_length=8,
        description="Nova senha (8+ chars, maiúscula, minúscula, número, caractere especial)",
    )

    confirm_password: str = Field(
        ...,
        min_length=8,
        description="Confirmação da nova senha",
    )

    @field_validator("new_password")
    @classmethod
    def validate_password_strength(cls, v: str) -> str:
        """Validar força de senha."""
        import re

        if not re.match(
            r"^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&_\-])[a-zA-Z\d@$!%*?&_\-]{8,}$",
            v,
        ):
            raise ValueError(
                "Senha deve ter 8+ caracteres, maiúscula, minúscula, número e caractere especial"
            )
        return v

    @field_validator("confirm_password")
    @classmethod
    def validate_passwords_match(cls, v: str, info) -> str:
        """Validar que senhas conferem."""
        if "new_password" in info.data and v != info.data["new_password"]:
            raise ValueError("As senhas não conferem")
        return v

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "current_password": "SenhaAtual123!",
                "new_password": "NovaSenha123!",
                "confirm_password": "NovaSenha123!",
            }
        }
    )


class PasswordResponseDTO(BaseModel):
    """DTO genérico de resposta para operações de senha."""

    message: str = Field(
        ...,
        description="Mensagem de sucesso ou erro",
    )

    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "message": "Senha alterada com sucesso",
            }
        }
    )
