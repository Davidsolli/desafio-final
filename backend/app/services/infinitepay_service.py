"""
Integração com a API de Checkout da InfinitePay
POST https://api.checkout.infinitepay.io/links
"""
import httpx
import logging
from typing import Optional
from uuid import UUID

from app.config.settings import settings

logger = logging.getLogger(__name__)

INFINITEPAY_API_URL = "https://api.checkout.infinitepay.io/links"


class InfinitePayCheckoutResult:
    def __init__(self, url: str, order_nsu: str):
        self.url = url
        self.order_nsu = order_nsu


async def create_payment_link(
    subscription_id: UUID,
    plan_name: str,
    price_brl: float,
    student_name: str,
    student_email: str,
    student_phone: Optional[str] = None,
) -> Optional[InfinitePayCheckoutResult]:
    """
    Cria um link de pagamento na InfinitePay.
    Retorna a URL de checkout ou None em caso de falha.
    price_brl em reais (ex: 150.00) — convertido para centavos internamente.
    """
    order_nsu = str(subscription_id)
    price_cents = int(round(price_brl * 100))

    webhook_url = (
        f"{settings.INFINITEPAY_WEBHOOK_URL}/api/v1/webhooks/infinitepay"
        if settings.INFINITEPAY_WEBHOOK_URL
        else None
    )

    payload: dict = {
        "handle": settings.INFINITEPAY_HANDLE,
        "redirect_url": f"{settings.INFINITEPAY_WEBHOOK_URL}/pagamento-confirmado" if settings.INFINITEPAY_WEBHOOK_URL else "https://omniconnect.fit/obrigado",
        "order_nsu": order_nsu,
        "items": [
            {
                "quantity": 1,
                "price": price_cents,
                "description": plan_name,
            }
        ],
        "customer": {
            "name": student_name,
            "email": student_email,
        },
    }

    if student_phone:
        payload["customer"]["phone"] = _sanitize_phone(student_phone)

    if webhook_url:
        payload["webhook_url"] = webhook_url

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(INFINITEPAY_API_URL, json=payload)
            response.raise_for_status()
            data = response.json()
            url = data.get("url") or data.get("payment_url") or data.get("link")
            if not url:
                logger.error(f"InfinitePay retornou resposta sem URL: {data}")
                return None
            logger.info(f"Link InfinitePay criado para subscription {subscription_id}: {url}")
            return InfinitePayCheckoutResult(url=url, order_nsu=order_nsu)

    except httpx.HTTPStatusError as e:
        logger.error(f"InfinitePay HTTP {e.response.status_code}: {e.response.text}")
        return None
    except Exception as e:
        logger.error(f"Erro ao criar link InfinitePay: {e}")
        return None


def _sanitize_phone(phone: str) -> str:
    """Remove caracteres não numéricos do telefone"""
    digits = "".join(c for c in phone if c.isdigit())
    # Garantir DDI Brasil se não tiver
    if len(digits) == 11 or len(digits) == 10:
        return f"55{digits}"
    return digits
