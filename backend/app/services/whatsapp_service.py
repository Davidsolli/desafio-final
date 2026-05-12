"""
Envio de mensagens via WhatsApp (Meta Cloud API)
Usado para notificar o aluno com o link de pagamento.
"""
import httpx
import logging
from typing import Optional

from app.config.settings import settings

logger = logging.getLogger(__name__)

META_API_URL = "https://graph.facebook.com/v19.0"


async def send_payment_link(
    phone: str,
    student_name: str,
    plan_name: str,
    payment_url: str,
    price_brl: float,
) -> bool:
    """
    Envia mensagem de texto com o link de pagamento para o aluno via WhatsApp.
    Retorna True se enviou com sucesso.
    Retorna False silenciosamente se o WhatsApp não estiver configurado.
    """
    if not settings.WHATSAPP_TOKEN or not settings.WHATSAPP_PHONE_NUMBER_ID:
        logger.info("WhatsApp não configurado — pulando envio de link de pagamento")
        return False

    phone_clean = _sanitize_phone(phone)
    if not phone_clean:
        logger.warning(f"Telefone inválido para WhatsApp: {phone}")
        return False

    price_formatted = f"R$ {price_brl:.2f}".replace(".", ",")

    message = (
        f"Olá, {student_name}! 👋\n\n"
        f"Seu link de pagamento para o *{plan_name}* ({price_formatted}) está pronto.\n\n"
        f"Clique para pagar agora:\n{payment_url}\n\n"
        f"_Após a confirmação do pagamento seu acesso será liberado automaticamente._"
    )

    payload = {
        "messaging_product": "whatsapp",
        "to": phone_clean,
        "type": "text",
        "text": {"body": message},
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(
                f"{META_API_URL}/{settings.WHATSAPP_PHONE_NUMBER_ID}/messages",
                headers={
                    "Authorization": f"Bearer {settings.WHATSAPP_TOKEN}",
                    "Content-Type": "application/json",
                },
                json=payload,
            )
            if response.status_code == 200:
                logger.info(f"WhatsApp enviado para {phone_clean}")
                return True
            else:
                logger.warning(f"WhatsApp falhou {response.status_code}: {response.text}")
                return False

    except Exception as e:
        logger.error(f"Erro ao enviar WhatsApp: {e}")
        return False


def _sanitize_phone(phone: str) -> Optional[str]:
    digits = "".join(c for c in phone if c.isdigit())
    if len(digits) == 11 or len(digits) == 10:
        return f"55{digits}"
    if len(digits) >= 12:
        return digits
    return None
