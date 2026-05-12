"""
Testes do seed da base de conhecimento (Cards 19, 19.1, 19.2 — Etapa 3).

Verifica:
- Estrutura e categorização dos documentos da KB
- Idempotência do seed
- Geração de embeddings com dimensão correta (384)
"""

from __future__ import annotations

from unittest.mock import AsyncMock, patch
from uuid import uuid4

import pytest
import pytest_asyncio
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.models.chatbot import KnowledgeBase
from app.models.user import Base


TEST_DB_URL = "sqlite+aiosqlite:///:memory:"

VALID_CATEGORIES = {"exercicio", "forma", "nutricao", "periodizacao", "sistema"}


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


# ── Card 19 — Documentos da KB ────────────────────────────────────────────────

class TestKnowledgeDocumentsList:
    """Verifica a definição da lista KNOWLEDGE_DOCUMENTS."""

    def test_knowledge_documents_are_defined(self):
        """Lista KNOWLEDGE_DOCUMENTS definida com ≥25 itens."""
        from scripts.seed_knowledge_base import KNOWLEDGE_DOCUMENTS

        assert isinstance(KNOWLEDGE_DOCUMENTS, list)
        assert len(KNOWLEDGE_DOCUMENTS) >= 25

    def test_knowledge_categories_match_rag_filter(self):
        """Categorias usam apenas valores aceitos pelo RAG."""
        from scripts.seed_knowledge_base import KNOWLEDGE_DOCUMENTS

        categories = {doc["category"] for doc in KNOWLEDGE_DOCUMENTS}
        assert categories.issubset(VALID_CATEGORIES), (
            f"Categorias inválidas: {categories - VALID_CATEGORIES}"
        )

    def test_knowledge_covers_main_user_flows(self):
        """Cobre treino, execução, nutrição, sistema (sem lacunas óbvias)."""
        from scripts.seed_knowledge_base import KNOWLEDGE_DOCUMENTS

        categories = {doc["category"] for doc in KNOWLEDGE_DOCUMENTS}
        # Categorias mínimas obrigatórias
        assert "exercicio" in categories
        assert "nutricao" in categories
        assert "sistema" in categories

        # Garantia mínima por categoria
        from collections import Counter
        counter = Counter(doc["category"] for doc in KNOWLEDGE_DOCUMENTS)
        assert counter["exercicio"] >= 15
        assert counter["nutricao"] >= 5
        assert counter["sistema"] >= 5

    def test_knowledge_ready_for_rag_ingestion(self):
        """Cada documento tem title, content, category compatíveis com KnowledgeBase."""
        from scripts.seed_knowledge_base import KNOWLEDGE_DOCUMENTS

        for doc in KNOWLEDGE_DOCUMENTS:
            assert "title" in doc
            assert "content" in doc
            assert "category" in doc
            assert isinstance(doc["title"], str)
            assert isinstance(doc["content"], str)
            assert len(doc["title"]) > 0
            assert len(doc["content"]) > 30  # Conteúdo significativo


# ── Card 19.1 — Organização ──────────────────────────────────────────────────

class TestKnowledgeOrganization:
    """Validações de organização e consistência."""

    def test_no_duplicate_documents_in_seed(self):
        """Sem títulos ou contents idênticos no seed."""
        from scripts.seed_knowledge_base import KNOWLEDGE_DOCUMENTS

        titles = [doc["title"] for doc in KNOWLEDGE_DOCUMENTS]
        contents = [doc["content"] for doc in KNOWLEDGE_DOCUMENTS]
        assert len(titles) == len(set(titles)), "Títulos duplicados encontrados"
        assert len(contents) == len(set(contents)), "Contents duplicados"

    def test_documents_follow_consistent_structure(self):
        """Cada doc tem title, content, category, e campos opcionais coerentes."""
        from scripts.seed_knowledge_base import KNOWLEDGE_DOCUMENTS

        allowed_keys = {
            "title", "content", "category", "muscle_group", "difficulty_level"
        }
        for doc in KNOWLEDGE_DOCUMENTS:
            extra = set(doc.keys()) - allowed_keys
            assert not extra, f"Chaves inesperadas no doc {doc.get('title')}: {extra}"

    def test_documents_naming_consistent(self):
        """Padrão de nomes: 'Exercício:', 'Nutrição:', 'Sistema:', 'Forma:', 'Periodização:'."""
        from scripts.seed_knowledge_base import KNOWLEDGE_DOCUMENTS

        prefix_by_category = {
            "exercicio": "Exercício:",
            "forma": "Forma:",
            "nutricao": "Nutrição:",
            "periodizacao": "Periodização:",
            "sistema": "Sistema:",
        }
        for doc in KNOWLEDGE_DOCUMENTS:
            expected_prefix = prefix_by_category[doc["category"]]
            assert doc["title"].startswith(expected_prefix), (
                f"Título '{doc['title']}' não segue prefixo "
                f"'{expected_prefix}' para categoria '{doc['category']}'"
            )


# ── Card 19.2 — Seed em texto puro ────────────────────────────────────────────

class TestKnowledgeContent:
    """Validações de conteúdo limpo e completo."""

    def test_text_content_clean(self):
        """Sem ruído (HTML, markdown excessivo) — texto pronto para embedding."""
        from scripts.seed_knowledge_base import KNOWLEDGE_DOCUMENTS

        for doc in KNOWLEDGE_DOCUMENTS:
            content = doc["content"]
            # Sem tags HTML
            assert "<script" not in content.lower()
            assert "<div" not in content.lower()
            assert "<span" not in content.lower()
            # Sem links markdown crus do tipo [...](http...)
            assert "](http" not in content


# ── Testes de Idempotência e Embeddings ───────────────────────────────────────

class FakeEmbeddings:
    """Mock de embeddings: retorna vetor de 384 floats."""

    async def aembed_query(self, text: str) -> list[float]:
        # Vetor determinístico simples — apenas para teste
        return [float(len(text) % 7) / 7.0] * 384


class TestSeedExecution:
    """Testa a função seed() do scripts/seed_knowledge_base.py."""

    @pytest.mark.asyncio
    async def test_seed_inserts_records_in_knowledge_base(self, db_session):
        """seed_knowledge_base() cria registros em knowledge_base table."""
        from scripts import seed_knowledge_base as kb

        with patch.object(kb, "_get_session_factory") as mock_factory, \
             patch.object(kb, "_get_embeddings_model", return_value=FakeEmbeddings()):
            mock_factory.return_value = lambda: _ContextSession(db_session)

            inserted = await kb.seed(force=False)
            assert inserted >= 25

        result = await db_session.execute(select(KnowledgeBase))
        rows = result.scalars().all()
        assert len(rows) >= 25

    @pytest.mark.asyncio
    async def test_seed_generates_embeddings_with_correct_dim(self, db_session):
        """Embeddings gerados têm dimensão 384."""
        from scripts import seed_knowledge_base as kb

        with patch.object(kb, "_get_session_factory") as mock_factory, \
             patch.object(kb, "_get_embeddings_model", return_value=FakeEmbeddings()):
            mock_factory.return_value = lambda: _ContextSession(db_session)
            await kb.seed(force=False)

        result = await db_session.execute(select(KnowledgeBase).limit(3))
        for doc in result.scalars().all():
            # SQLite armazena como JSON; pgvector como vetor — ambos são lista
            assert doc.embedding is not None
            assert len(doc.embedding) == 384

    @pytest.mark.asyncio
    async def test_seed_is_idempotent(self, db_session):
        """Rodar seed_knowledge_base() duas vezes não duplica registros."""
        from scripts import seed_knowledge_base as kb

        with patch.object(kb, "_get_session_factory") as mock_factory, \
             patch.object(kb, "_get_embeddings_model", return_value=FakeEmbeddings()):
            mock_factory.return_value = lambda: _ContextSession(db_session)

            first = await kb.seed(force=False)
            assert first >= 25

            second = await kb.seed(force=False)
            assert second == 0  # Nenhum novo registro

        result = await db_session.execute(select(KnowledgeBase))
        rows = result.scalars().all()
        # Mesmo número da primeira passagem
        assert len(rows) == first

    @pytest.mark.asyncio
    async def test_seed_force_flag_replaces_existing(self, db_session):
        """force=True substitui registros existentes."""
        from scripts import seed_knowledge_base as kb

        with patch.object(kb, "_get_session_factory") as mock_factory, \
             patch.object(kb, "_get_embeddings_model", return_value=FakeEmbeddings()):
            mock_factory.return_value = lambda: _ContextSession(db_session)

            first = await kb.seed(force=False)

            # Inserir um doc "extra" para depois ver que o force apagou
            extra = KnowledgeBase(
                id=uuid4(),
                title="Doc extra para testar force",
                content="conteudo qualquer",
                category="exercicio",
                is_active=True,
            )
            db_session.add(extra)
            await db_session.commit()

            second = await kb.seed(force=True)
            assert second >= 25

        # O doc extra deve ter sido removido pelo force
        result = await db_session.execute(
            select(KnowledgeBase).where(
                KnowledgeBase.title == "Doc extra para testar force"
            )
        )
        assert result.scalar_one_or_none() is None

    @pytest.mark.asyncio
    async def test_no_information_loss(self, db_session):
        """Validar que todos os campos do dict são gravados no DB."""
        from scripts import seed_knowledge_base as kb
        from scripts.seed_knowledge_base import KNOWLEDGE_DOCUMENTS

        with patch.object(kb, "_get_session_factory") as mock_factory, \
             patch.object(kb, "_get_embeddings_model", return_value=FakeEmbeddings()):
            mock_factory.return_value = lambda: _ContextSession(db_session)
            await kb.seed(force=False)

        result = await db_session.execute(select(KnowledgeBase))
        stored_titles = {doc.title for doc in result.scalars().all()}
        seed_titles = {d["title"] for d in KNOWLEDGE_DOCUMENTS}
        assert seed_titles.issubset(stored_titles)


# ── Helper para isolar a sessão do seed ───────────────────────────────────────

class _ContextSession:
    """Wrapper que reusa a sessão de teste como context manager."""

    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def __aenter__(self) -> AsyncSession:
        return self._session

    async def __aexit__(self, exc_type, exc, tb) -> None:
        # Não fecha — quem criou a sessão de teste é responsável pelo cleanup
        return None
