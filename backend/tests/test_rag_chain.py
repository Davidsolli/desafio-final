"""
Testes unitários para o pipeline RAG (app/ai/rag_chain.py).

Todos os testes usam mocks para as chamadas ao Groq (LLM) e ao HuggingFace
(embeddings), garantindo que nenhuma requisição real seja feita durante a execução.
"""

from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession

from app.ai.rag_chain import (
    ESCALATE_THRESHOLD,
    MIN_RELEVANCE_SCORE,
    RAGChain,
    RAGResult,
    RetrievedDocument,
    rag_chain,
)


# ── Fixtures ──────────────────────────────────────────────────────────────────

@pytest.fixture
def chain() -> RAGChain:
    """Instância limpa do RAGChain para cada teste."""
    return RAGChain()


@pytest.fixture
def mock_session() -> AsyncMock:
    """Sessão de banco de dados mockada."""
    return AsyncMock(spec=AsyncSession)


@pytest.fixture
def sample_docs() -> list[RetrievedDocument]:
    """Documentos de exemplo com score alto (≥ 0.7)."""
    return [
        RetrievedDocument(
            id=str(uuid4()),
            title="Como fazer Supino Reto",
            content="O supino reto é um exercício para o peitoral maior...",
            relevance_score=0.92,
            category="exercicio",
            muscle_group="Peito",
        ),
        RetrievedDocument(
            id=str(uuid4()),
            title="Execução do Supino com Halteres",
            content="Deite no banco com os halteres na altura do peito...",
            relevance_score=0.85,
            category="forma",
            muscle_group="Peito",
        ),
    ]


@pytest.fixture
def user_context() -> dict:
    """Contexto de aluno de exemplo."""
    return {
        "user_profile": {
            "name": "João Silva",
            "role": "client",
            "level": "intermediario",
            "objective": "hipertrofia",
        },
        "active_workout_sheet": {
            "name": "Treino A - Peito/Tríceps",
            "exercises": [
                {"name": "Supino Reto", "sets": "4", "reps": "10"},
                {"name": "Crucifixo", "sets": "3", "reps": "12"},
            ],
        },
    }


# ── Testes: Lazy Init (Groq + HuggingFace) ────────────────────────────────────


class TestLazyInit:
    """Inicialização lazy dos clients Groq e HuggingFace."""

    @patch("app.ai.rag_chain.HuggingFaceEmbeddings")
    def test_get_embeddings_creates_once(self, mock_embed_cls, chain):
        """_get_embeddings() deve criar instância apenas na primeira chamada."""
        mock_embed_cls.return_value = MagicMock()

        emb1 = chain._get_embeddings()
        emb2 = chain._get_embeddings()

        assert emb1 is emb2
        mock_embed_cls.assert_called_once()
        # Verifica que usa o modelo correto da HuggingFace
        kwargs = mock_embed_cls.call_args.kwargs
        assert "all-MiniLM-L6-v2" in kwargs.get("model_name", "")

    @patch("app.ai.rag_chain.ChatGroq")
    @patch("app.ai.rag_chain.settings")
    def test_get_llm_creates_once(self, mock_settings, mock_llm_cls, chain):
        """_get_llm() deve criar instância apenas na primeira chamada usando ChatGroq."""
        mock_settings.GROQ_API_KEY = "fake-key"
        mock_settings.GROQ_MODEL = "llama-3.3-70b-versatile"
        mock_llm_cls.return_value = MagicMock()

        llm1 = chain._get_llm()
        llm2 = chain._get_llm()

        assert llm1 is llm2
        mock_llm_cls.assert_called_once()


# ── Testes: retrieve() ─────────────────────────────────────────────────────────

class TestRetrieve:
    """Testa a etapa RETRIEVE do pipeline RAG."""

    @pytest.mark.asyncio
    async def test_retrieve_returns_docs_above_threshold(self, chain, mock_session):
        """Deve retornar apenas documentos com score ≥ 0.70 (RN-06)."""
        doc_id = str(uuid4())

        # Mock embedding
        mock_embed = AsyncMock()
        mock_embed.aembed_query = AsyncMock(return_value=[0.1] * 384)
        chain._embeddings = mock_embed

        # Mock resultado do banco — dois docs, scores 0.85 e 0.50
        row_high = MagicMock()
        row_high.id = doc_id
        row_high.title = "Supino Reto"
        row_high.content = "Conteúdo do supino..."
        row_high.category = "exercicio"
        row_high.muscle_group = "Peito"
        row_high.relevance_score = 0.85

        row_low = MagicMock()
        row_low.id = str(uuid4())
        row_low.title = "Agachamento"
        row_low.content = "Conteúdo do agachamento..."
        row_low.category = "exercicio"
        row_low.muscle_group = "Perna"
        row_low.relevance_score = 0.50  # abaixo do threshold → deve ser filtrado

        mock_result = MagicMock()
        mock_result.fetchall.return_value = [row_high, row_low]
        mock_session.execute = AsyncMock(return_value=mock_result)

        docs = await chain.retrieve("Como faço supino?", mock_session)

        assert len(docs) == 1
        assert docs[0].id == doc_id
        assert docs[0].relevance_score == 0.85

    @pytest.mark.asyncio
    async def test_retrieve_returns_empty_when_no_match(self, chain, mock_session):
        """Deve retornar lista vazia quando nenhum doc atinge score mínimo (RN-07)."""
        mock_embed = AsyncMock()
        mock_embed.aembed_query = AsyncMock(return_value=[0.1] * 384)
        chain._embeddings = mock_embed

        row_low = MagicMock()
        row_low.id = str(uuid4())
        row_low.title = "Doc irrelevante"
        row_low.content = "..."
        row_low.category = "exercicio"
        row_low.muscle_group = ""
        row_low.relevance_score = 0.40

        mock_result = MagicMock()
        mock_result.fetchall.return_value = [row_low]
        mock_session.execute = AsyncMock(return_value=mock_result)

        docs = await chain.retrieve("Pergunta sem match", mock_session)

        assert docs == []

    @pytest.mark.asyncio
    async def test_retrieve_handles_embedding_error(self, chain, mock_session):
        """Deve retornar lista vazia em caso de erro no embedding (resiliência)."""
        mock_embed = AsyncMock()
        mock_embed.aembed_query = AsyncMock(side_effect=Exception("API error"))
        chain._embeddings = mock_embed

        docs = await chain.retrieve("Qualquer pergunta", mock_session)

        assert docs == []

    @pytest.mark.asyncio
    async def test_retrieve_handles_db_error(self, chain, mock_session):
        """Deve retornar lista vazia em caso de erro no banco."""
        mock_embed = AsyncMock()
        mock_embed.aembed_query = AsyncMock(return_value=[0.1] * 384)
        chain._embeddings = mock_embed

        mock_session.execute = AsyncMock(side_effect=Exception("DB error"))

        docs = await chain.retrieve("Qualquer pergunta", mock_session)

        assert docs == []

    @pytest.mark.asyncio
    async def test_retrieve_filters_by_academy_id(self, chain, mock_session):
        """Deve passar academy_id como parâmetro ao banco quando fornecido."""
        mock_embed = AsyncMock()
        mock_embed.aembed_query = AsyncMock(return_value=[0.1] * 384)
        chain._embeddings = mock_embed

        mock_result = MagicMock()
        mock_result.fetchall.return_value = []
        mock_session.execute = AsyncMock(return_value=mock_result)

        academy_id = str(uuid4())
        await chain.retrieve("Pergunta", mock_session, academy_id=academy_id)

        # Verificar que execute foi chamado com os parâmetros corretos
        call_args = mock_session.execute.call_args
        params = call_args[0][1]  # segundo argumento posicional
        assert "academy_id" in params
        assert params["academy_id"] == academy_id


# ── Testes: augment() ─────────────────────────────────────────────────────────

class TestAugment:
    """Testa a etapa AUGMENT — montagem do prompt."""

    def test_augment_includes_user_profile(self, chain, sample_docs, user_context):
        """Prompt deve conter informações do perfil do aluno."""
        prompt = chain.augment("Como faço supino?", sample_docs, user_context, [])

        assert "João Silva" in prompt
        assert "intermediario" in prompt
        assert "hipertrofia" in prompt

    def test_augment_includes_workout_sheet(self, chain, sample_docs, user_context):
        """Prompt deve conter exercícios da ficha ativa."""
        prompt = chain.augment("Como faço supino?", sample_docs, user_context, [])

        assert "Treino A" in prompt
        assert "Supino Reto" in prompt

    def test_augment_includes_retrieved_docs(self, chain, sample_docs, user_context):
        """Prompt deve conter conteúdo dos documentos recuperados."""
        prompt = chain.augment("Como faço supino?", sample_docs, user_context, [])

        assert "Como fazer Supino Reto" in prompt
        assert "0.92" in prompt  # relevance score formatado

    def test_augment_includes_conversation_history(self, chain, sample_docs, user_context):
        """Prompt deve incluir histórico recente da conversa."""
        history = [
            {"role": "user", "content": "Tenho dúvida sobre supino"},
            {"role": "assistant", "content": "Posso ajudar com supino!"},
        ]
        prompt = chain.augment("Como faço supino?", sample_docs, user_context, history)

        assert "Aluno" in prompt or "Assistente" in prompt

    def test_augment_no_docs_message(self, chain, user_context):
        """Deve informar no prompt quando não há documentos recuperados."""
        prompt = chain.augment("Pergunta obscura", [], user_context, [])

        assert "Nenhum documento relevante" in prompt

    def test_augment_no_workout_sheet(self, chain, sample_docs):
        """Deve lidar com ausência de ficha ativa."""
        ctx = {"user_profile": {"name": "Maria"}, "active_workout_sheet": None}
        prompt = chain.augment("Pergunta", sample_docs, ctx, [])

        assert "Nenhuma ficha ativa" in prompt

    def test_augment_limits_history_to_recent(self, chain, sample_docs, user_context):
        """Deve usar apenas as últimas 6 mensagens do histórico (RN-05)."""
        history = [
            {"role": "user" if i % 2 == 0 else "assistant", "content": f"msg {i}"}
            for i in range(20)
        ]
        prompt = chain.augment("Pergunta", sample_docs, user_context, history)

        # "msg 19" deve estar, "msg 0" não deve
        assert "msg 19" in prompt
        assert "msg 0" not in prompt


# ── Testes: _should_escalate() ────────────────────────────────────────────────

class TestShouldEscalate:
    """Testa detecção de escalação (RN-11, RN-12, RN-17)."""

    def test_escalate_on_personal_keyword(self, chain, sample_docs):
        """Deve escalar quando usuário pede para falar com Personal (RN-12)."""
        should, reason = chain._should_escalate("quero falar com personal", sample_docs)
        assert should is True
        assert reason == "user_requested"

    def test_escalate_on_health_risk(self, chain, sample_docs):
        """Deve escalar em menção a risco de saúde com reason='health_risk' (RN-17, Etapa 3)."""
        should, reason = chain._should_escalate("estou com dor no peito", sample_docs)
        assert should is True
        assert reason == "health_risk"

    def test_escalate_on_no_docs(self, chain):
        """Deve escalar quando não há documentos relevantes (RN-07)."""
        should, reason = chain._should_escalate("pergunta técnica avançada", [])
        assert should is True
        assert reason == "low_confidence"

    def test_escalate_on_low_score_docs(self, chain):
        """Deve escalar quando o melhor doc tem score < ESCALATE_THRESHOLD."""
        low_docs = [
            RetrievedDocument(
                id=str(uuid4()), title="Doc", content="...",
                relevance_score=0.55,  # abaixo de ESCALATE_THRESHOLD (0.60)
            )
        ]
        should, reason = chain._should_escalate("pergunta complexa", low_docs)
        assert should is True
        assert reason == "too_complex"

    def test_no_escalate_normal_question(self, chain, sample_docs):
        """Não deve escalar para pergunta normal com docs relevantes."""
        should, reason = chain._should_escalate(
            "como faço supino reto corretamente?", sample_docs
        )
        assert should is False
        assert reason == ""

    def test_escalate_lesao_keyword(self, chain, sample_docs):
        """Deve escalar em menção a lesão (RN-17)."""
        should, reason = chain._should_escalate(
            "tenho uma lesão no ombro, como treino?", sample_docs
        )
        assert should is True

    def test_escalate_nao_entendi_keyword(self, chain, sample_docs):
        """Deve escalar quando usuário diz não entendeu (RN-12)."""
        should, reason = chain._should_escalate("não entendi a resposta", sample_docs)
        assert should is True


# ── Testes: validate() ────────────────────────────────────────────────────────

class TestValidate:
    """Testa a etapa VALIDATE."""

    def test_valid_answer(self, chain, sample_docs):
        """Resposta com conteúdo adequado deve ser válida."""
        answer = "O supino reto é executado deitado no banco com a barra..."
        is_valid, needs_review = chain.validate(answer, sample_docs)
        assert is_valid is True
        assert needs_review is False

    def test_empty_answer_is_invalid(self, chain, sample_docs):
        """Resposta vazia deve ser inválida e marcada para review."""
        is_valid, needs_review = chain.validate("", sample_docs)
        assert is_valid is False
        assert needs_review is True

    def test_very_short_answer_is_invalid(self, chain, sample_docs):
        """Resposta muito curta (< 20 chars) deve ser inválida."""
        is_valid, needs_review = chain.validate("ok", sample_docs)
        assert is_valid is False
        assert needs_review is True

    def test_uncertainty_answer_needs_review(self, chain, sample_docs):
        """Resposta com marcador de incerteza deve precisar de review."""
        answer = "Não posso responder com segurança sobre este exercício específico."
        is_valid, needs_review = chain.validate(answer, sample_docs)
        assert is_valid is True
        assert needs_review is True


# ── Testes: generate() ────────────────────────────────────────────────────────

class TestGenerate:
    """Testa a etapa GENERATE — integração com LLM mockado."""

    @pytest.mark.asyncio
    async def test_generate_returns_answer(self, chain):
        """Deve retornar a resposta do LLM corretamente."""
        mock_llm = AsyncMock()
        mock_response = MagicMock()
        mock_response.content = "O supino reto é um exercício fundamental..."
        mock_response.usage_metadata = None
        mock_llm.ainvoke = AsyncMock(return_value=mock_response)
        chain._llm = mock_llm

        # Mock do parser
        with patch("app.ai.rag_chain.StrOutputParser") as mock_parser_cls:
            mock_parser = AsyncMock()
            mock_parser.ainvoke = AsyncMock(return_value="O supino reto é um exercício fundamental...")
            mock_parser_cls.return_value = mock_parser

            answer, tokens, model = await chain.generate("system prompt", "Como faço supino?")

        assert "supino" in answer.lower()
        assert isinstance(tokens, int)

    @pytest.mark.asyncio
    async def test_generate_raises_on_llm_error(self, chain):
        """Deve propagar exceção quando o LLM falha."""
        mock_llm = AsyncMock()
        mock_llm.ainvoke = AsyncMock(side_effect=Exception("LLM unavailable"))
        chain._llm = mock_llm

        with pytest.raises(Exception, match="LLM unavailable"):
            await chain.generate("system prompt", "Pergunta?")


# ── Testes: run() — Pipeline Completo ─────────────────────────────────────────

class TestGreetingFastPath:
    """Saudações curtas devem retornar resposta direta sem chamar LLM nem retrieve."""

    @pytest.mark.parametrize(
        "greeting",
        [
            "olá",
            "Olá!",
            "oi",
            "Oi!",
            "Bom dia",
            "boa tarde",
            "Boa noite!",
            "tudo bem?",
            "tudo bom",
            "obrigado",
            "obrigada",
            "valeu",
            "tchau",
            "até mais",
        ],
    )
    @pytest.mark.asyncio
    async def test_greeting_returns_direct_response(self, chain, mock_session, greeting):
        """Saudações conhecidas devolvem resposta amigável sem ir ao LLM ou retrieve."""
        chain.retrieve = AsyncMock()
        chain.generate = AsyncMock()

        result = await chain.run(query=greeting, session=mock_session)

        assert isinstance(result, RAGResult)
        assert result.should_escalate is False
        assert result.model_used == "greeting_fallback"
        assert "OmniConnect" in result.answer or "assistente" in result.answer.lower()
        # Nem retrieve nem generate devem ter sido chamados
        chain.retrieve.assert_not_called()
        chain.generate.assert_not_called()

    @pytest.mark.asyncio
    async def test_non_greeting_does_not_use_fast_path(self, chain, mock_session, sample_docs):
        """Pergunta normal não deve cair no fast-path de saudação."""
        chain.retrieve = AsyncMock(return_value=sample_docs)
        chain.generate = AsyncMock(return_value=(
            "Resposta sobre o exercício.", 50, "llama-3.3-70b-versatile",
        ))

        result = await chain.run(query="Como faço supino reto?", session=mock_session)

        assert result.model_used != "greeting_fallback"
        chain.retrieve.assert_called_once()


class TestRunPipeline:
    """Testa o pipeline RAG completo (run())."""

    @pytest.mark.asyncio
    async def test_run_success_with_relevant_docs(self, chain, mock_session, user_context, sample_docs):
        """Fluxo completo deve retornar RAGResult com resposta e docs (não escalar)."""
        # Mock retrieve
        chain.retrieve = AsyncMock(return_value=sample_docs)
        # Mock generate
        chain.generate = AsyncMock(return_value=(
            "O supino reto deve ser executado com as escápulas retraídas...",
            120,
            "llama-3.3-70b-versatile",
        ))

        result = await chain.run(
            query="Como faço supino reto?",
            session=mock_session,
            user_context=user_context,
        )

        assert isinstance(result, RAGResult)
        assert result.should_escalate is False
        assert "supino" in result.answer.lower()
        assert len(result.retrieved_documents) == 2
        assert result.model_used == "llama-3.3-70b-versatile"
        assert result.tokens_used == 120
        assert result.latency_ms >= 0
        assert result.confidence_score > 0

    @pytest.mark.asyncio
    async def test_run_escalates_when_no_docs(self, chain, mock_session):
        """Deve escalar imediatamente quando retrieve retorna lista vazia e a IA não sabe responder."""
        chain.retrieve = AsyncMock(return_value=[])
        chain.generate = AsyncMock(return_value=("Não sei informar", 10, "llama-3.3-70b-versatile"))

        result = await chain.run(
            query="pergunta sem match na base",
            session=mock_session,
        )

        assert result.should_escalate is True
        assert result.escalation_reason in ("low_confidence", "too_complex", "validation_failed")
        assert result.retrieved_documents == []

    @pytest.mark.asyncio
    async def test_run_escalates_on_personal_keyword(self, chain, mock_session, sample_docs):
        """Deve escalar quando usuário pede Personal, mesmo com docs relevantes."""
        chain.retrieve = AsyncMock(return_value=sample_docs)
        # generate não deve ser chamado em caso de escalação por keyword
        chain.generate = AsyncMock()

        result = await chain.run(
            query="quero falar com personal",
            session=mock_session,
        )

        assert result.should_escalate is True
        assert result.escalation_reason == "user_requested"

    @pytest.mark.asyncio
    async def test_run_escalates_on_health_risk(self, chain, mock_session, sample_docs):
        """Deve escalar em situação de risco de saúde (RN-17)."""
        chain.retrieve = AsyncMock(return_value=sample_docs)

        result = await chain.run(
            query="estou com dor no peito ao treinar",
            session=mock_session,
        )

        assert result.should_escalate is True

    @pytest.mark.asyncio
    async def test_run_handles_generate_error_gracefully(self, chain, mock_session, sample_docs):
        """Deve escalar com mensagem amigável quando LLM falha."""
        chain.retrieve = AsyncMock(return_value=sample_docs)
        chain.generate = AsyncMock(side_effect=Exception("Timeout"))

        result = await chain.run(
            query="Como faço supino?",
            session=mock_session,
        )

        assert result.should_escalate is True
        assert result.escalation_reason == "generation_error"
        # Nova mensagem contextualizada por reason (Etapa 3, ESCALATION_MESSAGES)
        assert "Personal" in result.answer or "técnico" in result.answer

    @pytest.mark.asyncio
    async def test_run_calculates_confidence_score(self, chain, mock_session, user_context, sample_docs):
        """confidence_score deve ser a média dos scores dos documentos recuperados."""
        chain.retrieve = AsyncMock(return_value=sample_docs)
        chain.generate = AsyncMock(return_value=(
            "Resposta adequada sobre o exercício solicitado...", 80, "llama-3.3-70b-versatile"
        ))

        result = await chain.run("Como faço supino?", mock_session, user_context=user_context)

        expected = round(sum(d.relevance_score for d in sample_docs) / len(sample_docs), 4)
        assert result.confidence_score == expected
