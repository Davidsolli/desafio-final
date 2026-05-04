"""Rotas HTTP para autenticação.

Endpoints:
- POST /api/v1/auth/login   → Autenticar e retornar access + refresh tokens (RNF-05)
- POST /api/v1/auth/refresh → Renovar access token com refresh token
"""

from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.auth_dto import LoginDTO, RefreshTokenDTO, TokenResponseDTO
from app.controllers.auth_controller import AuthController
from app.services.auth_service import InvalidCredentialsError, InvalidRefreshTokenError
from app.config.database import get_db

router = APIRouter(
    prefix="/api/v1/auth",
    tags=["auth"],
    responses={
        401: {"description": "Credenciais inválidas"},
        500: {"description": "Erro interno do servidor"},
    },
)


@router.post(
    "/login",
    response_model=TokenResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Login — retorna access_token (24h) e refresh_token (30d)",
)
async def login(
    dto: LoginDTO,
    session: AsyncSession = Depends(get_db),
) -> TokenResponseDTO:
    """Autenticar usuário e retornar access + refresh tokens (RNF-05)."""
    controller = AuthController(session)
    try:
        return await controller.login(dto)
    except InvalidCredentialsError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao fazer login",
        )


@router.post(
    "/refresh",
    response_model=TokenResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Renovar access token usando refresh token (RNF-05)",
)
async def refresh_token(
    dto: RefreshTokenDTO,
    session: AsyncSession = Depends(get_db),
) -> TokenResponseDTO:
    """
    Renovar access token usando o refresh_token recebido no login.

    O refresh_token tem validade de 30 dias.
    Retorna um novo par access_token + refresh_token (rotação de refresh).
    """
    from app.services.auth_service import AuthService

    service = AuthService(session)
    try:
        return await service.refresh(dto)
    except InvalidRefreshTokenError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao renovar token",
        )
