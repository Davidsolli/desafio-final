"""
Service layer para Pagamentos (MVP V1)
Contém lógica de negócio e orquestração
"""
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional, List
from uuid import UUID
from decimal import Decimal
from datetime import datetime, timedelta
import logging

from app.models.payment import Plan, Subscription
from app.repositories.payment_repository import PlanRepository, SubscriptionRepository
from app.dtos.payment_dtos import (
    CreatePlanDTO,
    UpdatePlanDTO,
    PlanResponseDTO,
    SubscriptionResponseDTO,
    SubscriptionDetailDTO,
    CheckoutResponseDTO,
    SubscriptionSummaryDTO,
    AdminSubscriptionItemDTO
)

logger = logging.getLogger(__name__)


class PlanService:
    """Serviço de gerenciamento de planos"""

    @staticmethod
    async def create_plan(
        session: AsyncSession,
        admin_id: UUID,
        dto: CreatePlanDTO
    ) -> PlanResponseDTO:
        """Criar novo plano"""
        plan = await PlanRepository.create(session, admin_id, dto)
        await session.commit()
        logger.info(f"Plano criado: {plan.id} por admin {admin_id}")
        return PlanResponseDTO.model_validate(plan)

    @staticmethod
    async def get_plan(session: AsyncSession, plan_id: UUID) -> Optional[PlanResponseDTO]:
        """Buscar plano por ID"""
        plan = await PlanRepository.find_by_id(session, plan_id)
        if not plan:
            logger.warning(f"Plano não encontrado: {plan_id}")
            return None
        return PlanResponseDTO.model_validate(plan)

    @staticmethod
    async def list_plans(
        session: AsyncSession,
        admin_id: UUID,
        only_active: bool = True
    ) -> List[PlanResponseDTO]:
        """Listar planos de um admin"""
        plans = await PlanRepository.find_by_admin(session, admin_id, only_active)
        return [PlanResponseDTO.model_validate(p) for p in plans]

    @staticmethod
    async def update_plan(
        session: AsyncSession,
        plan_id: UUID,
        dto: UpdatePlanDTO
    ) -> Optional[PlanResponseDTO]:
        """Atualizar plano"""
        plan = await PlanRepository.update(session, plan_id, dto)
        if not plan:
            logger.warning(f"Plano não encontrado para atualizar: {plan_id}")
            return None
        await session.commit()
        logger.info(f"Plano atualizado: {plan_id}")
        return PlanResponseDTO.model_validate(plan)

    @staticmethod
    async def list_plans_for_student(
        session: AsyncSession,
        student_id: UUID
    ) -> List[PlanResponseDTO]:
        """
        Listar planos ativos para o aluno.
        Cadeia: aluno → trainer_id → invitation.trainer_id → admin que criou o convite
        Se não encontrar admin via convite, retorna todos os planos ativos do sistema.
        """
        from sqlalchemy import select
        from app.models.user import User
        from app.models.invitation import Invitation

        # 1. Buscar o aluno e seu trainer
        result = await session.execute(select(User).where(User.id == student_id))
        student = result.scalar_one_or_none()
        if not student or not student.trainer_id:
            # Sem trainer vinculado — retorna todos os planos ativos
            plans = await PlanRepository.find_all_active(session)
            return [PlanResponseDTO.model_validate(p) for p in plans]

        # 2. Buscar quem convidou o trainer (esse é o admin)
        inv_result = await session.execute(
            select(Invitation).where(
                Invitation.used_by_id == student.trainer_id,
                Invitation.used == True
            )
        )
        invitation = inv_result.scalar_one_or_none()

        if invitation:
            # O admin é quem criou o convite
            admin_result = await session.execute(
                select(User).where(User.id == invitation.trainer_id)
            )
            admin = admin_result.scalar_one_or_none()
            if admin and admin.role == "admin":
                plans = await PlanRepository.find_by_admin(session, admin.id, only_active=True)
                return [PlanResponseDTO.model_validate(p) for p in plans]

        # Fallback: planos do próprio trainer (caso ele seja admin autônomo)
        plans = await PlanRepository.find_by_admin(session, student.trainer_id, only_active=True)
        if plans:
            return [PlanResponseDTO.model_validate(p) for p in plans]

        # Último fallback: todos os planos ativos
        plans = await PlanRepository.find_all_active(session)
        return [PlanResponseDTO.model_validate(p) for p in plans]

    @staticmethod
    async def delete_plan(session: AsyncSession, plan_id: UUID) -> bool:
        """Deletar plano (soft delete)"""
        result = await PlanRepository.soft_delete(session, plan_id)
        if result:
            await session.commit()
            logger.info(f"Plano deletado (soft): {plan_id}")
        return result


class SubscriptionService:
    """Serviço de gerenciamento de assinaturas"""

    @staticmethod
    async def create_checkout(
        session: AsyncSession,
        student_id: UUID,
        plan_id: UUID,
        payment_method: str,
        replacement_policy: Optional[str] = None
    ) -> Optional[CheckoutResponseDTO]:
        """
        Criar checkout para assinatura via InfinitePay.
        Cria o link de pagamento e envia pelo WhatsApp do aluno.
        """
        from sqlalchemy import select
        from app.models.user import User
        from app.services.infinitepay_service import create_payment_link
        from app.services.whatsapp_service import send_payment_link

        # 1. Validar plano
        plan = await PlanRepository.find_by_id(session, plan_id)
        if not plan or not plan.is_active:
            logger.warning(f"Plano inválido: {plan_id}")
            return None

        # 2. Buscar dados do aluno
        result = await session.execute(select(User).where(User.id == student_id))
        student = result.scalar_one_or_none()
        if not student:
            logger.warning(f"Aluno não encontrado: {student_id}")
            return None

        # 3. Criar subscription em status PENDING
        subscription = await SubscriptionRepository.create(
            session,
            student_id,
            plan_id,
            plan.admin_id,
            payment_method,
            replacement_policy
        )
        await session.commit()
        logger.info(f"Assinatura criada (PENDING): {subscription.id}")

        # 4. Criar link de pagamento na InfinitePay
        infinitepay_result = await create_payment_link(
            subscription_id=subscription.id,
            plan_name=plan.name,
            price_brl=float(plan.price),
            student_name=student.name or student.email,
            student_email=student.email,
            student_phone=getattr(student, "phone_whatsapp", None),
        )

        if infinitepay_result:
            checkout_url = infinitepay_result.url
            external_id = f"infinitepay_{subscription.id}"

            # 5. Enviar link via WhatsApp se aluno tiver telefone
            phone = getattr(student, "phone_whatsapp", None) or getattr(student, "phone", None)
            if phone:
                await send_payment_link(
                    phone=phone,
                    student_name=student.name or student.email,
                    plan_name=plan.name,
                    payment_url=checkout_url,
                    price_brl=float(plan.price),
                )
        else:
            # InfinitePay falhou — retorna URL de fallback para o aluno copiar
            logger.warning(f"InfinitePay falhou para subscription {subscription.id}, usando fallback")
            checkout_url = f"https://checkout.infinitepay.io/natalia-faria-16"
            external_id = f"manual_{subscription.id}"

        return CheckoutResponseDTO(
            subscription_id=subscription.id,
            checkout_url=checkout_url,
            external_payment_id=external_id,
            status="pending"
        )

    @staticmethod
    async def get_subscription(
        session: AsyncSession,
        subscription_id: UUID
    ) -> Optional[SubscriptionDetailDTO]:
        """Buscar assinatura com plano"""
        subscription = await SubscriptionRepository.find_by_id(session, subscription_id)
        if not subscription:
            logger.warning(f"Assinatura não encontrada: {subscription_id}")
            return None

        # Carregar plano
        await session.refresh(subscription, ["plan"])
        plan_dto = PlanResponseDTO.model_validate(subscription.plan) if subscription.plan else None

        return SubscriptionDetailDTO(
            **SubscriptionResponseDTO.model_validate(subscription).model_dump(),
            plan=plan_dto
        )

    @staticmethod
    async def get_student_active_subscription(
        session: AsyncSession,
        student_id: UUID
    ) -> Optional[SubscriptionDetailDTO]:
        """Buscar assinatura mais recente do aluno (ativa, expirada ou cancelada)"""
        subscription = await SubscriptionRepository.find_student_latest(session, student_id)
        if not subscription:
            return None

        return await SubscriptionService.get_subscription(session, subscription.id)

    @staticmethod
    async def list_subscriptions(
        session: AsyncSession,
        admin_id: UUID,
        status: Optional[str] = None,
        limit: int = 50,
        offset: int = 0
    ) -> List[SubscriptionDetailDTO]:
        """Listar assinaturas de um admin"""
        subscriptions = await SubscriptionRepository.find_by_admin(
            session,
            admin_id,
            status,
            limit,
            offset
        )

        result = []
        for sub in subscriptions:
            await session.refresh(sub, ["plan"])
            plan_dto = PlanResponseDTO.model_validate(sub.plan) if sub.plan else None
            detail_dto = SubscriptionDetailDTO(
                **SubscriptionResponseDTO.model_validate(sub).model_dump(),
                plan=plan_dto
            )
            result.append(detail_dto)

        return result

    @staticmethod
    async def activate_subscription(
        session: AsyncSession,
        subscription_id: UUID,
        external_payment_id: str
    ) -> Optional[SubscriptionDetailDTO]:
        """
        Ativar assinatura após webhook de pagamento confirmado
        Chamado quando Asaas confirma o pagamento
        """
        subscription = await SubscriptionRepository.find_by_id(session, subscription_id)
        if not subscription:
            logger.warning(f"Assinatura não encontrada para ativar: {subscription_id}")
            return None

        if subscription.status != "pending":
            logger.warning(f"Assinatura não está em PENDING: {subscription_id}")
            return None

        # Carregar plano
        await session.refresh(subscription, ["plan"])
        plan = subscription.plan

        # Ativar
        success = await SubscriptionRepository.activate(
            session,
            subscription_id,
            external_payment_id,
            plan
        )
        
        if success:
            # Se a política for 'immediate', desativamos as outras agora
            if subscription.replacement_policy == "immediate":
                from sqlalchemy import update, and_
                stmt = (
                    update(Subscription)
                    .where(
                        and_(
                            Subscription.student_id == subscription.student_id,
                            Subscription.id != subscription.id,
                            Subscription.status == "active"
                        )
                    )
                    .values(status="canceled", canceled_at=datetime.utcnow())
                )
                await session.execute(stmt)
            
            await session.commit()
            logger.info(f"Assinatura ativada: {subscription_id}")
            return await SubscriptionService.get_subscription(session, subscription_id)

        return None

    @staticmethod
    async def cancel_subscription(
        session: AsyncSession,
        subscription_id: UUID
    ) -> bool:
        """Cancelar assinatura (status CANCELED_PENDING)"""
        result = await SubscriptionRepository.cancel_pending(session, subscription_id)
        if result:
            await session.commit()
            logger.info(f"Assinatura cancelada (PENDING): {subscription_id}")
        return result

    @staticmethod
    async def check_student_access(
        session: AsyncSession,
        student_id: UUID
    ) -> bool:
        """
        Verificar se aluno tem acesso ao app
        Retorna True se tem assinatura ACTIVE e não expirada
        """
        subscription = await SubscriptionRepository.find_student_active(session, student_id)
        if not subscription:
            return False
        return subscription.is_active_now()


    @staticmethod
    async def get_dashboard_summary(
        session: AsyncSession,
        admin_id: UUID
    ) -> SubscriptionSummaryDTO:
        """Resumo financeiro para o dashboard do admin"""
        return await SubscriptionRepository.get_summary(session, admin_id)

    @staticmethod
    async def list_subscriptions_dashboard(
        session: AsyncSession,
        admin_id: UUID,
        status: Optional[str] = None,
        limit: int = 50,
        offset: int = 0
    ) -> List[AdminSubscriptionItemDTO]:
        """Lista de assinaturas com dados do aluno para o dashboard"""
        return await SubscriptionRepository.find_with_student_info(
            session, admin_id, status, limit, offset
        )

    @staticmethod
    async def manual_activate(
        session: AsyncSession,
        subscription_id: UUID
    ) -> bool:
        """Ativar assinatura manualmente (admin sem webhook)"""
        subscription = await SubscriptionRepository.find_by_id(session, subscription_id)
        if not subscription:
            return False
        await session.refresh(subscription, ["plan"])
        success = await SubscriptionRepository.manual_activate(
            session, subscription_id, subscription.plan
        )
        if success:
            await session.commit()
            logger.info(f"Assinatura ativada manualmente: {subscription_id}")
        return success

    @staticmethod
    async def manual_cancel(
        session: AsyncSession,
        subscription_id: UUID
    ) -> bool:
        """Cancelar assinatura manualmente (admin)"""
        success = await SubscriptionRepository.manual_cancel(session, subscription_id)
        if success:
            await session.commit()
            logger.info(f"Assinatura cancelada manualmente: {subscription_id}")
        return success

    @staticmethod
    async def change_plan(
        session: AsyncSession,
        subscription_id: UUID,
        new_plan_id: UUID
    ) -> bool:
        """Alterar plano de uma assinatura (admin)"""
        subscription = await SubscriptionRepository.find_by_id(session, subscription_id)
        if not subscription:
            return False

        plan = await PlanRepository.find_by_id(session, new_plan_id)
        if not plan or not plan.is_active:
            return False

        subscription.plan_id = new_plan_id
        # Se estiver ativa, atualizamos a expiração baseada no novo plano a partir de hoje
        if subscription.status == "active":
            now = datetime.utcnow()
            subscription.expires_at = now + timedelta(days=30 * plan.duration_months)

        await session.flush()
        await session.commit()
        logger.info(f"Plano da assinatura {subscription_id} alterado para {new_plan_id}")
        return True



class PaymentCronService:
    """Serviço de tarefas agendadas (cron jobs)"""

    @staticmethod
    async def expire_subscriptions(session: AsyncSession) -> int:
        """Rodar diariamente para expirar assinaturas vencidas"""
        count = await SubscriptionRepository.expire_outdated(session)
        if count > 0:
            await session.commit()
            logger.info(f"Assinaturas expiradas: {count}")
        return count

    @staticmethod
    async def finalize_canceled(session: AsyncSession) -> int:
        """Rodar diariamente para finalizar cancelamentos"""
        count = await SubscriptionRepository.finalize_canceled(session)
        if count > 0:
            await session.commit()
            logger.info(f"Assinaturas canceladas (finalizadas): {count}")
        return count
