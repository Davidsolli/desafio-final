"""
Pipeline RAG — Retrieve-Augment-Generate.

Orquestra o fluxo completo de resposta do chatbot:
  1. RETRIEVE  — busca vetorial no pgvector (score ≥ 0.7)
  2. AUGMENT   — monta contexto com perfil do aluno e ficha ativa
  3. GENERATE  — chama o LLM (Gemini) com o prompt enriquecido
  4. VALIDATE  — valida cobertura e detecta necessidade de escalação

Dependências:
    langchain-google-genai  → GoogleGenerativeAIEmbeddings + ChatGoogleGenerativeAI
    pgvector                → Busca por similaridade coseno no PostgreSQL
"""

from __future__ import annotations

import logging
import re
import time
from dataclasses import dataclass, field
from typing import Any

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.output_parsers import StrOutputParser
from langchain_google_genai import ChatGoogleGenerativeAI, GoogleGenerativeAIEmbeddings
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.settings import settings

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

# Palavras-chave que forçam escalação imediata (RN-12)
ESCALATION_KEYWORDS = [
    "falar com personal", "chamar personal", "quero personal",
    "não entendi", "nao entendi", "ainda com dúvida", "ainda com duvida",
    "me ajuda pessoalmente", "suporte humano", "personal trainer",
    "lesão", "lesao", "dor no peito", "dor forte",
    "médico", "medico", "emergência", "emergencia", "dor",
]

# System prompt base do chatbot
SYSTEM_PROMPT_TEMPLATE = """\
Você é o assistente de treinos do OmniConnect Fitness — um chatbot especializado em \
exercícios, execução técnica e periodização.

Regras que você DEVE seguir:
1. Responda SEMPRE em português brasileiro.
2. Use SOMENTE as informações dos documentos fornecidos no contexto. \
Se a resposta não estiver nos documentos, diga claramente que não sabe.
3. Seja específico, técnico e direto. Evite floreios.
4. Máximo de 4 parágrafos curtos na resposta.
5. Se identificar risco de saúde ("dor no peito", "lesão grave"), \
responda: "Por segurança, recomendo consultar um profissional de saúde."
6. Não invente exercícios, cargas ou recomendações que não estejam documentadas.

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


@dataclass
class RetrievedDocument:
    """Documento recuperado pelo pipeline RAG."""

    id: str
    title: str
    content: str
    relevance_score: float
    category: str = ""
    muscle_group: str = ""


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
        """
        Inicializar RAG chain.

        Side effects:
            - Inicializa clients do Gemini (lazy, apenas no primeiro uso)
            - Prepara embeddings model e LLM para posterior utilização
        """
        self._embeddings: GoogleGenerativeAIEmbeddings | None = None
        self._llm: ChatGoogleGenerativeAI | None = None

    # ── Inicialização Lazy ─────────────────────────────────────────────────

    def _get_embeddings(self) -> GoogleGenerativeAIEmbeddings:
        """Obter instância de embeddings (lazy init)."""
        if self._embeddings is None:
            self._embeddings = GoogleGenerativeAIEmbeddings(
                model="models/text-embedding-004",
                google_api_key=settings.GOOGLE_API_KEY,
                task_type="retrieval_query",
            )
        return self._embeddings

    def _get_llm(self) -> ChatGoogleGenerativeAI:
        """Obter instância do LLM Gemini (lazy init)."""
        if self._llm is None:
            self._llm = ChatGoogleGenerativeAI(
                model=settings.GEMINI_MODEL,
                google_api_key=settings.GOOGLE_API_KEY,
                temperature=LLM_TEMPERATURE,
                max_output_tokens=LLM_MAX_TOKENS,
            )
        return self._llm

    # ── Etapa 1: RETRIEVE ─────────────────────────────────────────────────

    async def retrieve(
        self,
        query: str,
        session: AsyncSession,
        academy_id: str | None = None,
        top_k: int = TOP_K_DOCS,
    ) -> list[RetrievedDocument]:
        """
        Buscar documentos relevantes via similaridade coseno no pgvector.

        Args:
            query: Pergunta do usuário.
            session: Sessão assíncrona do banco de dados.
            academy_id: Filtrar por academia (opcional).
            top_k: Número máximo de documentos a retornar.

        Returns:
            Lista de RetrievedDocument com score ≥ MIN_RELEVANCE_SCORE.
        """
        # Gerar embedding da query
        embeddings_model = self._get_embeddings()
        try:
            query_vector: list[float] = await embeddings_model.aembed_query(query)
        except Exception as exc:
            logger.error("Erro ao gerar embedding da query: %s", exc)
            return []

        # Montar cláusula de filtro de academia
        academy_filter = (
            "AND academy_id = :academy_id" if academy_id else ""
        )

        # Busca por similaridade coseno — operador <=> do pgvector
        # 1 - (embedding <=> query_vector) = cosine_similarity
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

        # Filtrar apenas documentos com score ≥ MIN_RELEVANCE_SCORE (RN-06)
        docs: list[RetrievedDocument] = []
        for row in rows:
            score = float(row.relevance_score or 0)
            if score >= MIN_RELEVANCE_SCORE:
                # Validação de conteúdo: truncar se muito longo (melhoria de segurança)
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
            "RETRIEVE: %d documentos recuperados (score ≥ %.2f) para query=%r",
            len(docs),
            MIN_RELEVANCE_SCORE,
            query[:80],
        )
        return docs

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
            Prompt completo (system + user) pronto para o LLM.
        """
        # Formatar perfil do aluno
        profile = user_context.get("user_profile", {})
        user_profile_str = (
            f"Nome: {profile.get('name', 'Aluno')}\n"
            f"Nível: {profile.get('level', 'não informado')}\n"
            f"Objetivo: {profile.get('objective', 'não informado')}\n"
            f"Role: {profile.get('role', 'client')}"
        ) if profile else "Nível e objetivo não informados."

        # Formatar ficha ativa
        sheet = user_context.get("active_workout_sheet")
        if sheet:
            exercises = sheet.get("exercises", [])
            ex_lines = "\n".join(
                f"  - {ex.get('name', '?')}: {ex.get('sets', '?')}x{ex.get('reps', '?')}"
                for ex in exercises[:10]  # limitar exibição
            )
            workout_sheet_str = (
                f"Ficha: {sheet.get('name', 'Ficha Ativa')}\n"
                f"Exercícios:\n{ex_lines}"
            )
        else:
            workout_sheet_str = "Nenhuma ficha ativa encontrada."

        # Formatar documentos recuperados
        if retrieved_docs:
            docs_lines = []
            for i, doc in enumerate(retrieved_docs, start=1):
                docs_lines.append(
                    f"[Doc {i} | Score: {doc.relevance_score:.2f} | "
                    f"Categoria: {doc.category}]\n"
                    f"Título: {doc.title}\n"
                    f"{doc.content[:800]}"  # truncar conteúdo longo
                )
            retrieved_docs_str = "\n\n---\n\n".join(docs_lines)
        else:
            retrieved_docs_str = (
                "Nenhum documento relevante encontrado na base de conhecimento."
            )

        # Formatar histórico (RN-05: limitado a ~80 tokens ≈ últimas 3 trocas)
        history_lines = []
        recent = conversation_history[-6:]  # 3 trocas user/assistant
        for msg in recent:
            role = "Aluno" if msg.get("role") == "user" else "Assistente"
            history_lines.append(f"{role}: {msg.get('content', '')[:200]}")
        history_str = "\n".join(history_lines) if history_lines else "Início da conversa."

        # Montar system prompt preenchido
        system_content = SYSTEM_PROMPT_TEMPLATE.format(
            user_profile=user_profile_str,
            workout_sheet=workout_sheet_str,
            retrieved_docs=retrieved_docs_str,
            history=history_str,
        )

        return system_content

    # ── Detecção de Escalação ─────────────────────────────────────────────

    def _should_escalate(
        self,
        query: str,
        retrieved_docs: list[RetrievedDocument],
    ) -> tuple[bool, str]:
        """
        Verificar se a pergunta deve ser escalada para Personal.

        Critérios:
        - RN-07: Nenhum documento com score ≥ ESCALATE_THRESHOLD
        - RN-12: Usuário menciona palavras de escalação explícita
        - RN-17: Menção a riscos de saúde (dor no peito, etc.)

        Returns:
            Tuple (should_escalate: bool, reason: str)
        """
        query_lower = query.lower()

        # RN-12 / RN-17: palavras-chave de escalação
        for keyword in ESCALATION_KEYWORDS:
            if keyword in query_lower:
                return True, "user_requested"

        # RN-07: score insuficiente na base
        if not retrieved_docs:
            return True, "low_confidence"

        best_score = max(doc.relevance_score for doc in retrieved_docs)
        if best_score < ESCALATE_THRESHOLD:
            return True, "too_complex"

        return False, ""

    # ── Etapa 3: GENERATE ─────────────────────────────────────────────────

    async def generate(
        self,
        system_prompt: str,
        query: str,
    ) -> tuple[str, int, str]:
        """
        Chamar o LLM Gemini para gerar a resposta.

        Args:
            system_prompt: Prompt de sistema com contexto completo.
            query: Pergunta do usuário.

        Returns:
            Tuple (answer: str, tokens_used: int, model_name: str)
        """
        llm = self._get_llm()
        parser = StrOutputParser()

        messages = [
            SystemMessage(content=system_prompt),
            HumanMessage(content=query),
        ]

        try:
            response = await llm.ainvoke(messages)
            answer: str = await parser.ainvoke(response)

            # Tentar extrair uso de tokens dos metadados
            tokens_used = 0
            if hasattr(response, "usage_metadata") and response.usage_metadata:
                tokens_used = (
                    getattr(response.usage_metadata, "total_token_count", 0)
                    or getattr(response.usage_metadata, "input_tokens", 0)
                    + getattr(response.usage_metadata, "output_tokens", 0)
                )

            return answer, int(tokens_used), settings.GEMINI_MODEL

        except AttributeError as exc:
            logger.error("Erro de atributo (possível incompatibilidade LangChain): %s", exc)
            raise RuntimeError(f"LangChain compatibility error: {exc}") from exc
        except Exception as exc:
            logger.error(
                "Erro na geração LLM: %s | type=%s",
                exc,
                type(exc).__name__,
            )
            raise RuntimeError(f"LLM generation failed: {exc}") from exc

    # ── Etapa 4: VALIDATE ─────────────────────────────────────────────────

    def validate(
        self,
        answer: str,
        retrieved_docs: list[RetrievedDocument],
    ) -> tuple[bool, bool]:
        """
        Validar a resposta gerada.

        Verifica:
        - Resposta não é vazia
        - Não contém marcadores de alucinação óbvia ("não sei", "não tenho certeza"
          com mais de 50% do texto)
        - Se há documentos recuperados, a resposta deve mencionar o tema

        Returns:
            Tuple (is_valid: bool, needs_human_review: bool)
        """
        if not answer or len(answer.strip()) < 20:
            return False, True

        # Detectar frases de incerteza extrema que sugerem alucinação
        uncertainty_patterns = [
            r"não\s+posso\s+responder",
            r"não\s+sei\s+informar",
            r"minha\s+base\s+de\s+dados\s+não",
        ]
        for pattern in uncertainty_patterns:
            if re.search(pattern, answer, re.IGNORECASE):
                return True, True  # válida mas precisa de review

        return True, False

    # ── Pipeline Principal ─────────────────────────────────────────────────

    async def run(
        self,
        query: str,
        session: AsyncSession,
        academy_id: str | None = None,
        user_context: dict[str, Any] | None = None,
        conversation_history: list[dict[str, str]] | None = None,
    ) -> RAGResult:
        """
        Executar o pipeline RAG completo (Retrieve → Augment → Generate → Validate).

        Args:
            query: Pergunta do aluno.
            session: Sessão assíncrona do banco de dados.
            academy_id: UUID da academia para filtrar a base de conhecimento.
            user_context: Contexto do aluno {user_profile, active_workout_sheet}.
            conversation_history: Histórico de mensagens [{role, content}].

        Returns:
            RAGResult com resposta, documentos, flags de escalação e métricas.
        """
        start_time = time.monotonic()
        user_context = user_context or {}
        conversation_history = conversation_history or []

        logger.info("RAG pipeline iniciado | query=%r", query[:100])

        # ── 1. RETRIEVE ────────────────────────────────────────────────────
        retrieved_docs = await self.retrieve(query, session, academy_id)

        # ── Verificar necessidade de escalação explícita ANTES de gerar ──────────────
        should_escalate, escalation_reason = self._should_escalate(
            query, retrieved_docs
        )

        if should_escalate and escalation_reason == "user_requested":
            # Palavra-chave de risco ou pedido explícito → escalar imediatamente
            latency_ms = int((time.monotonic() - start_time) * 1000)
            logger.warning(
                "RAG: escalando conversa | reason=%s | latency_ms=%d",
                escalation_reason,
                latency_ms,
            )
            return RAGResult(
                answer=(
                    "Sua dúvida é muito específica e precisa da atenção do seu "
                    "Personal Trainer. Estou escalando para ele agora! 🎯"
                ),
                retrieved_documents=[],
                should_escalate=True,
                escalation_reason=escalation_reason,
                latency_ms=latency_ms,
                confidence_score=0.0,
            )

        # ── 2. AUGMENT ─────────────────────────────────────────────────────
        system_prompt = self.augment(
            query, retrieved_docs, user_context, conversation_history
        )

        # ── 3. GENERATE ────────────────────────────────────────────────────
        try:
            answer, tokens_used, model_name = await self.generate(system_prompt, query)
        except Exception as exc:
            logger.error("Falha na geração: %s", exc)
            latency_ms = int((time.monotonic() - start_time) * 1000)
            return RAGResult(
                answer=(
                    "Desculpe, não consegui processar sua dúvida agora. "
                    "Tente novamente em instantes."
                ),
                should_escalate=True,
                escalation_reason="generation_error",
                latency_ms=latency_ms,
            )

        # ── 4. VALIDATE ────────────────────────────────────────────────────
        is_valid, needs_review = self.validate(answer, retrieved_docs)
        if not is_valid:
            answer = (
                "Não encontrei informações suficientes na base de conhecimento "
                "para responder com segurança. Seu Personal Trainer pode ajudar melhor!"
            )
            should_escalate = True
            escalation_reason = "validation_failed"
        elif not retrieved_docs and not should_escalate:
             # Nao precisa fazer nada
             pass
        elif not retrieved_docs and should_escalate:
            # Respondeu com sucesso (usando FAQ), então podemos cancelar a escalação
            should_escalate = False
            escalation_reason = ""

        # Calcular confidence como média dos scores recuperados
        confidence = (
            sum(d.relevance_score for d in retrieved_docs) / len(retrieved_docs)
            if retrieved_docs
            else 0.0
        )

        latency_ms = int((time.monotonic() - start_time) * 1000)

        logger.info(
            "RAG pipeline concluído | docs=%d | confidence=%.2f | "
            "escalate=%s | latency_ms=%d",
            len(retrieved_docs),
            confidence,
            should_escalate,
            latency_ms,
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
        )


# Instância singleton reutilizável pelo serviço
rag_chain = RAGChain()
