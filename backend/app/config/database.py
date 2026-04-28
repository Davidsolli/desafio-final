"""
Configuração de banco de dados.

Define engine assíncrono, sessionmaker e função de dependency injection
para obter sessões de banco.
"""

import logging

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import NullPool

from app.config.settings import settings

logger = logging.getLogger(__name__)

# Engine e sessionmaker serão inicializados lazily
_engine = None
_AsyncSessionLocal = None


def _get_engine():
    """Obter engine, criando se necessário."""
    global _engine
    if _engine is None:
        _engine = create_async_engine(
            settings.DATABASE_URL,
            echo=settings.DATABASE_ECHO,
            poolclass=NullPool,
            future=True,
        )
    return _engine


def _get_async_session_local():
    """Obter sessionmaker, criando se necessário."""
    global _AsyncSessionLocal
    if _AsyncSessionLocal is None:
        engine = _get_engine()
        _AsyncSessionLocal = async_sessionmaker(
            engine,
            class_=AsyncSession,
            expire_on_commit=False,
            future=True,
        )
    return _AsyncSessionLocal


async def get_db() -> AsyncSession:
    """Dependency injection para obter sessão de banco."""
    session_local = _get_async_session_local()
    async with session_local() as session:
        yield session


async def init_db() -> None:
    """
    Inicializar banco: criar extensões e tabelas.

    Chamar uma vez na inicialização da aplicação.
    Steps:
        1. Habilitar extensão pgvector (para busca vetorial no RAG)
        2. Importar todos os models para que o metadata inclua todas as tabelas
        3. Criar todas as tabelas via SQLAlchemy ORM
    """
    from app.models.user import Base  # noqa: F401 — registra User
    import app.models.chatbot  # noqa: F401 — registra KnowledgeBase, ChatConversation, etc.
    from app.models.goal import Goal, GoalProgressEntry  # noqa: F401 — registra Goals
    import app.models.logbook  # noqa: F401 — registra WorkoutSession e SessionExercise no Base

    engine = _get_engine()
    async with engine.begin() as conn:
        # ── 1. Habilitar extensão pgvector ────────────────────────────────────
        # Necessária para criar coluna VECTOR na knowledge_base (RAG embeddings)
        try:
            await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector;"))
            logger.info("✓ Extensão pgvector habilitada com sucesso")
        except Exception as exc:
            logger.warning("Erro ao habilitar pgvector (pode já estar ativo): %s", exc)

        # ── 2. Criar todas as tabelas ──────────────────────────────────────────
        await conn.run_sync(Base.metadata.create_all)
        logger.info("✓ Todas as tabelas criadas/verificadas com sucesso")

