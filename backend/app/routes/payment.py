"""
Routes para Pagamentos e Assinaturas (MVP V1)
Endpoints: CRUD de Planos, Checkout, Webhooks
"""
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, List
from uuid import UUID

from app.config.database import get_db
from app.dependencies.auth import get_current_user
from app.models.user import User
from app.dtos.payment_dtos import (
    CreatePlanDTO,
    UpdatePlanDTO,
    PlanResponseDTO,
    CreateSubscriptionDTO,
    SubscriptionResponseDTO,
    SubscriptionDetailDTO,
    CheckoutResponseDTO,
    AsaasWebhookDTO,
    InfinitePayWebhookDTO,
    SubscriptionSummaryDTO,
    AdminSubscriptionItemDTO,
    ChangePlanDTO
)
from app.services.payment_service import PlanService, SubscriptionService

router = APIRouter(prefix="/api/v1", tags=["payments"])


# ============= PLANS =============

@router.post("/admin/plans", response_model=PlanResponseDTO, status_code=status.HTTP_201_CREATED)
async def create_plan(
    dto: CreatePlanDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db)
):
    """Criar novo plano (apenas Admin)"""
    # Validar que é admin
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas admins podem criar planos"
        )

    result = await PlanService.create_plan(session, current_user.id, dto)
    return result


@router.get("/admin/plans", response_model=List[PlanResponseDTO])
async def list_plans(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    only_active: bool = True
):
    """Listar planos do admin"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas admins podem listar planos"
        )

    return await PlanService.list_plans(session, current_user.id, only_active)


@router.get("/admin/plans/{plan_id}", response_model=PlanResponseDTO)
async def get_plan(
    plan_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db)
):
    """Buscar plano por ID"""
    plan = await PlanService.get_plan(session, plan_id)
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plano não encontrado")
    return plan


@router.put("/admin/plans/{plan_id}", response_model=PlanResponseDTO)
async def update_plan(
    plan_id: UUID,
    dto: UpdatePlanDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db)
):
    """Atualizar plano"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas admins podem atualizar planos"
        )

    plan = await PlanService.update_plan(session, plan_id, dto)
    if not plan:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plano não encontrado")
    return plan


@router.delete("/admin/plans/{plan_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_plan(
    plan_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db)
):
    """Deletar plano (soft delete)"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas admins podem deletar planos"
        )

    success = await PlanService.delete_plan(session, plan_id)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Plano não encontrado")


# ============= PLANS (STUDENT) =============

@router.get("/plans", response_model=List[PlanResponseDTO])
async def list_available_plans(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
):
    """Listar planos disponíveis para o aluno (do seu admin)"""
    return await PlanService.list_plans_for_student(session, current_user.id)


# ============= SUBSCRIPTIONS =============

@router.post("/subscriptions/checkout", response_model=CheckoutResponseDTO)
async def create_checkout(
    dto: CreateSubscriptionDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db)
):
    """Criar checkout para assinatura"""
    if current_user.role not in ("student", "client"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas alunos podem criar assinaturas"
        )

    result = await SubscriptionService.create_checkout(
        session,
        current_user.id,
        dto.plan_id,
        dto.payment_method
    )

    if not result:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Plano não encontrado ou inativo"
        )

    return result


@router.get("/subscriptions/current", response_model=SubscriptionDetailDTO)
async def get_current_subscription(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db)
):
    """Buscar assinatura ativa do aluno"""
    if current_user.role not in ("student", "client"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas alunos podem acessar suas assinaturas"
        )

    subscription = await SubscriptionService.get_student_active_subscription(session, current_user.id)
    if not subscription:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Assinatura ativa não encontrada"
        )

    return subscription


@router.get("/subscriptions/{subscription_id}", response_model=SubscriptionDetailDTO)
async def get_subscription(
    subscription_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db)
):
    """Buscar assinatura por ID"""
    subscription = await SubscriptionService.get_subscription(session, subscription_id)
    if not subscription:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assinatura não encontrada")

    # Validar permissão (aluno só vê sua, admin vê de seus alunos)
    if current_user.role in ("student", "client") and subscription.student_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Sem permissão")

    return subscription


@router.get("/admin/subscriptions", response_model=List[SubscriptionDetailDTO])
async def list_subscriptions(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    status_filter: Optional[str] = None,
    limit: int = 50,
    offset: int = 0
):
    """Listar assinaturas do admin"""
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Apenas admins podem listar assinaturas"
        )

    return await SubscriptionService.list_subscriptions(
        session,
        current_user.id,
        status_filter,
        limit,
        offset
    )


# ============= ADMIN DASHBOARD =============

@router.get("/admin/subscriptions/summary", response_model=SubscriptionSummaryDTO)
async def get_subscriptions_summary(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db)
):
    """Resumo financeiro do admin"""
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Apenas admins")
    return await SubscriptionService.get_dashboard_summary(session, current_user.id)


@router.get("/admin/subscriptions/dashboard", response_model=List[AdminSubscriptionItemDTO])
async def list_subscriptions_dashboard(
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db),
    status_filter: Optional[str] = None,
    limit: int = 50,
    offset: int = 0
):
    """Lista de assinaturas com dados do aluno para o dashboard"""
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Apenas admins")
    return await SubscriptionService.list_subscriptions_dashboard(
        session, current_user.id, status_filter, limit, offset
    )


@router.post("/admin/subscriptions/{subscription_id}/activate", status_code=status.HTTP_200_OK)
async def manual_activate_subscription(
    subscription_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db)
):
    """Ativar assinatura manualmente (admin)"""
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Apenas admins")
    success = await SubscriptionService.manual_activate(session, subscription_id)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assinatura não encontrada")
    return {"status": "activated"}


@router.post("/admin/subscriptions/{subscription_id}/cancel", status_code=status.HTTP_200_OK)
async def manual_cancel_subscription(
    subscription_id: UUID,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db)
):
    """Cancelar assinatura manualmente (admin)"""
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Apenas admins")
    success = await SubscriptionService.manual_cancel(session, subscription_id)
    if not success:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assinatura não encontrada")
    return {"status": "canceled"}


@router.put("/admin/subscriptions/{subscription_id}/change-plan", status_code=status.HTTP_200_OK)
async def change_plan_subscription(
    subscription_id: UUID,
    dto: ChangePlanDTO,
    current_user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_db)
):
    """Alterar plano de uma assinatura (admin)"""
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Apenas admins")
    success = await SubscriptionService.change_plan(session, subscription_id, dto.plan_id)
    if not success:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Erro ao alterar plano da assinatura")
    return {"status": "plan_changed"}



# ============= WEBHOOKS =============

@router.post("/webhooks/asaas")
async def handle_asaas_webhook(
    payload: AsaasWebhookDTO,
    session: AsyncSession = Depends(get_db)
):
    """
    Webhook do Asaas — pagamento confirmado libera acesso do aluno.

    Fluxo (PRD):
    1. Receber evento PAYMENT_CONFIRMED
    2. Extrair external_reference (subscription_id) e payment_id
    3. Buscar subscription pelo external_reference
    4. Alterar status → ACTIVE, setar started_at = now, calcular expires_at += duration_months
    5. Retornar 200 OK sempre (para o gateway não reenviar)
    """
    # Sempre retornar 200 para o gateway (mesmo em casos ignorados)
    if payload.event not in ("PAYMENT_CONFIRMED", "PAYMENT_RECEIVED"):
        return {"status": "ignored", "event": payload.event}

    external_ref = payload.get_external_reference()
    payment_id = payload.get_payment_id()

    if not external_ref:
        return {"status": "error", "message": "externalReference não fornecido"}

    try:
        subscription_id = UUID(external_ref)
    except ValueError:
        return {"status": "error", "message": "externalReference inválido"}

    result = await SubscriptionService.activate_subscription(
        session,
        subscription_id,
        payment_id or external_ref
    )

    if not result:
        return {
            "status": "error",
            "message": "Assinatura não encontrada ou já processada"
        }

    return {
        "status": "success",
        "subscription_id": str(subscription_id),
        "message": "Assinatura ativada — acesso liberado"
    }


@router.post("/webhooks/infinitepay")
async def handle_infinitepay_webhook(
    payload: InfinitePayWebhookDTO,
    session: AsyncSession = Depends(get_db)
):
    """
    Webhook da InfinitePay — pagamento confirmado libera acesso do aluno.

    Fluxo:
    1. Receber evento com status 'paid'/'approved'
    2. Extrair order_nsu (= subscription_id)
    3. Ativar a subscription → status ACTIVE, started_at = now, expires_at += duration
    4. Retornar 200 sempre (para a InfinitePay não reenviar)
    """
    if not payload.is_paid():
        return {"status": "ignored", "event_status": payload.status}

    subscription_id_str = payload.get_subscription_id()
    if not subscription_id_str:
        return {"status": "error", "message": "order_nsu não fornecido"}

    # Remover prefixo "infinitepay_" se presente
    subscription_id_str = subscription_id_str.replace("infinitepay_", "")

    try:
        subscription_id = UUID(subscription_id_str)
    except ValueError:
        return {"status": "error", "message": "order_nsu inválido"}

    result = await SubscriptionService.activate_subscription(
        session,
        subscription_id,
        payload.get_payment_id() or subscription_id_str
    )

    if not result:
        return {"status": "error", "message": "Assinatura não encontrada ou já processada"}

    return {
        "status": "success",
        "subscription_id": str(subscription_id),
        "message": "Assinatura ativada — acesso liberado"
    }


# ============= HEALTH CHECK =============

@router.get("/payments/health")
async def payments_health():
    """Health check do módulo de pagamentos"""
    return {"status": "ok", "service": "payments"}
