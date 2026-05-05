"""
Background job: refresh periódico da tabela student_analytics.

Usa APScheduler (AsyncIOScheduler) — sem Redis ou broker externo.
O scheduler é iniciado no lifespan do FastAPI (main.py) e dispara
a cada 15 minutos, recalculando métricas de todos os alunos ativos.

Upgrade path: quando o projeto adicionar Celery/Redis, basta substituir
a função _run_refresh por um @shared_task e manter a lógica do service.
"""

import logging

from apscheduler.schedulers.asyncio import AsyncIOScheduler

logger = logging.getLogger(__name__)

scheduler = AsyncIOScheduler(timezone="UTC")


def setup_analytics_scheduler(session_factory) -> AsyncIOScheduler:
    """
    Registra o job de refresh e retorna o scheduler configurado.

    Args:
        session_factory: callable que retorna AsyncSession (do _get_async_session_local())
    """

    async def _run_refresh() -> None:
        from app.services.dashboard_service import DashboardService

        async with session_factory() as session:
            service = DashboardService(session)
            try:
                updated = await service.refresh_all_analytics()
                logger.info("Analytics refresh: %d alunos atualizados", updated)
            except Exception as exc:
                logger.error("Erro no analytics refresh: %s", exc, exc_info=True)

    scheduler.add_job(
        _run_refresh,
        trigger="interval",
        minutes=15,
        id="student_analytics_refresh",
        replace_existing=True,
        max_instances=1,
    )

    return scheduler
