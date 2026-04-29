from datetime import datetime, date, timedelta
from typing import List, Tuple
from uuid import UUID

from sqlalchemy.ext.asyncio import AsyncSession

from app.dtos.body_measurement_dto import (
    CreateMeasurementDTO,
    EvolutionPointDTO,
    EvolutionResponseDTO,
    EvolutionStatisticsDTO,
    MeasurementResponseDTO,
    PaginatedMeasurementsResponseDTO,
    VALID_METRICS,
)
from app.models.body_measurement import BodyMeasurement
from app.models.user import User
from app.repositories.body_measurement_repository import BodyMeasurementRepository
from app.repositories.user_repository import UserRepository


class MeasurementNotFoundError(Exception):
    pass


class MeasurementAccessDeniedError(Exception):
    pass


class UserProfileIncompleteError(Exception):
    pass


ACTIVITY_FACTORS = {
    "sedentary": 1.2,
    "light": 1.375,
    "moderate": 1.55,
    "active": 1.725,
    "very_active": 1.9,
}


class BodyMeasurementService:
    def __init__(self, session: AsyncSession):
        self.session = session
        self.repository = BodyMeasurementRepository(session)
        self.user_repository = UserRepository(session)

    # --- Static calculation methods (testable without DB) ---

    @staticmethod
    def calculate_bmi(weight_kg: float, height_cm: float) -> float:
        height_m = height_cm / 100
        return round(weight_kg / (height_m ** 2), 1)

    @staticmethod
    def calculate_age(birth_date: date) -> int:
        today = date.today()
        return today.year - birth_date.year - (
            (today.month, today.day) < (birth_date.month, birth_date.day)
        )

    @staticmethod
    def calculate_bmr(weight_kg: float, height_cm: float, age_years: int, gender: str) -> float:
        base = 10 * weight_kg + 6.25 * height_cm - 5 * age_years
        return round(base + 5 if gender == "male" else base - 161, 1)

    @staticmethod
    def calculate_tdee(bmr: float, activity_level: str) -> float:
        return round(bmr * ACTIVITY_FACTORS[activity_level], 1)

    # --- RBAC helper ---

    def _assert_access(self, target_user_id: UUID, requesting_user: User) -> None:
        if requesting_user.role in ("admin", "personal_trainer"):
            return
        if requesting_user.id != target_user_id:
            raise MeasurementAccessDeniedError("Acesso negado a medidas de outro usuário")

    def _resolve_target_user_id(self, user_id_param: UUID | None, requesting_user: User) -> UUID:
        if user_id_param is not None:
            self._assert_access(user_id_param, requesting_user)
            return user_id_param
        return requesting_user.id

    # --- Business methods ---

    async def create(self, dto: CreateMeasurementDTO, current_user: User) -> MeasurementResponseDTO:
        if not current_user.gender or not current_user.birth_date:
            raise UserProfileIncompleteError(
                "Perfil incompleto: preencha 'gender' e 'birth_date' antes de registrar medidas"
            )

        age = self.calculate_age(current_user.birth_date)
        bmi = self.calculate_bmi(dto.weight_kg, dto.height_cm)
        bmr = self.calculate_bmr(dto.weight_kg, dto.height_cm, age, current_user.gender)
        tdee = self.calculate_tdee(bmr, dto.activity_level)

        measurement = BodyMeasurement(
            user_id=current_user.id,
            weight_kg=dto.weight_kg,
            height_cm=dto.height_cm,
            chest_cm=dto.chest_cm,
            waist_cm=dto.waist_cm,
            hip_cm=dto.hip_cm,
            thigh_cm=dto.thigh_cm,
            arm_cm=dto.arm_cm,
            body_fat_percentage=dto.body_fat_percentage,
            bmi=bmi,
            bmr_kcal=bmr,
            tdee_kcal=tdee,
            activity_level=dto.activity_level,
            measured_at=dto.measured_at or datetime.utcnow(),
            notes=dto.notes,
        )

        created = await self.repository.create(measurement)
        await self.repository.commit()
        return MeasurementResponseDTO.model_validate(created)

    async def list_measurements(
        self,
        user_id_param: UUID | None,
        requesting_user: User,
        page: int,
        limit: int,
    ) -> PaginatedMeasurementsResponseDTO:
        target_id = self._resolve_target_user_id(user_id_param, requesting_user)
        measurements, total = await self.repository.list_by_user(target_id, page, limit)
        return PaginatedMeasurementsResponseDTO(
            total=total,
            page=page,
            limit=limit,
            data=[MeasurementResponseDTO.model_validate(m) for m in measurements],
        )

    async def get_latest(self, user_id_param: UUID | None, requesting_user: User) -> MeasurementResponseDTO:
        target_id = self._resolve_target_user_id(user_id_param, requesting_user)
        measurement = await self.repository.get_latest_by_user(target_id)
        if not measurement:
            raise MeasurementNotFoundError("Nenhuma medida encontrada para este usuário")
        return MeasurementResponseDTO.model_validate(measurement)

    async def get_evolution(
        self,
        user_id_param: UUID | None,
        metric: str,
        days: int,
        requesting_user: User,
    ) -> EvolutionResponseDTO:
        if metric not in VALID_METRICS:
            raise ValueError(f"metric deve ser um de: {', '.join(sorted(VALID_METRICS))}")

        target_id = self._resolve_target_user_id(user_id_param, requesting_user)
        since = datetime.utcnow() - timedelta(days=days)
        measurements = await self.repository.get_evolution(target_id, since)

        field_map = {
            "weight": "weight_kg",
            "bmi": "bmi",
            "body_fat_percentage": "body_fat_percentage",
            "waist_cm": "waist_cm",
            "hip_cm": "hip_cm",
            "chest_cm": "chest_cm",
            "thigh_cm": "thigh_cm",
            "arm_cm": "arm_cm",
        }
        attr = field_map[metric]

        points: List[EvolutionPointDTO] = []
        for m in measurements:
            value = getattr(m, attr)
            if value is not None:
                points.append(EvolutionPointDTO(date=m.measured_at.date(), value=value))

        if not points:
            return EvolutionResponseDTO(
                metric=metric,
                data=[],
                statistics=EvolutionStatisticsDTO(
                    current=0, initial=0, change=0, change_percentage=0
                ),
            )

        initial = points[0].value
        current = points[-1].value
        change = round(current - initial, 2)
        change_pct = round((change / initial) * 100, 2) if initial != 0 else 0.0

        return EvolutionResponseDTO(
            metric=metric,
            data=points,
            statistics=EvolutionStatisticsDTO(
                current=current,
                initial=initial,
                change=change,
                change_percentage=change_pct,
            ),
        )
