"""Serviço de Autenticação com JWT."""

from datetime import datetime, timedelta
from typing import Dict

from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.settings import settings
from app.dtos.auth_dto import LoginDTO, TokenResponseDTO
from app.repositories.user_repository import UserRepository
from app.services.user_service import UserService


class InvalidCredentialsError(Exception):
    """Exceção para credenciais inválidas."""

    pass


class AuthService:
    """Serviço de autenticação com JWT."""

    def __init__(self, session: AsyncSession):
        """Inicializar serviço com sessão async."""
        self.session = session
        self.repository = UserRepository(session)

    async def login(self, dto: LoginDTO) -> TokenResponseDTO:
        """
        Autenticar usuário e retornar token JWT.

        Args:
            dto: LoginDTO com email e senha

        Returns:
            TokenResponseDTO com access_token

        Raises:
            InvalidCredentialsError: Se email/senha inválidos
        """
        user = await self.repository.get_by_email(dto.email)
        if not user:
            raise InvalidCredentialsError("Email ou senha incorretos")

        if not UserService.verify_password(dto.password, user.password):
            raise InvalidCredentialsError("Email ou senha incorretos")

        # Gerar token
        token = self.create_access_token({"sub": str(user.id)})
        expires_in_seconds = settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60

        return TokenResponseDTO(
            access_token=token,
            token_type="bearer",
            expires_in=expires_in_seconds,
        )

    @staticmethod
    def create_access_token(data: Dict) -> str:
        """
        Criar token JWT com expiração.

        Args:
            data: Dados a serem codificados no token (ex: {"sub": user_id})

        Returns:
            str: Token JWT assinado
        """
        to_encode = data.copy()
        expire = datetime.utcnow() + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )
        to_encode.update({"exp": expire})

        encoded_jwt = jwt.encode(
            to_encode,
            settings.SECRET_KEY,
            algorithm=settings.ALGORITHM,
        )
        return encoded_jwt
