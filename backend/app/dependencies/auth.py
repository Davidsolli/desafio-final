"""Dependências de autenticação para injeção nas rotas FastAPI."""

from uuid import UUID

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.config.settings import settings
from app.models.user import User
from app.repositories.user_repository import UserRepository

_bearer_scheme = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_scheme),
    session: AsyncSession = Depends(get_db),
) -> User:
    """Valida o Bearer token e retorna o usuário autenticado.

    Raises:
        HTTPException 401: Token ausente, inválido ou expirado.
        HTTPException 401: Usuário do token não encontrado ou inativo.
    """
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido ou expirado",
        headers={"WWW-Authenticate": "Bearer"},
    )

    try:
        payload = jwt.decode(
            credentials.credentials,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        user_id_str: str | None = payload.get("sub")
        if user_id_str is None:
            raise credentials_error
        user_id = UUID(user_id_str)
    except (JWTError, ValueError):
        raise credentials_error

    repo = UserRepository(session)
    user = await repo.get_by_id(user_id)
    if user is None:
        raise credentials_error

    return user
