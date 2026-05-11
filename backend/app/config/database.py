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


def SessionLocal():
    """Context manager de sessão para uso em tasks/schedulers (fora do ciclo de request)."""
    return _get_async_session_local()()


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
    import app.models.password_reset_token  # noqa: F401 — registra PasswordResetToken
    from app.models.goal import Goal, GoalProgressEntry  # noqa: F401 — registra Goals
    import app.models.logbook  # noqa: F401 — registra WorkoutSession e SessionExercise no Base
    import app.models.food_catalog  # noqa: F401 — registra FoodCatalog no Base
    import app.models.diet  # noqa: F401 — registra CustomFood, Diet, DietMeal, DietItem
    import app.models.diet_logbook  # noqa: F401 — registra DietLogbook, DietLogbookEntry
    from app.models.invitation import Invitation  # noqa: F401 — registra Invitation
    from app.models.whatsapp_pre_registration import WhatsAppPreRegistration  # noqa: F401
    import app.models.notification  # noqa: F401 — registra NotificationPreference, NotificationLog, WorkoutReminderSchedule

    logger = logging.getLogger(__name__)

    engine = _get_engine()
    async with engine.begin() as conn:
        # 1. Criar extensão pgvector antes de criar as tabelas
        try:
            await conn.execute(text("CREATE EXTENSION IF NOT EXISTS vector;"))
            logger.info("✓ Extensão pgvector habilitada com sucesso")
        except Exception as exc:
            logger.warning("Erro ao habilitar pgvector (pode já estar ativo): %s", exc)

        # 2. Criar todas as tabelas PRIMEIRO
        await conn.run_sync(Base.metadata.create_all)
        logger.info("✓ Todas as tabelas criadas/verificadas com sucesso")

        # 3. Migração manual: Adicionar colunas de dados corporais e FCM à tabela users
        alters = [
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS weight DOUBLE PRECISION",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS height DOUBLE PRECISION",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS age INTEGER",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS gender VARCHAR(10)",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_whatsapp VARCHAR(20)",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS goal_type VARCHAR(50)",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS theme_preference VARCHAR(20) DEFAULT NULL",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 0",
            "ALTER TABLE users ADD COLUMN IF NOT EXISTS fcm_token VARCHAR(500)",
        ]
        for alter in alters:
            try:
                await conn.execute(text(alter))
            except Exception as exc:
                logger.warning("Erro ao executar ALTER TABLE users: %s", exc)
        logger.info("✓ Colunas de dados corporais e FCM verificadas/adicionadas em users")

        # 4. Migração: Adaptar WorkoutSheets para usar WorkoutProgram
        alters_workout = [
            "ALTER TABLE workout_sheets ADD COLUMN IF NOT EXISTS workout_program_id UUID",
            "ALTER TABLE workout_sheets ADD COLUMN IF NOT EXISTS \"order\" INTEGER DEFAULT 1",
            "ALTER TABLE workout_sheets ALTER COLUMN day_of_week DROP NOT NULL",
            "ALTER TABLE workout_sheets ALTER COLUMN user_id DROP NOT NULL",
            "ALTER TABLE workout_sheets ALTER COLUMN personal_trainer_id DROP NOT NULL",
        ]
        for alter in alters_workout:
            try:
                await conn.execute(text(alter))
            except Exception as exc:
                logger.warning("Erro ao executar ALTER TABLE workout_sheets: %s", exc)
        logger.info("✓ Colunas atualizadas em workout_sheets para suportar WorkoutProgram")

        # 5. Migração: Adicionar water_target_ml ao diets se não existir
        alters_diets = [
            "ALTER TABLE diets ADD COLUMN IF NOT EXISTS water_target_ml INTEGER DEFAULT NULL",
        ]
        for alter in alters_diets:
            try:
                await conn.execute(text(alter))
            except Exception as exc:
                logger.warning("Erro ao executar ALTER TABLE diets: %s", exc)
        logger.info("✓ Colunas atualizadas em diets para suportar water_target_ml")

        # 6. Migração: converter colunas de password_reset_tokens para TIMESTAMPTZ
        token_col_alters = [
            "ALTER TABLE password_reset_tokens ALTER COLUMN expires_at TYPE TIMESTAMPTZ USING expires_at AT TIME ZONE 'UTC'",
            "ALTER TABLE password_reset_tokens ALTER COLUMN used_at TYPE TIMESTAMPTZ USING used_at AT TIME ZONE 'UTC'",
            "ALTER TABLE password_reset_tokens ALTER COLUMN created_at TYPE TIMESTAMPTZ USING created_at AT TIME ZONE 'UTC'",
        ]
        for alter in token_col_alters:
            try:
                await conn.execute(text(alter))
            except Exception:
                pass  # tabela ainda não existe ou coluna já é TIMESTAMPTZ

        # Migração: contexto da escalação na conversa de chat (chatbot Etapa 3)
        try:
            await conn.execute(
                text(
                    "ALTER TABLE chat_conversations "
                    "ADD COLUMN IF NOT EXISTS escalation_data JSON"
                )
            )
            logger.info("✓ Coluna escalation_data verificada/adicionada em chat_conversations")
        except Exception as exc:
            logger.warning(
                "Erro ao adicionar escalation_data em chat_conversations: %s", exc
            )

    # 4. Migração manual: Adicionar food_name ao logbook entries se não existir
    # (feita APÓS criar as tabelas, em transação separada)
    # COMENTADO TEMPORARIAMENTE - será aplicado depois
    # engine = _get_engine()
    # async with engine.begin() as conn:
    #     try:
    #         await conn.execute(text("ALTER TABLE diet_logbook_entries ADD COLUMN IF NOT EXISTS food_name VARCHAR(255) DEFAULT '';"))
    #         logger.info("✓ Coluna food_name verificada/adicionada em diet_logbook_entries")
    #     except Exception as exc:
    #         logger.warning("Erro na migração manual de diet_logbook_entries: %s", exc)

    # Popular Banco de Dados Inicial (Seed)
    import sys
    import os
    root_path = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    if root_path not in sys.path:
        sys.path.insert(0, root_path)

    from scripts.seed_exercises import seed as seed_exercises
    from scripts.seed_food import seed as seed_food
    from scripts.seed_users_domain_data import seed as seed_users_domain_data
    try:
        await seed_exercises(force=False)
        logger.info("✓ Verificação/Seed do catálogo de exercícios concluída")
    except Exception as exc:
        logger.warning("Erro ao popular catálogo de exercícios: %s", exc)

    try:
        await seed_food(force=False)
        logger.info("✓ Verificação/Seed do catálogo de alimentos concluída")
    except Exception as exc:
        logger.warning("Erro ao popular catálogo de alimentos: %s", exc)

    try:
        await seed_users_domain_data(force=False)
        logger.info("✓ Seed de usuários e dados de domínio concluída")
    except Exception as exc:
        logger.warning("Erro ao popular dados de domínio iniciais: %s", exc)

    try:
        from scripts.seed_knowledge_base import seed as seed_knowledge_base
        inserted = await seed_knowledge_base(force=False)
        logger.info(
            "✓ Verificação/Seed da base de conhecimento concluída (%d novos docs)",
            inserted,
        )
    except Exception as exc:
        logger.warning("Erro ao popular base de conhecimento: %s", exc)
