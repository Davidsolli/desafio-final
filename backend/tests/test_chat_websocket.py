"""
Testes de integração para WebSocket do Chatbot.

Testes:
- Autenticação com token válido/inválido
- Envio de mensagens
- Timeout de inatividade
- Validação de tamanho de mensagem
"""

import json
import pytest
from typing import AsyncGenerator
from uuid import uuid4
from httpx import AsyncClient
from app.dependencies.auth import create_jwt_token


@pytest.fixture
async def valid_token(test_user_id: str = None) -> str:
    """Token JWT válido para testes."""
    user_id = test_user_id or str(uuid4())
    return create_jwt_token(user_id=user_id, expires_in_minutes=60)


@pytest.fixture
async def invalid_token() -> str:
    """Token JWT inválido."""
    return "invalid.token.here"


@pytest.mark.asyncio
async def test_websocket_auth_success(
    client: AsyncClient,
    valid_token: str,
):
    """Testa autenticação bem-sucedida via WebSocket."""
    async with client.websocket_connect('/api/v1/chat/ws') as websocket:
        # Envia autenticação
        await websocket.send_json({'type': 'auth', 'token': valid_token})

        # Aguarda resposta
        response = await websocket.receive_json()
        assert response['type'] == 'auth_success'
        assert 'Autenticado com sucesso' in response.get('message', '')


@pytest.mark.asyncio
async def test_websocket_auth_failure_invalid_token(
    client: AsyncClient,
    invalid_token: str,
):
    """Testa rejeição com token inválido."""
    async with client.websocket_connect('/api/v1/chat/ws') as websocket:
        # Envia token inválido
        await websocket.send_json({'type': 'auth', 'token': invalid_token})

        # Aguarda erro
        response = await websocket.receive_json()
        assert response['type'] == 'auth_error'
        assert 'Token inválido' in response.get('error', '')


@pytest.mark.asyncio
async def test_websocket_auth_failure_missing_token(
    client: AsyncClient,
):
    """Testa rejeição sem token."""
    async with client.websocket_connect('/api/v1/chat/ws') as websocket:
        # Envia auth sem token
        await websocket.send_json({'type': 'auth'})

        # Aguarda erro
        response = await websocket.receive_json()
        assert response['type'] == 'auth_error'
        assert 'Token JWT não fornecido' in response.get('error', '')


@pytest.mark.asyncio
async def test_websocket_auth_failure_wrong_first_message(
    client: AsyncClient,
    valid_token: str,
):
    """Testa rejeição se primeira mensagem não for auth."""
    async with client.websocket_connect('/api/v1/chat/ws') as websocket:
        # Envia message sem antes autenticar
        await websocket.send_json({'type': 'message', 'content': 'Olá'})

        # Aguarda erro
        response = await websocket.receive_json()
        assert response['type'] == 'auth_error'
        assert 'type' in response.get('error', '').lower() or 'autenticação' in response.get('error', '').lower()


@pytest.mark.asyncio
async def test_websocket_message_empty(
    client: AsyncClient,
    valid_token: str,
):
    """Testa rejeição de mensagem vazia."""
    async with client.websocket_connect('/api/v1/chat/ws') as websocket:
        # Autentica
        await websocket.send_json({'type': 'auth', 'token': valid_token})
        await websocket.receive_json()  # auth_success

        # Envia mensagem vazia
        await websocket.send_json({'type': 'message', 'content': ''})

        # Aguarda erro
        response = await websocket.receive_json()
        assert response['type'] == 'error'
        assert 'vazia' in response.get('error', '').lower()


@pytest.mark.asyncio
async def test_websocket_message_too_long(
    client: AsyncClient,
    valid_token: str,
):
    """Testa rejeição de mensagem muito longa."""
    async with client.websocket_connect('/api/v1/chat/ws') as websocket:
        # Autentica
        await websocket.send_json({'type': 'auth', 'token': valid_token})
        await websocket.receive_json()  # auth_success

        # Envia mensagem > 1000 chars
        long_message = 'a' * 1001
        await websocket.send_json({'type': 'message', 'content': long_message})

        # Aguarda erro
        response = await websocket.receive_json()
        assert response['type'] == 'error'
        assert 'longa' in response.get('error', '').lower()


@pytest.mark.asyncio
async def test_websocket_message_max_length_ok(
    client: AsyncClient,
    valid_token: str,
):
    """Testa que mensagem no limite (1000 chars) é aceita."""
    async with client.websocket_connect('/api/v1/chat/ws') as websocket:
        # Autentica
        await websocket.send_json({'type': 'auth', 'token': valid_token})
        await websocket.receive_json()  # auth_success

        # Envia mensagem com 1000 chars (limite)
        message_1000 = 'a' * 1000
        await websocket.send_json({'type': 'message', 'content': message_1000})

        # Deve processar (ou retornar resposta, não erro de tamanho)
        response = await websocket.receive_json()
        # Pode ser erro de outro tipo (ex: RAG vazio) mas não de tamanho
        if response['type'] == 'error':
            assert 'longa' not in response.get('error', '').lower()


@pytest.mark.asyncio
async def test_websocket_unknown_message_type(
    client: AsyncClient,
    valid_token: str,
):
    """Testa rejeição de tipo de mensagem desconhecido."""
    async with client.websocket_connect('/api/v1/chat/ws') as websocket:
        # Autentica
        await websocket.send_json({'type': 'auth', 'token': valid_token})
        await websocket.receive_json()  # auth_success

        # Envia tipo desconhecido
        await websocket.send_json({'type': 'unknown', 'data': 'test'})

        # Aguarda erro
        response = await websocket.receive_json()
        assert response['type'] == 'error'
        assert 'desconhecido' in response.get('error', '').lower()


@pytest.mark.asyncio
async def test_websocket_invalid_conversation_id(
    client: AsyncClient,
    valid_token: str,
):
    """Testa rejeição de conversation_id em formato inválido."""
    async with client.websocket_connect('/api/v1/chat/ws') as websocket:
        # Autentica
        await websocket.send_json({'type': 'auth', 'token': valid_token})
        await websocket.receive_json()  # auth_success

        # Envia mensagem com conversation_id inválido
        await websocket.send_json({
            'type': 'message',
            'content': 'Olá',
            'conversation_id': 'not-a-uuid',
        })

        # Aguarda erro
        response = await websocket.receive_json()
        assert response['type'] == 'error'
        assert 'conversation_id' in response.get('error', '').lower() or 'inválido' in response.get('error', '').lower()
