"""
Background tasks para limpeza e manutenção do banco de dados.

Responsável por:
- Limpar tokens de recuperação de senha expirados
- Remover tokens usados há mais de N dias
"""

import asyncio
import logging
from datetime import datetime, timedelta, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import async_session_maker
from app.repositories.password_reset_repository import PasswordResetRepository

logger = logging.getLogger(__name__)


async def cleanup_expired_password_tokens() -> int:
    """
    Limpeza periódica de tokens de recuperação de senha expirados.

    Executa a cada 1 hora (chamado via startup event).
    Remove tokens que:
    - Já foram usados
    - Ou expiraram há mais de 24 horas

    Returns:
        Número de tokens deletados
    """
    try:
        async with async_session_maker() as session:
            repo = PasswordResetRepository(session)

            # Deletar tokens expirados
            deleted_count = await repo.delete_expired()

            if deleted_count > 0:
                logger.info(f"🧹 Limpeza executada: {deleted_count} tokens expirados deletados")
                await session.commit()

            return deleted_count

    except Exception as e:
        logger.error(f"❌ Erro ao limpar tokens expirados: {e}")
        return 0


async def background_cleanup_task():
    """
    Task assíncrona que executa limpeza periodicamente.

    Executa a cada 1 hora indefinidamente (deve rodar em background).
    """
    logger.info("🚀 Iniciando task de limpeza de tokens de senha expirados")

    while True:
        try:
            # Aguardar 1 hora antes da primeira execução
            await asyncio.sleep(3600)

            # Executar limpeza
            deleted = await cleanup_expired_password_tokens()

            if deleted == 0:
                logger.debug("✅ Nenhum token expirado para deletar")

        except asyncio.CancelledError:
            logger.info("🛑 Task de limpeza cancelada")
            break

        except Exception as e:
            logger.error(f"❌ Erro na task de limpeza: {e}")
            # Continuar executando mesmo com erro
            await asyncio.sleep(60)
