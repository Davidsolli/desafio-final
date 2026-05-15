"""
Testes de integração para o módulo de webhooks WhatsApp.
"""

import hmac
import hashlib
import json
import pytest


VALID_WHATSAPP_PAYLOAD = {
    "object": "whatsapp_business_account",
    "entry": [
        {
            "id": "123456789",
            "changes": [
                {
                    "value": {
                        "messaging_product": "whatsapp",
                        "metadata": {"display_phone_number": "15550001234", "phone_number_id": "987654321"},
                        "messages": [
                            {
                                "from": "5511999999999",
                                "id": "wamid.test123",
                                "type": "text",
                                "text": {"body": "Oi, quero me cadastrar!"},
                            }
                        ],
                    },
                    "field": "messages",
                }
            ],
        }
    ],
}


class TestVerifyWebhook:
    """Testes do GET /api/v1/webhooks/whatsapp (handshake Meta)."""

    @pytest.mark.asyncio
    async def test_handshake_valido_retorna_challenge_plain_text(self, async_client, monkeypatch):
        """Token correto → retorna hub.challenge como plain text."""
        monkeypatch.setenv("WHATSAPP_VERIFY_TOKEN", "meu_token_secreto")

        response = await async_client.get(
            "/api/v1/webhooks/whatsapp",
            params={
                "hub.mode": "subscribe",
                "hub.challenge": "123456789",
                "hub.verify_token": "meu_token_secreto",
            },
        )

        assert response.status_code == 200
        assert response.text == "123456789"
        assert "application/json" not in response.headers.get("content-type", "")

    @pytest.mark.asyncio
    async def test_handshake_token_invalido_retorna_403(self, async_client, monkeypatch):
        """Token errado → 403."""
        monkeypatch.setenv("WHATSAPP_VERIFY_TOKEN", "meu_token_secreto")

        response = await async_client.get(
            "/api/v1/webhooks/whatsapp",
            params={
                "hub.mode": "subscribe",
                "hub.challenge": "123456789",
                "hub.verify_token": "token_errado",
            },
        )

        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_handshake_modo_invalido_retorna_403(self, async_client, monkeypatch):
        """hub.mode diferente de 'subscribe' → 403."""
        monkeypatch.setenv("WHATSAPP_VERIFY_TOKEN", "meu_token_secreto")

        response = await async_client.get(
            "/api/v1/webhooks/whatsapp",
            params={
                "hub.mode": "unsubscribe",
                "hub.challenge": "123456789",
                "hub.verify_token": "meu_token_secreto",
            },
        )

        assert response.status_code == 403


class TestReceiveWebhook:
    """Testes do POST /api/v1/webhooks/whatsapp."""

    @pytest.mark.asyncio
    async def test_payload_valido_retorna_ok(self, async_client, monkeypatch):
        """Payload válido sem APP_SECRET configurado → {"status": "ok"}."""
        monkeypatch.delenv("WHATSAPP_APP_SECRET", raising=False)

        response = await async_client.post(
            "/api/v1/webhooks/whatsapp",
            json=VALID_WHATSAPP_PAYLOAD,
        )

        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

    @pytest.mark.asyncio
    async def test_entry_vazia_retorna_ok(self, async_client, monkeypatch):
        """Payload sem entries → {"status": "ok"} sem erros."""
        monkeypatch.delenv("WHATSAPP_APP_SECRET", raising=False)

        response = await async_client.post(
            "/api/v1/webhooks/whatsapp",
            json={"object": "whatsapp_business_account", "entry": []},
        )

        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

    @pytest.mark.asyncio
    async def test_sem_mensagens_retorna_ok(self, async_client, monkeypatch):
        """Webhook de notificação sem messages (ex. status read) → {"status": "ok"}."""
        monkeypatch.delenv("WHATSAPP_APP_SECRET", raising=False)

        payload = {
            "object": "whatsapp_business_account",
            "entry": [
                {
                    "id": "123",
                    "changes": [{"value": {"messages": []}, "field": "messages"}],
                }
            ],
        }

        response = await async_client.post(
            "/api/v1/webhooks/whatsapp",
            json=payload,
        )

        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

    @pytest.mark.asyncio
    async def test_assinatura_invalida_retorna_403(self, async_client, monkeypatch):
        """APP_SECRET configurado e assinatura errada → 403."""
        monkeypatch.setenv("WHATSAPP_APP_SECRET", "segredo_real")

        response = await async_client.post(
            "/api/v1/webhooks/whatsapp",
            json=VALID_WHATSAPP_PAYLOAD,
            headers={"X-Hub-Signature-256": "sha256=assinatura_invalida"},
        )

        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_assinatura_valida_aceita(self, async_client, monkeypatch):
        """APP_SECRET configurado e assinatura correta → {"status": "ok"}."""
        secret = "segredo_real"
        monkeypatch.setenv("WHATSAPP_APP_SECRET", secret)

        body = json.dumps(VALID_WHATSAPP_PAYLOAD).encode()
        signature = "sha256=" + hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()

        response = await async_client.post(
            "/api/v1/webhooks/whatsapp",
            content=body,
            headers={
                "Content-Type": "application/json",
                "X-Hub-Signature-256": signature,
            },
        )

        assert response.status_code == 200
        assert response.json() == {"status": "ok"}

    @pytest.mark.asyncio
    async def test_multiplas_mensagens_processadas(self, async_client, monkeypatch):
        """Payload com múltiplas mensagens → todas processadas sem erro."""
        monkeypatch.delenv("WHATSAPP_APP_SECRET", raising=False)

        payload = {
            "object": "whatsapp_business_account",
            "entry": [
                {
                    "id": "123",
                    "changes": [
                        {
                            "value": {
                                "messages": [
                                    {"from": "5511111111111", "id": "msg1", "type": "text", "text": {"body": "Oi"}},
                                    {"from": "5522222222222", "id": "msg2", "type": "text", "text": {"body": "Olá"}},
                                ]
                            },
                            "field": "messages",
                        }
                    ],
                }
            ],
        }

        response = await async_client.post(
            "/api/v1/webhooks/whatsapp",
            json=payload,
        )

        assert response.status_code == 200
        assert response.json() == {"status": "ok"}
