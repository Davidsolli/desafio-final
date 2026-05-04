"""
Configuração de banco de dados.

Define engine assíncrono, sessionmaker e função de dependency injection
para obter sessões de banco.

Pool configurado para RNF-02: suportar 200 requisições simultâneas.
  - pool_size=20  → conexões permanentes no pool
  - max_overflow=30 → conexões extras em pico (total 50 por worker)
  - pool_pre_ping=True → detecta conexões mortas automaticamente
  - pool_recycle=1800 → recicla conexões a cada 30min (previne timeout de TCP)
"""

import logging
import os

from sqlalchemy import text
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import NullPool

from app.config.settings import settings

logger = logging.getLogger(__name__)

# Engine e sessionmaker serão inicializados lazily
_engine = None
_AsyncSessionLocal = None


def _get_engine():
    """Obter engine, criando se necessário.

    Em ambiente de teste (TEST_ENV=1) usa NullPool para isolamento entre testes.
    Em produção usa QueuePool configurado para suportar carga (RNF-02).
    """
    global _engine
    if _engine is None:
        is_test = os.getenv("TEST_ENV", "0") == "1"
        if is_test:
            _engine = create_async_engine(
                settings.DATABASE_URL,
                echo=settings.DATABASE_ECHO,
                poolclass=NullPool,
                future=True,
            )
        else:
            _engine = create_async_engine(
                settings.DATABASE_URL,
                echo=settings.DATABASE_ECHO,
                pool_size=20,
                max_overflow=30,
                pool_timeout=30,
                pool_pre_ping=True,
                pool_recycle=1800,
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
    import app.models.nutrition  # noqa: F401 — registra Food, Meal, MealFoodEntry

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

    # ── 3. Popular Banco de Dados Inicial (Seed) ──────────────────────
    import sys
    import os
    # Adicionar raiz ao sys.path caso não esteja (para o script seed funcionar isoladamente ou importado)
    root_path = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    if root_path not in sys.path:
        sys.path.insert(0, root_path)

    from scripts.seed_exercises import seed
    try:
        await seed(force=False)
        logger.info("✓ Verificação/Seed do catálogo de exercícios concluída")
    except Exception as exc:
        logger.warning("Erro ao popular catálogo de exercícios: %s", exc)

