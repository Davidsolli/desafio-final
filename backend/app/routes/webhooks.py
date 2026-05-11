"""Webhooks para integrações externas (WhatsApp, etc).

Endpoints:
- GET /api/v1/webhooks/whatsapp → Validar webhook (handshake Meta)
- POST /api/v1/webhooks/whatsapp → Receber mensagens do WhatsApp
"""

import hmac
import hashlib
import json
import logging
import os
from fastapi import APIRouter, Depends, HTTPException, status, Request
from fastapi.responses import Response
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.services.whatsapp_service import WhatsAppService

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
async def verify_whatsapp_webhook(request: Request):
    """
    Validar webhook do WhatsApp.

    O Meta envia uma requisição GET para verificar que você é o dono do webhook.
    Retorna o hub.challenge como plain text para confirmar.
    """
    hub_mode = request.query_params.get("hub.mode")
    hub_challenge = request.query_params.get("hub.challenge")
    hub_verify_token = request.query_params.get("hub.verify_token")

    verify_token = os.getenv("WHATSAPP_VERIFY_TOKEN")

    if hub_mode != "subscribe":
        raise HTTPException(status_code=403, detail="Modo inválido")

    if hub_verify_token != verify_token:
        logger.warning("❌ Token de verificação inválido recebido no handshake")
        raise HTTPException(status_code=403, detail="Token inválido")

    if not hub_challenge:
        raise HTTPException(status_code=400, detail="hub.challenge ausente")

    logger.info("✅ Webhook validado com sucesso!")
    return Response(content=hub_challenge, media_type="text/plain")


@router.post(
    "/whatsapp",
    status_code=status.HTTP_200_OK,
    summary="Receber mensagens do WhatsApp",
)
async def receive_whatsapp_message(
    request: Request,
    session: AsyncSession = Depends(get_db),
):
    """
    Receber mensagens do WhatsApp em tempo real.

    O WhatsApp envia um JSON com a mensagem do usuário.
    """
    payload = await request.body()
    signature = request.headers.get("X-Hub-Signature-256", "")

    app_secret = os.getenv("WHATSAPP_APP_SECRET")
    if not app_secret:
        logger.warning("⚠️ WHATSAPP_APP_SECRET não configurado — validação de assinatura desativada")
    elif not _verify_signature(payload, signature):
        logger.warning("❌ Assinatura inválida no webhook POST")
        raise HTTPException(status_code=403, detail="Assinatura inválida")

    data = json.loads(payload)

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

        service = WhatsAppService(session)

        for message in messages:
            user_phone = message.get("from")
            message_type = message.get("type", "text")

            if message_type != "text":
                logger.info(f"📱 Mensagem do tipo {message_type!r} ignorada (apenas texto suportado)")
                continue

            message_text = message.get("text", {}).get("body", "")

            logger.info(f"📱 Mensagem recebida de {user_phone}: {message_text!r}")

            await service.handle_message(phone=user_phone, text=message_text)

    except Exception as e:
        logger.error(f"❌ Erro ao processar webhook: {str(e)}")

    return {"status": "ok"}
