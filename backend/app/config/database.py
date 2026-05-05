"""
Configuração de banco de dados.

Define engine assíncrono, sessionmaker e função de dependency injection
para obter sessões de banco.
"""

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import NullPool
from sqlalchemy import text

from app.config.settings import settings

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
    Inicializar banco: criar todas as tabelas.

    Chamar uma vez na inicialização da aplicação.
    Importar todos os models para que o metadata inclua todas as tabelas.
    """
    import logging
    from app.models.user import Base  # noqa: F401 — registra User
    from app.models.user_profile import UserProfile  # noqa: F401 — registra UserProfile
    from app.models.goal import Goal, GoalProgressEntry  # noqa: F401 — registra Goals
    import app.models.logbook  # noqa: F401 — registra WorkoutSession e SessionExercise no Base
    import app.models.food_catalog  # noqa: F401 — registra FoodCatalog no Base
    import app.models.diet  # noqa: F401 — registra CustomFood, Diet, DietMeal, DietItem
    import app.models.diet_logbook  # noqa: F401 — registra DietLogbook, DietLogbookEntry
    from app.models.invitation import Invitation  # noqa: F401 — registra Invitation

    logger = logging.getLogger(__name__)

    engine = _get_engine()
    async with engine.begin() as conn:
        # Criar extensão pgvector antes de criar as tabelas
        try:
            await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector;"))
            logger.info("✓ Extensão pgvector habilitada com sucesso")
        except Exception as exc:
            logger.warning("Erro ao habilitar pgvector (pode já estar ativo): %s", exc)

        # Migração manual: Adicionar food_name ao logbook entries se não existir
        try:
            await conn.execute(text("ALTER TABLE diet_logbook_entries ADD COLUMN IF NOT EXISTS food_name VARCHAR(255) DEFAULT '';"))
            logger.info("✓ Coluna food_name verificada/adicionada em diet_logbook_entries")
        except Exception as exc:
            logger.warning("Erro na migração manual de diet_logbook_entries: %s", exc)

        # Criar todas as tabelas
        await conn.run_sync(Base.metadata.create_all)
        logger.info("✓ Todas as tabelas criadas/verificadas com sucesso")

    # Popular Banco de Dados Inicial (Seed)
    import sys
    import os
    root_path = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    if root_path not in sys.path:
        sys.path.insert(0, root_path)

    from scripts.seed_exercises import seed
    try:
        await seed(force=False)
        logger.info("✓ Verificação/Seed do catálogo de exercícios concluída")
    except Exception as exc:
        logger.warning("Erro ao popular catálogo de exercícios: %s", exc)
