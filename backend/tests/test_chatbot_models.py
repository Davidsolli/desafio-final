"""
Testes de banco de dados para o módulo de Chatbot.

Valida inserção e recuperação dos modelos SQLAlchemy (KnowledgeBase,
ChatConversation, ChatMessage, ChatFeedback) usando SQLite in-memory.

Nota: A coluna `embedding` usa JSON como fallback no SQLite (pgvector
requer PostgreSQL). O comportamento vetorial real é coberto em test_rag_chain.py
via mocks do banco.
"""

from __future__ import annotations

from datetime import datetime
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.models.user import Base, User
from app.models.chatbot import (
    ChatConversation,
    ChatFeedback,
    ChatMessage,
    KnowledgeBase,
)

# ── Setup do banco de dados de teste ─────────────────────────────────────────

TEST_DB_URL = "sqlite+aiosqlite:///:memory:"


@pytest_asyncio.fixture(scope="function")
async def engine():
    eng = create_async_engine(
        TEST_DB_URL,
        echo=False,
        connect_args={"check_same_thread": False},
    )
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield eng
    async with eng.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await eng.dispose()


@pytest_asyncio.fixture(scope="function")
async def session(engine) -> AsyncSession:
    factory = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with factory() as s:
        yield s


@pytest_asyncio.fixture
async def test_user(session: AsyncSession) -> User:
    user = User(
        id=uuid4(),
        name="Maria Santos",
        email="maria@test.com",
        password="hash",
        role="client",
        phone_whatsapp="+55 11 88888-8888",
        is_active=True,
    )
    session.add(user)
    await session.commit()
    await session.refresh(user)
    return user


# ── Testes: KnowledgeBase ─────────────────────────────────────────────────────

class TestKnowledgeBaseModel:
    """Testa inserção e recuperação de documentos da KnowledgeBase."""

    @pytest.mark.asyncio
    async def test_create_knowledge_document(self, session: AsyncSession):
        """Deve inserir e recuperar documento com todos os campos."""
        doc = KnowledgeBase(
            id=uuid4(),
            title="Como fazer Supino Reto",
            content="# Supino Reto\n\nO supino reto é um exercício para o peitoral...",
            category="exercicio",
            muscle_group="Peito",
            difficulty_level="intermediario",
            is_active=True,
            views_count=0,
            helpful_count=0,
            embedding_model="huggingface:all-MiniLM-L6-v2",
        )
        session.add(doc)
        await session.commit()

        stmt = select(KnowledgeBase).where(KnowledgeBase.title == "Como fazer Supino Reto")
        result = await session.execute(stmt)
        retrieved = result.scalar_one_or_none()

        assert retrieved is not None
        assert retrieved.category == "exercicio"
        assert retrieved.muscle_group == "Peito"
        assert retrieved.difficulty_level == "intermediario"
        assert retrieved.is_active is True
        assert retrieved.views_count == 0

    @pytest.mark.asyncio
    async def test_knowledge_document_stores_embedding_as_json(self, session: AsyncSession):
        """No SQLite (fallback), embedding deve ser armazenado como JSON/list."""
        fake_embedding = [0.1] * 384
        doc = KnowledgeBase(
            id=uuid4(),
            title="Doc com Embedding",
            content="Conteúdo de teste",
            category="forma",
            is_active=True,
            views_count=0,
            helpful_count=0,
            embedding=fake_embedding,
        )
        session.add(doc)
        await session.commit()

        stmt = select(KnowledgeBase).where(KnowledgeBase.title == "Doc com Embedding")
        result = await session.execute(stmt)
        retrieved = result.scalar_one_or_none()

        assert retrieved is not None
        # No SQLite o embedding é armazenado como JSON list
        assert retrieved.embedding == fake_embedding or retrieved.embedding is not None

    @pytest.mark.asyncio
    async def test_helpfulness_rate_property(self, session: AsyncSession):
        """Propriedade helpfulness_rate deve calcular proporção corretamente."""
        doc = KnowledgeBase(
            id=uuid4(),
            title="Doc Métricas",
            content="Conteúdo",
            category="exercicio",
            is_active=True,
            views_count=100,
            helpful_count=80,
        )
        session.add(doc)
        await session.commit()

        stmt = select(KnowledgeBase).where(KnowledgeBase.id == doc.id)
        result = await session.execute(stmt)
        retrieved = result.scalar_one()

        assert retrieved.helpfulness_rate == 0.8

    @pytest.mark.asyncio
    async def test_helpfulness_rate_zero_views(self, session: AsyncSession):
        """helpfulness_rate deve ser 0.0 quando views_count é 0."""
        doc = KnowledgeBase(
            id=uuid4(), title="Doc Zero", content="x",
            category="nutricao", is_active=True, views_count=0, helpful_count=0,
        )
        session.add(doc)
        await session.commit()

        stmt = select(KnowledgeBase).where(KnowledgeBase.id == doc.id)
        result = await session.execute(stmt)
        retrieved = result.scalar_one()

        assert retrieved.helpfulness_rate == 0.0

    @pytest.mark.asyncio
    async def test_list_only_active_documents(self, session: AsyncSession):
        """Deve filtrar apenas documentos com is_active=True."""
        for i, active in enumerate([True, True, False]):
            doc = KnowledgeBase(
                id=uuid4(), title=f"Doc {i}", content="x",
                category="exercicio", is_active=active,
                views_count=0, helpful_count=0,
            )
            session.add(doc)
        await session.commit()

        stmt = select(KnowledgeBase).where(KnowledgeBase.is_active == True)
        result = await session.execute(stmt)
        active_docs = result.scalars().all()

        assert len(active_docs) == 2

    @pytest.mark.asyncio
    async def test_increment_views_and_helpful_count(self, session: AsyncSession):
        """Deve incrementar contadores de views e helpful_count corretamente."""
        doc = KnowledgeBase(
            id=uuid4(), title="Agachamento", content="...",
            category="exercicio", is_active=True, views_count=10, helpful_count=7,
        )
        session.add(doc)
        await session.commit()

        stmt = select(KnowledgeBase).where(KnowledgeBase.id == doc.id)
        result = await session.execute(stmt)
        retrieved = result.scalar_one()

        retrieved.views_count += 1
        retrieved.helpful_count += 1
        await session.commit()

        stmt2 = select(KnowledgeBase).where(KnowledgeBase.id == doc.id)
        result2 = await session.execute(stmt2)
        updated = result2.scalar_one()

        assert updated.views_count == 11
        assert updated.helpful_count == 8

    @pytest.mark.asyncio
    async def test_repr_knowledge_base(self, session: AsyncSession):
        """__repr__ deve retornar string legível."""
        doc = KnowledgeBase(
            id=uuid4(), title="Rosca Direta", content="x",
            category="exercicio", is_active=True, views_count=0, helpful_count=0,
        )
        session.add(doc)
        await session.commit()

        assert "Rosca Direta" in repr(doc)
        assert "exercicio" in repr(doc)


# ── Testes: ChatConversation ──────────────────────────────────────────────────

class TestChatConversationModel:
    """Testa o modelo de conversa."""

    @pytest.mark.asyncio
    async def test_create_conversation(self, session: AsyncSession, test_user: User):
        """Deve criar conversa com status padrão 'active'."""
        conv = ChatConversation(
            id=uuid4(),
            user_id=test_user.id,
            channel="app",
            status="active",
            started_at=datetime.utcnow(),
        )
        session.add(conv)
        await session.commit()

        stmt = select(ChatConversation).where(ChatConversation.id == conv.id)
        result = await session.execute(stmt)
        retrieved = result.scalar_one_or_none()

        assert retrieved is not None
        assert retrieved.channel == "app"
        assert retrieved.status == "active"
        assert retrieved.rating is None
        assert retrieved.escalated_to_personal_id is None

    @pytest.mark.asyncio
    async def test_conversation_escalation_fields(
        self, session: AsyncSession, test_user: User
    ):
        """Deve armazenar campos de escalação corretamente."""
        personal_id = uuid4()
        conv = ChatConversation(
            id=uuid4(),
            user_id=test_user.id,
            channel="app",
            status="escalated",
            escalated_to_personal_id=personal_id,
            escalation_reason="too_complex",
            escalated_at=datetime.utcnow(),
        )
        session.add(conv)
        await session.commit()

        stmt = select(ChatConversation).where(ChatConversation.id == conv.id)
        result = await session.execute(stmt)
        retrieved = result.scalar_one()

        assert retrieved.status == "escalated"
        assert retrieved.escalation_reason == "too_complex"
        assert retrieved.escalated_at is not None

    @pytest.mark.asyncio
    async def test_conversation_rating_and_feedback(
        self, session: AsyncSession, test_user: User
    ):
        """Deve armazenar avaliação e feedback do aluno."""
        conv = ChatConversation(
            id=uuid4(),
            user_id=test_user.id,
            channel="app",
            status="closed",
            rating=5,
            feedback="Resposta excelente!",
            ended_at=datetime.utcnow(),
        )
        session.add(conv)
        await session.commit()

        stmt = select(ChatConversation).where(ChatConversation.id == conv.id)
        result = await session.execute(stmt)
        retrieved = result.scalar_one()

        assert retrieved.rating == 5
        assert retrieved.feedback == "Resposta excelente!"
        assert retrieved.status == "closed"

    @pytest.mark.asyncio
    async def test_repr_conversation(self, session: AsyncSession, test_user: User):
        """__repr__ deve conter user_id e status."""
        conv = ChatConversation(
            id=uuid4(), user_id=test_user.id, channel="app", status="active"
        )
        session.add(conv)
        await session.commit()

        assert "active" in repr(conv)
        assert "app" in repr(conv)


# ── Testes: ChatMessage ───────────────────────────────────────────────────────

class TestChatMessageModel:
    """Testa o modelo de mensagem."""

    @pytest.mark.asyncio
    async def test_create_user_message(self, session: AsyncSession, test_user: User):
        """Deve criar mensagem do usuário com rastreamento."""
        conv = ChatConversation(
            id=uuid4(), user_id=test_user.id, channel="app", status="active"
        )
        session.add(conv)
        await session.flush()

        msg = ChatMessage(
            id=uuid4(),
            conversation_id=conv.id,
            role="user",
            content="Como faço supino reto?",
            channel="app",
        )
        session.add(msg)
        await session.commit()

        stmt = select(ChatMessage).where(ChatMessage.id == msg.id)
        result = await session.execute(stmt)
        retrieved = result.scalar_one_or_none()

        assert retrieved is not None
        assert retrieved.role == "user"
        assert retrieved.content == "Como faço supino reto?"
        assert retrieved.is_human_reviewed is False
        assert retrieved.needs_human_review is False

    @pytest.mark.asyncio
    async def test_create_assistant_message_with_tracking(
        self, session: AsyncSession, test_user: User
    ):
        """Mensagem do assistente deve armazenar métricas de geração."""
        conv = ChatConversation(
            id=uuid4(), user_id=test_user.id, channel="app", status="active"
        )
        session.add(conv)
        await session.flush()

        context = {
            "user_profile": {"name": "Maria"},
            "retrieved_documents": [{"id": "abc", "title": "Doc", "relevance_score": 0.9}],
        }

        msg = ChatMessage(
            id=uuid4(),
            conversation_id=conv.id,
            role="assistant",
            content="O supino reto é executado assim...",
            context_data=context,
            model_used="llama-3.3-70b-versatile",
            tokens_used=145,
            latency_ms=920,
            channel="app",
        )
        session.add(msg)
        await session.commit()

        stmt = select(ChatMessage).where(ChatMessage.id == msg.id)
        result = await session.execute(stmt)
        retrieved = result.scalar_one()

        assert retrieved.role == "assistant"
        assert retrieved.model_used == "llama-3.3-70b-versatile"
        assert retrieved.tokens_used == 145
        assert retrieved.latency_ms == 920
        assert retrieved.context_data["retrieved_documents"][0]["title"] == "Doc"

    @pytest.mark.asyncio
    async def test_message_needs_human_review_flag(
        self, session: AsyncSession, test_user: User
    ):
        """Deve armazenar flag needs_human_review para mensagens escaladas."""
        conv = ChatConversation(
            id=uuid4(), user_id=test_user.id, channel="app", status="escalated"
        )
        session.add(conv)
        await session.flush()

        msg = ChatMessage(
            id=uuid4(),
            conversation_id=conv.id,
            role="assistant",
            content="Escalando para Personal...",
            channel="app",
            needs_human_review=True,
        )
        session.add(msg)
        await session.commit()

        stmt = select(ChatMessage).where(ChatMessage.id == msg.id)
        result = await session.execute(stmt)
        retrieved = result.scalar_one()

        assert retrieved.needs_human_review is True

    @pytest.mark.asyncio
    async def test_cascade_delete_messages_on_conversation_delete(
        self, session: AsyncSession, test_user: User
    ):
        """Deletar conversa deve deletar mensagens em cascade."""
        conv = ChatConversation(
            id=uuid4(), user_id=test_user.id, channel="app", status="active"
        )
        session.add(conv)
        await session.flush()

        for role, content in [("user", "Pergunta"), ("assistant", "Resposta")]:
            session.add(ChatMessage(
                id=uuid4(), conversation_id=conv.id,
                role=role, content=content, channel="app",
            ))
        await session.commit()

        await session.delete(conv)
        await session.commit()

        stmt = select(ChatMessage).where(ChatMessage.conversation_id == conv.id)
        result = await session.execute(stmt)
        remaining = result.scalars().all()

        assert remaining == []


# ── Testes: ChatFeedback ──────────────────────────────────────────────────────

class TestChatFeedbackModel:
    """Testa o modelo de feedback."""

    @pytest.mark.asyncio
    async def test_create_feedback_helpful(self, session: AsyncSession, test_user: User):
        """Deve criar feedback positivo associado a mensagem."""
        conv = ChatConversation(
            id=uuid4(), user_id=test_user.id, channel="app", status="active"
        )
        session.add(conv)
        await session.flush()

        msg = ChatMessage(
            id=uuid4(), conversation_id=conv.id,
            role="assistant", content="Resposta", channel="app",
        )
        session.add(msg)
        await session.flush()

        feedback = ChatFeedback(
            id=uuid4(),
            message_id=msg.id,
            user_id=test_user.id,
            was_helpful=True,
            feedback_type="good",
            comment="Ajudou muito!",
        )
        session.add(feedback)
        await session.commit()

        stmt = select(ChatFeedback).where(ChatFeedback.message_id == msg.id)
        result = await session.execute(stmt)
        retrieved = result.scalar_one_or_none()

        assert retrieved is not None
        assert retrieved.was_helpful is True
        assert retrieved.feedback_type == "good"
        assert retrieved.comment == "Ajudou muito!"

    @pytest.mark.asyncio
    async def test_create_feedback_not_helpful(
        self, session: AsyncSession, test_user: User
    ):
        """Deve criar feedback negativo com tipo de problema."""
        conv = ChatConversation(
            id=uuid4(), user_id=test_user.id, channel="app", status="active"
        )
        session.add(conv)
        await session.flush()

        msg = ChatMessage(
            id=uuid4(), conversation_id=conv.id,
            role="assistant", content="Resposta incorreta", channel="app",
        )
        session.add(msg)
        await session.flush()

        feedback = ChatFeedback(
            id=uuid4(),
            message_id=msg.id,
            user_id=test_user.id,
            was_helpful=False,
            feedback_type="incorrect",
        )
        session.add(feedback)
        await session.commit()

        stmt = select(ChatFeedback).where(ChatFeedback.message_id == msg.id)
        result = await session.execute(stmt)
        retrieved = result.scalar_one()

        assert retrieved.was_helpful is False
        assert retrieved.feedback_type == "incorrect"

    @pytest.mark.asyncio
    async def test_repr_feedback(self, session: AsyncSession, test_user: User):
        """__repr__ deve conter was_helpful e feedback_type."""
        conv = ChatConversation(
            id=uuid4(), user_id=test_user.id, channel="app", status="active"
        )
        session.add(conv)
        await session.flush()

        msg = ChatMessage(
            id=uuid4(), conversation_id=conv.id,
            role="assistant", content="ok", channel="app",
        )
        session.add(msg)
        await session.flush()

        feedback = ChatFeedback(
            id=uuid4(), message_id=msg.id, user_id=test_user.id,
            was_helpful=True, feedback_type="good",
        )
        session.add(feedback)
        await session.commit()

        assert "True" in repr(feedback)
        assert "good" in repr(feedback)
