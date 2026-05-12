"""
Rotas HTTP do Diário Alimentar (Diet Logbook).

Endpoints:
- POST   /api/v1/diet-logbook                              → Registrar alimento consumido (201)
- GET    /api/v1/diet-logbook/analytics/summary            → Sumário histórico de nutrição (200)
- GET    /api/v1/diet-logbook/{date}                       → Diário do dia (200)
- DELETE /api/v1/diet-logbook/entries/{entry_id}           → Remover registro (204)
- GET    /api/v1/diet-logbook/student/{user_id}/{date}     → Diário do aluno p/ Personal (200)
"""

from datetime import date
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.config.database import get_db
from app.controllers.diet_controller import DietController
from app.dependencies.auth import get_current_user
from app.dtos.diet_logbook_dto import (
    AddLogbookEntryDTO,
    DietLogbookResponseDTO,
    LogbookEntryResponseDTO,
    NutritionAnalyticsSummaryResponseDTO,
)
from app.models.user import User
from app.services.diet_logbook_service import (
    LogbookEntryNotFoundError,
    LogbookForbiddenError,
    LogbookValidationError,
)


router = APIRouter(
    prefix="/api/v1/diet-logbook",
    tags=["diet-logbook"],
    responses={
        401: {"description": "Não autenticado"},
        500: {"description": "Erro interno do servidor"},
    },
)


# ---------------------------------------------------------------------------
# POST /diet-logbook — Registrar Alimento Consumido
# ---------------------------------------------------------------------------


@router.post(
    "",
    response_model=LogbookEntryResponseDTO,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar alimento consumido",
    responses={
        201: {"description": "Alimento registrado com sucesso"},
        400: {"description": "Alimento não encontrado"},
        422: {"description": "Dados inválidos"},
    },
)
async def add_logbook_entry(
    dto: AddLogbookEntryDTO,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> LogbookEntryResponseDTO:
    """
    Registra um alimento consumido no diário alimentar do dia.

    **Funcionamento:**
    1. Busca dados nutricionais na TACO ou Custom Foods
    2. Calcula macros proporcionais (`valor × quantidade / 100`)
    3. Grava snapshot imutável dos macros
    4. Atualiza totais acumulados do dia

    **Campos:**
    - `food_id`: ID do alimento na Tabela TACO (use um **ou** outro)
    - `custom_food_id`: UUID do alimento personalizado
    - `meal_name`: Nome da refeição (ex: "Café da Manhã")
    - `quantity_g`: Quantidade consumida em gramas
    - `date`: Data do consumo (default: hoje)
    """
    controller = DietController(db)
    try:
        return await controller.add_logbook_entry(
            user_id=current_user.id, dto=dto
        )
    except LogbookValidationError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail=str(e)
        )
    except Exception as e:
        print(f"ERROR adding logbook entry: {e}")
        import traceback
        traceback.print_exc()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro ao registrar alimento no diário: {str(e)}",
        )


# ---------------------------------------------------------------------------
# GET /diet-logbook/{date} — Diário do Dia
# ---------------------------------------------------------------------------


@router.get(
    "/{log_date}",
    response_model=DietLogbookResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Consultar diário alimentar do dia",
    responses={
        200: {"description": "Diário do dia retornado"},
        404: {"description": "Nenhum registro para esta data"},
    },
)
async def get_logbook(
    log_date: date,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DietLogbookResponseDTO:
    """
    Retorna o diário alimentar completo de uma data.

    Inclui todos os alimentos registrados com seus macros (snapshot),
    agrupados por refeição, e os **totais do dia**.

    Formato da data: `YYYY-MM-DD` (ex: `2026-05-03`)
    """
    controller = DietController(db)
    try:
        result = await controller.get_logbook(
            user_id=current_user.id, log_date=log_date
        )
        if result is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Nenhum registro para a data {log_date}.",
            )
        return result
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao buscar diário alimentar.",
        )


# ---------------------------------------------------------------------------
# DELETE /diet-logbook/entries/{entry_id} — Remover Registro
# ---------------------------------------------------------------------------


@router.delete(
    "/entries/{entry_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Remover registro do diário",
    responses={
        204: {"description": "Registro removido"},
        403: {"description": "Sem permissão para remover este registro"},
        404: {"description": "Registro não encontrado"},
    },
)
async def remove_logbook_entry(
    entry_id: UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> None:
    """
    Remove um alimento do diário e **subtrai** os macros dos totais do dia.
    """
    controller = DietController(db)
    try:
        await controller.remove_logbook_entry(
            entry_id=entry_id, user_id=current_user.id
        )
    except LogbookEntryNotFoundError as e:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail=str(e)
        )
    except LogbookForbiddenError as e:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, detail=str(e)
        )
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao remover registro do diário.",
        )


LOGBOOK_READ_ROLES = {"admin", "personal_trainer", "professor", "gestor"}


# ---------------------------------------------------------------------------
# GET /diet-logbook/analytics/summary — Sumário Histórico de Nutrição
# ---------------------------------------------------------------------------


@router.get(
    "/analytics/summary",
    response_model=NutritionAnalyticsSummaryResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Sumário histórico de nutrição por período",
    responses={
        200: {"description": "Sumário agregado por dia retornado"},
        400: {"description": "Parâmetros de data inválidos"},
        403: {"description": "Sem permissão para acessar dados de outro aluno"},
    },
)
async def get_nutrition_analytics_summary(
    start_date: date = Query(..., description="Data de início (YYYY-MM-DD)"),
    end_date: date = Query(..., description="Data de fim (YYYY-MM-DD)"),
    student_id: Optional[UUID] = Query(
        None, description="ID do aluno — apenas Personal/Admin"
    ),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> NutritionAnalyticsSummaryResponseDTO:
    """
    Retorna o resumo agregado de nutrição por dia em um período.

    - **Aluno autenticado**: retorna seus próprios dados (ignora `student_id`).
    - **Personal/Admin**: pode usar `student_id` para consultar dados de um aluno
      vinculado.

    O período máximo recomendado é de **90 dias** para performance otimizada.
    """
    # Determina o usuário alvo
    target_user_id = current_user.id
    if student_id is not None:
        if current_user.role not in LOGBOOK_READ_ROLES:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Apenas profissionais podem acessar dados de alunos.",
            )
        target_user_id = student_id

    if start_date > end_date:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="start_date deve ser anterior ou igual a end_date.",
        )

    controller = DietController(db)
    try:
        return await controller.get_nutrition_analytics(
            user_id=target_user_id,
            start_date=start_date,
            end_date=end_date,
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erro ao gerar sumário de nutrição: {str(e)}",
        )


# ---------------------------------------------------------------------------
# GET /diet-logbook/student/{user_id}/{date} — Personal lê logbook do aluno
# ---------------------------------------------------------------------------


@router.get(
    "/student/{user_id}/{log_date}",
    response_model=DietLogbookResponseDTO,
    status_code=status.HTTP_200_OK,
    summary="Consultar diário alimentar de um aluno (Personal/Admin)",
    responses={
        200: {"description": "Diário do aluno retornado"},
        403: {"description": "Sem permissão para visualizar"},
        404: {"description": "Nenhum registro para esta data"},
    },
)
async def get_student_logbook(
    user_id: UUID,
    log_date: date,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> DietLogbookResponseDTO:
    """
    Permite que **Personal Trainers** e **Admins** consultem o diário
    alimentar de um aluno em uma data específica.

    Alunos não podem acessar este endpoint (devem usar `GET /diet-logbook/{date}`).
    """
    if current_user.role not in LOGBOOK_READ_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas profissionais podem visualizar o logbook de alunos.",
        )

    controller = DietController(db)
    try:
        result = await controller.get_logbook(
            user_id=user_id, log_date=log_date
        )
        if result is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f"Nenhum registro para a data {log_date}.",
            )
        return result
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Erro ao buscar diário alimentar do aluno.",
        )

