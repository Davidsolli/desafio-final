"""Webhooks para integrações externas (WhatsApp, etc).

Endpoints:
- POST /api/v1/webhooks/whatsapp → Receber mensagens do WhatsApp
- GET /api/v1/webhooks/whatsapp → Validar webhook (handshake Meta)
"""

import hmac
import hashlib
import logging
import os
from fastapi import APIRouter, HTTPException, status, Request, Query

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/api/v1/webhooks",
    tags=["webhooks"],
)


def _verify_signature(payload: bytes, signature_header: str) -> bool:
    """Valida a assinatura X-Hub-Signature-256 enviada pelo Meta."""
    app_secret = os.getenv("WHATSAPP_APP_SECRET", "")
    if not app_secret or not signature_header:
        return False
    expected = "sha256=" + hmac.new(
        app_secret.encode(), payload, hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(expected, signature_header)


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
    verify_token = os.getenv("WHATSAPP_VERIFY_TOKEN")

    if hub_mode != "subscribe":
        raise HTTPException(status_code=403, detail="Modo inválido")

    if hub_verify_token != verify_token:
        logger.warning(f"❌ Token de verificação inválido: {hub_verify_token}")
        raise HTTPException(status_code=403, detail="Token inválido")

    logger.info("✅ Webhook validado com sucesso!")
    return {"hub.challenge": hub_challenge}


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
    payload = await request.body()
    signature = request.headers.get("X-Hub-Signature-256", "")

    if os.getenv("WHATSAPP_APP_SECRET") and not _verify_signature(payload, signature):
        logger.warning("❌ Assinatura inválida no webhook POST")
        raise HTTPException(status_code=403, detail="Assinatura inválida")

    data = await request.json()

    logger.info(f"📩 WEBHOOK RECEBIDO:\n{data}")

    try:
        entry = data.get("entry", [])
        if not entry:
            return {"status": "ok"}

        changes = entry[0].get("changes", [])
        if not changes:
            return {"status": "ok"}

        value = changes[0].get("value", {})

        messages = value.get("messages", [])
        if not messages:
            return {"status": "ok"}

        message = messages[0]
        user_phone = message.get("from")
        message_id = message.get("id")
        timestamp = message.get("timestamp")

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

        # TODO: Implementar lógica de pré-cadastro

    except Exception as e:
        logger.error(f"❌ Erro ao processar webhook: {str(e)}")

    return {"status": "ok"}
