"""Rotas HTTP para autenticação.

Endpoints:
- POST /api/v1/auth/login → Autenticar e retornar token JWT
"""

from fastapi import APIRouter, HTTPException, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.auth_dto import LoginDTO, TokenResponseDTO
from app.controllers.auth_controller import AuthController
from app.services.auth_service import InvalidCredentialsError
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
    summary="Login e obter token JWT",
    responses={
        200: {"description": "Login bem-sucedido"},
        401: {"description": "Email ou senha incorretos"},
        422: {"description": "Validação falhou"},
    },
)
async def login(
    dto: LoginDTO,
    session: AsyncSession = Depends(get_db),
) -> TokenResponseDTO:
    """
    Autenticar usuário e retornar token JWT.

    **Request body:**
    - email: Email do usuário
    - password: Senha do usuário

    **Responses:**
    - 200: Token JWT retornado com sucesso
    - 401: Email ou senha incorretos
    - 422: Validação falhou (email inválido, senha ausente, etc)

    **Exemplo de uso:**
    ```
    curl -X POST http://localhost:8000/api/v1/auth/login \
      -H "Content-Type: application/json" \
      -d '{"email": "user@test.com", "password": "SenhaForte123!"}'
    ```

    **Retorno:**
    ```json
    {
        "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
        "token_type": "bearer",
        "expires_in": 86400
    }
    ```

    **Uso do Token:**
    ```
    curl -H "Authorization: Bearer {access_token}" \
      http://localhost:8000/api/v1/users
    ```
    """
    controller = AuthController(session)

    try:
        return await controller.login(dto)
    except InvalidCredentialsError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao fazer login",
        )
