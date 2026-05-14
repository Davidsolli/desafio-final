"""
Repository layer para operações de Pagamentos (MVP V1)
"""
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, update, and_, desc, func
from typing import Optional, List
from uuid import UUID
from datetime import datetime, timedelta
from decimal import Decimal

from app.models.payment import Plan, Subscription
from app.dtos.payment_dtos import CreatePlanDTO, UpdatePlanDTO, SubscriptionSummaryDTO, AdminSubscriptionItemDTO


class PlanRepository:
    """Operações de banco para Plans"""

    @staticmethod
    async def create(session: AsyncSession, admin_id: UUID, dto: CreatePlanDTO) -> Plan:
        """Criar novo plano"""
        plan = Plan(
            admin_id=admin_id,
            name=dto.name,
            description=dto.description,
            price=dto.price,
            duration_months=dto.duration_months,
            modality=dto.modality,
            evaluations_included=dto.evaluations_included or 0,
        )
        session.add(plan)
        await session.flush()
        return plan

    @staticmethod
    async def find_by_id(session: AsyncSession, plan_id: UUID) -> Optional[Plan]:
        """Buscar plano por ID"""
        result = await session.execute(select(Plan).where(Plan.id == plan_id))
        return result.scalars().first()

    @staticmethod
    async def find_by_admin(session: AsyncSession, admin_id: UUID, only_active: bool = True) -> List[Plan]:
        """Listar planos de um admin"""
        query = select(Plan).where(Plan.admin_id == admin_id)
        if only_active:
            query = query.where(Plan.is_active == True, Plan.deleted_at == None)
        query = query.order_by(desc(Plan.created_at))
        result = await session.execute(query)
        return result.scalars().all()

    @staticmethod
    async def find_all_active(session: AsyncSession) -> List[Plan]:
        """Listar todos os planos ativos do sistema"""
        query = select(Plan).where(Plan.is_active == True, Plan.deleted_at == None)
        query = query.order_by(desc(Plan.created_at))
        result = await session.execute(query)
        return result.scalars().all()

    @staticmethod
    async def update(session: AsyncSession, plan_id: UUID, dto: UpdatePlanDTO) -> Optional[Plan]:
        """Atualizar plano"""
        plan = await PlanRepository.find_by_id(session, plan_id)
        if not plan:
            return None

        update_data = dto.model_dump(exclude_unset=True)
        for key, value in update_data.items():
            setattr(plan, key, value)

        plan.updated_at = datetime.utcnow()
        await session.flush()
        return plan

    @staticmethod
    async def soft_delete(session: AsyncSession, plan_id: UUID) -> bool:
        """Soft delete (marca como deletado)"""
        plan = await PlanRepository.find_by_id(session, plan_id)
        if not plan:
            return False

        plan.deleted_at = datetime.utcnow()
        await session.flush()
        return True


class SubscriptionRepository:
    """Operações de banco para Subscriptions"""

    @staticmethod
    async def create(
        session: AsyncSession,
        student_id: UUID,
        plan_id: UUID,
        admin_id: UUID,
        payment_method: str
    ) -> Subscription:
        """Criar nova assinatura (status PENDING)"""
        subscription = Subscription(
            student_id=student_id,
            plan_id=plan_id,
            admin_id=admin_id,
            payment_method=payment_method,
            status="pending"
        )
        session.add(subscription)
        await session.flush()
        return subscription

    @staticmethod
    async def find_by_id(session: AsyncSession, subscription_id: UUID) -> Optional[Subscription]:
        """Buscar assinatura por ID"""
        result = await session.execute(
            select(Subscription).where(Subscription.id == subscription_id)
        )
        return result.scalars().first()

    @staticmethod
    async def find_by_external_id(session: AsyncSession, external_payment_id: str) -> Optional[Subscription]:
        """Buscar assinatura por ID externo (Asaas)"""
        result = await session.execute(
            select(Subscription).where(Subscription.external_payment_id == external_payment_id)
        )
        return result.scalars().first()

    @staticmethod
    async def find_student_active(session: AsyncSession, student_id: UUID) -> Optional[Subscription]:
        """Buscar assinatura ativa do aluno"""
        result = await session.execute(
            select(Subscription)
            .where(
                and_(
                    Subscription.student_id == student_id,
                    Subscription.status == "active"
                )
            )
        )
        return result.scalars().first()

    @staticmethod
    async def find_student_latest(session: AsyncSession, student_id: UUID) -> Optional[Subscription]:
        """Buscar assinatura mais recente do aluno (qualquer status)"""
        result = await session.execute(
            select(Subscription)
            .where(Subscription.student_id == student_id)
            .order_by(Subscription.created_at.desc())
        )
        return result.scalars().first()

    @staticmethod
    async def find_by_admin(
        session: AsyncSession,
        admin_id: UUID,
        status: Optional[str] = None,
        limit: int = 50,
        offset: int = 0
    ) -> List[Subscription]:
        """Listar assinaturas de um admin com paginação"""
        query = select(Subscription).where(Subscription.admin_id == admin_id)
        if status:
            query = query.where(Subscription.status == status)
        query = query.order_by(desc(Subscription.created_at)).limit(limit).offset(offset)
        result = await session.execute(query)
        return result.scalars().all()

    @staticmethod
    async def activate(
        session: AsyncSession,
        subscription_id: UUID,
        external_payment_id: str,
        plan: Plan
    ) -> bool:
        """Ativar assinatura (webhook confirmado)"""
        subscription = await SubscriptionRepository.find_by_id(session, subscription_id)
        if not subscription:
            return False

        # Calcular datas
        now = datetime.utcnow()
        subscription.status = "active"
        subscription.started_at = now
        subscription.expires_at = now + timedelta(days=30 * plan.duration_months)
        subscription.external_payment_id = external_payment_id

        await session.flush()
        return True

    @staticmethod
    async def cancel_pending(session: AsyncSession, subscription_id: UUID) -> bool:
        """Cancelar assinatura (status CANCELED_PENDING)"""
        subscription = await SubscriptionRepository.find_by_id(session, subscription_id)
        if not subscription:
            return False

        subscription.status = "canceled_pending"
        subscription.canceled_at = datetime.utcnow()
        await session.flush()
        return True

    @staticmethod
    async def expire_outdated(session: AsyncSession) -> int:
        """Cron job: marcar assinaturas expiradas como EXPIRED"""
        now = datetime.utcnow()

        stmt = (
            update(Subscription)
            .where(
                and_(
                    Subscription.status == "active",
                    Subscription.expires_at < now
                )
            )
            .values(status="expired")
        )

        result = await session.execute(stmt)
        await session.flush()
        return result.rowcount

    @staticmethod
    async def finalize_canceled(session: AsyncSession) -> int:
        """Cron job: marcar CANCELED_PENDING que já expiraram como CANCELED"""
        now = datetime.utcnow()

        stmt = (
            update(Subscription)
            .where(
                and_(
                    Subscription.status == "canceled_pending",
                    Subscription.expires_at < now
                )
            )
            .values(status="canceled")
        )

        result = await session.execute(stmt)
        await session.flush()
        return result.rowcount

    @staticmethod
    async def count_by_admin(session: AsyncSession, admin_id: UUID, status: Optional[str] = None) -> int:
        """Contar assinaturas de um admin"""
        query = select(func.count(Subscription.id)).where(Subscription.admin_id == admin_id)
        if status:
            query = query.where(Subscription.status == status)
        result = await session.execute(query)
        return result.scalar()

    @staticmethod
    async def get_summary(session: AsyncSession, admin_id: UUID) -> SubscriptionSummaryDTO:
        """Resumo financeiro do admin"""
        now = datetime.utcnow()
        first_this_month = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        if now.month == 1:
            first_last_month = now.replace(year=now.year - 1, month=12, day=1, hour=0, minute=0, second=0, microsecond=0)
        else:
            first_last_month = now.replace(month=now.month - 1, day=1, hour=0, minute=0, second=0, microsecond=0)

        async def count_status(s: str) -> int:
            r = await session.execute(
                select(func.count(Subscription.id)).where(
                    and_(Subscription.admin_id == admin_id, Subscription.status == s)
                )
            )
            return r.scalar() or 0

        async def revenue_in_period(start: datetime, end: datetime) -> Decimal:
            r = await session.execute(
                select(func.coalesce(func.sum(Plan.price), 0)).select_from(
                    Subscription.__table__.join(Plan.__table__, Subscription.plan_id == Plan.id)
                ).where(
                    and_(
                        Subscription.admin_id == admin_id,
                        Subscription.status == "active",
                        Subscription.started_at >= start,
                        Subscription.started_at < end,
                    )
                )
            )
            return Decimal(str(r.scalar() or 0))

        return SubscriptionSummaryDTO(
            total_active=await count_status("active"),
            total_pending=await count_status("pending"),
            total_canceled=await count_status("canceled") + await count_status("canceled_pending"),
            total_expired=await count_status("expired"),
            revenue_this_month=await revenue_in_period(first_this_month, now),
            revenue_last_month=await revenue_in_period(first_last_month, first_this_month),
        )

    @staticmethod
    async def find_with_student_info(
        session: AsyncSession,
        admin_id: UUID,
        status: Optional[str] = None,
        limit: int = 50,
        offset: int = 0
    ) -> List[AdminSubscriptionItemDTO]:
        """Lista de assinaturas com dados do aluno para o dashboard"""
        from app.models.user import User

        query = (
            select(
                Subscription.id,
                Subscription.student_id,
                Subscription.status,
                Subscription.payment_method,
                Subscription.started_at,
                Subscription.expires_at,
                Subscription.created_at,
                User.name.label("student_name"),
                User.email.label("student_email"),
                Plan.name.label("plan_name"),
                Plan.price.label("plan_price"),
            )
            .join(User, Subscription.student_id == User.id)
            .join(Plan, Subscription.plan_id == Plan.id)
            .where(Subscription.admin_id == admin_id)
        )
        if status:
            query = query.where(Subscription.status == status)
        query = query.order_by(desc(Subscription.created_at)).limit(limit).offset(offset)

        result = await session.execute(query)
        rows = result.mappings().all()
        return [AdminSubscriptionItemDTO(**dict(row)) for row in rows]

    @staticmethod
    async def manual_activate(
        session: AsyncSession,
        subscription_id: UUID,
        plan: Plan
    ) -> bool:
        """Ativar manualmente pelo admin (sem webhook)"""
        subscription = await SubscriptionRepository.find_by_id(session, subscription_id)
        if not subscription:
            return False
        now = datetime.utcnow()
        subscription.status = "active"
        subscription.started_at = now
        subscription.expires_at = now + timedelta(days=30 * plan.duration_months)
        if not subscription.external_payment_id:
            subscription.external_payment_id = f"manual_{subscription_id}"
        await session.flush()
        return True

    @staticmethod
    async def manual_cancel(session: AsyncSession, subscription_id: UUID) -> bool:
        """Cancelar manualmente pelo admin"""
        subscription = await SubscriptionRepository.find_by_id(session, subscription_id)
        if not subscription:
            return False
        subscription.status = "canceled"
        subscription.canceled_at = datetime.utcnow()
        await session.flush()
        return True
