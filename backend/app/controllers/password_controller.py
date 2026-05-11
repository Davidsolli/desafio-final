"""Controller para recuperação e redefinição de senha."""

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.password_dto import ForgotPasswordDTO, MessageResponseDTO, ResetPasswordDTO
from app.services.password_service import PasswordService


class PasswordController:
    """Orquestra operações de recuperação de senha."""

    def __init__(self, session: AsyncSession):
        self.service = PasswordService(session)

    async def forgot_password(self, dto: ForgotPasswordDTO) -> MessageResponseDTO:
        await self.service.request_reset(dto.email)
        return MessageResponseDTO(
            message="Se existir uma conta com este email, enviaremos instruções de recuperação."
        )

    async def reset_password(self, dto: ResetPasswordDTO) -> MessageResponseDTO:
        await self.service.reset_password(
            token=dto.token,
            new_password=dto.new_password,
            confirm_password=dto.confirm_password,
        )
        return MessageResponseDTO(message="Senha redefinida com sucesso. Faça login novamente.")
