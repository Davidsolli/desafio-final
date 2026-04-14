"""
Testes unitários para UserService.

Testa lógica de negócio: hash de senha, validação, operações CRUD.
"""

import pytest

from app.services.user_service import UserService, UserAlreadyExistsError, UserNotFoundError
from app.dtos.user_dto import CreateUserDTO, UpdateUserDTO


class TestUserServicePasswordHashing:
    """Testes de hash de senha."""

    def test_hash_password_creates_hash(self):
        """Teste: Hash de senha não é igual ao texto plano."""
        password = "SenhaForte123!"
        hashed = UserService.hash_password(password)

        assert hashed != password
        assert len(hashed) > len(password)

    def test_hash_password_consistent(self):
        """Teste: Hash é consistente para mesma senha."""
        password = "SenhaForte123!"
        hash1 = UserService.hash_password(password)
        hash2 = UserService.hash_password(password)

        # Os hashes são diferentes (salt aleatório), mas ambos verificam
        assert hash1 != hash2
        assert UserService.verify_password(password, hash1)
        assert UserService.verify_password(password, hash2)

    def test_verify_password_correct(self):
        """Teste: Verificar senha correta."""
        password = "SenhaForte123!"
        hashed = UserService.hash_password(password)

        assert UserService.verify_password(password, hashed) is True

    def test_verify_password_incorrect(self):
        """Teste: Verificar senha incorreta."""
        password = "SenhaForte123!"
        wrong_password = "OutraSenha456!"
        hashed = UserService.hash_password(password)

        assert UserService.verify_password(wrong_password, hashed) is False

    def test_hash_uses_bcrypt(self):
        """Teste: Hash começa com $2b$ (prefixo bcrypt)."""
        password = "SenhaForte123!"
        hashed = UserService.hash_password(password)

        # bcrypt começa com $2b$ ou $2a$ ou $2x$ ou $2y$
        assert hashed.startswith(("$2a$", "$2b$", "$2x$", "$2y$"))


class TestUserServiceCreate:
    """Testes de criação de usuário."""

    @pytest.mark.asyncio
    async def test_create_user_success(self, test_db_session, sample_user_data):
        """Teste: Criar usuário com sucesso."""
        service = UserService(test_db_session)
        dto = CreateUserDTO(**sample_user_data)

        user = await service.create(dto)

        assert user.id is not None
        assert user.name == sample_user_data["name"]
        assert user.email == sample_user_data["email"]
        assert user.role == sample_user_data["role"]
        assert "password" not in user.model_dump()

    @pytest.mark.asyncio
    async def test_create_user_password_hashed(self, test_db_session, sample_user_data):
        """Teste: Senha deve estar hasheada no banco."""
        service = UserService(test_db_session)
        dto = CreateUserDTO(**sample_user_data)

        user_response = await service.create(dto)

        # Buscar direto do banco para verificar que senha está hasheada
        from app.models.user import User

        user_in_db = await test_db_session.get(User, user_response.id)

        # A senha armazenada não deve ser igual à senha original
        assert user_in_db.password != sample_user_data["password"]
        assert user_in_db.password.startswith(("$2a$", "$2b$"))

    @pytest.mark.asyncio
    async def test_create_user_duplicate_email(self, test_db_session, sample_user_data):
        """Teste: Não permitir email duplicado."""
        service = UserService(test_db_session)
        dto1 = CreateUserDTO(**sample_user_data)

        # Criar primeiro usuário
        await service.create(dto1)

        # Tentar criar segundo com mesmo email
        dto2 = CreateUserDTO(**sample_user_data)

        with pytest.raises(UserAlreadyExistsError):
            await service.create(dto2)

    @pytest.mark.asyncio
    async def test_create_user_is_active_by_default(self, test_db_session, sample_user_data):
        """Teste: Usuário criado deve estar ativo por padrão."""
        service = UserService(test_db_session)
        dto = CreateUserDTO(**sample_user_data)

        user = await service.create(dto)

        assert user.is_active is True


class TestUserServiceRead:
    """Testes de leitura de usuário."""

    @pytest.mark.asyncio
    async def test_get_by_id_success(self, test_db_session, sample_user):
        """Teste: Buscar usuário por ID."""
        service = UserService(test_db_session)

        user = await service.get_by_id(sample_user.id)

        assert user.id == sample_user.id
        assert user.email == sample_user.email

    @pytest.mark.asyncio
    async def test_get_by_id_not_found(self, test_db_session):
        """Teste: Usuário não encontrado."""
        from uuid import uuid4

        service = UserService(test_db_session)
        fake_id = uuid4()

        with pytest.raises(UserNotFoundError):
            await service.get_by_id(fake_id)

    @pytest.mark.asyncio
    async def test_get_by_email_success(self, test_db_session, sample_user, sample_user_data):
        """Teste: Buscar usuário por email."""
        service = UserService(test_db_session)

        user = await service.get_by_email(sample_user_data["email"])

        assert user is not None
        assert user.email == sample_user_data["email"]

    @pytest.mark.asyncio
    async def test_get_by_email_not_found(self, test_db_session):
        """Teste: Email não encontrado."""
        service = UserService(test_db_session)

        user = await service.get_by_email("nonexistent@example.com")

        assert user is None


class TestUserServiceUpdate:
    """Testes de atualização de usuário."""

    @pytest.mark.asyncio
    async def test_update_user_success(self, test_db_session, sample_user, sample_user_data):
        """Teste: Atualizar usuário."""
        service = UserService(test_db_session)
        dto = UpdateUserDTO(name="Novo Nome")

        updated_user = await service.update(sample_user.id, dto)

        assert updated_user.name == "Novo Nome"
        assert updated_user.email == sample_user_data["email"]

    @pytest.mark.asyncio
    async def test_update_user_not_found(self, test_db_session):
        """Teste: Atualizar usuário inexistente."""
        from uuid import uuid4

        service = UserService(test_db_session)
        fake_id = uuid4()
        dto = UpdateUserDTO(name="Novo Nome")

        with pytest.raises(UserNotFoundError):
            await service.update(fake_id, dto)

    @pytest.mark.asyncio
    async def test_update_user_partial(self, test_db_session, sample_user, sample_user_data):
        """Teste: Atualização parcial (não altera campos não fornecidos)."""
        service = UserService(test_db_session)
        dto = UpdateUserDTO(name="Novo Nome", is_active=False)

        updated_user = await service.update(sample_user.id, dto)

        assert updated_user.name == "Novo Nome"
        assert updated_user.is_active is False
        assert updated_user.email == sample_user_data["email"]
        assert updated_user.role == sample_user_data["role"]


class TestUserServiceDelete:
    """Testes de deleção de usuário."""

    @pytest.mark.asyncio
    async def test_delete_user_success(self, test_db_session, sample_user):
        """Teste: Deletar usuário (soft delete)."""
        service = UserService(test_db_session)

        result = await service.delete(sample_user.id)

        assert result is True

        # Verificar que usuário não pode ser encontrado
        with pytest.raises(UserNotFoundError):
            await service.get_by_id(sample_user.id)

    @pytest.mark.asyncio
    async def test_delete_user_not_found(self, test_db_session):
        """Teste: Deletar usuário inexistente."""
        from uuid import uuid4

        service = UserService(test_db_session)
        fake_id = uuid4()

        with pytest.raises(UserNotFoundError):
            await service.delete(fake_id)

    @pytest.mark.asyncio
    async def test_soft_delete_marks_as_inactive(self, test_db_session, sample_user):
        """Teste: Soft delete marca como inativo, não remove do banco."""
        from app.models.user import User

        service = UserService(test_db_session)

        await service.delete(sample_user.id)

        # Buscar direto do banco
        user_in_db = await test_db_session.get(User, sample_user.id)

        # Deve estar no banco mas inativo
        assert user_in_db is not None
        assert user_in_db.is_active is False
