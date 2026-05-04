"""
Endpoints HTTP do módulo de Nutrição (RF-59 a RF-66).

Rotas:
    GET    /api/v1/nutrition/meals                    → Listar refeições
    POST   /api/v1/nutrition/meals                    → Criar refeição
    GET    /api/v1/nutrition/meals/{id}               → Buscar refeição
    PUT    /api/v1/nutrition/meals/{id}               → Atualizar refeição
    DELETE /api/v1/nutrition/meals/{id}               → Deletar refeição
    GET    /api/v1/nutrition/daily-summary            → Resumo diário
    GET    /api/v1/nutrition/foods/search             → Buscar alimentos
    POST   /api/v1/nutrition/foods                    → Criar alimento (admin/personal)
"""

from datetime import date
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.dependencies.auth import get_current_user
from app.dtos.nutrition_dto import (
    CreateFoodDTO,
    CreateMealDTO,
    DailySummaryDTO,
    FoodResponseDTO,
    MealResponseDTO,
    UpdateMealDTO,
)
from app.models.user import User
from app.services.nutrition_service import (
    MealForbiddenError,
    MealNotFoundError,
    NutritionService,
)

router = APIRouter(
    prefix="/api/v1/nutrition",
    tags=["nutrition"],
    responses={
        401: {"description": "Não autenticado"},
        500: {"description": "Erro interno do servidor"},
    },
)


# ---------------------------------------------------------------------------
# Dependency
# ---------------------------------------------------------------------------


async def get_nutrition_service(
    session: AsyncSession = Depends(get_db),
) -> NutritionService:
    return NutritionService(session)


# ---------------------------------------------------------------------------
# Endpoints de Refeições
# ---------------------------------------------------------------------------


@router.get(
    "/meals",
    response_model=List[MealResponseDTO],
    status_code=status.HTTP_200_OK,
    summary="Listar refeições do usuário",
)
async def list_meals(
    meal_date: Optional[date] = Query(
        None, description="Filtrar por data (YYYY-MM-DD)"
    ),
    limit: int = Query(10, ge=1, le=100, description="Itens por página"),
    offset: int = Query(0, ge=0, description="Itens a pular"),
    current_user: User = Depends(get_current_user),
    service: NutritionService = Depends(get_nutrition_service),
) -> List[MealResponseDTO]:
    """Lista refeições do usuário autenticado, com filtro opcional por data."""
    meals, _ = await service.list_meals(
        user_id=current_user.id,
        meal_date=meal_date,
        limit=limit,
        offset=offset,
    )
    return meals


@router.post(
    "/meals",
    response_model=MealResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar nova refeição",
)
async def create_meal(
    dto: CreateMealDTO,
    current_user: User = Depends(get_current_user),
    service: NutritionService = Depends(get_nutrition_service),
) -> MealResponseDTO:
    """
    Registra uma nova refeição com seus alimentos.

    - `meal_type`: breakfast | lunch | dinner | snack
    - `foods`: lista de alimentos com macros calculados
    """
    try:
        return await service.create_meal(current_user.id, dto)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao registrar refeição.",
        )


@router.get(
    "/meals/{meal_id}",
    response_model=MealResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Buscar refeição por ID",
)
async def get_meal(
    meal_id: UUID,
    current_user: User = Depends(get_current_user),
    service: NutritionService = Depends(get_nutrition_service),
) -> MealResponseDTO:
    """Retorna dados completos de uma refeição específica."""
    try:
        return await service.get_meal(meal_id, current_user.id)
    except MealNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except MealForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao buscar refeição.",
        )


@router.put(
    "/meals/{meal_id}",
    response_model=MealResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Atualizar refeição",
)
async def update_meal(
    meal_id: UUID,
    dto: UpdateMealDTO,
    current_user: User = Depends(get_current_user),
    service: NutritionService = Depends(get_nutrition_service),
) -> MealResponseDTO:
    """Atualiza dados de uma refeição. Se `foods` for informado, substituirá os itens existentes."""
    try:
        return await service.update_meal(meal_id, current_user.id, dto)
    except MealNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except MealForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao atualizar refeição.",
        )


@router.delete(
    "/meals/{meal_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Deletar refeição (soft delete)",
)
async def delete_meal(
    meal_id: UUID,
    current_user: User = Depends(get_current_user),
    service: NutritionService = Depends(get_nutrition_service),
) -> None:
    """Soft delete de uma refeição (os dados são mantidos para LGPD)."""
    try:
        await service.delete_meal(meal_id, current_user.id)
    except MealNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(e))
    except MealForbiddenError as e:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=str(e))
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao deletar refeição.",
        )


@router.get(
    "/daily-summary",
    response_model=DailySummaryDTO,
    status_code=status.HTTP_200_OK,
    summary="Resumo diário de macronutrientes",
)
async def get_daily_summary(
    summary_date: date = Query(..., description="Data do resumo (YYYY-MM-DD)"),
    current_user: User = Depends(get_current_user),
    service: NutritionService = Depends(get_nutrition_service),
) -> DailySummaryDTO:
    """Retorna o total de macronutrientes do dia, agrupado por refeição."""
    try:
        return await service.get_daily_summary(current_user.id, summary_date)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao calcular resumo diário.",
        )


# ---------------------------------------------------------------------------
# Endpoints de Catálogo de Alimentos
# ---------------------------------------------------------------------------


@router.get(
    "/foods/search",
    response_model=List[FoodResponseDTO],
    status_code=status.HTTP_200_OK,
    summary="Buscar alimentos no catálogo",
)
async def search_foods(
    q: str = Query(..., min_length=1, description="Termo de busca"),
    limit: int = Query(20, ge=1, le=100, description="Máximo de resultados"),
    current_user: User = Depends(get_current_user),
    service: NutritionService = Depends(get_nutrition_service),
) -> List[FoodResponseDTO]:
    """Busca alimentos no catálogo por nome (busca parcial, case-insensitive)."""
    try:
        return await service.search_foods(q, limit=limit)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao buscar alimentos.",
        )


@router.post(
    "/foods",
    response_model=FoodResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Criar alimento no catálogo (admin/personal)",
)
async def create_food(
    dto: CreateFoodDTO,
    current_user: User = Depends(get_current_user),
    service: NutritionService = Depends(get_nutrition_service),
) -> FoodResponseDTO:
    """
    Adiciona um novo alimento ao catálogo.

    Apenas admin e personal_trainer podem criar alimentos.
    """
    if current_user.role not in ["admin", "personal_trainer"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas admin ou personal_trainer podem criar alimentos no catálogo",
        )
    try:
        return await service.create_food(dto)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao criar alimento.",
        )
