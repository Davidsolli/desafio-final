"""Service de dados de saúde: frequência cardíaca e calorias."""

import logging
from datetime import date as date_type
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.health_dto import (
    HealthSyncRequestDTO,
    HealthSyncResponseDTO,
    HealthSummaryResponseDTO,
)
from app.repositories.health_repository import HealthRepository

logger = logging.getLogger(__name__)


class HealthService:
    """Serviço de sincronização e consulta de dados de saúde."""

    def __init__(self, session: AsyncSession):
        self.session = session
        self.repository = HealthRepository(session)

    async def sync_health_data(
        self, user_id: UUID, dto: HealthSyncRequestDTO
    ) -> HealthSyncResponseDTO:
        """Sincroniza amostras de FC e calorias do dia. Idempotente."""
        samples = [
            (reading.measured_at, reading.bpm, reading.is_from_smartwatch, reading.source_name)
            for reading in dto.heart_rate_readings
        ]
        saved_count = await self.repository.upsert_heart_rate_samples(user_id, samples)

        await self.repository.upsert_daily_calories(
            user_id=user_id,
            day=dto.date,
            active_calories=dto.active_calories,
            total_calories=dto.total_calories,
        )

        await self.repository.commit()

        logger.info(
            "Health sync: user=%s date=%s hr_samples=%d calories=%.1f",
            user_id,
            dto.date,
            saved_count,
            dto.active_calories,
        )

        return HealthSyncResponseDTO(
            success=True,
            message="Dados de saúde sincronizados com sucesso.",
            heart_rate_samples_saved=saved_count,
            date=dto.date,
        )

    async def get_summary(
        self, user_id: UUID, day: date_type
    ) -> HealthSummaryResponseDTO:
        """Retorna resumo de saúde do dia: FC média, min, max e calorias."""
        hr_stats = await self.repository.get_heart_rate_stats(user_id, day)
        calorie_log = await self.repository.get_daily_summary(user_id, day)

        return HealthSummaryResponseDTO(
            date=day,
            average_heart_rate_bpm=round(hr_stats["avg_bpm"], 1),
            min_heart_rate_bpm=hr_stats["min_bpm"],
            max_heart_rate_bpm=hr_stats["max_bpm"],
            heart_rate_samples=hr_stats["count"],
            active_calories=calorie_log.active_calories if calorie_log else 0.0,
            total_calories=calorie_log.total_calories if calorie_log else 0.0,
            is_from_smartwatch=hr_stats["is_from_smartwatch"],
            smartwatch_source_name=hr_stats["smartwatch_source_name"],
        )
