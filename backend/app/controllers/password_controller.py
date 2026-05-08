"""
Controller para operações de recuperação e troca de senha.

Orquestra entre routes, services e repositories.
"""

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.password_dto import (
    ForgotPasswordDTO,
    ResetPasswordDTO,
    ChangePasswordDTO,
    PasswordResponseDTO,
)
from app.models.user import User
from app.services.password_service import PasswordService, PasswordValidationError, PasswordMismatchError, InvalidTokenError
from app.services.email_service import EmailService, EmailSendError
from app.repositories.user_repository import UserRepository


class PasswordController:
    """Controller para gerenciamento de senhas."""

    def __init__(self, session: AsyncSession):
        """Inicializar controller com sessão async."""
        self.session = session
        self.password_service = PasswordService(session)
        self.user_repo = UserRepository(session)

    async def forgot_password(self, dto: ForgotPasswordDTO) -> PasswordResponseDTO:
        """
        Iniciar recuperação de senha.

        Sempre retorna sucesso (HTTP 200) sem indicar se email existe.

        Args:
            dto: ForgotPasswordDTO com email

        Returns:
            PasswordResponseDTO com mensagem genérica
        """
        # Chamar service (gera token e salva no banco UMA VEZ)
        result = await self.password_service.forgot_password(dto.email)

        # Tentar enviar email (melhor esforço)
        if result:
            token_raw, token_hash = result
            try:
                user = await self.user_repo.get_by_email(dto.email)
                if user:
                    email_service = EmailService()
                    await email_service.send_password_reset_email(
                        user_name=user.name,
                        to_email=user.email,
                        token=token_raw,
                    )
            except EmailSendError as e:
                import logging
                logging.error(f"Falha ao enviar email de recuperação: {e}")
            except Exception as e:
                import logging
                logging.error(f"Erro inesperado ao enviar email: {e}")

        return PasswordResponseDTO(
            message="Se existir uma conta com este email, enviaremos instruções de recuperação."
        )

    async def reset_password(self, dto: ResetPasswordDTO) -> PasswordResponseDTO:
        """
        Redefinir senha com token.

        Args:
            dto: ResetPasswordDTO com token e nova senha

        Returns:
            PasswordResponseDTO com mensagem de sucesso

        Raises:
            PasswordMismatchError: Senhas não conferem
            PasswordValidationError: Senha fraca
            InvalidTokenError: Token inválido, expirado ou já usado
        """
        await self.password_service.reset_password(
            token=dto.token,
            new_password=dto.new_password,
            confirm_password=dto.confirm_password,
        )

        return PasswordResponseDTO(message="Senha redefinida com sucesso. Faça login novamente.")

    async def change_password(
        self,
        user: User,
        dto: ChangePasswordDTO,
    ) -> PasswordResponseDTO:
        """
        Trocar senha para usuário autenticado.

        Args:
            user: Usuário autenticado
            dto: ChangePasswordDTO com senhas

        Returns:
            PasswordResponseDTO com mensagem de sucesso

        Raises:
            PasswordMismatchError: Passwords não conferem
            PasswordValidationError: Senha fraca
            InvalidTokenError: Senha atual incorreta
        """
        await self.password_service.change_password(
            user=user,
            current_password=dto.current_password,
            new_password=dto.new_password,
            confirm_password=dto.confirm_password,
        )

        return PasswordResponseDTO(
            message="Senha alterada com sucesso. Você será desconectado para fazer login novamente."
        )
