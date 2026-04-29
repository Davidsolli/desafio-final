from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.controllers.body_measurement_controller import BodyMeasurementController
from app.dependencies.auth import get_current_user
from app.dtos.body_measurement_dto import (
    CreateMeasurementDTO,
    EvolutionResponseDTO,
    MeasurementResponseDTO,
    PaginatedMeasurementsResponseDTO,
)
from app.models.user import User
from app.services.body_measurement_service import (
    MeasurementAccessDeniedError,
    MeasurementNotFoundError,
    UserProfileIncompleteError,
)

router = APIRouter(
    prefix="/api/v1/measurements",
    tags=["measurements"],
    responses={
        404: {"description": "Medida não encontrada"},
        403: {"description": "Acesso negado"},
    },
)


@router.post(
    "",
    response_model=MeasurementResponseDTO,
    status_code=status.HTTP_201_CREATED,
)
async def create_measurement(
    dto: CreateMeasurementDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> MeasurementResponseDTO:
    controller = BodyMeasurementController(session)
    try:
        return await controller.create_measurement(dto, current_user)
    except UserProfileIncompleteError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Erro ao registrar medida")


@router.get(
    "/latest",
    response_model=MeasurementResponseDTO,
    status_code=status.HTTP_200_OK,
)
async def get_latest_measurement(
    user_id: Optional[UUID] = Query(None, description="ID do aluno (admin/personal)"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> MeasurementResponseDTO:
    controller = BodyMeasurementController(session)
    try:
        return await controller.get_latest(user_id, current_user)
    except MeasurementNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except MeasurementAccessDeniedError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Erro ao buscar medida")


@router.get(
    "/evolution",
    response_model=EvolutionResponseDTO,
    status_code=status.HTTP_200_OK,
)
async def get_evolution(
    metric: str = Query("weight", description="Métrica: weight, bmi, waist_cm, etc."),
    days: int = Query(90, ge=1, le=3650, description="Quantidade de dias para análise"),
    user_id: Optional[UUID] = Query(None, description="ID do aluno (admin/personal)"),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> EvolutionResponseDTO:
    controller = BodyMeasurementController(session)
    try:
        return await controller.get_evolution(user_id, metric, days, current_user)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    except MeasurementAccessDeniedError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Erro ao buscar evolução")


@router.get(
    "",
    response_model=PaginatedMeasurementsResponseDTO,
    status_code=status.HTTP_200_OK,
)
async def list_measurements(
    user_id: Optional[UUID] = Query(None, description="ID do aluno (admin/personal)"),
    page: int = Query(1, ge=1),
    limit: int = Query(10, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
) -> PaginatedMeasurementsResponseDTO:
    controller = BodyMeasurementController(session)
    try:
        return await controller.list_measurements(user_id, current_user, page, limit)
    except MeasurementAccessDeniedError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Erro ao listar medidas")
