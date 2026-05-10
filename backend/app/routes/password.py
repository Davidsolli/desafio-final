"""Rotas HTTP para recuperação de senha.

Endpoints:
- POST /api/v1/auth/forgot-password → Solicitar link de recuperação
- POST /api/v1/auth/reset-password  → Redefinir senha com token
"""

from fastapi import APIRouter, Depends, HTTPException, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.controllers.password_controller import PasswordController
from app.dtos.password_dto import ForgotPasswordDTO, MessageResponseDTO, ResetPasswordDTO
from app.services.password_service import (
    InvalidTokenError,
    PasswordMismatchError,
    WeakPasswordError,
)

limiter = Limiter(key_func=get_remote_address)

router = APIRouter(
    prefix="/api/v1/auth",
    tags=["recuperação de senha"],
)


@router.post(
    "/forgot-password",
    response_model=MessageResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Solicitar recuperação de senha",
    responses={
        200: {"description": "Instruções enviadas (mesmo para emails inexistentes)"},
        429: {"description": "Muitas tentativas — tente novamente mais tarde"},
    },
)
@limiter.limit("5/hour")
async def forgot_password(
    request: Request,
    dto: ForgotPasswordDTO,
    session: AsyncSession = Depends(get_db),
) -> MessageResponseDTO:
    """
    Solicita o envio de link de recuperação de senha por email.

    Retorna **sempre** HTTP 200 para evitar enumeração de emails cadastrados.
    """
    controller = PasswordController(session)
    return await controller.forgot_password(dto)


@router.post(
    "/reset-password",
    response_model=MessageResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Redefinir senha com token",
    responses={
        200: {"description": "Senha redefinida com sucesso"},
        400: {"description": "Token inválido / expirado / senhas não conferem / senha fraca"},
        429: {"description": "Muitas tentativas — tente novamente mais tarde"},
    },
)
@limiter.limit("10/hour")
async def reset_password(
    request: Request,
    dto: ResetPasswordDTO,
    session: AsyncSession = Depends(get_db),
) -> MessageResponseDTO:
    """Redefine a senha usando o token recebido por email."""
    controller = PasswordController(session)
    try:
        return await controller.reset_password(dto)
    except PasswordMismatchError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except WeakPasswordError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except InvalidTokenError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
