"""
Pipeline RAG — Retrieve-Augment-Generate.

Orquestra o fluxo completo de resposta do chatbot:
  1. RETRIEVE  — busca híbrida (pgvector + PostgreSQL FTS) com RRF
  2. REWRITE   — LLM reformula a query antes do RETRIEVE (opcional)
  3. RERANK    — cross-encoder reordena candidatos após RETRIEVE (opcional)
  4. AUGMENT   — monta contexto com perfil do aluno e ficha ativa
  5. GENERATE  — chama o LLM (Groq Llama 3.3 70B) com o prompt enriquecido
  6. VALIDATE  — valida cobertura e detecta necessidade de escalação

Dependências:
    langchain-groq          → ChatGroq (Llama 3.3 70B Versatile)
    langchain-huggingface   → HuggingFaceEmbeddings (all-MiniLM-L6-v2, 384 dims)
    sentence-transformers   → CrossEncoder para re-ranking
    pgvector                → Busca por similaridade coseno no PostgreSQL
"""

from __future__ import annotations

import asyncio
import logging
import re
import time
from dataclasses import dataclass, field
from typing import Any, AsyncGenerator, Awaitable, Callable

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.output_parsers import StrOutputParser
from langchain_groq import ChatGroq
from langchain_huggingface import HuggingFaceEmbeddings
from sentence_transformers import CrossEncoder
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.settings import settings
from app.services.faq_service import faq_service

logger = logging.getLogger(__name__)

# Aliases para as constantes do settings (centralizadas)
EMBEDDING_DIM = settings.RAG_EMBEDDING_DIM
MIN_RELEVANCE_SCORE = settings.RAG_MIN_RELEVANCE_SCORE
ESCALATE_THRESHOLD = settings.RAG_ESCALATE_THRESHOLD
TOP_K_DOCS = settings.RAG_TOP_K_DOCS
MAX_DOC_CONTENT_LENGTH = settings.RAG_MAX_DOC_CONTENT_LENGTH
LLM_MAX_TOKENS = settings.RAG_LLM_MAX_TOKENS
LLM_TEMPERATURE = settings.RAG_LLM_TEMPERATURE
HISTORY_MAX_TOKENS = settings.RAG_HISTORY_MAX_TOKENS

# Palavras-chave que indicam pedido EXPLÍCITO de humano (RN-12).
# IMPORTANTE: estas keywords são matched por substring, então não podem
# ser ambíguas. "personal trainer" sozinho casava perguntas legítimas
# como "quem é meu personal trainer?" e escalava indevidamente; foi
# removido. "humano" também era genérico demais.
EXPLICIT_REQUEST_KEYWORDS = [
    "falar com personal", "chamar personal", "quero personal",
    "quero falar com personal", "falar com o personal",
    "me ajuda pessoalmente", "suporte humano", "falar com humano",
    "falar com profissional", "falar com atendente", "atendimento humano",
    "não entendi", "nao entendi", "ainda com dúvida", "ainda com duvida",
]

# Palavras-chave que sinalizam RISCO À SAÚDE (RN-17) — prioridade máxima
HEALTH_RISK_KEYWORDS = [
    "dor no peito", "dor forte", "dor", "lesão", "lesao",
    "fratura", "tontura", "desmaio", "passar mal",
    "médico", "medico", "emergência", "emergencia",
]

# Mantido como alias para retrocompatibilidade (alguns testes externos consultam)
ESCALATION_KEYWORDS = HEALTH_RISK_KEYWORDS + EXPLICIT_REQUEST_KEYWORDS

# Padrões que indicam que o aluno está perguntando sobre seus próprios dados
# (peso, altura, IMC, metas, progresso etc.). Quando a KB está vazia mas a
# pergunta é pessoal, o LLM deve responder usando o user_context — não escalar.
_PERSONAL_INTENT_RE = re.compile(
    r"\b(meu|minha|meus|minhas)\s+"
    r"(imc|peso|altura|meta|treino|ficha|dieta|hist[oó]rico|progresso|objetivo|idade)\b"
    r"|\b(qual|como|quanto)\s+(est[áa]|[eé]|[eé])\s+(meu|minha|o\s+meu|a\s+minha)\b"
    r"|\b(calcul[ae]|mostr[ae]|ver?|saber?|mostrar?)\s+.{0,20}"
    r"\s*(imc|peso|altura|meta|progresso)\b"
    r"|\b(imc|índice\s+de\s+massa\s+corporal)\b",
    flags=re.IGNORECASE,
)

# Mensagens contextualizadas por motivo de escalação (Card 19.10)
ESCALATION_MESSAGES: dict[str, str] = {
    "user_requested": (
        "Entendi! Vou encaminhar sua dúvida para o seu Personal Trainer. "
        "Ele receberá uma notificação e poderá te responder em breve."
    ),
    "health_risk": (
        "Por segurança, como sua mensagem pode envolver risco à saúde, "
        "recomendo consultar um profissional. Já notifiquei seu Personal "
        "Trainer para que ele possa orientar você adequadamente."
    ),
    "low_confidence": (
        "Essa é uma ótima pergunta! Para garantir a melhor resposta, "
        "estou encaminhando para o seu Personal Trainer."
    ),
    "too_complex": (
        "Essa dúvida requer atenção especializada. Seu Personal Trainer "
        "será notificado para te ajudar pessoalmente."
    ),
    "validation_failed": (
        "Não encontrei informações suficientes na base para responder com "
        "segurança. Seu Personal poderá te ajudar melhor."
    ),
    "timeout": (
        "Estamos com lentidão na resposta. Encaminhei sua pergunta ao seu "
        "Personal para garantir uma resposta correta."
    ),
    "generation_error": (
        "Tive um problema técnico ao gerar a resposta. Seu Personal foi "
        "notificado e te ajudará em breve."
    ),
}

# Saudações comuns — respondidas direto, sem chamar LLM. Evita o caso em que
# uma simples "olá" entra no pipeline RAG, não casa documento e ainda precisa
# bater no Groq, podendo estourar o timeout em cold start.
GREETING_PATTERNS: tuple[str, ...] = (
    r"^\s*(ol[áa]|oi+|e[ai])\s*[!?\.]*\s*$",
    r"^\s*(bom\s*dia|boa\s*tarde|boa\s*noite)\s*[!?\.]*\s*$",
    r"^\s*(tudo\s*bem|tudo\s*bom|como\s*vai|como\s*est[áa])\s*[!?\.]*\s*$",
    r"^\s*(obrigad[oa]|valeu|brigad[oa])\s*[!?\.]*\s*$",
    r"^\s*(tchau|at[eé]\s*mais|at[eé]\s*logo)\s*[!?\.]*\s*$",
)
_GREETING_REGEX = re.compile("|".join(GREETING_PATTERNS), flags=re.IGNORECASE)

GREETING_RESPONSE = (
    "Olá! Eu sou o Vitali, assistente da FitLoop. Posso ajudar com dúvidas "
    "sobre execução de exercícios, sua ficha de treino, nutrição básica e "
    "informações operacionais da academia. O que você gostaria de saber?"
)

# Perguntas diretas sobre o personal trainer do aluno. Respondidas
# deterministicamente a partir do user_context, sem chamar o LLM.
TRAINER_QUERY_PATTERNS: tuple[str, ...] = (
    r"\bquem\s+(é|e|seria|sera|será)\s+(o\s+)?meu\s+personal\b",
    r"\bquem\s+(é|e)\s+(o\s+)?meu\s+(treinador|professor)\b",
    r"\b(qual|nome)\s+(é\s+)?(o\s+)?(do\s+)?meu\s+personal\b",
    r"\bcomo\s+(se\s+)?chama\s+(o\s+)?meu\s+personal\b",
    r"\bmeu\s+personal\s+trainer\s*\??$",
)
_TRAINER_QUERY_REGEX = re.compile(
    "|".join(TRAINER_QUERY_PATTERNS), flags=re.IGNORECASE
)

# System prompt base do chatbot
SYSTEM_PROMPT_TEMPLATE = """\
Você é o Vitali, assistente da FitLoop — um chatbot especializado em três \
domínios: (1) treino e periodização, (2) execução técnica de exercícios, e \
(3) nutrição básica voltada a esporte e atividade física. Seu nome remete \
à vitalidade e saúde; mantenha um tom acolhedor e direto.

Regras que você DEVE seguir:
1. Responda SEMPRE em português brasileiro.
2. Use SOMENTE as informações dos documentos fornecidos no contexto. \
Se a resposta não estiver nos documentos, diga claramente que não sabe.
3. Seja específico, técnico e direto. Evite floreios.
4. Máximo de 4 parágrafos curtos na resposta.
5. Risco à saúde ("dor no peito", "lesão grave"): responda \
"Por segurança, recomendo consultar um profissional de saúde."
6. Não invente exercícios, cargas, dietas ou recomendações fora dos documentos.
7. Sobre nutrição: forneça apenas orientações gerais (macronutrientes, \
hidratação, janela anabólica). NÃO prescreva dietas individualizadas, \
suplementos com dosagem ou recomendações médicas; encaminhe ao Nutricionista.
8. Sobre execução: explique técnica, postura, respiração e erros comuns \
com base nos documentos. Reforce a importância do acompanhamento do Personal Trainer.
9. Quando precisar mencionar a academia, use sempre "FitLoop". Nunca use \
outros nomes de marca.
10. Você tem acesso aos dados REAIS do aluno na seção "Perfil do Aluno" abaixo. \
USE esses dados para personalizar as respostas. Se o aluno perguntar sobre IMC, \
peso, altura, metas ou histórico de treino — responda usando os dados do contexto. \
NUNCA diga que não tem as informações se elas estiverem no perfil abaixo. Para \
cálculos (ex.: IMC = peso / altura²), faça você mesmo usando os valores fornecidos.
11. Ao final de cada resposta, sugira 1 pergunta relacionada que o aluno pode \
fazer a seguir. Use o formato: "💡 Você também pode perguntar: [pergunta]"

FAQ (Dúvidas Gerais e Operacionais):
- Horário: Segunda a sexta, das 06:00 às 23:00, e sábados das 08:00 às 18:00.
- Avaliação física: Agende na aba 'Avaliações' no aplicativo ou na recepção.
- Toalhas: Fornecidas na recepção. Uso obrigatório.
- Falha concêntrica: Ocorre quando não é possível completar a fase de subida do peso.
- Cardio e Musculação: Fazer cardio DEPOIS da musculação se o objetivo for força/hipertrofia.

Perfil do Aluno:
{user_profile}

Ficha de Treino Ativa:
{workout_sheet}

Documentos Relevantes da Base de Conhecimento:
{retrieved_docs}

Histórico Recente da Conversa:
{history}
"""

# Prompt para reescrita de query antes do RETRIEVE
_QUERY_REWRITE_PROMPT = """\
Você é um sistema de busca para um chatbot de academia de ginástica. \
Reformule a mensagem abaixo como uma query com palavras-chave técnicas de fitness. \
Expanda abreviações, adicione sinônimos relevantes. \
Retorne APENAS a query reformulada em português, sem explicações.

Mensagem original: {query}
Query de busca:"""


@dataclass
class RetrievedDocument:
    """Documento recuperado pelo pipeline RAG."""

    id: str
    title: str
    content: str
    relevance_score: float          # cosine similarity (usado na lógica de escalação)
    category: str = ""
    muscle_group: str = ""
    rrf_score: float = 0.0          # Reciprocal Rank Fusion score (usado na ordenação)


@dataclass
class RAGResult:
    """Resultado do pipeline RAG."""

    answer: str
    retrieved_documents: list[RetrievedDocument] = field(default_factory=list)
    should_escalate: bool = False
    escalation_reason: str = ""
    model_used: str = ""
    tokens_used: int = 0
    latency_ms: int = 0
    confidence_score: float = 0.0
    query_rewritten: str = ""       # Query reformulada pelo LLM (ou original)


class RAGChain:
    """
    Orquestrador do pipeline RAG para o Chatbot de Dúvidas.

    Uso:
        chain = RAGChain()
        result = await chain.run(
            query="Como faço agachamento livre?",
            session=db_session,
            academy_id=uuid,
            user_context={...},
            conversation_history=[...],
        )
    """

    def __init__(self) -> None:
        self._embeddings: HuggingFaceEmbeddings | None = None
        self._llm: ChatGroq | None = None
        self._cross_encoder: CrossEncoder | None = None
        self._last_model_name: str | None = None

    # ── Inicialização Lazy ─────────────────────────────────────────────────

    def _get_embeddings(self) -> HuggingFaceEmbeddings:
        if self._embeddings is None:
            self._embeddings = HuggingFaceEmbeddings(
                model_name="sentence-transformers/all-MiniLM-L6-v2",
            )
        return self._embeddings

    def _get_llm(self) -> ChatGroq:
        if self._llm is None:
            self._llm = ChatGroq(
                model_name=settings.GROQ_MODEL,
                groq_api_key=settings.GROQ_API_KEY,
                temperature=LLM_TEMPERATURE,
                max_tokens=LLM_MAX_TOKENS,
            )
        return self._llm

    def _get_cross_encoder(self) -> CrossEncoder:
        if self._cross_encoder is None:
            self._cross_encoder = CrossEncoder(settings.RAG_RERANK_MODEL)
        return self._cross_encoder

    # ── Warm-up (chamado no startup da aplicação) ─────────────────────────

    async def warm_up(self) -> None:
        """
        Pré-aquece embeddings e cross-encoder para reduzir latência da
        primeira requisição.
        """
        try:
            embeddings = self._get_embeddings()
            await embeddings.aembed_query("warmup")
            logger.info("RAGChain.warm_up: embeddings prontos para uso")
        except Exception as exc:
            logger.warning("RAGChain.warm_up (embeddings) falhou: %s", exc)

        if settings.RAG_RERANK_ENABLED:
            try:
                loop = asyncio.get_event_loop()
                cross_encoder = self._get_cross_encoder()
                await loop.run_in_executor(
                    None, cross_encoder.predict, [("warmup query", "warmup doc")]
                )
                logger.info("RAGChain.warm_up: cross-encoder pronto para uso")
            except Exception as exc:
                logger.warning("RAGChain.warm_up (cross-encoder) falhou: %s", exc)

    # ── Etapa 0: QUERY REWRITE ─────────────────────────────────────────────

    async def rewrite_query(self, query: str) -> str:
        """
        Reformula a query do usuário para melhorar o recall do RETRIEVE.

        Expande abreviações, adiciona sinônimos técnicos e converte português
        coloquial em termos de fitness precisos.

        Falha silenciosamente: retorna a query original em caso de exceção.
        """
        llm = self._get_llm()
        prompt = _QUERY_REWRITE_PROMPT.format(query=query)
        messages = [HumanMessage(content=prompt)]
        try:
            response = await asyncio.wait_for(llm.ainvoke(messages), timeout=5.0)
            rewritten = response.content.strip()
            if rewritten and len(rewritten) < 300:
                logger.debug("Query rewritten: %r → %r", query[:60], rewritten[:60])
                return rewritten
        except Exception as exc:
            logger.debug("Query rewrite falhou, usando original: %s", exc)
        return query

    # ── Etapa 1a: RETRIEVE (vector puro — fallback) ───────────────────────

    async def _retrieve_vector(
        self,
        query: str,
        session: AsyncSession,
        academy_id: str | None = None,
        top_k: int = TOP_K_DOCS,
    ) -> list[RetrievedDocument]:
        """Busca vetorial pura por similaridade coseno (fallback do hybrid)."""
        embeddings_model = self._get_embeddings()
        try:
            query_vector: list[float] = await embeddings_model.aembed_query(query)
        except Exception as exc:
            logger.error("Erro ao gerar embedding da query: %s", exc)
            return []

        academy_filter = "AND academy_id = :academy_id" if academy_id else ""

        sql = text(
            f"""
            SELECT
                id::text,
                title,
                content,
                category,
                muscle_group,
                1 - (embedding <=> CAST(:query_vector AS vector)) AS relevance_score
            FROM knowledge_base
            WHERE is_active = true
              {academy_filter}
            ORDER BY embedding <=> CAST(:query_vector AS vector)
            LIMIT :top_k
            """
        )

        params: dict[str, Any] = {
            "query_vector": str(query_vector),
            "top_k": top_k,
        }
        if academy_id:
            params["academy_id"] = academy_id

        try:
            result = await session.execute(sql, params)
            rows = result.fetchall()
        except Exception as exc:
            logger.error("Erro na busca vetorial: %s", exc)
            return []

        docs: list[RetrievedDocument] = []
        for row in rows:
            score = float(row.relevance_score or 0)
            if score >= MIN_RELEVANCE_SCORE:
                content = str(row.content)
                if len(content) > MAX_DOC_CONTENT_LENGTH:
                    content = content[:MAX_DOC_CONTENT_LENGTH] + "..."
                docs.append(
                    RetrievedDocument(
                        id=str(row.id),
                        title=str(row.title),
                        content=content,
                        relevance_score=round(score, 4),
                        category=str(row.category or ""),
                        muscle_group=str(row.muscle_group or ""),
                    )
                )

        logger.info(
            "RETRIEVE (vector): %d docs (score ≥ %.2f) | query=%r",
            len(docs),
            MIN_RELEVANCE_SCORE,
            query[:80],
        )
        return docs

    # ── Etapa 1b: RETRIEVE (híbrido = vetorial + BM25 + RRF) ──────────────

    async def _retrieve_hybrid(
        self,
        query: str,
        session: AsyncSession,
        academy_id: str | None = None,
        top_k: int = TOP_K_DOCS,
    ) -> list[RetrievedDocument]:
        """
        Busca híbrida: combina pgvector (cosine) + PostgreSQL FTS (BM25-like)
        usando Reciprocal Rank Fusion.

        O rrf_score é usado apenas para ordenação; o relevance_score
        preserva a cosine similarity original (necessário para escalation logic).
        """
        fetch_k = settings.RAG_HYBRID_FETCH_K  # candidatos extras para o reranker

        embeddings_model = self._get_embeddings()
        try:
            query_vector: list[float] = await embeddings_model.aembed_query(query)
        except Exception as exc:
            logger.error("Erro ao gerar embedding (hybrid): %s", exc)
            return []

        academy_filter = "AND academy_id = :academy_id" if academy_id else ""

        # RRF k=60 é o padrão amplamente usado na literatura
        sql = text(
            f"""
            WITH vector_ranked AS (
                SELECT
                    id::text AS doc_id,
                    ROW_NUMBER() OVER (
                        ORDER BY embedding <=> CAST(:query_vector AS vector)
                    ) AS vrank,
                    1 - (embedding <=> CAST(:query_vector AS vector)) AS vscore
                FROM knowledge_base
                WHERE is_active = true {academy_filter}
                ORDER BY embedding <=> CAST(:query_vector AS vector)
                LIMIT :fetch_k
            ),
            text_ranked AS (
                SELECT
                    id::text AS doc_id,
                    ROW_NUMBER() OVER (
                        ORDER BY ts_rank(
                            to_tsvector('simple', title || ' ' || content),
                            plainto_tsquery('simple', :query_text)
                        ) DESC
                    ) AS trank
                FROM knowledge_base
                WHERE is_active = true {academy_filter}
                  AND to_tsvector('simple', title || ' ' || content)
                          @@ plainto_tsquery('simple', :query_text)
                LIMIT :fetch_k
            ),
            rrf AS (
                SELECT
                    COALESCE(v.doc_id, t.doc_id) AS doc_id,
                    COALESCE(v.vscore, 0)                      AS vscore,
                    COALESCE(1.0 / (60.0 + v.vrank), 0)
                        + COALESCE(1.0 / (60.0 + t.trank), 0) AS rrf_score
                FROM vector_ranked v
                FULL OUTER JOIN text_ranked t ON v.doc_id = t.doc_id
            )
            SELECT
                kb.id::text,
                kb.title,
                kb.content,
                kb.category,
                kb.muscle_group,
                rrf.vscore     AS relevance_score,
                rrf.rrf_score
            FROM knowledge_base kb
            JOIN rrf ON kb.id::text = rrf.doc_id
            ORDER BY rrf.rrf_score DESC
            LIMIT :top_k
            """
        )

        params: dict[str, Any] = {
            "query_vector": str(query_vector),
            "query_text": query,
            "fetch_k": fetch_k,
            "top_k": top_k,
        }
        if academy_id:
            params["academy_id"] = academy_id

        try:
            result = await session.execute(sql, params)
            rows = result.fetchall()
        except Exception as exc:
            # FTS pode falhar com queries muito curtas ou caracteres especiais
            logger.warning("Hybrid search falhou, caindo para vector puro: %s", exc)
            return await self._retrieve_vector(query, session, academy_id, top_k)

        # Threshold mais permissivo que o vector puro para permitir que o
        # reranker selecione candidatos de text-search com vscore baixo
        min_vscore = MIN_RELEVANCE_SCORE / 2  # 0.35

        docs: list[RetrievedDocument] = []
        for row in rows:
            vscore = float(row.relevance_score or 0)
            rrf_score = float(row.rrf_score or 0)

            # Inclui docs que passaram em pelo menos uma das buscas
            if vscore >= min_vscore or rrf_score >= (1.0 / (60.0 + fetch_k)):
                content = str(row.content)
                if len(content) > MAX_DOC_CONTENT_LENGTH:
                    content = content[:MAX_DOC_CONTENT_LENGTH] + "..."
                docs.append(
                    RetrievedDocument(
                        id=str(row.id),
                        title=str(row.title),
                        content=content,
                        relevance_score=round(vscore, 4),
                        rrf_score=round(rrf_score, 6),
                        category=str(row.category or ""),
                        muscle_group=str(row.muscle_group or ""),
                    )
                )

        logger.info(
            "RETRIEVE (hybrid): %d docs | query=%r",
            len(docs),
            query[:80],
        )
        return docs

    # ── Etapa 1: RETRIEVE (dispatcher) ────────────────────────────────────

    async def retrieve(
        self,
        query: str,
        session: AsyncSession,
        academy_id: str | None = None,
        top_k: int = TOP_K_DOCS,
    ) -> list[RetrievedDocument]:
        """Dispatcher: usa busca híbrida se habilitada, senão vetor puro."""
        if settings.RAG_HYBRID_SEARCH:
            return await self._retrieve_hybrid(query, session, academy_id, top_k)
        return await self._retrieve_vector(query, session, academy_id, top_k)

    # ── Etapa 1.5: RERANK ─────────────────────────────────────────────────

    async def rerank(
        self,
        query: str,
        docs: list[RetrievedDocument],
        top_k: int = TOP_K_DOCS,
    ) -> list[RetrievedDocument]:
        """
        Re-ordena docs recuperados usando um cross-encoder.

        O cross-encoder avalia cada par (query, doc_content) de forma conjunta,
        capturando interações semânticas que os bi-encoders (embeddings) perdem.
        A relevance_score original (cosine similarity) é preservada para a
        lógica de escalação.
        """
        if not docs or len(docs) <= 1:
            return docs[:top_k]

        cross_encoder = self._get_cross_encoder()
        # Trunca conteúdo para o limite do cross-encoder (512 tokens ≈ 400 chars)
        pairs = [(query, doc.content[:400]) for doc in docs]

        try:
            loop = asyncio.get_event_loop()
            scores = await loop.run_in_executor(None, cross_encoder.predict, pairs)
            scores_list: list[float] = (
                scores.tolist() if hasattr(scores, "tolist") else list(scores)
            )
            sorted_pairs = sorted(
                zip(docs, scores_list), key=lambda x: x[1], reverse=True
            )
            reranked = [doc for doc, _ in sorted_pairs[:top_k]]

            logger.info(
                "RERANK: %d → %d docs | top_score=%.3f",
                len(docs),
                len(reranked),
                scores_list[0] if scores_list else 0,
            )
            return reranked
        except Exception as exc:
            logger.warning("RERANK falhou, usando ordem original: %s", exc)
            return docs[:top_k]

    # ── Etapa 2: AUGMENT ──────────────────────────────────────────────────

    def augment(
        self,
        query: str,
        retrieved_docs: list[RetrievedDocument],
        user_context: dict[str, Any],
        conversation_history: list[dict[str, str]],
    ) -> str:
        """
        Montar o prompt completo com contexto enriquecido.

        Args:
            query: Pergunta original do usuário.
            retrieved_docs: Documentos recuperados pelo RETRIEVE.
            user_context: Dicionário com 'user_profile' e 'active_workout_sheet'.
            conversation_history: Últimas mensagens da conversa [{role, content}].

        Returns:
            Prompt completo (system) pronto para o LLM.
        """
        # Formatar perfil do aluno
        profile = user_context.get("user_profile", {})
        trainer = user_context.get("personal_trainer")
        trainer_line = (
            f"\nPersonal Trainer: {trainer.get('name')}"
            if trainer and trainer.get("name")
            else "\nPersonal Trainer: ainda não vinculado"
        )
        weight = profile.get("weight")
        height = profile.get("height")
        age = profile.get("age")
        gender = profile.get("gender", "não informado")
        imc_line = ""
        if weight and height:
            imc = round(weight / ((height / 100) ** 2), 1)
            imc_line = f"\nPeso: {weight} kg | Altura: {height} cm | IMC calculado: {imc}"
        elif weight:
            imc_line = f"\nPeso: {weight} kg"
        elif height:
            imc_line = f"\nAltura: {height} cm"
        age_gender_line = ""
        if age:
            age_gender_line = f"\nIdade: {age} anos | Sexo: {gender}"

        user_profile_str = (
            f"Nome: {profile.get('name', 'Aluno')}\n"
            f"Nível: {profile.get('level', 'não informado')}\n"
            f"Objetivo: {profile.get('objective', 'não informado')}\n"
            f"Role: {profile.get('role', 'client')}"
            f"{imc_line}"
            f"{age_gender_line}"
            f"{trainer_line}"
        ) if profile else "Nível e objetivo não informados."

        # Formatar ficha ativa
        sheet = user_context.get("active_workout_sheet")
        if sheet:
            exercises = sheet.get("exercises", [])
            ex_lines = "\n".join(
                f"  - {ex.get('name', '?')}: {ex.get('sets', '?')}x{ex.get('reps', '?')}"
                for ex in exercises[:10]
            )
            workout_sheet_str = (
                f"Ficha: {sheet.get('name', 'Ficha Ativa')}\n"
                f"Exercícios:\n{ex_lines}"
            )
        else:
            workout_sheet_str = "Nenhuma ficha ativa encontrada."

        # Metas em andamento (opcional)
        active_goals = user_context.get("active_goals") or []
        if active_goals:
            goal_lines = "\n".join(
                f"  - {g.get('title', '?')} "
                f"({g.get('current_value', '?')}/{g.get('target_value', '?')} {g.get('unit', '')})"
                for g in active_goals[:5]
            )
            goals_block = f"\n\nMetas em Andamento:\n{goal_lines}"
        else:
            goals_block = ""

        # Dieta ativa (opcional)
        diet = user_context.get("active_diet")
        if diet:
            diet_block = (
                f"\n\nDieta Ativa: {diet.get('name', '?')}"
                f" (objetivo: {diet.get('goal') or 'não informado'})"
            )
        else:
            diet_block = ""

        # Histórico recente de treinos completos (opcional)
        recent = user_context.get("recent_history") or []
        if recent:
            hist_lines = "\n".join(
                f"  - {item.get('session_date', '')} (esforço: {item.get('difficulty_level', '?')}, humor: {item.get('mood', '?')})"
                for item in recent[:3]
            )
            history_block = f"\n\nÚltimos Treinos Concluídos:\n{hist_lines}"
        else:
            history_block = ""

        workout_sheet_str = workout_sheet_str + goals_block + diet_block + history_block

        # Formatar documentos recuperados
        if retrieved_docs:
            docs_lines = []
            for i, doc in enumerate(retrieved_docs, start=1):
                docs_lines.append(
                    f"[Doc {i} | Score: {doc.relevance_score:.2f} | "
                    f"Categoria: {doc.category}]\n"
                    f"Título: {doc.title}\n"
                    f"{doc.content[:800]}"
                )
            retrieved_docs_str = "\n\n---\n\n".join(docs_lines)
        else:
            retrieved_docs_str = (
                "Nenhum documento relevante encontrado na base de conhecimento."
            )

        # Formatar histórico (RN-05: limitado a ~80 tokens ≈ últimas 3 trocas)
        history_lines = []
        recent_msgs = conversation_history[-6:]
        for msg in recent_msgs:
            role = "Aluno" if msg.get("role") == "user" else "Assistente"
            history_lines.append(f"{role}: {msg.get('content', '')[:200]}")
        history_str = "\n".join(history_lines) if history_lines else "Início da conversa."

        return SYSTEM_PROMPT_TEMPLATE.format(
            user_profile=user_profile_str,
            workout_sheet=workout_sheet_str,
            retrieved_docs=retrieved_docs_str,
            history=history_str,
        )

    # ── Detecção de Escalação ─────────────────────────────────────────────

    def _should_escalate(
        self,
        query: str,
        retrieved_docs: list[RetrievedDocument],
        user_context: dict[str, Any] | None = None,
    ) -> tuple[bool, str]:
        """
        Verificar se a pergunta deve ser escalada para Personal.

        Ordem de prioridade dos motivos (mais grave primeiro):
            1. health_risk     — RN-17: menção a risco de saúde
            2. user_requested  — RN-12: pedido explícito por humano
            3. low_confidence  — RN-07: nenhum documento recuperado
                (exceto quando a pergunta é sobre dados pessoais do aluno)
            4. too_complex     — best score < ESCALATE_THRESHOLD
        """
        query_lower = query.lower()

        for keyword in HEALTH_RISK_KEYWORDS:
            if keyword in query_lower:
                return True, "health_risk"

        for keyword in EXPLICIT_REQUEST_KEYWORDS:
            if keyword in query_lower:
                return True, "user_requested"

        if not retrieved_docs:
            ctx = user_context or {}
            has_personal_data = bool(
                ctx.get("user_profile") or ctx.get("active_goals") or ctx.get("recent_history")
            )
            if has_personal_data and _PERSONAL_INTENT_RE.search(query):
                return False, ""
            return True, "low_confidence"

        best_score = max(doc.relevance_score for doc in retrieved_docs)
        if best_score < ESCALATE_THRESHOLD:
            return True, "too_complex"

        return False, ""

    # ── Etapa 3: GENERATE (blocking) ──────────────────────────────────────

    async def generate(
        self,
        system_prompt: str,
        query: str,
    ) -> tuple[str, int, str]:
        """Chamar o LLM Groq para gerar a resposta completa (modo blocking)."""
        llm = self._get_llm()
        parser = StrOutputParser()

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=query),
        ]

        try:
            response = await llm.ainvoke(messages)
            answer: str = await parser.ainvoke(response)

            tokens_used = 0
            if hasattr(response, "usage_metadata") and response.usage_metadata:
                tokens_used = (
                    getattr(response.usage_metadata, "total_token_count", 0)
                    or getattr(response.usage_metadata, "input_tokens", 0)
                    + getattr(response.usage_metadata, "output_tokens", 0)
                )

            return answer, int(tokens_used), settings.GROQ_MODEL

        except AttributeError as exc:
            logger.error("Erro de atributo (possível incompatibilidade LangChain): %s", exc)
            raise RuntimeError(f"LangChain compatibility error: {exc}") from exc
        except Exception as exc:
            logger.error("Erro na geração LLM: %s | type=%s", exc, type(exc).__name__)
            raise RuntimeError(f"LLM generation failed: {exc}") from exc

    # ── Etapa 3b: GENERATE (streaming) ────────────────────────────────────

    async def generate_stream(
        self,
        system_prompt: str,
        query: str,
    ) -> AsyncGenerator[str, None]:
        """
        Chamar o LLM Groq e gerar tokens incrementalmente (modo streaming).

        Yields:
            Fragmentos de texto conforme o LLM gera.
        """
        llm = self._get_llm()
        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=query),
        ]
        try:
            async for chunk in llm.astream(messages):
                if hasattr(chunk, "content") and chunk.content:
                    yield chunk.content
        except Exception as exc:
            logger.error("Erro no streaming do LLM: %s", exc)
            raise RuntimeError(f"LLM streaming failed: {exc}") from exc

    # ── Etapa 4: VALIDATE ─────────────────────────────────────────────────

    def validate(
        self,
        answer: str,
        retrieved_docs: list[RetrievedDocument],
    ) -> tuple[bool, bool]:
        """
        Validar a resposta gerada.

        Returns:
            Tuple (is_valid: bool, needs_human_review: bool)
        """
        if not answer or len(answer.strip()) < 20:
            return False, True

        uncertainty_patterns = [
            r"não\s+posso\s+responder",
            r"não\s+sei\s+informar",
            r"minha\s+base\s+de\s+dados\s+não",
        ]
        for pattern in uncertainty_patterns:
            if re.search(pattern, answer, re.IGNORECASE):
                return True, True

        return True, False

    # ── Pipeline Interno Compartilhado ─────────────────────────────────────

    async def _run_pipeline_setup(
        self,
        query: str,
        session: AsyncSession,
        academy_id: str | None,
        user_context: dict[str, Any],
        conversation_history: list[dict[str, str]],
        start_time: float,
    ) -> dict[str, Any] | RAGResult:
        """
        Executa os passos compartilhados entre run() e run_stream():
        fast-paths, query rewrite, retrieve híbrido e rerank.

        Returns:
            dict com campos intermediários para continuar o pipeline, OU
            RAGResult pronto (fast-paths: greeting, trainer, escalação precoce).
        """
        # ── 0. FAST-PATH SAUDAÇÕES ────────────────────────────────────────
        if _GREETING_REGEX.match(query):
            latency_ms = int((time.monotonic() - start_time) * 1000)
            return RAGResult(
                answer=GREETING_RESPONSE,
                retrieved_documents=[],
                should_escalate=False,
                latency_ms=latency_ms,
                confidence_score=1.0,
                model_used="greeting_fallback",
            )

        # ── 0.5. FAST-PATH "QUEM É MEU PERSONAL?" ─────────────────────────
        if _TRAINER_QUERY_REGEX.search(query):
            trainer = user_context.get("personal_trainer")
            if trainer and trainer.get("name"):
                answer = (
                    f"Seu Personal Trainer é o(a) {trainer['name']}. Você "
                    "pode falar com ele(a) pelo aplicativo ou na recepção "
                    "da academia."
                )
            else:
                answer = (
                    "Você ainda não tem um Personal Trainer vinculado no "
                    "sistema. Procure a recepção para fazer essa associação."
                )
            latency_ms = int((time.monotonic() - start_time) * 1000)
            return RAGResult(
                answer=answer,
                retrieved_documents=[],
                should_escalate=False,
                latency_ms=latency_ms,
                confidence_score=1.0,
                model_used="trainer_lookup",
            )

        # ── 0.8. QUERY REWRITE ─────────────────────────────────────────────
        effective_query = query
        if settings.RAG_QUERY_REWRITE:
            effective_query = await self.rewrite_query(query)

        # ── 1. RETRIEVE HÍBRIDO ────────────────────────────────────────────
        retrieved_docs = await self.retrieve(effective_query, session, academy_id)

        # ── Escalação precoce (antes de chamar o LLM) ─────────────────────
        should_escalate, escalation_reason = self._should_escalate(
            query, retrieved_docs, user_context
        )

        if should_escalate and escalation_reason in {"user_requested", "health_risk"}:
            latency_ms = int((time.monotonic() - start_time) * 1000)
            logger.warning(
                "RAG: escalando conversa | reason=%s | latency_ms=%d",
                escalation_reason,
                latency_ms,
            )
            return RAGResult(
                answer=ESCALATION_MESSAGES[escalation_reason],
                retrieved_documents=[],
                should_escalate=True,
                escalation_reason=escalation_reason,
                latency_ms=latency_ms,
                confidence_score=0.0,
                query_rewritten=effective_query,
            )

        # ── 1.5. FAST-PATH FAQ ────────────────────────────────────────────
        faq_response = faq_service.match(query)
        if faq_response is not None:
            latency_ms = int((time.monotonic() - start_time) * 1000)
            return RAGResult(
                answer=faq_response,
                retrieved_documents=[],
                should_escalate=False,
                latency_ms=latency_ms,
                confidence_score=1.0,
                model_used="faq_fallback",
                query_rewritten=effective_query,
            )

        # ── 1.8. RERANK ───────────────────────────────────────────────────
        if settings.RAG_RERANK_ENABLED and retrieved_docs:
            retrieved_docs = await self.rerank(query, retrieved_docs, TOP_K_DOCS)

        # Retorna estado intermediário para os métodos run() e run_stream()
        return {
            "effective_query": effective_query,
            "retrieved_docs": retrieved_docs,
            "should_escalate": should_escalate,
            "escalation_reason": escalation_reason,
        }

    # ── Pipeline Principal (blocking) ─────────────────────────────────────

    async def run(
        self,
        query: str,
        session: AsyncSession,
        academy_id: str | None = None,
        user_context: dict[str, Any] | None = None,
        conversation_history: list[dict[str, str]] | None = None,
        on_status: Callable[[dict[str, Any]], Awaitable[None]] | None = None,
    ) -> RAGResult:
        """
        Executar o pipeline RAG completo (Rewrite → Retrieve → Rerank →
        Augment → Generate → Validate).
        """
        start_time = time.monotonic()
        user_context = user_context or {}
        conversation_history = conversation_history or []
        _ = on_status  # mantido por compatibilidade; emissão fica no ChatService

        logger.info("RAG pipeline iniciado | query=%r", query[:100])

        setup = await self._run_pipeline_setup(
            query, session, academy_id, user_context, conversation_history, start_time
        )

        # Se setup retornou um RAGResult já pronto (fast-path), devolve direto
        if isinstance(setup, RAGResult):
            return setup

        effective_query: str = setup["effective_query"]
        retrieved_docs: list[RetrievedDocument] = setup["retrieved_docs"]
        should_escalate: bool = setup["should_escalate"]
        escalation_reason: str = setup["escalation_reason"]

        # ── 2. AUGMENT ─────────────────────────────────────────────────────
        system_prompt = self.augment(
            query, retrieved_docs, user_context, conversation_history
        )

        # ── 3. GENERATE ────────────────────────────────────────────────────
        timeout_seconds = settings.CHAT_MAX_RESPONSE_LATENCY_MS / 1000
        try:
            answer, tokens_used, model_name = await asyncio.wait_for(
                self.generate(system_prompt, query),
                timeout=timeout_seconds,
            )
        except asyncio.TimeoutError:
            logger.warning(
                "Geração excedeu %d ms — abortando com fallback",
                settings.CHAT_MAX_RESPONSE_LATENCY_MS,
            )
            latency_ms = int((time.monotonic() - start_time) * 1000)
            return RAGResult(
                answer=ESCALATION_MESSAGES["timeout"],
                should_escalate=True,
                escalation_reason="timeout",
                latency_ms=latency_ms,
                query_rewritten=effective_query,
            )
        except Exception as exc:
            logger.error("Falha na geração: %s", exc)
            latency_ms = int((time.monotonic() - start_time) * 1000)
            return RAGResult(
                answer=ESCALATION_MESSAGES["generation_error"],
                should_escalate=True,
                escalation_reason="generation_error",
                latency_ms=latency_ms,
                query_rewritten=effective_query,
            )

        # ── 4. VALIDATE ────────────────────────────────────────────────────
        is_valid, _needs_review = self.validate(answer, retrieved_docs)
        if not is_valid:
            answer = ESCALATION_MESSAGES["validation_failed"]
            should_escalate = True
            escalation_reason = "validation_failed"

        confidence = (
            sum(d.relevance_score for d in retrieved_docs) / len(retrieved_docs)
            if retrieved_docs
            else 0.0
        )

        latency_ms = int((time.monotonic() - start_time) * 1000)

        logger.info(
            "RAG pipeline concluído | docs=%d | confidence=%.2f | "
            "escalate=%s | latency_ms=%d | rewritten=%r",
            len(retrieved_docs),
            confidence,
            should_escalate,
            latency_ms,
            effective_query[:60] if effective_query != query else "(same)",
        )

        return RAGResult(
            answer=answer,
            retrieved_documents=retrieved_docs,
            should_escalate=should_escalate,
            escalation_reason=escalation_reason,
            model_used=model_name,
            tokens_used=tokens_used,
            latency_ms=latency_ms,
            confidence_score=round(confidence, 4),
            query_rewritten=effective_query,
        )

    # ── Pipeline Streaming ─────────────────────────────────────────────────

    async def run_stream(
        self,
        query: str,
        session: AsyncSession,
        academy_id: str | None = None,
        user_context: dict[str, Any] | None = None,
        conversation_history: list[dict[str, str]] | None = None,
    ) -> AsyncGenerator[dict[str, Any], None]:
        """
        Pipeline RAG com resposta streamada.

        Yields dicts com campo 'type':
            {"type": "status",  "status": "...", "message": "..."}
            {"type": "chunk",   "content": "<token(s)>"}
            {"type": "done",    "answer": "...", "should_escalate": bool, ...}
        """
        start_time = time.monotonic()
        user_context = user_context or {}
        conversation_history = conversation_history or []

        logger.info("RAG stream iniciado | query=%r", query[:100])

        yield {"type": "status", "status": "thinking", "message": "Analisando sua pergunta..."}

        setup = await self._run_pipeline_setup(
            query, session, academy_id, user_context, conversation_history, start_time
        )

        # Fast-path retornou RAGResult pronto — emite como "done" sem chunks
        if isinstance(setup, RAGResult):
            yield {
                "type": "done",
                "answer": setup.answer,
                "retrieved_documents": setup.retrieved_documents,
                "should_escalate": setup.should_escalate,
                "escalation_reason": setup.escalation_reason,
                "model_used": setup.model_used,
                "tokens_used": setup.tokens_used,
                "latency_ms": setup.latency_ms,
                "confidence_score": setup.confidence_score,
                "query_rewritten": setup.query_rewritten,
            }
            return

        effective_query: str = setup["effective_query"]
        retrieved_docs: list[RetrievedDocument] = setup["retrieved_docs"]
        should_escalate: bool = setup["should_escalate"]
        escalation_reason: str = setup["escalation_reason"]

        yield {"type": "status", "status": "generating", "message": "Gerando resposta..."}

        # ── 2. AUGMENT ─────────────────────────────────────────────────────
        system_prompt = self.augment(
            query, retrieved_docs, user_context, conversation_history
        )

        # ── 3. GENERATE STREAM ─────────────────────────────────────────────
        full_answer = ""
        try:
            async for chunk in self.generate_stream(system_prompt, query):
                full_answer += chunk
                yield {"type": "chunk", "content": chunk}
        except Exception as exc:
            logger.error("Falha no streaming: %s", exc)
            latency_ms = int((time.monotonic() - start_time) * 1000)
            yield {
                "type": "done",
                "answer": ESCALATION_MESSAGES["generation_error"],
                "retrieved_documents": [],
                "should_escalate": True,
                "escalation_reason": "generation_error",
                "model_used": "",
                "tokens_used": 0,
                "latency_ms": latency_ms,
                "confidence_score": 0.0,
                "query_rewritten": effective_query,
            }
            return

        # ── 4. VALIDATE ────────────────────────────────────────────────────
        is_valid, _ = self.validate(full_answer, retrieved_docs)
        if not is_valid:
            full_answer = ESCALATION_MESSAGES["validation_failed"]
            should_escalate = True
            escalation_reason = "validation_failed"

        confidence = (
            sum(d.relevance_score for d in retrieved_docs) / len(retrieved_docs)
            if retrieved_docs
            else 0.0
        )
        latency_ms = int((time.monotonic() - start_time) * 1000)

        logger.info(
            "RAG stream concluído | docs=%d | escalate=%s | latency_ms=%d",
            len(retrieved_docs),
            should_escalate,
            latency_ms,
        )

        yield {
            "type": "done",
            "answer": full_answer,
            "retrieved_documents": retrieved_docs,
            "should_escalate": should_escalate,
            "escalation_reason": escalation_reason,
            "model_used": settings.GROQ_MODEL,
            "tokens_used": 0,  # streaming não expõe contagem de tokens
            "latency_ms": latency_ms,
            "confidence_score": round(confidence, 4),
            "query_rewritten": effective_query,
        }


# Instância singleton reutilizável pelo serviço
rag_chain = RAGChain()
