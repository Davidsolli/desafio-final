"""Dependências de autenticação para injeção nas rotas FastAPI."""

from uuid import UUID

from fastapi import Depends, HTTPException, status, WebSocket
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

    # Validar token_version para detectar mudanças de senha
    token_version = payload.get("token_version", 0)
    if token_version != user.token_version:
        raise credentials_error

    return user

async def get_current_user_ws(
    websocket: WebSocket,
    session: AsyncSession,
) -> User | None:
    """Valida o token passado via query params e retorna o usuário."""
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None

    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        user_id_str: str | None = payload.get("sub")
        if user_id_str is None:
            await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
            return None
        user_id = UUID(user_id_str)
    except (JWTError, ValueError):
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None

    repo = UserRepository(session)
    user = await repo.get_by_id(user_id)
    if user is None:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return None

    return user


async def get_user_from_token(token: str, session: AsyncSession) -> User | None:
    """Decodifica JWT e retorna o usuário correspondente.

    Retorna None se token for inválido ou usuário não existir.
    """
    try:
        payload = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        user_id_str: str | None = payload.get("sub")
        if user_id_str is None:
            return None
        user_id = UUID(user_id_str)
    except (JWTError, ValueError):
        return None

    repo = UserRepository(session)
    user = await repo.get_by_id(user_id)
    return user
