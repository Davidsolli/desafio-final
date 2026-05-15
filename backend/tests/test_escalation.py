"""
Testes de escalação inteligente (Card 19.10 — Etapa 3).

Verifica os 7 reasons distintos:
    user_requested, health_risk, low_confidence, too_complex,
    validation_failed, timeout, generation_error

E a persistência de contexto na ChatConversation.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.ai.rag_chain import RAGChain, RAGResult, RetrievedDocument
from app.models.chatbot import ChatConversation
from app.models.user import Base, User
from app.services.chat_service import ChatService


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
async def sample_user(db_session: AsyncSession) -> User:
    user = User(
        id=uuid4(),
        name="Aluno Test",
        email="aluno@test.com",
        password="hash",
        role="client",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest.fixture
def chain() -> RAGChain:
    return RAGChain()


@pytest.fixture
def good_docs() -> list[RetrievedDocument]:
    return [
        RetrievedDocument(
            id=str(uuid4()),
            title="Supino Reto",
            content="Conteúdo técnico...",
            relevance_score=0.91,
            category="exercicio",
        )
    ]


# ── Detecção de motivo de escalação ───────────────────────────────────────────

class TestShouldEscalateDistinguishesReasons:
    """_should_escalate diferencia os 4 reasons detectáveis pré-LLM."""

    def test_escalation_triggers_on_explicit_user_request(self, chain, good_docs):
        """'Quero falar com personal' → escala com reason=user_requested."""
        should, reason = chain._should_escalate("quero falar com personal", good_docs)
        assert should is True
        assert reason == "user_requested"

    def test_escalation_triggers_on_health_risk_keyword(self, chain, good_docs):
        """'Estou com dor no peito' → escala com reason=health_risk."""
        should, reason = chain._should_escalate("estou com dor no peito", good_docs)
        assert should is True
        assert reason == "health_risk"

    def test_escalation_triggers_on_health_risk_lesion(self, chain, good_docs):
        """'Tenho uma lesão' → escala com reason=health_risk."""
        should, reason = chain._should_escalate(
            "tenho uma lesão no ombro, como treino?", good_docs
        )
        assert should is True
        assert reason == "health_risk"

    def test_escalation_triggers_on_no_documents_retrieved(self, chain):
        """RAG vazio → escala com reason=low_confidence."""
        should, reason = chain._should_escalate("pergunta técnica sem KB", [])
        assert should is True
        assert reason == "low_confidence"

    def test_escalation_triggers_on_low_relevance_score(self, chain):
        """Melhor score < ESCALATE_THRESHOLD → reason=too_complex."""
        low_docs = [
            RetrievedDocument(
                id=str(uuid4()),
                title="Doc fraco",
                content="...",
                relevance_score=0.55,
                category="exercicio",
            )
        ]
        should, reason = chain._should_escalate("pergunta complexa", low_docs)
        assert should is True
        assert reason == "too_complex"

    def test_no_escalation_on_normal_question(self, chain, good_docs):
        """Pergunta normal com docs bons → não escala."""
        should, reason = chain._should_escalate(
            "como faço supino reto corretamente?", good_docs
        )
        assert should is False
        assert reason == ""

    def test_health_risk_takes_priority_over_user_request(self, chain, good_docs):
        """Mensagem com 'dor no peito' E 'falar com personal' → health_risk vence."""
        should, reason = chain._should_escalate(
            "estou com dor no peito, quero falar com personal", good_docs
        )
        assert should is True
        assert reason == "health_risk"


# ── Mensagens contextualizadas por reason ─────────────────────────────────────

class TestEscalationMessagesByReason:
    """Mensagem ao usuário difere por reason (Card 19.10)."""

    def test_escalation_messages_dict_exists(self):
        """Existe ESCALATION_MESSAGES com chaves para os 7 reasons."""
        from app.ai.rag_chain import ESCALATION_MESSAGES

        expected_reasons = {
            "user_requested",
            "health_risk",
            "low_confidence",
            "too_complex",
            "validation_failed",
            "timeout",
            "generation_error",
        }
        assert expected_reasons.issubset(set(ESCALATION_MESSAGES.keys()))

    def test_escalation_message_differentiates_by_reason(self):
        """Mensagem para health_risk ≠ user_requested ≠ too_complex."""
        from app.ai.rag_chain import ESCALATION_MESSAGES

        assert (
            ESCALATION_MESSAGES["health_risk"]
            != ESCALATION_MESSAGES["user_requested"]
        )
        assert (
            ESCALATION_MESSAGES["too_complex"]
            != ESCALATION_MESSAGES["user_requested"]
        )
        assert (
            ESCALATION_MESSAGES["validation_failed"]
            != ESCALATION_MESSAGES["timeout"]
        )

    def test_health_risk_message_mentions_safety(self):
        """Mensagem de health_risk reforça segurança/profissional."""
        from app.ai.rag_chain import ESCALATION_MESSAGES

        msg = ESCALATION_MESSAGES["health_risk"].lower()
        assert "segurança" in msg or "profissional" in msg or "saúde" in msg


# ── Persistência do contexto da escalação na conversa ────────────────────────

class TestEscalationPersistence:
    """ChatConversation guarda escalation_data no campo JSON."""

    @pytest.mark.asyncio
    async def test_escalation_records_context_on_conversation(
        self, db_session, sample_user
    ):
        """Conversa marcada como escalada inclui contexto: pergunta, score, motivo."""
        service = ChatService(db_session)

        rag_result = RAGResult(
            answer="Encaminhando ao Personal...",
            retrieved_documents=[],
            should_escalate=True,
            escalation_reason="low_confidence",
            confidence_score=0.0,
            latency_ms=200,
        )

        with patch("app.services.chat_service.rag_chain") as mock_rag:
            mock_rag.run = AsyncMock(return_value=rag_result)

            await service.send_message(
                user_id=sample_user.id,
                message="pergunta sem cobertura na base",
            )

        result = await db_session.execute(
            select(ChatConversation).where(
                ChatConversation.user_id == sample_user.id
            )
        )
        conv = result.scalar_one_or_none()
        assert conv is not None
        assert conv.status == "escalated"
        assert conv.escalation_reason == "low_confidence"
        # Contexto persistido
        assert conv.escalation_data is not None
        assert "original_question" in conv.escalation_data
        assert (
            "pergunta sem cobertura"
            in conv.escalation_data["original_question"].lower()
        )
        assert conv.escalation_data.get("reason") == "low_confidence"


# ── Mensagem de escalação não é a resposta da IA ─────────────────────────────

class TestEscalationAvoidsGenericAnswers:
    """Em todos os reasons, mensagem ao aluno NÃO é a resposta gerada pela IA."""

    @pytest.mark.asyncio
    async def test_user_requested_returns_specific_message(
        self, db_session, sample_user
    ):
        """Pedido explícito → resposta vem de ESCALATION_MESSAGES, não do LLM."""
        from app.ai.rag_chain import ESCALATION_MESSAGES

        service = ChatService(db_session)

        # rag_chain.run real (sem mock) processaria via _should_escalate
        # e devolveria mensagem do ESCALATION_MESSAGES["user_requested"]
        with patch("app.ai.rag_chain.rag_chain.retrieve") as mock_retrieve:
            mock_retrieve.return_value = []  # não importa, escala antes

            with patch("app.services.chat_service.rag_chain") as mock_rag:
                mock_rag.run = AsyncMock(
                    return_value=RAGResult(
                        answer=ESCALATION_MESSAGES["user_requested"],
                        retrieved_documents=[],
                        should_escalate=True,
                        escalation_reason="user_requested",
                    )
                )
                result = await service.send_message(
                    user_id=sample_user.id,
                    message="quero falar com personal",
                )
                assert "personal" in result["content"].lower() or "trainer" in result["content"].lower()

    @pytest.mark.asyncio
    async def test_health_risk_returns_safety_message(
        self, db_session, sample_user
    ):
        """Risco de saúde → resposta de segurança, não tentativa de diagnóstico."""
        from app.ai.rag_chain import ESCALATION_MESSAGES

        service = ChatService(db_session)
        with patch("app.services.chat_service.rag_chain") as mock_rag:
            mock_rag.run = AsyncMock(
                return_value=RAGResult(
                    answer=ESCALATION_MESSAGES["health_risk"],
                    retrieved_documents=[],
                    should_escalate=True,
                    escalation_reason="health_risk",
                )
            )

            result = await service.send_message(
                user_id=sample_user.id,
                message="estou com dor no peito",
            )

        content_lower = result["content"].lower()
        assert (
            "profissional" in content_lower
            or "segurança" in content_lower
            or "saúde" in content_lower
        )
