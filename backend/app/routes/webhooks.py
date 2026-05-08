"""Webhooks para integrações externas (WhatsApp, etc).

Endpoints:
- POST /api/v1/webhooks/whatsapp → Receber mensagens do WhatsApp
- GET /api/v1/webhooks/whatsapp → Validar webhook (handshake Meta)
"""

import hmac
import hashlib
import logging
from fastapi import APIRouter, HTTPException, status, Request, Query
from pydantic import BaseModel
from typing import Optional

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/v1/webhooks",
    tags=["webhooks"],
)


class WhatsAppMessage(BaseModel):
    """Modelo para message do WhatsApp."""
    from_number: str
    message_text: str
    message_id: str
    timestamp: int


@router.get(
    "/whatsapp",
    status_code=status.HTTP_200_OK,
    summary="Validar webhook do WhatsApp (handshake)",
)
async def verify_whatsapp_webhook(
    hub_mode: str = Query(None, alias="hub.mode"),
    hub_challenge: str = Query(None, alias="hub.challenge"),
    hub_verify_token: str = Query(None, alias="hub.verify_token"),
):
    """
    Validar webhook do WhatsApp.

    O Meta envia uma requisição GET para verificar que você é o dono do webhook.
    Você precisa retornar o hub.challenge para confirmar.
    """
    import os

    verify_token = os.getenv("WHATSAPP_VERIFY_TOKEN")

    if hub_mode != "subscribe":
        raise HTTPException(status_code=403, detail="Modo inválido")

    if hub_verify_token != verify_token:
        logger.warning(f"❌ Token de verificação inválido: {hub_verify_token}")
        raise HTTPException(status_code=403, detail="Token inválido")

    logger.info("✅ Webhook validado com sucesso!")
    return int(hub_challenge)


@router.post(
    "/whatsapp",
    status_code=status.HTTP_200_OK,
    summary="Receber mensagens do WhatsApp",
)
async def receive_whatsapp_message(request: Request):
    """
    Receber mensagens do WhatsApp em tempo real.

    O WhatsApp envia um JSON com a mensagem do usuário.
    Aqui você pode processar e responder.
    """
    data = await request.json()

    # Log para debug
    logger.info(f"📩 WEBHOOK RECEBIDO:\n{data}")

    # Parse da estrutura do Meta
    try:
        entry = data.get("entry", [])
        if not entry:
            return {"status": "ok"}

        changes = entry[0].get("changes", [])
        if not changes:
            return {"status": "ok"}

        value = changes[0].get("value", {})

        # Verificar se é uma mensagem (não status)
        messages = value.get("messages", [])
        if not messages:
            return {"status": "ok"}

        message = messages[0]
        user_phone = message.get("from")
        message_id = message.get("id")
        timestamp = message.get("timestamp")

        # Extrair texto da mensagem
        message_type = message.get("type", "text")
        message_text = ""

        if message_type == "text":
            message_text = message.get("text", {}).get("body", "")

        logger.info(
            f"📱 Mensagem recebida:\n"
            f"  De: {user_phone}\n"
            f"  Tipo: {message_type}\n"
            f"  Texto: {message_text}\n"
            f"  ID: {message_id}"
        )

        # TODO: Aqui você implementa a lógica de pré-cadastro
        # Por enquanto, apenas log

    except Exception as e:
        logger.error(f"❌ Erro ao processar webhook: {str(e)}")

    # Sempre retornar 200 OK para o Meta não reenviar
    return {"status": "ok"}
