"""
Configuração de banco de dados.

Define engine assíncrono, sessionmaker e função de dependency injection
para obter sessões de banco.
"""

from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.pool import NullPool

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
    """
    Dependency injection para obter sessão de banco.

    Uso em FastAPI:
    ```python
    @app.get("/users")
    async def list_users(session: AsyncSession = Depends(get_db)):
        ...
    ```

    Yields:
        AsyncSession: Sessão de banco
    """
    session_local = _get_async_session_local()
    async with session_local() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_db() -> None:
    """
    Inicializar banco: criar todas as tabelas.

    Chamar uma vez na inicialização da aplicação.
    """
    from app.models.user import Base
    from app.models.goal import Goal as _Goal, GoalProgressEntry as _GoalProgressEntry  # noqa: F401

    engine = _get_engine()
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
