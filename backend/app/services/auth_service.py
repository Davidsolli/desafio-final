"""Serviço de Autenticação com JWT (RNF-05: access=24h, refresh=30d)."""

from datetime import datetime, timedelta
from typing import Dict
from uuid import UUID

from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.settings import settings
from app.dtos.auth_dto import LoginDTO, RefreshTokenDTO, TokenResponseDTO
from app.repositories.user_repository import UserRepository
from app.services.user_service import UserService


class InvalidCredentialsError(Exception):
    """Exceção para credenciais inválidas."""
    pass


class InvalidRefreshTokenError(Exception):
    """Exceção para refresh token inválido ou expirado."""
    pass


class AuthService:
    """Serviço de autenticação com JWT."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.repository = UserRepository(session)

    async def login(self, dto: LoginDTO) -> TokenResponseDTO:
        """Autenticar usuário e retornar access + refresh tokens."""
        user = await self.repository.get_by_email(dto.email)
        if not user:
            raise InvalidCredentialsError("Email ou senha incorretos")

        if not UserService.verify_password(dto.password, user.password):
            raise InvalidCredentialsError("Email ou senha incorretos")

        if not user.is_active:
            raise InvalidCredentialsError("Esta conta foi desativada")

        access_token = self.create_access_token({"sub": str(user.id), "type": "access"})
        refresh_token = self.create_refresh_token({"sub": str(user.id), "type": "refresh"})
        expires_in_seconds = settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60

        return TokenResponseDTO(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=expires_in_seconds,
        )

    async def refresh(self, dto: RefreshTokenDTO) -> TokenResponseDTO:
        """Renovar access token usando um refresh token válido (RNF-05)."""
        try:
            payload = jwt.decode(
                dto.refresh_token,
                settings.SECRET_KEY,
                algorithms=[settings.ALGORITHM],
            )
            if payload.get("type") != "refresh":
                raise InvalidRefreshTokenError("Token não é do tipo refresh")

            user_id: str = payload.get("sub")
            if not user_id:
                raise InvalidRefreshTokenError("Token sem subject")
        except (JWTError, ValueError) as exc:
            raise InvalidRefreshTokenError("Refresh token inválido ou expirado") from exc

        try:
            user_uuid = UUID(user_id)
        except ValueError as exc:
            raise InvalidRefreshTokenError("Subject do token não é um UUID válido") from exc

        user = await self.repository.get_by_id(user_uuid)
        if not user or not user.is_active:
            raise InvalidRefreshTokenError("Usuário não encontrado ou inativo")

        new_access = self.create_access_token({"sub": user_id, "type": "access"})
        new_refresh = self.create_refresh_token({"sub": user_id, "type": "refresh"})

        return TokenResponseDTO(
            access_token=new_access,
            refresh_token=new_refresh,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        )

    @staticmethod
    def create_access_token(data: Dict) -> str:
        """Criar access token JWT (expira em ACCESS_TOKEN_EXPIRE_MINUTES)."""
        to_encode = data.copy()
        expire = datetime.utcnow() + timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
        to_encode.update({"exp": expire})
        return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)

    @staticmethod
    def create_refresh_token(data: Dict) -> str:
        """Criar refresh token JWT (expira em REFRESH_TOKEN_EXPIRE_DAYS)."""
        to_encode = data.copy()
        expire = datetime.utcnow() + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
        to_encode.update({"exp": expire})
        return jwt.encode(to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM)
