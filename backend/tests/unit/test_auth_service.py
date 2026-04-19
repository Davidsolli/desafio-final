"""Testes unitários para o serviço de autenticação."""

import pytest
from jose import jwt
from sqlalchemy.ext.asyncio import AsyncSession
from unittest.mock import AsyncMock, MagicMock, patch

from app.config.settings import settings
from app.services.auth_service import AuthService, InvalidCredentialsError
from app.dtos.auth_dto import LoginDTO


class TestAuthServiceCreateAccessToken:
    """Testes para criação de tokens JWT."""

    def test_create_access_token_success(self):
        """Teste: Token é criado e decodificável."""
        data = {"sub": "user-123"}
        token = AuthService.create_access_token(data)

        assert token is not None
        assert isinstance(token, str)
        assert token.count(".") == 2  # JWT tem 3 partes separadas por ponto

        # Decodificar e validar
        decoded = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        assert decoded["sub"] == "user-123"
        assert "exp" in decoded

    def test_create_access_token_includes_expiration(self):
        """Teste: Token inclui campo de expiração."""
        data = {"sub": "user-456"}
        token = AuthService.create_access_token(data)

        decoded = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        assert "exp" in decoded
        assert isinstance(decoded["exp"], (int, float))

    def test_create_access_token_respects_settings(self):
        """Teste: Token usa configurações corretas (SECRET_KEY, ALGORITHM)."""
        data = {"sub": "user-789"}
        token = AuthService.create_access_token(data)

        # Tentar decodificar com SECRET_KEY correto — deve suceder
        decoded = jwt.decode(
            token,
            settings.SECRET_KEY,
            algorithms=[settings.ALGORITHM],
        )
        assert decoded["sub"] == "user-789"

        # Tentar com SECRET_KEY errada — deve falhar
        with pytest.raises(Exception):  # JWTError
            jwt.decode(
                token,
                "chave-invalida",
                algorithms=[settings.ALGORITHM],
            )


@pytest.mark.asyncio
class TestAuthServiceLogin:
    """Testes para método de login."""

    async def test_login_with_valid_credentials(self):
        """Teste: Login com credenciais válidas retorna token."""
        from app.models.user import User
        from app.repositories.user_repository import UserRepository
        from app.services.user_service import UserService
        from uuid import uuid4

        # Mock do usuário
        mock_user = MagicMock(spec=User)
        mock_user.id = uuid4()
        mock_user.email = "test@example.com"
        mock_user.password = UserService.hash_password("SenhaForte123!")

        # Mock da sessão e repositório
        mock_session = AsyncMock(spec=AsyncSession)
        mock_repo = AsyncMock(spec="UserRepository")
        mock_repo.get_by_email = AsyncMock(return_value=mock_user)

        service = AuthService(mock_session)
        service.repository = mock_repo

        # Fazer login
        dto = LoginDTO(email="test@example.com", password="SenhaForte123!")
        result = await service.login(dto)

        assert result.access_token is not None
        assert result.token_type == "bearer"
        assert result.expires_in > 0

    async def test_login_with_invalid_email(self):
        """Teste: Login com email não existente lança InvalidCredentialsError."""
        mock_session = AsyncMock(spec=AsyncSession)
        mock_repo = AsyncMock(spec="UserRepository")
        mock_repo.get_by_email = AsyncMock(return_value=None)

        service = AuthService(mock_session)
        service.repository = mock_repo

        dto = LoginDTO(email="naoexiste@example.com", password="SenhaForte123!")

        with pytest.raises(InvalidCredentialsError):
            await service.login(dto)

    async def test_login_with_invalid_password(self):
        """Teste: Login com senha incorreta lança InvalidCredentialsError."""
        from app.models.user import User
        from app.services.user_service import UserService
        from uuid import uuid4

        mock_user = MagicMock(spec=User)
        mock_user.id = uuid4()
        mock_user.email = "test@example.com"
        mock_user.password = UserService.hash_password("SenhaCorreta123!")

        mock_session = AsyncMock(spec=AsyncSession)
        mock_repo = AsyncMock(spec="UserRepository")
        mock_repo.get_by_email = AsyncMock(return_value=mock_user)

        service = AuthService(mock_session)
        service.repository = mock_repo

        dto = LoginDTO(email="test@example.com", password="SenhaErrada123!")

        with pytest.raises(InvalidCredentialsError):
            await service.login(dto)

    async def test_login_error_message_is_vague(self):
        """Teste: Mensagem de erro é igual para email inválido/senha errada."""
        from app.models.user import User
        from app.services.user_service import UserService
        from uuid import uuid4

        # Erro 1: email não existe
        mock_session1 = AsyncMock(spec=AsyncSession)
        mock_repo1 = AsyncMock(spec="UserRepository")
        mock_repo1.get_by_email = AsyncMock(return_value=None)

        service1 = AuthService(mock_session1)
        service1.repository = mock_repo1

        dto1 = LoginDTO(email="naoexiste@example.com", password="SenhaForte123!")

        with pytest.raises(InvalidCredentialsError) as exc_info1:
            await service1.login(dto1)
        msg1 = str(exc_info1.value)

        # Erro 2: senha errada
        mock_user = MagicMock(spec=User)
        mock_user.id = uuid4()
        mock_user.email = "test@example.com"
        mock_user.password = UserService.hash_password("SenhaCorreta123!")

        mock_session2 = AsyncMock(spec=AsyncSession)
        mock_repo2 = AsyncMock(spec="UserRepository")
        mock_repo2.get_by_email = AsyncMock(return_value=mock_user)

        service2 = AuthService(mock_session2)
        service2.repository = mock_repo2

        dto2 = LoginDTO(email="test@example.com", password="SenhaErrada123!")

        with pytest.raises(InvalidCredentialsError) as exc_info2:
            await service2.login(dto2)
        msg2 = str(exc_info2.value)

        # Ambas mensagens devem ser iguais
        assert msg1 == msg2
