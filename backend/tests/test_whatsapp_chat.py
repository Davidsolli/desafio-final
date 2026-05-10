"""
Testes da integração WhatsApp ↔ Chatbot (Card 18.8 — Etapa 3).

Verifica o roteamento de mensagens recebidas via webhook WhatsApp:
- Telefone vinculado a User ativo  → ChatService.send_message(channel="whatsapp")
- Telefone NÃO vinculado            → fluxo de pré-cadastro (preservado)

Usa SQLite in-memory + mocks para isolar do Groq/HuggingFace e da Cloud API.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.ai.rag_chain import RAGResult, RetrievedDocument
from app.models.chatbot import ChatConversation, ChatMessage
from app.models.user import Base, User
from app.models.whatsapp_pre_registration import WhatsAppPreRegistration  # noqa: F401
from app.services.chat_service import (
    MessageTooLongError,
    RateLimitExceededError,
)
from app.services.whatsapp_service import WhatsAppService


TEST_DB_URL = "sqlite+aiosqlite:///:memory:"


@pytest_asyncio.fixture(scope="function")
async def db_engine():
    engine = create_async_engine(
        TEST_DB_URL,
        echo=False,
        connect_args={"check_same_thread": False},
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest_asyncio.fixture(scope="function")
async def db_session(db_engine):
    factory = async_sessionmaker(
        db_engine,
        class_=AsyncSession,
        expire_on_commit=False,
    )
    async with factory() as session:
        yield session


@pytest_asyncio.fixture
async def registered_user(db_session: AsyncSession) -> User:
    """User ativo com phone_whatsapp = '5511999999999'."""
    user = User(
        id=uuid4(),
        name="Aluno WhatsApp",
        email="aluno@whatsapp.com",
        password="hash_fake",
        role="client",
        phone_whatsapp="5511999999999",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
def rag_ok_result() -> RAGResult:
    return RAGResult(
        answer="Para o supino reto, mantenha as escápulas retraídas e o peito alto.",
        retrieved_documents=[
            RetrievedDocument(
                id=str(uuid4()),
                title="Supino Reto",
                content="Conteúdo...",
                relevance_score=0.92,
                category="exercicio",
            )
        ],
        should_escalate=False,
        escalation_reason="",
        model_used="llama-3.3-70b-versatile",
        tokens_used=120,
        latency_ms=850,
        confidence_score=0.92,
    )


# ── Identificação por telefone ────────────────────────────────────────────────

class TestFindUserByPhone:
    """Identificação do User pelo phone_whatsapp normalizado."""

    @pytest.mark.asyncio
    async def test_whatsapp_user_identified_by_phone_whatsapp(
        self, db_session, registered_user
    ):
        """Encontra User cadastrado a partir do telefone (apenas dígitos)."""
        service = WhatsAppService(db_session)
        found = await service._find_user_by_phone("5511999999999")
        assert found is not None
        assert found.id == registered_user.id

    @pytest.mark.asyncio
    async def test_find_user_by_phone_normalizes_input(
        self, db_session, registered_user
    ):
        """Telefone com '+', espaços e '-' deve ser normalizado para apenas dígitos."""
        service = WhatsAppService(db_session)
        found = await service._find_user_by_phone("+55 11 99999-9999")
        assert found is not None
        assert found.id == registered_user.id

    @pytest.mark.asyncio
    async def test_find_user_by_phone_returns_none_when_not_registered(
        self, db_session
    ):
        """Telefone não vinculado a User retorna None."""
        service = WhatsAppService(db_session)
        found = await service._find_user_by_phone("5511000000000")
        assert found is None


# ── Roteamento WhatsApp → Chat ────────────────────────────────────────────────

class TestWhatsAppRouting:
    """handle_message roteia para chat ou pré-cadastro conforme o User."""

    @pytest.mark.asyncio
    async def test_whatsapp_message_from_registered_user_routes_to_chat(
        self, db_session, registered_user, rag_ok_result
    ):
        """Mensagem de número vinculado a User ativo é roteada ao ChatService."""
        service = WhatsAppService(db_session)

        with patch("app.services.chat_service.rag_chain") as mock_rag, \
             patch.object(service, "send_message", new=AsyncMock()) as mock_send:
            mock_rag.run = AsyncMock(return_value=rag_ok_result)

            await service.handle_message(
                phone="5511999999999",
                text="Como faço supino reto?",
            )

            mock_send.assert_awaited()
            sent_text = mock_send.await_args.args[1]
            assert "supino" in sent_text.lower() or "escápulas" in sent_text.lower()

    @pytest.mark.asyncio
    async def test_whatsapp_message_from_unregistered_user_routes_to_pre_registration(
        self, db_session
    ):
        """Mensagem de número não vinculado mantém fluxo de pré-cadastro existente."""
        service = WhatsAppService(db_session)

        with patch.object(service, "send_message", new=AsyncMock()) as mock_send:
            await service.handle_message(
                phone="5511000000000",
                text="Oi, quero me cadastrar!",
            )

            # Cria pré-cadastro e envia welcome
            mock_send.assert_awaited()
            sent_text = mock_send.await_args.args[1]
            assert "Fitloop" in sent_text or "nome" in sent_text.lower()

        # Confirma criação do pré-cadastro
        from sqlalchemy import select
        result = await db_session.execute(
            select(WhatsAppPreRegistration).where(
                WhatsAppPreRegistration.phone == "5511000000000"
            )
        )
        pre_reg = result.scalar_one_or_none()
        assert pre_reg is not None
        assert pre_reg.state == "awaiting_name"

    @pytest.mark.asyncio
    async def test_whatsapp_pre_registration_flow_unaffected(
        self, db_session
    ):
        """Fluxo completo de pré-cadastro continua funcionando inalterado."""
        service = WhatsAppService(db_session)
        phone = "5511444444444"

        with patch.object(service, "send_message", new=AsyncMock()):
            # 1. Mensagem inicial → cria pre_reg
            await service.handle_message(phone, "Oi")
            # 2. Envia nome → avança para awaiting_email
            await service.handle_message(phone, "João Silva")
            # 3. Envia email → pending_approval
            await service.handle_message(phone, "joao@teste.com")

        from sqlalchemy import select
        result = await db_session.execute(
            select(WhatsAppPreRegistration).where(
                WhatsAppPreRegistration.phone == phone
            )
        )
        pre_reg = result.scalar_one_or_none()
        assert pre_reg is not None
        assert pre_reg.state == "pending_approval"
        assert pre_reg.name == "João Silva"
        assert pre_reg.email == "joao@teste.com"


# ── Persistência e contexto ───────────────────────────────────────────────────

class TestWhatsAppChatPersistence:
    """Mensagens via WhatsApp são persistidas com channel correto."""

    @pytest.mark.asyncio
    async def test_whatsapp_chat_persists_with_channel_whatsapp(
        self, db_session, registered_user, rag_ok_result
    ):
        """ChatMessage e ChatConversation salvos com channel='whatsapp'."""
        service = WhatsAppService(db_session)

        with patch("app.services.chat_service.rag_chain") as mock_rag, \
             patch.object(service, "send_message", new=AsyncMock()):
            mock_rag.run = AsyncMock(return_value=rag_ok_result)

            await service.handle_message(
                phone="5511999999999",
                text="Como faço supino reto?",
            )

        from sqlalchemy import select
        conv_result = await db_session.execute(
            select(ChatConversation).where(
                ChatConversation.user_id == registered_user.id
            )
        )
        conv = conv_result.scalar_one_or_none()
        assert conv is not None
        assert conv.channel == "whatsapp"

        msg_result = await db_session.execute(
            select(ChatMessage).where(ChatMessage.conversation_id == conv.id)
        )
        messages = msg_result.scalars().all()
        assert len(messages) >= 2  # user + assistant
        for msg in messages:
            assert msg.channel == "whatsapp"

    @pytest.mark.asyncio
    async def test_whatsapp_chat_reuses_same_rag_pipeline(
        self, db_session, registered_user, rag_ok_result
    ):
        """Pipeline RAG é o mesmo do app (mesmo ChatService, mesmo rag_chain)."""
        service = WhatsAppService(db_session)

        with patch("app.services.chat_service.rag_chain") as mock_rag, \
             patch.object(service, "send_message", new=AsyncMock()):
            mock_rag.run = AsyncMock(return_value=rag_ok_result)

            await service.handle_message(
                phone="5511999999999",
                text="Como faço supino reto?",
            )

            # rag_chain.run foi invocado UMA vez (mesma instância do app)
            mock_rag.run.assert_awaited_once()


# ── Tratamento de erros ───────────────────────────────────────────────────────

class TestWhatsAppErrorHandling:
    """Erros são tratados sem expor stacktrace ao usuário."""

    @pytest.mark.asyncio
    async def test_whatsapp_chat_handles_rate_limit_exceeded(
        self, db_session, registered_user
    ):
        """RateLimitExceededError → mensagem amigável ao usuário."""
        service = WhatsAppService(db_session)

        with patch(
            "app.services.whatsapp_service.ChatService"
        ) as mock_chat_service_cls, patch.object(
            service, "send_message", new=AsyncMock()
        ) as mock_send:
            chat_instance = mock_chat_service_cls.return_value
            chat_instance.send_message = AsyncMock(
                side_effect=RateLimitExceededError("limite")
            )

            await service.handle_message(
                phone="5511999999999",
                text="Pergunta",
            )

            mock_send.assert_awaited()
            sent_text = mock_send.await_args.args[1]
            assert "limite" in sent_text.lower() or "tente" in sent_text.lower()

    @pytest.mark.asyncio
    async def test_whatsapp_chat_handles_message_too_long(
        self, db_session, registered_user
    ):
        """MessageTooLongError → mensagem de aviso de tamanho."""
        service = WhatsAppService(db_session)

        with patch(
            "app.services.whatsapp_service.ChatService"
        ) as mock_chat_service_cls, patch.object(
            service, "send_message", new=AsyncMock()
        ) as mock_send:
            chat_instance = mock_chat_service_cls.return_value
            chat_instance.send_message = AsyncMock(
                side_effect=MessageTooLongError("muito longa")
            )

            await service.handle_message(
                phone="5511999999999",
                text="x" * 600,
            )

            mock_send.assert_awaited()
            sent_text = mock_send.await_args.args[1]
            assert "longa" in sent_text.lower() or "500" in sent_text

    @pytest.mark.asyncio
    async def test_whatsapp_chat_handles_generic_error_without_stacktrace(
        self, db_session, registered_user
    ):
        """Exceção genérica → mensagem amigável, sem expor erro interno."""
        service = WhatsAppService(db_session)

        with patch(
            "app.services.whatsapp_service.ChatService"
        ) as mock_chat_service_cls, patch.object(
            service, "send_message", new=AsyncMock()
        ) as mock_send:
            chat_instance = mock_chat_service_cls.return_value
            chat_instance.send_message = AsyncMock(
                side_effect=RuntimeError("falha interna detalhada")
            )

            await service.handle_message(
                phone="5511999999999",
                text="Pergunta",
            )

            mock_send.assert_awaited()
            sent_text = mock_send.await_args.args[1]
            # Sem expor 'falha interna detalhada' ao usuário
            assert "falha interna detalhada" not in sent_text

    @pytest.mark.asyncio
    async def test_whatsapp_chat_handles_empty_message(
        self, db_session, registered_user
    ):
        """Mensagem vazia/whitespace é ignorada sem crash."""
        service = WhatsAppService(db_session)

        with patch("app.services.chat_service.rag_chain") as mock_rag, \
             patch.object(service, "send_message", new=AsyncMock()) as mock_send:
            mock_rag.run = AsyncMock()
            await service.handle_message(phone="5511999999999", text="   ")

            # Não deve invocar rag nem send_message
            mock_rag.run.assert_not_awaited()
            mock_send.assert_not_awaited()
