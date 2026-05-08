"""
Rotas HTTP para recuperação e redefinição de senha.

Endpoints:
- POST /api/v1/auth/forgot-password → Iniciar recuperação
- POST /api/v1/auth/reset-password → Redefinir com token
"""

from fastapi import APIRouter, HTTPException, Depends, status, Request
from sqlalchemy.ext.asyncio import AsyncSession
from slowapi import Limiter
from slowapi.util import get_remote_address

from app.dtos.password_dto import (
    ForgotPasswordDTO,
    ResetPasswordDTO,
    ChangePasswordDTO,
    PasswordResponseDTO,
)
from app.controllers.password_controller import PasswordController
from app.services.password_service import (
    PasswordValidationError,
    PasswordMismatchError,
    InvalidTokenError,
)
from app.config.database import get_db

router = APIRouter(
    prefix="/api/v1/auth",
    tags=["password"],
    responses={
        400: {"description": "Validação falhou"},
        500: {"description": "Erro interno do servidor"},
    },
)

limiter = Limiter(key_func=get_remote_address)


@router.post(
    "/forgot-password",
    response_model=PasswordResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Iniciar recuperação de senha",
    responses={
        200: {"description": "Requisição processada (sem indicar se email existe)"},
        422: {"description": "Email inválido"},
    },
)
@limiter.limit("5/hour")
async def forgot_password(
    dto: ForgotPasswordDTO,
    request: Request,
    session: AsyncSession = Depends(get_db),
) -> PasswordResponseDTO:
    """
    Iniciar processo de recuperação de senha.

    **Segurança:**
    - Sempre retorna HTTP 200 (mesmo que email não exista)
    - Previne enumeração de emails
    - Rate limit: 5 requisições/hora por IP

    **Request body:**
    - email: Email válido do usuário

    **Response:**
    - message: Mensagem genérica de sucesso
    """
    controller = PasswordController(session)

    try:
        return await controller.forgot_password(dto)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao processar requisição",
        )


@router.post(
    "/reset-password",
    response_model=PasswordResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Redefinir senha com token",
    responses={
        200: {"description": "Senha redefinida com sucesso"},
        400: {"description": "Token inválido, expirado ou senha inválida"},
        422: {"description": "Validação falhou"},
    },
)
@limiter.limit("10/hour")
async def reset_password(
    dto: ResetPasswordDTO,
    request: Request,
    session: AsyncSession = Depends(get_db),
) -> PasswordResponseDTO:
    """
    Redefinir senha usando token temporário.

    **Segurança:**
    - Token deve ser válido, não expirado e não previamente usado
    - Senha deve atender requisitos de força
    - Rate limit: 10 requisições/hora por IP

    **Request body:**
    - token: Token enviado por email
    - new_password: Nova senha forte
    - confirm_password: Confirmação da nova senha

    **Response:**
    - message: Confirmação de sucesso

    **Errors:**
    - 400: Token inválido/expirado, senhas não conferem, senha fraca
    """
    controller = PasswordController(session)

    try:
        return await controller.reset_password(dto)
    except PasswordMismatchError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except PasswordValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao redefinir senha",
        )
