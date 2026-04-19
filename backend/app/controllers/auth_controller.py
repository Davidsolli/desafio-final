"""Controller para autenticação."""

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.auth_dto import LoginDTO, TokenResponseDTO
from app.services.auth_service import AuthService


class AuthController:
    """Controller para operações de autenticação."""

    def __init__(self, session: AsyncSession):
        """Inicializar controller com sessão async."""
        self.service = AuthService(session)

    async def login(self, dto: LoginDTO) -> TokenResponseDTO:
        """
        Fazer login e retornar token JWT.

        Args:
            dto: LoginDTO com email e senha

        Returns:
            TokenResponseDTO com access_token
        """
        return await self.service.login(dto)
