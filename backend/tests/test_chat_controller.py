"""
Testes do ChatController (Tarefa 3 do PRD_CHATBOT_REFACTOR_ETAPA1).

A arquitetura em camadas exige um controller entre routes e services.
Atualmente, routes/chat.py instancia ChatService diretamente — isto deve mudar.
"""

from __future__ import annotations

import inspect
from importlib import import_module
from unittest.mock import AsyncMock
from uuid import uuid4

import pytest


class TestChatControllerExistsAndContract:
    """ChatController deve existir e expor os métodos esperados."""

    def test_chat_controller_module_exists(self):
        try:
            mod = import_module("app.controllers.chat_controller")
        except ModuleNotFoundError as exc:
            pytest.fail(f"Módulo app.controllers.chat_controller não encontrado: {exc}")

        assert hasattr(mod, "ChatController"), "Classe ChatController deve estar exportada"

    def test_chat_controller_has_send_message(self):
        from app.controllers.chat_controller import ChatController

        assert hasattr(ChatController, "send_message")

    def test_chat_controller_has_list_conversations(self):
        from app.controllers.chat_controller import ChatController

        assert hasattr(ChatController, "list_conversations")

    def test_chat_controller_has_get_conversation(self):
        from app.controllers.chat_controller import ChatController

        assert hasattr(ChatController, "get_conversation")

    def test_chat_controller_has_rate_conversation(self):
        from app.controllers.chat_controller import ChatController

        assert hasattr(ChatController, "rate_conversation")


class TestChatControllerDelegatesToService:
    """O controller deve apenas orquestrar — toda lógica de negócio fica no service."""

    @pytest.mark.asyncio
    async def test_send_message_delegates_to_service(self):
        from app.controllers.chat_controller import ChatController

        fake_service = AsyncMock()
        fake_service.send_message = AsyncMock(return_value={"content": "ok"})

        controller = ChatController(fake_service)
        result = await controller.send_message(
            user_id=uuid4(),
            message="Como faço supino?",
            conversation_id=None,
        )

        assert result == {"content": "ok"}
        fake_service.send_message.assert_awaited_once()


class TestRouteUsesController:
    """A camada de routes deve delegar ao controller (não chamar service direto)."""

    def test_route_module_imports_chat_controller(self):
        from app.routes import chat as chat_route

        source = inspect.getsource(chat_route)
        assert "ChatController" in source or "chat_controller" in source, (
            "routes/chat.py deve importar ChatController para seguir a arquitetura"
        )
