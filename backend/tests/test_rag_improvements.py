"""
Testes unitários e de integração para as melhorias do pipeline RAG:
  - Busca híbrida (RRF + fallback vector)
  - Query rewriting
  - Re-ranking com cross-encoder
  - Streaming SSE (run_stream / send_message_stream)
  - Fixes do code review (len(clean_message), get_running_loop, timeout)
"""

from __future__ import annotations

import asyncio
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.ai.rag_chain import (
    RAGChain,
    RAGResult,
    RetrievedDocument,
    ESCALATION_MESSAGES,
    GREETING_RESPONSE,
    rag_chain,
)
from app.models.chatbot import ChatConversation, ChatMessage
from app.models.user import Base, User
from app.services.chat_service import (
    ChatService,
    MessageTooLongError,
    RateLimitExceededError,
)

# ── Infraestrutura de teste ────────────────────────────────────────────────────

TEST_DB_URL = "sqlite+aiosqlite:///:memory:"


@pytest_asyncio.fixture
async def db_engine():
    engine = create_async_engine(TEST_DB_URL, echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest_asyncio.fixture
async def db_session(db_engine):
    factory = async_sessionmaker(db_engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        yield session


@pytest_asyncio.fixture
async def sample_user(db_session: AsyncSession) -> User:
    user = User(
        id=uuid4(),
        name="Ana Teste",
        email="ana@test.com",
        password="hash_fake",
        role="client",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


def _make_doc(**kwargs) -> RetrievedDocument:
    defaults = dict(
        id=str(uuid4()),
        title="Doc de teste",
        content="Conteúdo de exemplo para testes",
        relevance_score=0.85,
        category="exercicio",
    )
    defaults.update(kwargs)
    return RetrievedDocument(**defaults)


# ── 1. Sanitização / Validação de comprimento ─────────────────────────────────

class TestMessageValidation:

    @pytest.mark.asyncio
    async def test_rejects_clean_message_over_limit(self, db_session, sample_user):
        """Fix #1: validação deve usar len(clean_message), não len(message)."""
        service = ChatService(db_session)
        # Cria mensagem que, após sanitização, excede MAX_MESSAGE_LENGTH
        # (500 chars por padrão). Usamos >500 chars para forçar o erro.
        long_message = "a" * 501
        with pytest.raises(MessageTooLongError):
            # Precisamos mock do rag_chain para não invocar DB real
            with patch("app.services.chat_service.rag_chain") as mock_rag:
                mock_rag.run = AsyncMock(return_value=RAGResult(
                    answer="ok", should_escalate=False
                ))
                await service.send_message(
                    user_id=sample_user.id,
                    message=long_message,
                )

    def test_sanitize_shortens_html_content(self):
        """Sanitização remove tags HTML e o resultado pode ser mais curto que o input."""
        service = ChatService.__new__(ChatService)
        raw = "<script>alert('xss')</script>" + "x" * 20
        result = service.sanitize_input(raw)
        assert "<script>" not in result
        assert len(result) <= 500

    def test_sanitize_removes_sql_injection(self):
        service = ChatService.__new__(ChatService)
        result = service.sanitize_input("SELECT * FROM users; DROP TABLE users;")
        assert "DROP" not in result
        assert "SELECT" not in result


# ── 2. Greeting fast-path ─────────────────────────────────────────────────────

class TestGreetingFastPath:

    @pytest.mark.asyncio
    async def test_greeting_returns_immediately(self):
        """Saudações não devem chamar o LLM."""
        chain = RAGChain()
        mock_session = AsyncMock(spec=AsyncSession)

        result = await chain.run(
            query="Olá!",
            session=mock_session,
            user_context={},
        )
        assert result.model_used == "greeting_fallback"
        assert result.should_escalate is False
        assert GREETING_RESPONSE in result.answer

    @pytest.mark.asyncio
    async def test_greeting_streaming_emits_done(self):
        """run_stream com saudação deve emitir evento done sem chunks."""
        chain = RAGChain()
        mock_session = AsyncMock(spec=AsyncSession)

        events = []
        async for event in chain.run_stream(query="oi!", session=mock_session):
            events.append(event)

        types = [e["type"] for e in events]
        assert "done" in types
        assert "chunk" not in types
        done = next(e for e in events if e["type"] == "done")
        assert done["should_escalate"] is False


# ── 3. _run_pipeline_setup — assinatura sem conversation_history ──────────────

class TestPipelineSetupSignature:

    @pytest.mark.asyncio
    async def test_setup_does_not_accept_conversation_history(self):
        """Fix #6: _run_pipeline_setup não deve ter param conversation_history."""
        import inspect
        sig = inspect.signature(RAGChain._run_pipeline_setup)
        assert "conversation_history" not in sig.parameters, (
            "_run_pipeline_setup não deve receber conversation_history — "
            "só é usado em augment() após o setup."
        )

    @pytest.mark.asyncio
    async def test_setup_greeting_fast_path(self):
        chain = RAGChain()
        mock_session = AsyncMock(spec=AsyncSession)
        result = await chain._run_pipeline_setup(
            query="bom dia",
            session=mock_session,
            academy_id=None,
            user_context={},
            start_time=0.0,
        )
        assert isinstance(result, RAGResult)
        assert result.model_used == "greeting_fallback"


# ── 4. Re-ranking ─────────────────────────────────────────────────────────────

class TestReranking:

    @pytest.mark.asyncio
    async def test_rerank_sorts_by_cross_encoder_score(self):
        """Rerank deve reordenar docs pelo score do cross-encoder."""
        chain = RAGChain()
        docs = [
            _make_doc(id="a", title="Agachamento", relevance_score=0.90),
            _make_doc(id="b", title="Supino", relevance_score=0.72),
            _make_doc(id="c", title="Nutrição", relevance_score=0.80),
        ]
        # cross_encoder.predict retorna scores: supino > agachamento > nutrição
        mock_ce = MagicMock()
        mock_ce.predict.return_value = [0.3, 0.9, 0.1]  # b > a > c

        with patch.object(chain, "_get_cross_encoder", return_value=mock_ce):
            reranked = await chain.rerank("como fazer supino", docs, top_k=2)

        assert reranked[0].id == "b"  # supino primeiro
        assert reranked[1].id == "a"  # agachamento segundo
        assert len(reranked) == 2  # top_k=2

    @pytest.mark.asyncio
    async def test_rerank_preserves_relevance_score(self):
        """relevance_score original deve ser preservado (usado na escalação)."""
        chain = RAGChain()
        original_score = 0.77
        docs = [_make_doc(relevance_score=original_score)]

        mock_ce = MagicMock()
        mock_ce.predict.return_value = [0.5]
        with patch.object(chain, "_get_cross_encoder", return_value=mock_ce):
            reranked = await chain.rerank("query", docs, top_k=1)

        assert reranked[0].relevance_score == original_score

    @pytest.mark.asyncio
    async def test_rerank_fallback_on_error(self):
        """Se o cross-encoder falhar, retorna os docs na ordem original."""
        chain = RAGChain()
        docs = [
            _make_doc(id="x", relevance_score=0.8),
            _make_doc(id="y", relevance_score=0.9),
        ]
        mock_ce = MagicMock()
        mock_ce.predict.side_effect = RuntimeError("model unavailable")

        with patch.object(chain, "_get_cross_encoder", return_value=mock_ce):
            result = await chain.rerank("query", docs, top_k=2)

        assert [d.id for d in result] == ["x", "y"]  # ordem preservada

    @pytest.mark.asyncio
    async def test_rerank_single_doc_skips_model(self):
        """Com ≤1 doc não deve chamar o cross-encoder."""
        chain = RAGChain()
        docs = [_make_doc()]
        mock_ce = MagicMock()
        with patch.object(chain, "_get_cross_encoder", return_value=mock_ce):
            result = await chain.rerank("query", docs, top_k=1)
        mock_ce.predict.assert_not_called()
        assert len(result) == 1


# ── 5. Escalonamento — lógica preservada após hybrid ─────────────────────────

class TestEscalationLogic:

    def test_health_risk_escalates_regardless_of_docs(self):
        chain = RAGChain()
        docs = [_make_doc(relevance_score=0.95)]
        should, reason = chain._should_escalate("sinto dor no peito", docs)
        assert should is True
        assert reason == "health_risk"

    def test_low_confidence_when_no_docs(self):
        chain = RAGChain()
        should, reason = chain._should_escalate("alguma dúvida", [], user_context={})
        assert should is True
        assert reason == "low_confidence"

    def test_personal_intent_skips_escalation_without_docs(self):
        chain = RAGChain()
        user_context = {"user_profile": {"name": "João"}}
        should, reason = chain._should_escalate(
            "qual é meu IMC?", [], user_context=user_context
        )
        assert should is False

    def test_too_complex_when_low_score(self):
        chain = RAGChain()
        docs = [_make_doc(relevance_score=0.55)]  # abaixo de ESCALATE_THRESHOLD=0.60
        should, reason = chain._should_escalate("pergunta difícil", docs)
        assert should is True
        assert reason == "too_complex"


# ── 6. Hybrid threshold — ajuste quando reranking desligado ──────────────────

class TestHybridThreshold:

    @pytest.mark.asyncio
    async def test_hybrid_fallback_to_vector_on_fts_error(self):
        """Se o FTS falhar, _retrieve_hybrid deve usar _retrieve_vector."""
        chain = RAGChain()
        mock_session = AsyncMock(spec=AsyncSession)
        # FTS falha
        mock_session.execute.side_effect = [
            Exception("FTS error"),
            # vector fallback: retorna ResultProxy vazio
        ]
        with patch.object(chain, "_retrieve_vector", new_callable=AsyncMock) as mock_vec:
            mock_vec.return_value = []
            result = await chain._retrieve_hybrid("agachamento", mock_session)
        mock_vec.assert_awaited_once()
        assert result == []


# ── 7. Streaming com timeout ──────────────────────────────────────────────────

class TestStreamingTimeout:

    @pytest.mark.asyncio
    async def test_run_stream_emits_chunks_then_done(self):
        """run_stream deve emitir eventos chunk e ao final um done."""
        chain = RAGChain()
        mock_session = AsyncMock(spec=AsyncSession)

        async def fake_setup(*args, **kwargs):
            return {
                "effective_query": "query",
                "retrieved_docs": [_make_doc()],
                "should_escalate": False,
                "escalation_reason": "",
            }

        async def fake_generate_stream(system_prompt, query):
            for word in ["O ", "agachamento ", "livre..."]:
                yield word

        with patch.object(chain, "_run_pipeline_setup", side_effect=fake_setup):
            with patch.object(chain, "augment", return_value="system_prompt"):
                with patch.object(chain, "generate_stream", side_effect=lambda *a: fake_generate_stream(*a)):
                    events = []
                    async for event in chain.run_stream(
                        query="como fazer agachamento?",
                        session=mock_session,
                    ):
                        events.append(event)

        types = [e["type"] for e in events]
        assert "chunk" in types
        assert "done" in types

        chunks = [e["content"] for e in events if e["type"] == "chunk"]
        full = "".join(chunks)
        assert full == "O agachamento livre..."

        done = next(e for e in events if e["type"] == "done")
        assert done["answer"] == full
        assert done["tokens_used"] > 0  # estimativa não deve ser 0

    @pytest.mark.asyncio
    async def test_run_stream_timeout_escalates(self):
        """Se o LLM não responder, deve emitir done com escalação de timeout."""
        chain = RAGChain()
        mock_session = AsyncMock(spec=AsyncSession)

        async def fake_setup(*args, **kwargs):
            return {
                "effective_query": "query",
                "retrieved_docs": [_make_doc()],
                "should_escalate": False,
                "escalation_reason": "",
            }

        async def slow_generate(system_prompt, query):
            await asyncio.sleep(999)  # nunca termina
            yield "never"

        with patch("app.config.settings.settings.CHAT_MAX_RESPONSE_LATENCY_MS", 100):
            with patch.object(chain, "_run_pipeline_setup", side_effect=fake_setup):
                with patch.object(chain, "augment", return_value="sp"):
                    with patch.object(chain, "generate_stream", side_effect=lambda *a: slow_generate(*a)):
                        events = []
                        async for event in chain.run_stream(
                            query="pergunta lenta",
                            session=mock_session,
                        ):
                            events.append(event)

        done = next((e for e in events if e["type"] == "done"), None)
        assert done is not None
        assert done["should_escalate"] is True
        assert done["escalation_reason"] == "timeout"

    @pytest.mark.asyncio
    async def test_run_stream_generation_error_escalates(self):
        """Exceção no LLM deve emitir done com generation_error."""
        chain = RAGChain()
        mock_session = AsyncMock(spec=AsyncSession)

        async def fake_setup(*args, **kwargs):
            return {
                "effective_query": "q",
                "retrieved_docs": [_make_doc()],
                "should_escalate": False,
                "escalation_reason": "",
            }

        async def failing_generate(sp, q):
            raise RuntimeError("groq down")
            yield  # torna função um async generator

        with patch.object(chain, "_run_pipeline_setup", side_effect=fake_setup):
            with patch.object(chain, "augment", return_value="sp"):
                with patch.object(chain, "generate_stream", side_effect=lambda *a: failing_generate(*a)):
                    events = []
                    async for event in chain.run_stream(
                        query="pergunta qualquer",
                        session=mock_session,
                    ):
                        events.append(event)

        done = next((e for e in events if e["type"] == "done"), None)
        assert done is not None
        assert done["should_escalate"] is True
        assert done["escalation_reason"] == "generation_error"


# ── 8. send_message_stream — ponta a ponta com mock ──────────────────────────

class TestSendMessageStream:

    @pytest.mark.asyncio
    async def test_stream_yields_chunks_and_final(self, db_session, sample_user):
        """send_message_stream deve yield chunks + evento final com IDs."""

        async def fake_run_stream(**kwargs):
            yield {"type": "status", "status": "thinking", "message": "..."}
            yield {"type": "chunk", "content": "Resposta "}
            yield {"type": "chunk", "content": "completa."}
            yield {
                "type": "done",
                "answer": "Resposta completa.",
                "retrieved_documents": [],
                "should_escalate": False,
                "escalation_reason": "",
                "model_used": "llama",
                "tokens_used": 5,
                "latency_ms": 300,
                "confidence_score": 0.9,
                "query_rewritten": "query",
            }

        service = ChatService(db_session)
        with patch("app.services.chat_service.rag_chain") as mock_rag:
            mock_rag.run_stream = fake_run_stream
            events = []
            async for event in service.send_message_stream(
                user_id=sample_user.id,
                message="Como faço agachamento?",
            ):
                events.append(event)

        types = [e["type"] for e in events]
        assert "chunk" in types
        assert "final" in types

        final = next(e for e in events if e["type"] == "final")
        assert "message_id" in final
        assert "conversation_id" in final
        assert final["content"] == "Resposta completa."
        assert final["escalation"] is None

    @pytest.mark.asyncio
    async def test_stream_rate_limit_raises_before_yield(self, db_session, sample_user):
        """RateLimitExceededError deve ser levantado ANTES do primeiro yield."""
        service = ChatService(db_session)
        with patch.object(service, "_check_rate_limit", side_effect=RateLimitExceededError("limite")):
            with pytest.raises(RateLimitExceededError):
                # O código antes do primeiro yield deve levantar a exceção
                gen = service.send_message_stream(
                    user_id=sample_user.id,
                    message="olá",
                )
                await gen.__anext__()

    @pytest.mark.asyncio
    async def test_stream_message_too_long_raises(self, db_session, sample_user):
        """Mensagem longa deve levantar MessageTooLongError antes do yield."""
        service = ChatService(db_session)
        with pytest.raises(MessageTooLongError):
            gen = service.send_message_stream(
                user_id=sample_user.id,
                message="x" * 501,
            )
            await gen.__anext__()


# ── 9. Validate ───────────────────────────────────────────────────────────────

class TestValidate:

    def test_empty_answer_is_invalid(self):
        chain = RAGChain()
        is_valid, needs_review = chain.validate("", [])
        assert is_valid is False
        assert needs_review is True

    def test_short_answer_is_invalid(self):
        chain = RAGChain()
        is_valid, _ = chain.validate("ok", [])
        assert is_valid is False

    def test_normal_answer_is_valid(self):
        chain = RAGChain()
        is_valid, needs_review = chain.validate(
            "O agachamento livre deve ser executado com a coluna reta.", []
        )
        assert is_valid is True
        assert needs_review is False


# ── 10. RRF score no RetrievedDocument ───────────────────────────────────────

class TestRetrievedDocumentFields:

    def test_rrf_score_defaults_to_zero(self):
        doc = RetrievedDocument(
            id="1", title="t", content="c", relevance_score=0.8
        )
        assert doc.rrf_score == 0.0

    def test_rrf_score_set_correctly(self):
        doc = _make_doc(rrf_score=0.025)
        assert doc.rrf_score == 0.025
