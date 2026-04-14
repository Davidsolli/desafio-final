"""
Testes unitários para DTOs de usuário.

Testa validações de Pydantic para CreateUserDTO, UpdateUserDTO, UserResponseDTO.
"""

import pytest
from pydantic import ValidationError

from app.dtos.user_dto import (
    CreateUserDTO,
    UpdateUserDTO,
    UserResponseDTO,
)


class TestCreateUserDTO:
    """Testes de validação para CreateUserDTO."""

    def test_valid_dto(self):
        """Teste: DTO válido deve passar."""
        dto = CreateUserDTO(
            name="João Silva",
            email="joao@example.com",
            password="SenhaForte123!",
            role="client",
            phone_whatsapp="+55 11 99999-9999",
        )

        assert dto.name == "João Silva"
        assert dto.email == "joao@example.com"
        assert dto.role == "client"

    def test_invalid_email(self):
        """Teste: Email inválido deve falhar."""
        with pytest.raises(ValidationError) as exc_info:
            CreateUserDTO(
                name="João Silva",
                email="invalid-email",
                password="SenhaForte123!",
                role="client",
                phone_whatsapp="+55 11 99999-9999",
            )

        assert "email" in str(exc_info.value)

    def test_weak_password(self):
        """Teste: Senha fraca deve falhar."""
        with pytest.raises(ValidationError) as exc_info:
            CreateUserDTO(
                name="João Silva",
                email="joao@example.com",
                password="123",  # Muito fraca
                role="client",
                phone_whatsapp="+55 11 99999-9999",
            )

        assert "password" in str(exc_info.value)

    def test_password_no_uppercase(self):
        """Teste: Senha sem maiúscula."""
        with pytest.raises(ValidationError):
            CreateUserDTO(
                name="João Silva",
                email="joao@example.com",
                password="senhafraca123!",  # Sem maiúscula
                role="client",
                phone_whatsapp="+55 11 99999-9999",
            )

    def test_password_no_lowercase(self):
        """Teste: Senha sem minúscula."""
        with pytest.raises(ValidationError):
            CreateUserDTO(
                name="João Silva",
                email="joao@example.com",
                password="SENHAFRACA123!",  # Sem minúscula
                role="client",
                phone_whatsapp="+55 11 99999-9999",
            )

    def test_password_no_number(self):
        """Teste: Senha sem número."""
        with pytest.raises(ValidationError):
            CreateUserDTO(
                name="João Silva",
                email="joao@example.com",
                password="SenhaFracaBem!",  # Sem número
                role="client",
                phone_whatsapp="+55 11 99999-9999",
            )

    def test_password_no_special_char(self):
        """Teste: Senha sem caractere especial."""
        with pytest.raises(ValidationError):
            CreateUserDTO(
                name="João Silva",
                email="joao@example.com",
                password="SenhaFraca123",  # Sem caractere especial
                role="client",
                phone_whatsapp="+55 11 99999-9999",
            )

    def test_invalid_role(self):
        """Teste: Role inválido."""
        with pytest.raises(ValidationError) as exc_info:
            CreateUserDTO(
                name="João Silva",
                email="joao@example.com",
                password="SenhaForte123!",
                role="superadmin",  # Inválido
                phone_whatsapp="+55 11 99999-9999",
            )

        assert "role" in str(exc_info.value)

    def test_valid_roles(self):
        """Teste: Todos os roles válidos."""
        for role in ["admin", "personal_trainer", "client"]:
            dto = CreateUserDTO(
                name="João Silva",
                email=f"joao{role}@example.com",
                password="SenhaForte123!",
                role=role,
                phone_whatsapp="+55 11 99999-9999",
            )
            assert dto.role == role

    def test_invalid_phone(self):
        """Teste: Telefone em formato inválido."""
        with pytest.raises(ValidationError):
            CreateUserDTO(
                name="João Silva",
                email="joao@example.com",
                password="SenhaForte123!",
                role="client",
                phone_whatsapp="1199999999",  # Formato inválido
            )

    def test_name_too_short(self):
        """Teste: Nome muito curto."""
        with pytest.raises(ValidationError):
            CreateUserDTO(
                name="Jo",  # Menos de 3 caracteres
                email="joao@example.com",
                password="SenhaForte123!",
                role="client",
                phone_whatsapp="+55 11 99999-9999",
            )

    def test_name_too_long(self):
        """Teste: Nome muito longo."""
        with pytest.raises(ValidationError):
            CreateUserDTO(
                name="A" * 256,  # Mais de 255 caracteres
                email="joao@example.com",
                password="SenhaForte123!",
                role="client",
                phone_whatsapp="+55 11 99999-9999",
            )

    def test_name_with_numbers(self):
        """Teste: Nome com números."""
        with pytest.raises(ValidationError):
            CreateUserDTO(
                name="João Silva 123",
                email="joao@example.com",
                password="SenhaForte123!",
                role="client",
                phone_whatsapp="+55 11 99999-9999",
            )


class TestUpdateUserDTO:
    """Testes de validação para UpdateUserDTO."""

    def test_all_fields_optional(self):
        """Teste: Todos os campos são opcionais."""
        dto = UpdateUserDTO()
        assert dto.name is None
        assert dto.role is None
        assert dto.phone_whatsapp is None
        assert dto.is_active is None

    def test_partial_update(self):
        """Teste: Atualizar apenas alguns campos."""
        dto = UpdateUserDTO(
            name="Novo Nome",
            is_active=True,
        )

        assert dto.name == "Novo Nome"
        assert dto.role is None
        assert dto.phone_whatsapp is None
        assert dto.is_active is True

    def test_invalid_role_on_update(self):
        """Teste: Role inválido na atualização."""
        with pytest.raises(ValidationError):
            UpdateUserDTO(role="superadmin")

    def test_invalid_phone_on_update(self):
        """Teste: Telefone inválido na atualização."""
        with pytest.raises(ValidationError):
            UpdateUserDTO(phone_whatsapp="1199999999")

    def test_can_toggle_is_active(self):
        """Teste: Poder ativar/desativar usuário."""
        dto_inactive = UpdateUserDTO(is_active=False)
        assert dto_inactive.is_active is False

        dto_active = UpdateUserDTO(is_active=True)
        assert dto_active.is_active is True


class TestUserResponseDTO:
    """Testes para UserResponseDTO."""

    def test_response_from_user_model(self):
        """Teste: Criar DTO de resposta de modelo User."""
        from datetime import datetime
        from uuid import uuid4

        # Mock de um usuário
        user_data = {
            "id": uuid4(),
            "name": "João Silva",
            "email": "joao@example.com",
            "role": "client",
            "phone_whatsapp": "+55 11 99999-9999",
            "is_active": True,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
        }

        # Não temos a instância real do User, mas testamos que o DTO funciona
        # Este teste seria mais realista com um mock do User
        dto = UserResponseDTO(**user_data)

        assert dto.name == "João Silva"
        assert dto.email == "joao@example.com"
        assert "password" not in dto.model_dump()
