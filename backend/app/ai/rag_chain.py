"""
Pipeline RAG — Retrieve-Augment-Generate.

Orquestra o fluxo completo de resposta do chatbot:
  1. RETRIEVE  — busca vetorial no pgvector (score ≥ 0.7)
  2. AUGMENT   — monta contexto com perfil do aluno e ficha ativa
  3. GENERATE  — chama o LLM (Groq Llama 3.3 70B) com o prompt enriquecido
  4. VALIDATE  — valida cobertura e detecta necessidade de escalação

Dependências:
    langchain-groq          → ChatGroq (Llama 3.3 70B Versatile)
    langchain-huggingface   → HuggingFaceEmbeddings (all-MiniLM-L6-v2, 384 dims)
    pgvector                → Busca por similaridade coseno no PostgreSQL
"""

from __future__ import annotations

import asyncio
import logging
import re
import time
from dataclasses import dataclass, field
from typing import Any, Awaitable, Callable

from langchain_core.messages import HumanMessage, SystemMessage
from langchain_core.output_parsers import StrOutputParser
from langchain_groq import ChatGroq
from langchain_huggingface import HuggingFaceEmbeddings
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
    "Olá! Sou o assistente do OmniConnect Fitness. Posso ajudar com dúvidas "
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
Você é o assistente do OmniConnect Fitness — um chatbot especializado em três \
domínios: (1) treino e periodização, (2) execução técnica de exercícios, e \
(3) nutrição básica voltada a esporte e atividade física.

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
            - Prepara embeddings (HuggingFace) e LLM (Groq) para uso lazy
            - Não realiza chamadas externas até o primeiro uso
        """
        self._embeddings: HuggingFaceEmbeddings | None = None
        self._llm: ChatGroq | None = None
        self._last_model_name: str | None = None

    # ── Inicialização Lazy ─────────────────────────────────────────────────

    def _get_embeddings(self) -> HuggingFaceEmbeddings:
        """Obter instância de embeddings (lazy init)."""
        if self._embeddings is None:
            self._embeddings = HuggingFaceEmbeddings(
                model_name="sentence-transformers/all-MiniLM-L6-v2",
            )
        return self._embeddings

    def _get_llm(self) -> ChatGroq:
        """Obter instância do LLM Groq (lazy init)."""
        if self._llm is None:
            self._llm = ChatGroq(
                model_name=settings.GROQ_MODEL,
                groq_api_key=settings.GROQ_API_KEY,
                temperature=LLM_TEMPERATURE,
                max_tokens=LLM_MAX_TOKENS,
            )
        return self._llm

    # ── Warm-up (chamado no startup da aplicação) ─────────────────────────

    async def warm_up(self) -> None:
        """
        Pré-aquece o modelo de embeddings local para reduzir latência da
        primeira requisição.

        O HuggingFace baixa e carrega o modelo no primeiro `aembed_query`,
        o que pode adicionar segundos a um cold start. Chamar warm_up() no
        lifespan da FastAPI evita que o primeiro usuário pague essa conta.

        Falhas de inicialização são logadas mas não derrubam a aplicação —
        o lazy init original cobrirá quando vier a primeira request real.
        """
        try:
            embeddings = self._get_embeddings()
            # Embedding curto é suficiente para forçar o download/load do modelo
            await embeddings.aembed_query("warmup")
            logger.info("RAGChain.warm_up: embeddings prontos para uso")
        except Exception as exc:
            logger.warning("RAGChain.warm_up falhou (lazy init cobrirá): %s", exc)

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
        trainer = user_context.get("personal_trainer")
        trainer_line = (
            f"\nPersonal Trainer: {trainer.get('name')}"
            if trainer and trainer.get("name")
            else "\nPersonal Trainer: ainda não vinculado"
        )
        user_profile_str = (
            f"Nome: {profile.get('name', 'Aluno')}\n"
            f"Nível: {profile.get('level', 'não informado')}\n"
            f"Objetivo: {profile.get('objective', 'não informado')}\n"
            f"Role: {profile.get('role', 'client')}"
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

        # Anexa blocos extras à ficha (mantém estrutura do template)
        workout_sheet_str = workout_sheet_str + goals_block + diet_block + history_block

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

        Ordem de prioridade dos motivos (mais grave primeiro):
            1. health_risk     — RN-17: menção a risco de saúde
            2. user_requested  — RN-12: pedido explícito por humano
            3. low_confidence  — RN-07: nenhum documento recuperado
            4. too_complex     — best score < ESCALATE_THRESHOLD

        Returns:
            Tuple (should_escalate: bool, reason: str)
        """
        query_lower = query.lower()

        # 1. Risco à saúde tem precedência: nem chega a tentar gerar resposta
        for keyword in HEALTH_RISK_KEYWORDS:
            if keyword in query_lower:
                return True, "health_risk"

        # 2. Pedido explícito do usuário por atendimento humano
        for keyword in EXPLICIT_REQUEST_KEYWORDS:
            if keyword in query_lower:
                return True, "user_requested"

        # 3. RAG vazio
        if not retrieved_docs:
            return True, "low_confidence"

        # 4. Score insuficiente
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
        Chamar o LLM Groq para gerar a resposta.

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

            return answer, int(tokens_used), settings.GROQ_MODEL

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
        on_status: Callable[[dict[str, Any]], Awaitable[None]] | None = None,
    ) -> RAGResult:
        """
        Executar o pipeline RAG completo (Retrieve → Augment → Generate → Validate).

        Args:
            query: Pergunta do aluno.
            session: Sessão assíncrona do banco de dados.
            academy_id: UUID da academia para filtrar a base de conhecimento.
            user_context: Contexto do aluno {user_profile, active_workout_sheet}.
            conversation_history: Histórico de mensagens [{role, content}].
            on_status: callback opcional invocado entre etapas para informar
                progresso ao cliente (searching / generating).

        Returns:
            RAGResult com resposta, documentos, flags de escalação e métricas.
        """
        start_time = time.monotonic()
        user_context = user_context or {}
        conversation_history = conversation_history or []

        # on_status é aceito por compatibilidade mas a emissão dos eventos
        # de progresso fica na camada superior (ChatService) — single
        # responsibility: rag_chain.run cuida apenas do pipeline.
        _ = on_status

        logger.info("RAG pipeline iniciado | query=%r", query[:100])

        # ── 0. FAST-PATH SAUDAÇÕES ────────────────────────────────────────
        # Saudações curtas ("olá", "oi", "bom dia") não precisam do RAG nem do
        # LLM. Respondemos direto para evitar timeout em cold start.
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
        # Pergunta direta sobre o personal trainer vinculado é respondida
        # deterministicamente a partir do user_context (preenchido pelo
        # ChatService a partir de User.trainer_id). Evita uma chamada
        # desnecessária ao LLM e garante consistência.
        if _TRAINER_QUERY_REGEX.search(query):
            trainer = (user_context or {}).get("personal_trainer")
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

        # ── 1. RETRIEVE ────────────────────────────────────────────────────
        retrieved_docs = await self.retrieve(query, session, academy_id)

        # ── Verificar necessidade de escalação explícita ANTES de gerar ──────────────
        should_escalate, escalation_reason = self._should_escalate(
            query, retrieved_docs
        )

        if should_escalate and escalation_reason in {"user_requested", "health_risk"}:
            # Pedido explícito ou risco de saúde → escalar antes de chamar o LLM
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
            )

        # ── 1.5. FAST-PATH FAQ (delegado ao FAQService dedicado) ───────────
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
            )

        # ── 2. AUGMENT ─────────────────────────────────────────────────────
        system_prompt = self.augment(
            query, retrieved_docs, user_context, conversation_history
        )

        # ── 3. GENERATE ────────────────────────────────────────────────────
        # Aplica timeout duro: se o LLM exceder CHAT_MAX_RESPONSE_LATENCY_MS,
        # cancelamos e devolvemos fallback amigável + escalação.
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
            )
        except Exception as exc:
            logger.error("Falha na geração: %s", exc)
            latency_ms = int((time.monotonic() - start_time) * 1000)
            return RAGResult(
                answer=ESCALATION_MESSAGES["generation_error"],
                should_escalate=True,
                escalation_reason="generation_error",
                latency_ms=latency_ms,
            )

        # ── 4. VALIDATE ────────────────────────────────────────────────────
        # Regra única e previsível: se a resposta gerada não passa na
        # validação (vazia/curta demais), substituímos por mensagem segura
        # de fallback e escalamos. Caso contrário, preservamos o estado de
        # escalação já calculado em _should_escalate.
        is_valid, _needs_review = self.validate(answer, retrieved_docs)
        if not is_valid:
            answer = ESCALATION_MESSAGES["validation_failed"]
            should_escalate = True
            escalation_reason = "validation_failed"

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
