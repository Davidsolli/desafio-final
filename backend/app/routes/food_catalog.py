"""
Rota HTTP para o catálogo de alimentos (Tabela TACO + Custom Foods).

Endpoint:
- GET /api/v1/food-catalog — Busca unificada: TACO + alimentos personalizados do usuário
"""

from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy import func, select, union_all, literal, cast, String
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.dependencies.auth import get_current_user
from app.models.diet import CustomFood
from app.models.food_catalog import FoodCatalog
from app.models.user import User


# ---------------------------------------------------------------------------
# DTOs de Resposta
# ---------------------------------------------------------------------------


class FoodCatalogItemDTO(BaseModel):
    """DTO de um item do catálogo de alimentos."""

    id: str  # string para unificar int (TACO) e UUID (Custom)
    name: str
    category: Optional[str] = None
    energy_kcal: float
    protein_g: float
    carbohydrate_g: float
    lipid_g: float
    fiber_g: float
    source: str = "taco"  # "taco" ou "custom"


class PaginatedFoodCatalogDTO(BaseModel):
    """DTO de resposta paginada do catálogo de alimentos."""

    items: List[FoodCatalogItemDTO]
    total: int
    page: int
    limit: int


# ---------------------------------------------------------------------------
# Router
# ---------------------------------------------------------------------------


router = APIRouter(
    prefix="/api/v1/food-catalog",
    tags=["food-catalog"],
    responses={
        401: {"description": "Não autenticado"},
    },
)


@router.get(
    "",
    response_model=PaginatedFoodCatalogDTO,
    status_code=status.HTTP_200_OK,
    summary="Buscar alimentos (TACO + personalizados)",
    responses={
        200: {"description": "Resultados do catálogo de alimentos"},
    },
)
async def search_food_catalog(
    search: Optional[str] = Query(
        None,
        description="Busca por nome (parcial, case-insensitive)",
    ),
    category: Optional[str] = Query(
        None,
        description="Filtrar por categoria (ex: 'Cereais e derivados')",
    ),
    source: Optional[str] = Query(
        None,
        description="Filtrar por fonte: 'taco' ou 'custom'",
    ),
    min_protein: Optional[float] = Query(
        None,
        description="Filtrar por mínimo de proteína em 100g",
    ),
    max_carbohydrate: Optional[float] = Query(
        None,
        description="Filtrar por máximo de carboidrato em 100g",
    ),
    max_lipid: Optional[float] = Query(
        None,
        description="Filtrar por máximo de gordura em 100g",
    ),
    page: int = Query(1, ge=1, description="Número da página"),
    limit: int = Query(20, ge=1, le=100, description="Itens por página (máx. 100)"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> PaginatedFoodCatalogDTO:
    """
    Busca **unificada** no catálogo de alimentos.

    Retorna alimentos da **Tabela TACO** (597 alimentos brasileiros) e
    os **alimentos personalizados** do usuário logado, em uma única lista
    paginada e ordenada por nome.

    - **search**: Filtra por nome (case-insensitive, parcial).
    - **category**: Filtra por categoria exata.
    - **source**: `taco` para apenas TACO, `custom` para apenas personalizados.
    - **min_protein**: Filtra por quantidade mínima de proteína.
    - **max_carbohydrate**: Filtra por quantidade máxima de carboidrato.
    - **max_lipid**: Filtra por quantidade máxima de gordura.
    - **page/limit**: Paginação.
    """
    try:
        items_result: List[FoodCatalogItemDTO] = []
        total = 0

        # Construir queries separadas para cada fonte e unificar
        include_taco = source is None or source == "taco"
        include_custom = source is None or source == "custom"

        # ── TACO ──
        if include_taco:
            taco_stmt = select(FoodCatalog)
            if search:
                taco_stmt = taco_stmt.where(FoodCatalog.name.ilike(f"%{search}%"))
            if category:
                taco_stmt = taco_stmt.where(FoodCatalog.category == category)
            if min_protein is not None:
                taco_stmt = taco_stmt.where(FoodCatalog.protein_g >= min_protein)
            if max_carbohydrate is not None:
                taco_stmt = taco_stmt.where(FoodCatalog.carbohydrate_g <= max_carbohydrate)
            if max_lipid is not None:
                taco_stmt = taco_stmt.where(FoodCatalog.lipid_g <= max_lipid)

            taco_count_stmt = select(func.count()).select_from(taco_stmt.subquery())
            taco_count_result = await db.execute(taco_count_stmt)
            taco_total = taco_count_result.scalar() or 0
            total += taco_total

        # ── Custom Foods ──
        if include_custom:
            custom_stmt = select(CustomFood).where(
                CustomFood.user_id == current_user.id
            )
            if search:
                custom_stmt = custom_stmt.where(CustomFood.name.ilike(f"%{search}%"))
            if category:
                custom_stmt = custom_stmt.where(CustomFood.category == category)
            if min_protein is not None:
                custom_stmt = custom_stmt.where(CustomFood.protein_g >= min_protein)
            if max_carbohydrate is not None:
                custom_stmt = custom_stmt.where(CustomFood.carbohydrate_g <= max_carbohydrate)
            if max_lipid is not None:
                custom_stmt = custom_stmt.where(CustomFood.lipid_g <= max_lipid)

            custom_count_stmt = select(func.count()).select_from(custom_stmt.subquery())
            custom_count_result = await db.execute(custom_count_stmt)
            custom_total = custom_count_result.scalar() or 0
            total += custom_total

        # ── Paginação combinada ──
        # Para simplicidade, buscar ambos e combinar em Python
        offset = (page - 1) * limit
        combined = []

        if include_taco:
            taco_paged = taco_stmt.order_by(FoodCatalog.name.asc())
            taco_result = await db.execute(taco_paged)
            for item in taco_result.scalars().all():
                combined.append(
                    FoodCatalogItemDTO(
                        id=str(item.id),
                        name=item.name,
                        category=item.category,
                        energy_kcal=item.energy_kcal,
                        protein_g=item.protein_g,
                        carbohydrate_g=item.carbohydrate_g,
                        lipid_g=item.lipid_g,
                        fiber_g=item.fiber_g,
                        source="taco",
                    )
                )

        if include_custom:
            custom_paged = custom_stmt.order_by(CustomFood.name.asc())
            custom_result = await db.execute(custom_paged)
            for item in custom_result.scalars().all():
                combined.append(
                    FoodCatalogItemDTO(
                        id=str(item.id),
                        name=item.name,
                        category=item.category,
                        energy_kcal=item.energy_kcal,
                        protein_g=item.protein_g,
                        carbohydrate_g=item.carbohydrate_g,
                        lipid_g=item.lipid_g,
                        fiber_g=item.fiber_g,
                        source="custom",
                    )
                )

        # Ordenar por nome e paginar
        combined.sort(key=lambda x: x.name.lower())
        paged_items = combined[offset: offset + limit]

        return PaginatedFoodCatalogDTO(
            items=paged_items,
            total=total,
            page=page,
            limit=limit,
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao buscar catálogo de alimentos.",
        )
