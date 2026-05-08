"""
Testes para funcionalidade de preferência de tema (theme_preference).
"""

import pytest
from pydantic import ValidationError

from app.dtos.user_dto import UpdateUserDTO, UpdateThemePreferenceDTO


class TestThemePreferenceValidation:
    """Testes para validação de theme_preference nos DTOs."""

    def test_update_user_dto_theme_preference_valid_light(self):
        """Validar tema 'light' em UpdateUserDTO."""
        dto = UpdateUserDTO(theme_preference="light")
        assert dto.theme_preference == "light"

    def test_update_user_dto_theme_preference_valid_dark(self):
        """Validar tema 'dark' em UpdateUserDTO."""
        dto = UpdateUserDTO(theme_preference="dark")
        assert dto.theme_preference == "dark"

    def test_update_user_dto_theme_preference_valid_system(self):
        """Validar tema 'system' em UpdateUserDTO."""
        dto = UpdateUserDTO(theme_preference="system")
        assert dto.theme_preference == "system"

    def test_update_user_dto_theme_preference_none(self):
        """Validar theme_preference None em UpdateUserDTO (permitido)."""
        dto = UpdateUserDTO(theme_preference=None)
        assert dto.theme_preference is None

    def test_update_user_dto_theme_preference_invalid(self):
        """Rejeitar tema inválido em UpdateUserDTO."""
        with pytest.raises(ValidationError) as exc_info:
            UpdateUserDTO(theme_preference="invalid_theme")
        assert "Tema deve ser um de:" in str(exc_info.value)

    def test_update_theme_preference_dto_valid_light(self):
        """Validar tema 'light' em UpdateThemePreferenceDTO."""
        dto = UpdateThemePreferenceDTO(theme_preference="light")
        assert dto.theme_preference == "light"

    def test_update_theme_preference_dto_valid_dark(self):
        """Validar tema 'dark' em UpdateThemePreferenceDTO."""
        dto = UpdateThemePreferenceDTO(theme_preference="dark")
        assert dto.theme_preference == "dark"

    def test_update_theme_preference_dto_valid_system(self):
        """Validar tema 'system' em UpdateThemePreferenceDTO."""
        dto = UpdateThemePreferenceDTO(theme_preference="system")
        assert dto.theme_preference == "system"

    def test_update_theme_preference_dto_invalid(self):
        """Rejeitar tema inválido em UpdateThemePreferenceDTO."""
        with pytest.raises(ValidationError) as exc_info:
            UpdateThemePreferenceDTO(theme_preference="invalid_theme")
        assert "Tema deve ser um de:" in str(exc_info.value)

    def test_update_theme_preference_dto_none_rejected(self):
        """Rejeitar theme_preference None em UpdateThemePreferenceDTO (obrigatório)."""
        with pytest.raises(ValidationError) as exc_info:
            UpdateThemePreferenceDTO(theme_preference=None)
        # UpdateThemePreferenceDTO não permite None porque é obrigatório


class TestThemePreferenceIntegration:
    """Testes de integração para theme_preference (requerem DB)."""

    @pytest.mark.asyncio
    async def test_update_theme_preference_endpoint_valid(self, auth_client):
        """Testar PUT /users/me/theme-preference com tema válido."""
        response = await auth_client.put(
            "/api/v1/users/me/theme-preference",
            json={"theme_preference": "dark"},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["theme_preference"] == "dark"

    @pytest.mark.asyncio
    async def test_update_theme_preference_endpoint_all_valid_themes(self, auth_client):
        """Testar PUT /users/me/theme-preference com todos os temas válidos."""
        for theme in ["light", "dark", "system"]:
            response = await auth_client.put(
                "/api/v1/users/me/theme-preference",
                json={"theme_preference": theme},
            )
            assert response.status_code == 200
            data = response.json()
            assert data["theme_preference"] == theme

    @pytest.mark.asyncio
    async def test_update_theme_preference_endpoint_invalid_theme(self, auth_client):
        """Testar PUT /users/me/theme-preference com tema inválido."""
        response = await auth_client.put(
            "/api/v1/users/me/theme-preference",
            json={"theme_preference": "invalid"},
        )
        assert response.status_code == 422  # Validation error

    @pytest.mark.asyncio
    async def test_update_theme_preference_endpoint_unauthenticated(self, async_client):
        """Testar PUT /users/me/theme-preference sem autenticação."""
        response = await async_client.put(
            "/api/v1/users/me/theme-preference",
            json={"theme_preference": "dark"},
        )
        assert response.status_code == 401  # Unauthorized
