"""Serviço de integração com WhatsApp Cloud API.

Responsável por:
- Enviar mensagens via Meta Cloud API
- Gerenciar o fluxo conversacional de pré-cadastro

States da conversa:
    awaiting_name     → aguardando nome do usuário
    awaiting_email    → aguardando email
    pending_approval  → dados coletados, aguardando aprovação do admin
    approved          → admin aprovou, código de convite enviado
"""

import logging
import os
import re

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.whatsapp_pre_registration import WhatsAppPreRegistration

logger = logging.getLogger(__name__)

_WHATSAPP_API_BASE = "https://graph.facebook.com/v20.0"

_MESSAGES = {
    "welcome": (
        "Olá! 👋 Sou o assistente do *Fitloop*.\n\n"
        "Vou te ajudar a fazer seu pré-cadastro rapidinho. "
        "Qual é o seu *nome completo*?"
    ),
    "ask_email": "Perfeito, *{name}*! 💪\n\nAgora me passa o seu *email*:",
    "invalid_email": "Hmm, esse email não parece válido. Tenta de novo:",
    "pending_approval": (
        "✅ *Pré-cadastro recebido!*\n\n"
        "Seus dados foram enviados para análise. "
        "Em breve você receberá aqui o seu código de acesso. 🎉"
    ),
    "already_pending": (
        "Seu pré-cadastro já está em análise! ⏳\n\n"
        "Assim que aprovado, você receberá o código de acesso aqui mesmo."
    ),
    "approval_code": (
        "🎉 *Seu cadastro foi aprovado!*\n\n"
        "Abra o app *Fitloop*, toque em *Tenho código de convite* "
        "e use o código:\n\n"
        "🔑 *{code}*\n\n"
        "Seus dados já vão estar preenchidos. Bem-vindo(a)!"
    ),
    "already_approved": (
        "Seu cadastro já foi aprovado! 🎉\n\n"
        "Use o código *{code}* no app *Fitloop* para finalizar."
    ),
}

_EMAIL_REGEX = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")


class WhatsAppService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self._token = os.getenv("WHATSAPP_TOKEN", "")
        self._phone_id = os.getenv("WHATSAPP_PHONE_NUMBER_ID", "")

    async def send_message(self, to: str, text: str) -> None:
        """Envia mensagem de texto via WhatsApp Cloud API."""
        if not self._token or not self._phone_id:
            logger.warning("⚠️ WHATSAPP_TOKEN ou WHATSAPP_PHONE_NUMBER_ID não configurados")
            return

        url = f"{_WHATSAPP_API_BASE}/{self._phone_id}/messages"
        payload = {
            "messaging_product": "whatsapp",
            "to": to,
            "type": "text",
            "text": {"body": text},
        }

        async with httpx.AsyncClient(timeout=10) as client:
            response = await client.post(
                url,
                headers={"Authorization": f"Bearer {self._token}"},
                json=payload,
            )

        if response.status_code != 200:
            logger.error(
                f"❌ Erro ao enviar mensagem WhatsApp: "
                f"{response.status_code} — {response.text}"
            )
        else:
            logger.info(f"✅ Mensagem enviada para {to}")

    async def send_approval_code(self, phone: str, code: str) -> None:
        """Envia o código de convite ao usuário após aprovação do admin."""
        result = await self.session.execute(
            select(WhatsAppPreRegistration).where(
                WhatsAppPreRegistration.phone == phone
            )
        )
        pre_reg = result.scalar_one_or_none()
        if not pre_reg:
            logger.error(f"❌ Pré-cadastro não encontrado para {phone}")
            return

        pre_reg.invitation_code = code
        pre_reg.state = "approved"
        await self.session.commit()

        await self.send_message(phone, _MESSAGES["approval_code"].format(code=code))

    async def handle_message(self, phone: str, text: str) -> None:
        """Processa a mensagem recebida e avança o fluxo de pré-cadastro."""
        text = text.strip()

        result = await self.session.execute(
            select(WhatsAppPreRegistration).where(
                WhatsAppPreRegistration.phone == phone
            )
        )
        pre_reg = result.scalar_one_or_none()

        # Número novo: iniciar fluxo
        if pre_reg is None:
            pre_reg = WhatsAppPreRegistration(phone=phone, state="awaiting_name")
            self.session.add(pre_reg)
            await self.session.commit()
            await self.send_message(phone, _MESSAGES["welcome"])
            return

        if pre_reg.state == "pending_approval":
            await self.send_message(phone, _MESSAGES["already_pending"])
            return

        if pre_reg.state == "approved":
            await self.send_message(
                phone,
                _MESSAGES["already_approved"].format(code=pre_reg.invitation_code),
            )
            return

        if pre_reg.state == "awaiting_name":
            pre_reg.name = text
            pre_reg.state = "awaiting_email"
            await self.session.commit()
            await self.send_message(phone, _MESSAGES["ask_email"].format(name=text))
            return

        if pre_reg.state == "awaiting_email":
            if not _EMAIL_REGEX.match(text):
                await self.send_message(phone, _MESSAGES["invalid_email"])
                return
            pre_reg.email = text
            pre_reg.state = "pending_approval"
            await self.session.commit()
            await self.send_message(phone, _MESSAGES["pending_approval"])
