"""Serviço de integração com WhatsApp Cloud API.

Responsável por:
- Enviar mensagens via Meta Cloud API
- Menu interativo para usuários cadastrados (chat IA / treino / resumo)
- Menu de boas-vindas para não-cadastrados (pitch / pré-cadastro / código)
- Registro de refeição por áudio (Groq Whisper + FoodParser)
- Registro de refeição por foto (Groq Vision + FoodParser)
- Fluxo de pré-cadastro via WhatsApp

Estado da sessão (em memória):
    Cadastrados   → "menu" (padrão) | "chat" (modo conversa com Vitali)
    Não-cadastros → "menu" (padrão)
"""

from __future__ import annotations

import logging
import os
import re
from datetime import date, datetime, timezone, timedelta
from typing import Optional
from uuid import UUID

import httpx
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.settings import settings
from app.models.user import User
from app.models.whatsapp_pre_registration import WhatsAppPreRegistration

logger = logging.getLogger(__name__)

_WHATSAPP_API_BASE = "https://graph.facebook.com/v20.0"

# ── Estado da sessão em memória ───────────────────────────────────────────────
# Resetado ao reiniciar o processo — comportamento aceitável para o menu.
_SESSION: dict[str, str] = {}

_WEEKDAY_NAMES = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]

# ── Textos ────────────────────────────────────────────────────────────────────

_MENU_REGISTERED = """\
Olá, *{name}*! 💪 O que posso fazer por você?

1️⃣ 💬 Conversar com o Vitali (IA)
2️⃣ 🏋️ Ver meu treino de hoje
3️⃣ 📊 Meu resumo diário

_Digite o número da opção ou envie um áudio/foto para registrar uma refeição._"""

_MENU_UNREGISTERED = """\
👋 Olá! Sou o *Vitali*, assistente do *FitLoop*!

O que deseja fazer?

1️⃣ Conhecer a FitLoop
2️⃣ Solicitar cadastro
3️⃣ Já tenho código de convite

_Digite o número da opção desejada._"""

_FITLOOP_PITCH = """\
🏋️ *Sobre a FitLoop*

A FitLoop é uma plataforma completa de fitness que conecta alunos e personal trainers.

✅ Treinos personalizados pelo seu personal
✅ Diário alimentar com IA
✅ Acompanhamento de metas e evolução
✅ Chat com o Vitali, seu assistente fitness 24h

Para entrar, você precisa de um convite do seu personal trainer.
Quer solicitar um cadastro? Digite *2*."""

_INVITE_CODE_INSTRUCTIONS = """\
📱 *Tenho código de convite*

Para finalizar seu cadastro:

1. Abra o app *FitLoop*
2. Toque em *Tenho código de convite*
3. Digite seu código

Ainda não tem o app? Baixe na loja do seu dispositivo e procure por _FitLoop_."""

_MESSAGES = {
    "welcome_pre_reg": (
        "Ótimo! Vamos iniciar seu cadastro. 😊\n\n"
        "Qual é o seu *nome completo*?"
    ),
    "ask_email": "Perfeito, *{name}*!\n\nAgora me passa o seu *email*:",
    "invalid_email": "Hmm, esse email não parece válido. Tenta de novo:",
    "plan_list_header": (
        "💳 *Escolha o seu plano:*\n\n"
        "{plans}\n\n"
        "_Digite o número da opção desejada._"
    ),
    "invalid_plan": "Opção inválida. Por favor, escolha um número da lista:",
    "no_plans_available": (
        "⚠️ Não há planos disponíveis no momento.\n"
        "Entre em contato com a equipe FitLoop."
    ),
    "payment_link_sent": (
        "✅ *Plano selecionado: {plan_name}*\n\n"
        "Clique no link abaixo para realizar o pagamento:\n"
        "{checkout_url}\n\n"
        "_Após a confirmação do pagamento, seu cadastro será enviado para análise._"
    ),
    "awaiting_payment": (
        "⏳ *Aguardando confirmação do pagamento.*\n\n"
        "Clique no link para pagar:\n"
        "{checkout_url}\n\n"
        "_Assim que o pagamento for confirmado, seu cadastro será analisado._"
    ),
    "payment_confirmed_user": (
        "✅ *Pagamento confirmado!*\n\n"
        "Seu cadastro foi enviado para análise. "
        "Em breve você receberá o código de acesso aqui mesmo."
    ),
    "pending_approval": (
        "*Pré-cadastro recebido!* ✅\n\n"
        "Seus dados foram enviados para análise. "
        "Em breve você receberá aqui o seu código de acesso."
    ),
    "already_pending": (
        "Seu pré-cadastro já está em análise! ⏳\n\n"
        "Assim que aprovado, você receberá o código de acesso aqui mesmo."
    ),
    "invitation_expired": (
        "⚠️ *Seu código de acesso expirou.*\n\n"
        "Não se preocupe! Seu pré-cadastro foi reenviado para análise. "
        "Em breve você receberá um novo código."
    ),
    "approval_code": (
        "*Seu cadastro foi aprovado!* 🎉\n\n"
        "Abra o app *FitLoop*, toque em *Tenho código de convite* "
        "e use o código:\n\n"
        "*{code}*\n\n"
        "Seus dados já vão estar preenchidos. Bem-vindo(a)!"
    ),
    "already_approved": (
        "Seu cadastro já foi aprovado! ✅\n\n"
        "Use o código *{code}* no app *FitLoop* para finalizar."
    ),
    "chat_activated": (
        "💬 *Modo conversa ativado!*\n\n"
        "Pode perguntar o que quiser ao Vitali.\n\n"
        "_Para voltar ao menu, digite *0* ou *menu*._"
    ),
    "chat_rate_limited": (
        "Você atingiu o limite de mensagens por hora.\n"
        "Tente novamente em breve!"
    ),
    "chat_message_too_long": (
        "Sua mensagem é muito longa.\n"
        "Tente reformular em até 500 caracteres."
    ),
    "chat_generic_error": (
        "Tive um problema ao processar sua mensagem.\n"
        "Tente novamente em alguns instantes!"
    ),
    "no_workout_today": (
        "📅 Não há treino programado para hoje.\n\n"
        "Aproveite para descansar ou fazer uma atividade leve! 😊"
    ),
    "audio_processing": "🎤 Processando seu áudio...",
    "photo_processing": "📸 Analisando sua foto...",
    "media_download_error": (
        "❌ Não consegui baixar a mídia. Tente novamente."
    ),
    "media_generic_error": (
        "❌ Não consegui processar a mídia.\n"
        "Tente descrever o alimento em texto ou tente novamente."
    ),
}

_EMAIL_REGEX = re.compile(r"^[^@\s]+@[^@\s]+\.[^@\s]+$")
_BACK_TO_MENU = {"0", "menu", "Menu", "MENU", "voltar", "Voltar"}


# ── Helpers de sessão ─────────────────────────────────────────────────────────

def _get_session(phone: str) -> str:
    return _SESSION.get(phone, "menu")


def _set_session(phone: str, state: str) -> None:
    _SESSION[phone] = state


# ── Utilitários ───────────────────────────────────────────────────────────────

def _sanitize_phone(phone: str) -> Optional[str]:
    digits = "".join(c for c in phone if c.isdigit())
    if len(digits) in (10, 11):
        return f"55{digits}"
    if len(digits) >= 12:
        return digits
    return None


def _local_now(user: "User") -> datetime:
    """Retorna datetime atual no fuso do usuário (fallback: UTC-3 / BRT)."""
    tz_name = getattr(user, "timezone", None)
    if tz_name:
        try:
            from zoneinfo import ZoneInfo
            return datetime.now(tz=ZoneInfo(tz_name))
        except Exception:
            pass
    # Fallback: Brasília UTC-3
    return datetime.now(tz=timezone(timedelta(hours=-3)))


def _first_name(full_name: str | None) -> str:
    if not full_name:
        return "você"
    return full_name.split()[0]


# ── Função standalone para envio de link de pagamento ────────────────────────

async def send_payment_link(
    phone: str,
    student_name: str,
    plan_name: str,
    payment_url: str,
    price_brl: float,
) -> bool:
    if not settings.WHATSAPP_TOKEN or not settings.WHATSAPP_PHONE_NUMBER_ID:
        return False

    phone_clean = _sanitize_phone(phone)
    if not phone_clean:
        return False

    price_fmt = f"R$ {price_brl:.2f}".replace(".", ",")
    message = (
        f"Olá, {student_name}! 👋\n\n"
        f"Seu link de pagamento para o *{plan_name}* ({price_fmt}) está pronto.\n\n"
        f"Clique para pagar:\n{payment_url}\n\n"
        f"_Após a confirmação do pagamento seu acesso será liberado automaticamente._"
    )

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                f"{_WHATSAPP_API_BASE}/{settings.WHATSAPP_PHONE_NUMBER_ID}/messages",
                headers={"Authorization": f"Bearer {settings.WHATSAPP_TOKEN}"},
                json={
                    "messaging_product": "whatsapp",
                    "to": phone_clean,
                    "type": "text",
                    "text": {"body": message},
                },
            )
            return resp.status_code == 200
    except Exception as exc:
        logger.error("Erro ao enviar link de pagamento WhatsApp: %s", exc)
        return False


# ── Serviço principal ─────────────────────────────────────────────────────────

class WhatsAppService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self._token = settings.WHATSAPP_TOKEN or os.getenv("WHATSAPP_TOKEN", "")
        self._phone_id = (
            settings.WHATSAPP_PHONE_NUMBER_ID
            or os.getenv("WHATSAPP_PHONE_NUMBER_ID", "")
        )

    # ── Envio ─────────────────────────────────────────────────────────────────

    async def send_message(self, to: str, text: str) -> None:
        if not self._token or not self._phone_id:
            logger.warning("WhatsApp não configurado — mensagem não enviada")
            return

        async with httpx.AsyncClient(timeout=10) as client:
            resp = await client.post(
                f"{_WHATSAPP_API_BASE}/{self._phone_id}/messages",
                headers={"Authorization": f"Bearer {self._token}"},
                json={
                    "messaging_product": "whatsapp",
                    "to": to,
                    "type": "text",
                    "text": {"body": text},
                },
            )

        if resp.status_code != 200:
            logger.error("Erro ao enviar WhatsApp %s: %s", resp.status_code, resp.text)
        else:
            logger.info("WhatsApp enviado para %s", to)

    async def send_approval_code(self, phone: str, code: str) -> None:
        result = await self.session.execute(
            select(WhatsAppPreRegistration).where(
                WhatsAppPreRegistration.phone == phone
            )
        )
        pre_reg = result.scalar_one_or_none()
        if not pre_reg:
            logger.error("Pré-cadastro não encontrado para %s", phone)
            return

        pre_reg.invitation_code = code
        pre_reg.state = "approved"
        await self.session.commit()
        await self.send_message(phone, _MESSAGES["approval_code"].format(code=code))

    # ── Roteamento principal ──────────────────────────────────────────────────

    async def handle_message(
        self,
        phone: str,
        text: str | None = None,
        message_type: str = "text",
        media_id: str | None = None,
        mime_type: str | None = None,
    ) -> None:
        user = await self._find_user_by_phone(phone)

        if user is not None and user.is_active:
            await self._handle_registered(
                user=user,
                phone=phone,
                text=text,
                message_type=message_type,
                media_id=media_id,
                mime_type=mime_type,
            )
        else:
            await self._handle_unregistered(phone=phone, text=text or "")

    # ── Usuário cadastrado ────────────────────────────────────────────────────

    async def _handle_registered(
        self,
        user: User,
        phone: str,
        text: str | None,
        message_type: str,
        media_id: str | None,
        mime_type: str | None,
    ) -> None:
        # Áudio e foto → registrar refeição (independe do estado do menu)
        if message_type == "audio" and media_id:
            await self._handle_audio_food(user, phone, media_id, mime_type)
            return

        if message_type == "image" and media_id:
            await self._handle_image_food(user, phone, media_id, mime_type)
            return

        # Texto
        text = (text or "").strip()
        if not text:
            return

        # Voltar ao menu
        if text in _BACK_TO_MENU:
            _set_session(phone, "menu")
            await self.send_message(
                phone, _MENU_REGISTERED.format(name=_first_name(user.name))
            )
            return

        state = _get_session(phone)

        if state == "chat":
            await self._handle_chat_message(user=user, phone=phone, text=text)
        else:
            await self._handle_menu_option(user=user, phone=phone, text=text)

    async def _handle_menu_option(
        self, user: User, phone: str, text: str
    ) -> None:
        if text == "1":
            _set_session(phone, "chat")
            await self.send_message(phone, _MESSAGES["chat_activated"])

        elif text == "2":
            await self.send_message(
                phone, await self._get_today_workout(user.id)
            )

        elif text == "3":
            await self.send_message(
                phone, await self._get_daily_summary(user.id, user)
            )

        else:
            # Qualquer texto não reconhecido → mostra o menu
            await self.send_message(
                phone, _MENU_REGISTERED.format(name=_first_name(user.name))
            )

    async def _handle_chat_message(
        self, user: User, phone: str, text: str
    ) -> None:
        from app.services.chat_service import (
            ChatService,
            MessageTooLongError,
            RateLimitExceededError,
        )

        chat_service = ChatService(self.session)
        try:
            result = await chat_service.send_message(
                user_id=user.id,
                message=text,
                channel="whatsapp",
            )
            await self.send_message(phone, result["content"])
        except RateLimitExceededError:
            await self.send_message(phone, _MESSAGES["chat_rate_limited"])
        except MessageTooLongError:
            await self.send_message(phone, _MESSAGES["chat_message_too_long"])
        except Exception:
            logger.exception("Erro ao processar chat WhatsApp user=%s", user.id)
            await self.send_message(phone, _MESSAGES["chat_generic_error"])

    # ── Download de mídia ─────────────────────────────────────────────────────

    async def _download_media(
        self, media_id: str
    ) -> tuple[bytes, str, str] | None:
        """Baixa mídia dos servidores da Meta. Retorna (bytes, filename, mime)."""
        if not self._token:
            return None

        ext_map = {
            "audio/ogg": "ogg",
            "audio/mpeg": "mp3",
            "audio/mp4": "m4a",
            "audio/webm": "webm",
            "image/jpeg": "jpg",
            "image/png": "png",
            "image/webp": "webp",
        }

        try:
            async with httpx.AsyncClient(timeout=30) as client:
                # 1. Obter URL de download
                meta_resp = await client.get(
                    f"{_WHATSAPP_API_BASE}/{media_id}",
                    headers={"Authorization": f"Bearer {self._token}"},
                )
                if meta_resp.status_code != 200:
                    logger.error("Erro ao obter URL da mídia: %s", meta_resp.text)
                    return None

                info = meta_resp.json()
                download_url = info.get("url")
                full_mime = info.get("mime_type", "")
                if not download_url:
                    return None

                base_mime = full_mime.split(";")[0].strip()
                ext = ext_map.get(base_mime, "bin")

                # 2. Baixar o arquivo
                file_resp = await client.get(
                    download_url,
                    headers={"Authorization": f"Bearer {self._token}"},
                )
                if file_resp.status_code != 200:
                    logger.error("Erro ao baixar mídia: %s", file_resp.status_code)
                    return None

                return file_resp.content, f"media.{ext}", base_mime

        except Exception as exc:
            logger.error("Erro ao baixar mídia %s: %s", media_id, exc)
            return None

    # ── Áudio → refeição ──────────────────────────────────────────────────────

    async def _handle_audio_food(
        self, user: User, phone: str, media_id: str, mime_type: str | None
    ) -> None:
        await self.send_message(phone, _MESSAGES["audio_processing"])

        media = await self._download_media(media_id)
        if not media:
            await self.send_message(phone, _MESSAGES["media_download_error"])
            return

        audio_bytes, filename, content_type = media

        try:
            from app.ai.audio_transcriber import (
                AudioFormatError,
                AudioTooLargeError,
                AudioTranscriptionError,
                audio_transcriber,
            )
            from app.ai.food_parser import (
                FoodNotFoundError,
                FoodParseError,
                QuantityNotFoundError,
                food_parser,
            )
            from app.dtos.diet_logbook_dto import AddLogbookEntryDTO
            from app.services.diet_logbook_service import DietLogbookService

            transcription = await audio_transcriber.transcribe(
                audio_bytes=audio_bytes,
                filename=filename,
                content_type=content_type,
            )

            local_dt = _local_now(user)
            parse_result = await food_parser.parse(
                transcription,
                self.session,
                local_hour=local_dt.hour,
                user_id=user.id,
            )

            logbook_service = DietLogbookService(self.session)
            if parse_result.source == "taco" and parse_result.catalog_item:
                entry_dto = AddLogbookEntryDTO(
                    meal_name=parse_result.meal_name,
                    food_id=parse_result.catalog_item.id,
                    quantity_g=parse_result.quantity_g,
                    log_date=local_dt.date(),
                )
                food_name = parse_result.catalog_item.name
            else:
                assert parse_result.custom_food is not None
                entry_dto = AddLogbookEntryDTO(
                    meal_name=parse_result.meal_name,
                    custom_food_id=parse_result.custom_food.id,
                    quantity_g=parse_result.quantity_g,
                    log_date=local_dt.date(),
                )
                food_name = parse_result.custom_food.name

            entry = await logbook_service.add_entry(user_id=user.id, dto=entry_dto)

            source_note = {
                "web": " _(dados da web)_",
                "estimativa": " _(estimativa da IA)_",
            }.get(parse_result.source, "")

            await self.send_message(
                phone,
                f"✅ *{parse_result.quantity_g:.0f}g de {food_name}* "
                f"registrado no {parse_result.meal_name}!{source_note}\n\n"
                f"• {entry.kcal:.0f} kcal\n"
                f"• Prot: {entry.protein:.1f}g | "
                f"Carbs: {entry.carbs:.1f}g | "
                f"Gord: {entry.fats:.1f}g",
            )

        except (AudioTooLargeError, AudioFormatError, AudioTranscriptionError) as exc:
            await self.send_message(phone, f"❌ {exc}")
        except QuantityNotFoundError as exc:
            await self.send_message(phone, f"🤔 {exc}")
        except (FoodNotFoundError, FoodParseError) as exc:
            await self.send_message(phone, f"❌ {exc}")
        except Exception:
            logger.exception("Erro no audio food logging WhatsApp user=%s", user.id)
            await self.send_message(phone, _MESSAGES["media_generic_error"])

    # ── Foto → refeição ───────────────────────────────────────────────────────

    async def _handle_image_food(
        self, user: User, phone: str, media_id: str, mime_type: str | None
    ) -> None:
        await self.send_message(phone, _MESSAGES["photo_processing"])

        media = await self._download_media(media_id)
        if not media:
            await self.send_message(phone, _MESSAGES["media_download_error"])
            return

        image_bytes, filename, content_type = media

        try:
            from app.ai.food_parser import (
                FoodNotFoundError,
                FoodParseError,
                QuantityNotFoundError,
                food_parser,
            )
            from app.ai.photo_food_parser import PhotoParseError, photo_food_parser
            from app.dtos.diet_logbook_dto import AddLogbookEntryDTO
            from app.services.diet_logbook_service import DietLogbookService

            photo_result = await photo_food_parser.analyze(
                image_bytes=image_bytes,
                filename=filename,
                content_type=content_type,
            )

            local_dt = _local_now(user)
            logbook_service = DietLogbookService(self.session)
            foods_logged: list[str] = []
            foods_failed: list[str] = []
            meal_name = "refeição"

            for photo_food in photo_result.foods:
                try:
                    parse_result = await food_parser.parse(
                        photo_food.description_text,
                        self.session,
                        local_hour=local_dt.hour,
                        user_id=user.id,
                    )

                    if parse_result.source == "taco" and parse_result.catalog_item:
                        entry_dto = AddLogbookEntryDTO(
                            meal_name=parse_result.meal_name,
                            food_id=parse_result.catalog_item.id,
                            quantity_g=parse_result.quantity_g,
                            log_date=local_dt.date(),
                        )
                        food_name = parse_result.catalog_item.name
                    else:
                        assert parse_result.custom_food is not None
                        entry_dto = AddLogbookEntryDTO(
                            meal_name=parse_result.meal_name,
                            custom_food_id=parse_result.custom_food.id,
                            quantity_g=parse_result.quantity_g,
                            log_date=local_dt.date(),
                        )
                        food_name = parse_result.custom_food.name

                    entry = await logbook_service.add_entry(
                        user_id=user.id, dto=entry_dto
                    )
                    meal_name = parse_result.meal_name
                    foods_logged.append(
                        f"• {food_name} {parse_result.quantity_g:.0f}g "
                        f"({entry.kcal:.0f} kcal)"
                    )

                except (FoodParseError, FoodNotFoundError, QuantityNotFoundError) as exc:
                    logger.warning("FoodParser WhatsApp falhou para %r: %s", photo_food.name, exc)
                    foods_failed.append(photo_food.name)

            if not foods_logged:
                await self.send_message(phone, _MESSAGES["media_generic_error"])
                return

            failed_note = (
                f"\n\n⚠️ Não identifiquei: {', '.join(foods_failed)}"
                if foods_failed else ""
            )
            await self.send_message(
                phone,
                f"📸 *Registrado no {meal_name}!*\n\n"
                + "\n".join(foods_logged)
                + failed_note,
            )

        except PhotoParseError as exc:
            await self.send_message(phone, f"❌ {exc}")
        except Exception:
            logger.exception("Erro no photo food logging WhatsApp user=%s", user.id)
            await self.send_message(phone, _MESSAGES["media_generic_error"])

    # ── Consultas ─────────────────────────────────────────────────────────────

    async def _get_today_workout(self, user_id: UUID) -> str:
        try:
            from app.models.workout_sheet import Exercise, WorkoutProgram, WorkoutSheet

            today = datetime.now().weekday()  # 0=seg, 6=dom
            day_name = _WEEKDAY_NAMES[today]

            prog_result = await self.session.execute(
                select(WorkoutProgram)
                .where(
                    WorkoutProgram.user_id == user_id,
                    WorkoutProgram.is_active == True,
                )
                .order_by(WorkoutProgram.created_at.desc())
                .limit(1)
            )
            program = prog_result.scalar_one_or_none()
            if not program:
                return _MESSAGES["no_workout_today"]

            sheet_result = await self.session.execute(
                select(WorkoutSheet)
                .where(
                    WorkoutSheet.workout_program_id == program.id,
                    WorkoutSheet.day_of_week == today,
                    WorkoutSheet.is_active == True,
                )
                .limit(1)
            )
            sheet = sheet_result.scalar_one_or_none()
            if not sheet:
                return _MESSAGES["no_workout_today"]

            ex_result = await self.session.execute(
                select(Exercise)
                .where(Exercise.workout_sheet_id == sheet.id)
                .order_by(Exercise.order)
            )
            exercises = list(ex_result.scalars().all())

            if not exercises:
                return (
                    f"🏋️ *Treino de {day_name} — {sheet.name}*\n\n"
                    "Nenhum exercício cadastrado nessa ficha ainda."
                )

            lines = [f"🏋️ *Treino de {day_name} — {sheet.name}*\n"]
            for i, ex in enumerate(exercises, 1):
                load = f" | {ex.load_kg:.0f}kg" if ex.load_kg else ""
                lines.append(
                    f"{i}. *{ex.name}* — {ex.series}x{ex.repetitions}{load}"
                )

            return "\n".join(lines)

        except Exception:
            logger.exception("Erro ao buscar treino WhatsApp user=%s", user_id)
            return "❌ Não consegui buscar seu treino. Acesse o app para ver."

    async def _get_daily_summary(self, user_id: UUID, user: "User") -> str:
        try:
            from app.models.diet_logbook import DietLogbook

            today = _local_now(user).date()
            logbook_result = await self.session.execute(
                select(DietLogbook).where(
                    DietLogbook.user_id == user_id,
                    DietLogbook.date == today,
                )
            )
            logbook = logbook_result.scalar_one_or_none()

            if not logbook or logbook.total_kcal == 0:
                diet_text = "📊 *Dieta de hoje:* Nenhum alimento registrado ainda."
            else:
                diet_text = (
                    f"📊 *Dieta de hoje:*\n"
                    f"• Calorias: *{logbook.total_kcal:.0f} kcal*\n"
                    f"• Proteínas: {logbook.total_protein:.1f}g\n"
                    f"• Carboidratos: {logbook.total_carbs:.1f}g\n"
                    f"• Gorduras: {logbook.total_fats:.1f}g"
                )

            return diet_text + "\n\n_Para mais detalhes, acesse o app FitLoop._"

        except Exception:
            logger.exception("Erro ao buscar resumo diário WhatsApp user=%s", user_id)
            return "❌ Não consegui buscar seu resumo. Acesse o app para ver."

    # ── Usuário não cadastrado ────────────────────────────────────────────────

    async def _handle_unregistered(self, phone: str, text: str) -> None:
        result = await self.session.execute(
            select(WhatsAppPreRegistration).where(
                WhatsAppPreRegistration.phone == phone
            )
        )
        pre_reg = result.scalar_one_or_none()

        # Usuário com pré-cadastro em andamento → continua o fluxo
        if pre_reg is not None:
            await self._continue_pre_registration(phone, text, pre_reg)
            return

        # Número novo ou opção inválida → mostra menu
        if text not in ("1", "2", "3"):
            await self.send_message(phone, _MENU_UNREGISTERED)
            return

        if text == "1":
            await self.send_message(phone, _FITLOOP_PITCH)
        elif text == "2":
            new_pre_reg = WhatsAppPreRegistration(phone=phone, state="awaiting_name")
            self.session.add(new_pre_reg)
            await self.session.commit()
            await self.send_message(phone, _MESSAGES["welcome_pre_reg"])
        elif text == "3":
            await self.send_message(phone, _INVITE_CODE_INSTRUCTIONS)

    async def _continue_pre_registration(
        self, phone: str, text: str, pre_reg: WhatsAppPreRegistration
    ) -> None:
        if pre_reg.state == "awaiting_payment":
            await self.send_message(
                phone,
                _MESSAGES["awaiting_payment"].format(
                    checkout_url=pre_reg.checkout_url or "—"
                ),
            )
            return

        if pre_reg.state == "pending_approval":
            await self.send_message(phone, _MESSAGES["already_pending"])
            return

        if pre_reg.state == "approved":
            # 1. Verificar primeiro se o usuário já se cadastrou
            user = await self._find_user_by_phone(phone)

            if user is None and pre_reg.email:
                result = await self.session.execute(
                    select(User).where(
                        User.email == pre_reg.email,
                        User.is_active == True,
                    ).limit(1)
                )
                user = result.scalar_one_or_none()
                if user:
                    user.phone_whatsapp = phone
                    await self.session.commit()
                    logger.info(
                        "phone_whatsapp atualizado via pre_reg email: user=%s phone=%s",
                        user.id, phone,
                    )

            if user and user.is_active:
                # Usuário já registrado — mostrar menu normalmente
                await self.send_message(
                    phone, _MENU_REGISTERED.format(name=_first_name(user.name))
                )
                return

            # 2. Usuário ainda não se cadastrou — verificar se o código ainda é válido
            if pre_reg.invitation_code:
                from app.services.invitation_service import InvitationService
                inv_service = InvitationService(self.session)
                is_valid = await inv_service.validate(pre_reg.invitation_code)
                if not is_valid:
                    # Código expirado — resetar para admin aprovar novamente
                    pre_reg.state = "pending_approval"
                    pre_reg.invitation_code = None
                    await self.session.commit()
                    await self.send_message(phone, _MESSAGES["invitation_expired"])
                    return

            # Código ainda válido — lembrar o usuário
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
            pre_reg.state = "awaiting_plan"
            await self.session.commit()
            await self._send_plan_list(phone)
            return

        if pre_reg.state == "awaiting_plan":
            await self._handle_plan_selection(phone, text, pre_reg)

    # ── Seleção de plano no pré-cadastro ──────────────────────────────────────

    async def _send_plan_list(self, phone: str) -> None:
        """Busca planos ativos e envia lista numerada ao usuário."""
        from app.repositories.payment_repository import PlanRepository

        plans = await PlanRepository.find_all_active(self.session)
        if not plans:
            await self.send_message(phone, _MESSAGES["no_plans_available"])
            return

        lines = []
        emojis = ["1️⃣", "2️⃣", "3️⃣", "4️⃣", "5️⃣", "6️⃣", "7️⃣", "8️⃣", "9️⃣"]
        for i, plan in enumerate(plans):
            emoji = emojis[i] if i < len(emojis) else f"{i + 1}."
            price = f"R$ {float(plan.price):.2f}".replace(".", ",")
            duration = (
                f"{plan.duration_months} mês"
                if plan.duration_months == 1
                else f"{plan.duration_months} meses"
            )
            lines.append(f"{emoji} *{plan.name}* — {price}/{duration}")

        plan_text = "\n".join(lines)
        await self.send_message(
            phone, _MESSAGES["plan_list_header"].format(plans=plan_text)
        )

    async def _handle_plan_selection(
        self, phone: str, text: str, pre_reg: WhatsAppPreRegistration
    ) -> None:
        """Processa a escolha do plano, cria checkout e transita para awaiting_payment."""
        from app.repositories.payment_repository import PlanRepository
        from app.services.infinitepay_service import create_payment_link

        plans = await PlanRepository.find_all_active(self.session)
        if not plans:
            await self.send_message(phone, _MESSAGES["no_plans_available"])
            return

        try:
            choice = int(text.strip())
        except ValueError:
            await self.send_message(phone, _MESSAGES["invalid_plan"])
            return

        if choice < 1 or choice > len(plans):
            await self.send_message(phone, _MESSAGES["invalid_plan"])
            return

        plan = plans[choice - 1]
        order_nsu = f"prereg_{pre_reg.id}"

        result = await create_payment_link(
            subscription_id=pre_reg.id,
            plan_name=plan.name,
            price_brl=float(plan.price),
            student_name=pre_reg.name or "Usuário",
            student_email=pre_reg.email or "",
            student_phone=pre_reg.phone,
            order_nsu_override=order_nsu,
        )

        checkout_url = result.url if result else None
        if not checkout_url:
            # Fallback: URL padrão da InfinitePay se integração falhar
            checkout_url = "https://checkout.infinitepay.io/fitloop"

        pre_reg.selected_plan_id = plan.id
        pre_reg.payment_status = "pending"
        pre_reg.pre_reg_payment_id = order_nsu
        pre_reg.checkout_url = checkout_url
        pre_reg.state = "awaiting_payment"
        await self.session.commit()

        await self.send_message(
            phone,
            _MESSAGES["payment_link_sent"].format(
                plan_name=plan.name,
                checkout_url=checkout_url,
            ),
        )

    # ── Helpers ───────────────────────────────────────────────────────────────

    @staticmethod
    def _normalize_phone(phone: str) -> str:
        return re.sub(r"\D", "", phone or "")

    async def _find_user_by_phone(self, phone: str) -> User | None:
        normalized = self._normalize_phone(phone)
        if not normalized:
            return None

        # Variantes: com e sem DDI 55
        variants: list[str] = [normalized]
        if normalized.startswith("55") and len(normalized) >= 12:
            variants.append(normalized[2:])
        elif len(normalized) in (10, 11):
            variants.append(f"55{normalized}")

        # regexp_replace remove tudo que não é dígito do valor armazenado
        # para comparar corretamente com +55 11 9xxxx-xxxx, (11)9xxxx-xxxx, etc.
        from sqlalchemy import func, or_
        stripped = func.regexp_replace(User.phone_whatsapp, "[^0-9]", "", "g")
        result = await self.session.execute(
            select(User).where(
                or_(*[stripped == v for v in variants])
            ).limit(1)
        )
        return result.scalar_one_or_none()
