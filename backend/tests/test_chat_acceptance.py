"""
Testes dos critérios de aceite — Refatoração do Chatbot (Etapa 1).

Cobre os cards do Trello mapeados no PRD_CHATBOT_REFACTOR_ETAPA1.md (seção 3.4):
- Card 18:    Escolha do LLM
- Card 18.1:  Serviço de integração com IA
- Card 18.2:  Endpoint de chatbot (parcial — completado em test_chat_websocket.py)
- Card 18.3:  Contexto mínimo do aluno (dados REAIS — ficha, metas, histórico, dieta)
- Cards 18.4, 18.5, 18.6: Domínios treino, execução, nutrição
- Cards 19.3-19.8: Pipeline RAG e dados reais

Os testes assumem stack atual: Groq + Llama 3.3 70B Versatile, HuggingFace all-MiniLM-L6-v2 (384 dims).
"""

from __future__ import annotations

import asyncio
import inspect
import time
from datetime import datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.ai import rag_chain as rag_chain_module
from app.ai.rag_chain import (
    SYSTEM_PROMPT_TEMPLATE,
    RAGChain,
    RAGResult,
    RetrievedDocument,
    rag_chain,
)
from app.config.settings import settings
from app.models.chatbot import ChatConversation, ChatMessage
from app.models.diet import Diet
from app.models.goal import Goal
from app.models.user import Base, User
from app.models.workout_sheet import Exercise, WorkoutSheet
from app.services.chat_service import ChatService


# ── Setup do banco de dados de teste ─────────────────────────────────────────

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
    factory = async_sessionmaker(db_engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as session:
        yield session


@pytest_asyncio.fixture
async def fitness_user(db_session: AsyncSession) -> User:
    """Cria um aluno com perfil fitness completo para testes de contexto."""
    user = User(
        id=uuid4(),
        name="Carlos Pereira",
        email="carlos@test.com",
        password="hash_fake",
        role="client",
        weight=82.0,
        height=178.0,
        age=29,
        gender="male",
        goal_type="hipertrofia",
        is_active=True,
    )
    db_session.add(user)
    await db_session.commit()
    await db_session.refresh(user)
    return user


@pytest_asyncio.fixture
async def chat_service(db_session: AsyncSession) -> ChatService:
    return ChatService(db_session)


@pytest_asyncio.fixture
async def workout_sheet_with_exercises(db_session: AsyncSession, fitness_user: User) -> WorkoutSheet:
    """Cria ficha de treino ativa para o aluno."""
    sheet = WorkoutSheet(
        id=uuid4(),
        user_id=fitness_user.id,
        personal_trainer_id=None,
        name="Treino A — Peito/Tríceps",
        description="Hipertrofia avançada",
        day_of_week=1,
        is_active=True,
    )
    db_session.add(sheet)
    await db_session.flush()

    for i, (name, group) in enumerate(
        [("Supino Reto", "Peito"), ("Crucifixo", "Peito"), ("Tríceps Pulley", "Tríceps")],
        start=1,
    ):
        ex = Exercise(
            id=uuid4(),
            workout_sheet_id=sheet.id,
            name=name,
            muscle_group=group,
            series=4,
            repetitions=10,
            load_kg=40.0,
            rest_seconds=90,
            order=i,
        )
        db_session.add(ex)

    await db_session.commit()
    await db_session.refresh(sheet)
    return sheet


@pytest_asyncio.fixture
async def active_goal(db_session: AsyncSession, fitness_user: User) -> Goal:
    """Cria meta ativa de hipertrofia."""
    goal = Goal(
        id=uuid4(),
        user_id=fitness_user.id,
        created_by_id=fitness_user.id,
        title="Atingir 85kg em 90 dias",
        description="Bulking limpo",
        category="weight_gain",
        target_value=85.0,
        current_value=82.0,
        initial_value=80.0,
        unit="kg",
        target_date=datetime.utcnow() + timedelta(days=90),
        status="active",
        progress_percentage=40.0,
    )
    db_session.add(goal)
    await db_session.commit()
    await db_session.refresh(goal)
    return goal


@pytest_asyncio.fixture
async def active_diet(db_session: AsyncSession, fitness_user: User) -> Diet:
    """Cria dieta ativa do aluno."""
    diet = Diet(
        id=uuid4(),
        user_id=fitness_user.id,
        professional_id=None,
        is_custom=False,
        name="Hipertrofia 3000 kcal",
        goal="bulking",
        is_active=True,
    )
    db_session.add(diet)
    await db_session.commit()
    await db_session.refresh(diet)
    return diet


# ── Card 18 — Escolha do LLM ──────────────────────────────────────────────────


class TestLLMConfiguration:
    """Card 18: O LLM correto está configurado e a stack é Groq + Llama 3.3 70B."""

    def test_llm_provider_is_configured(self):
        """Settings deve ter GROQ_API_KEY e GROQ_MODEL definidos."""
        assert hasattr(settings, "GROQ_API_KEY")
        assert hasattr(settings, "GROQ_MODEL")
        assert settings.GROQ_MODEL == "llama-3.3-70b-versatile"

    def test_embeddings_dimension_matches_huggingface(self):
        """Dimensão de embeddings deve ser 384 (all-MiniLM-L6-v2)."""
        assert settings.RAG_EMBEDDING_DIM == 384

    def test_max_response_latency_setting_exists(self):
        """Deve existir CHAT_MAX_RESPONSE_LATENCY_MS no settings (otimização ≤ 2s)."""
        # Esperado após Tarefa 6 do PRD
        assert hasattr(settings, "CHAT_MAX_RESPONSE_LATENCY_MS"), (
            "settings.CHAT_MAX_RESPONSE_LATENCY_MS deve existir após otimização de performance"
        )
        assert settings.CHAT_MAX_RESPONSE_LATENCY_MS <= 2000


# ── Card 18.1 — Serviço de Integração com IA ──────────────────────────────────


class TestRAGChainCharacteristics:
    """Card 18.1: O RAGChain é centralizado, isolado e tolerante a falhas."""

    def test_rag_chain_is_centralized_singleton(self):
        """Deve existir instância singleton de RAGChain importável."""
        assert rag_chain is not None
        assert isinstance(rag_chain, RAGChain)

    def test_rag_chain_module_does_not_import_routes(self):
        """RAGChain não deve importar de app.routes (camada superior)."""
        source = inspect.getsource(rag_chain_module)
        assert "from app.routes" not in source
        assert "import app.routes" not in source

    def test_rag_chain_module_does_not_import_controllers(self):
        """RAGChain não deve importar de app.controllers (camada superior)."""
        source = inspect.getsource(rag_chain_module)
        assert "from app.controllers" not in source
        assert "import app.controllers" not in source

    def test_rag_chain_module_does_not_import_dtos(self):
        """RAGChain não deve depender de DTOs (Pydantic da camada de aplicação)."""
        source = inspect.getsource(rag_chain_module)
        assert "from app.dtos" not in source
        assert "import app.dtos" not in source

    @pytest.mark.asyncio
    async def test_rag_chain_fallback_on_generation_failure(self):
        """Falha do LLM deve produzir RAGResult com mensagem de fallback amigável."""
        chain = RAGChain()
        chain.retrieve = AsyncMock(return_value=[])
        chain.generate = AsyncMock(side_effect=RuntimeError("Provedor indisponível"))

        result = await chain.run(query="Como faço supino?", session=AsyncMock())

        assert isinstance(result, RAGResult)
        # No estado de "retrieve vazio", o pipeline pode escalar antes de chamar generate.
        # O importante é que o usuário receba uma mensagem segura — nunca uma exceção crua.
        assert result.answer  # mensagem não vazia
        assert result.should_escalate is True


# ── Card 18.3 — Contexto Real do Aluno (CRÍTICO) ─────────────────────────────


class TestUserContextRealData:
    """Card 18.3: O contexto deve incluir dados REAIS do aluno (ficha, metas, dieta)."""

    @pytest.mark.asyncio
    async def test_context_includes_user_profile(
        self, chat_service, fitness_user
    ):
        """Contexto deve incluir nome, role e dados corporais do aluno."""
        context = await chat_service._build_user_context(fitness_user.id)

        assert "user_profile" in context
        profile = context["user_profile"]
        assert profile.get("name") == "Carlos Pereira"
        assert profile.get("role") == "client"
        assert profile.get("weight") == 82.0
        assert profile.get("height") == 178.0
        assert profile.get("goal_type") == "hipertrofia"

    @pytest.mark.asyncio
    async def test_context_includes_active_workout_sheet(
        self, chat_service, fitness_user, workout_sheet_with_exercises
    ):
        """Contexto deve preencher 'active_workout_sheet' com ficha REAL — não None."""
        context = await chat_service._build_user_context(fitness_user.id)

        sheet = context.get("active_workout_sheet")
        assert sheet is not None, (
            "BUG conhecido: _build_user_context retorna sempre None. "
            "Após fix, deve carregar ficha ativa via WorkoutSheetRepository."
        )
        assert sheet.get("name") == "Treino A — Peito/Tríceps"
        exercises = sheet.get("exercises") or []
        assert len(exercises) >= 1
        assert any(ex.get("name") == "Supino Reto" for ex in exercises)

    @pytest.mark.asyncio
    async def test_context_includes_active_goals(
        self, chat_service, fitness_user, active_goal
    ):
        """Contexto deve incluir metas em andamento do aluno."""
        context = await chat_service._build_user_context(fitness_user.id)

        goals = context.get("active_goals")
        assert goals is not None and len(goals) >= 1
        titles = [g.get("title") for g in goals]
        assert "Atingir 85kg em 90 dias" in titles

    @pytest.mark.asyncio
    async def test_context_includes_active_diet(
        self, chat_service, fitness_user, active_diet
    ):
        """Contexto deve incluir dieta ativa quando existir."""
        context = await chat_service._build_user_context(fitness_user.id)

        diet = context.get("active_diet")
        assert diet is not None
        assert diet.get("name") == "Hipertrofia 3000 kcal"
        assert diet.get("goal") == "bulking"

    @pytest.mark.asyncio
    async def test_context_includes_recent_history(
        self, chat_service, fitness_user
    ):
        """Contexto deve incluir histórico de treinos recente (chave 'recent_history')."""
        context = await chat_service._build_user_context(fitness_user.id)

        # Mesmo sem registros, a chave deve existir como lista (vazia) — não None.
        assert "recent_history" in context
        assert isinstance(context["recent_history"], list)

    @pytest.mark.asyncio
    async def test_context_respects_user_privacy(
        self, chat_service, db_session, fitness_user, workout_sheet_with_exercises
    ):
        """Contexto de outro aluno NÃO deve vazar para o aluno autenticado."""
        # Cria outro usuário com sua própria ficha
        other = User(
            id=uuid4(),
            name="Outro Aluno",
            email="outro@test.com",
            password="hash",
            role="client",
            is_active=True,
        )
        db_session.add(other)
        await db_session.flush()

        other_sheet = WorkoutSheet(
            id=uuid4(),
            user_id=other.id,
            name="Treino Confidencial",
            day_of_week=2,
            is_active=True,
        )
        db_session.add(other_sheet)
        await db_session.commit()

        context = await chat_service._build_user_context(fitness_user.id)
        sheet = context.get("active_workout_sheet")
        if sheet:
            assert sheet.get("name") != "Treino Confidencial"


# ── Cards 18.4 / 18.5 / 18.6 — Domínios cobertos pelo system prompt ───────────


class TestSystemPromptDomains:
    """Cards 18.4-18.6: System prompt deve cobrir treino, execução e nutrição."""

    def test_system_prompt_addresses_training_domain(self):
        """Card 18.4: prompt deve mencionar 'treino' como domínio."""
        prompt_lower = SYSTEM_PROMPT_TEMPLATE.lower()
        assert "treino" in prompt_lower

    def test_system_prompt_addresses_execution_domain(self):
        """Card 18.5: prompt deve mencionar 'execução' (técnica) explicitamente."""
        prompt_lower = SYSTEM_PROMPT_TEMPLATE.lower()
        assert "execução" in prompt_lower or "execucao" in prompt_lower

    def test_system_prompt_addresses_nutrition_domain(self):
        """Card 18.6: prompt deve mencionar 'nutrição' como domínio coberto."""
        prompt_lower = SYSTEM_PROMPT_TEMPLATE.lower()
        assert "nutri" in prompt_lower

    def test_system_prompt_avoids_medical_recommendations(self):
        """Card 18.6: prompt deve instruir a NÃO dar recomendações médicas."""
        prompt_lower = SYSTEM_PROMPT_TEMPLATE.lower()
        assert "saúde" in prompt_lower or "saude" in prompt_lower
        # Deve haver instrução para evitar recomendações fora do escopo
        assert (
            "consultar" in prompt_lower
            or "profissional" in prompt_lower
            or "médico" in prompt_lower
            or "medico" in prompt_lower
        )


# ── Cards 19.3-19.8 — Pipeline RAG ────────────────────────────────────────────


class TestRAGPipelineWithRealContext:
    """Cards 19.3-19.8: pipeline integra busca + geração e usa contexto real."""

    @pytest.mark.asyncio
    async def test_pipeline_uses_real_context_in_augment(
        self, chat_service, fitness_user, workout_sheet_with_exercises, active_goal, active_diet
    ):
        """Augment deve incluir nome do aluno, ficha, metas no prompt final."""
        context = await chat_service._build_user_context(fitness_user.id)

        chain = RAGChain()
        prompt = chain.augment(
            query="Como melhoro no supino?",
            retrieved_docs=[],
            user_context=context,
            conversation_history=[],
        )

        assert "Carlos Pereira" in prompt
        # Esperado após enriquecimento do contexto:
        assert "Treino A — Peito/Tríceps" in prompt or "Supino Reto" in prompt

    @pytest.mark.asyncio
    async def test_pipeline_no_sensitive_data_in_prompt(
        self, chat_service, fitness_user
    ):
        """Prompt NÃO deve expor email/senha do usuário."""
        context = await chat_service._build_user_context(fitness_user.id)

        chain = RAGChain()
        prompt = chain.augment(
            query="dúvida",
            retrieved_docs=[],
            user_context=context,
            conversation_history=[],
        )

        assert "carlos@test.com" not in prompt
        assert "hash_fake" not in prompt
        assert "password" not in prompt.lower()


# ── Performance — Latência ≤ 2s ───────────────────────────────────────────────


class TestPipelinePerformance:
    """Card 18 / 19.5: latência total deve respeitar CHAT_MAX_RESPONSE_LATENCY_MS."""

    def test_warm_up_method_exists_on_rag_chain(self):
        """RAGChain deve expor método warm_up() para inicialização ansiosa."""
        assert hasattr(rag_chain, "warm_up"), (
            "RAGChain.warm_up() deve existir após otimização de performance"
        )

    @pytest.mark.asyncio
    async def test_pipeline_records_latency_metric(self, fitness_user):
        """RAGResult deve registrar latency_ms ao final do pipeline."""
        chain = RAGChain()
        chain.retrieve = AsyncMock(return_value=[
            RetrievedDocument(
                id=str(uuid4()),
                title="Doc",
                content="conteúdo",
                relevance_score=0.85,
                category="exercicio",
            )
        ])
        chain.generate = AsyncMock(return_value=("Resposta válida e detalhada com mais de vinte caracteres.", 30, "llama-3.3-70b-versatile"))

        start = time.monotonic()
        result = await chain.run(query="oi", session=AsyncMock())
        elapsed_ms = int((time.monotonic() - start) * 1000)

        assert result.latency_ms >= 0
        # Sanidade: a medição interna não pode exceder o tempo real do teste
        assert result.latency_ms <= elapsed_ms + 50


# ── Validação pós-geração simplificada (Tarefa 8) ─────────────────────────────


class TestPostGenerationValidation:
    """Tarefa 8 do PRD: validação pós-geração deve ser previsível e sem dead code."""

    @pytest.mark.asyncio
    async def test_run_does_not_double_escalate(self, fitness_user):
        """Sucesso do FAQ/RAG não deve depois desativar escalação previamente correta."""
        chain = RAGChain()
        chain.retrieve = AsyncMock(return_value=[
            RetrievedDocument(
                id=str(uuid4()),
                title="Supino",
                content="Conteúdo do supino",
                relevance_score=0.9,
                category="exercicio",
            )
        ])
        chain.generate = AsyncMock(return_value=(
            "Resposta longa e válida sobre o supino reto, descrevendo a execução.",
            50,
            "llama-3.3-70b-versatile",
        ))

        result = await chain.run(query="como faço supino?", session=AsyncMock())

        # Sucesso → não escalar
        assert result.should_escalate is False
        assert result.escalation_reason == ""

    @pytest.mark.asyncio
    async def test_run_keeps_validation_failed_escalation(self, fitness_user):
        """Resposta inválida (vazia) deve escalar com reason='validation_failed' e mensagem de fallback."""
        chain = RAGChain()
        chain.retrieve = AsyncMock(return_value=[
            RetrievedDocument(
                id=str(uuid4()),
                title="Doc",
                content="conteúdo",
                relevance_score=0.85,
                category="exercicio",
            )
        ])
        # Resposta muito curta → invalida na validate()
        chain.generate = AsyncMock(return_value=("ok", 5, "llama-3.3-70b-versatile"))

        result = await chain.run(query="dúvida válida", session=AsyncMock())

        assert result.should_escalate is True
        assert result.escalation_reason == "validation_failed"
        assert "Personal" in result.answer or "base de conhecimento" in result.answer.lower()


# ── Streaming de status (Tarefa 7 do PRD) ─────────────────────────────────────


class TestStreamingStatusCallback:
    """Tarefa 7: ChatService deve emitir status intermediários via callback opcional.

    Isso desacopla a lógica de geração de WebSocket — o WebSocket apenas
    repassa os eventos do callback. Os testes ficam unitários.
    """

    @pytest.mark.asyncio
    async def test_send_message_supports_on_status_callback(
        self, chat_service, fitness_user
    ):
        """ChatService.send_message deve aceitar callback opcional 'on_status'."""
        statuses = []

        async def on_status(event: dict):
            statuses.append(event)

        rag_result = RAGResult(
            answer="O supino é um exercício clássico de peito; comece com a barra na linha do peitoral.",
            retrieved_documents=[
                RetrievedDocument(
                    id=str(uuid4()),
                    title="Supino",
                    content="...",
                    relevance_score=0.9,
                    category="exercicio",
                )
            ],
            should_escalate=False,
            model_used="llama-3.3-70b-versatile",
            tokens_used=30,
            latency_ms=300,
            confidence_score=0.9,
        )

        with patch("app.services.chat_service.rag_chain") as mock_rag:
            mock_rag.run = AsyncMock(return_value=rag_result)

            await chat_service.send_message(
                user_id=fitness_user.id,
                message="Como faço supino?",
                on_status=on_status,
            )

        # Esperam-se 3 eventos de status: thinking → searching → generating
        kinds = [s.get("status") for s in statuses]
        assert "thinking" in kinds, f"Deve emitir status 'thinking'. Recebido: {kinds}"
        assert "searching" in kinds, f"Deve emitir status 'searching'. Recebido: {kinds}"
        assert "generating" in kinds, f"Deve emitir status 'generating'. Recebido: {kinds}"

    @pytest.mark.asyncio
    async def test_status_callback_messages_are_human_readable(
        self, chat_service, fitness_user
    ):
        """Cada evento de status deve conter mensagem em português para exibir no UI."""
        events = []

        async def on_status(event: dict):
            events.append(event)

        rag_result = RAGResult(
            answer="Resposta completa sobre a dúvida do aluno descrevendo execução com clareza.",
            retrieved_documents=[],
            should_escalate=False,
            model_used="llama-3.3-70b-versatile",
            tokens_used=30,
            latency_ms=300,
        )

        with patch("app.services.chat_service.rag_chain") as mock_rag:
            mock_rag.run = AsyncMock(return_value=rag_result)

            await chat_service.send_message(
                user_id=fitness_user.id,
                message="dúvida",
                on_status=on_status,
            )

        for ev in events:
            assert "message" in ev and isinstance(ev["message"], str) and len(ev["message"]) > 0
            assert "type" in ev and ev["type"] == "status"
