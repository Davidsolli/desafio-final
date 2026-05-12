"""
Testes para o módulo de Pagamentos (MVP V1)
"""
import pytest
from uuid import uuid4
from decimal import Decimal
from datetime import datetime, timedelta

from app.models.payment import Plan, Subscription
from app.dtos.payment_dtos import CreatePlanDTO, CreateSubscriptionDTO
from app.repositories.payment_repository import PlanRepository, SubscriptionRepository
from app.services.payment_service import PlanService, SubscriptionService


class TestPlanRepository:
    """Testes para PlanRepository"""

    @pytest.mark.asyncio
    async def test_create_plan(self, async_session):
        """Teste: criar um plano"""
        admin_id = uuid4()
        dto = CreatePlanDTO(
            name="Premium",
            description="Treino + Dieta + IA",
            price=Decimal("150.00"),
            duration_months=1
        )

        plan = await PlanRepository.create(async_session, admin_id, dto)

        assert plan.id is not None
        assert plan.admin_id == admin_id
        assert plan.name == "Premium"
        assert plan.price == Decimal("150.00")
        assert plan.is_active is True

    @pytest.mark.asyncio
    async def test_find_plan_by_id(self, async_session):
        """Teste: buscar plano por ID"""
        admin_id = uuid4()
        dto = CreatePlanDTO(
            name="Basic",
            price=Decimal("50.00"),
            duration_months=1
        )

        plan = await PlanRepository.create(async_session, admin_id, dto)
        found = await PlanRepository.find_by_id(async_session, plan.id)

        assert found is not None
        assert found.id == plan.id
        assert found.name == "Basic"

    @pytest.mark.asyncio
    async def test_find_plans_by_admin(self, async_session):
        """Teste: listar planos de um admin"""
        admin_id = uuid4()

        dto1 = CreatePlanDTO(name="Plan 1", price=Decimal("50.00"), duration_months=1)
        dto2 = CreatePlanDTO(name="Plan 2", price=Decimal("100.00"), duration_months=3)

        await PlanRepository.create(async_session, admin_id, dto1)
        await PlanRepository.create(async_session, admin_id, dto2)

        plans = await PlanRepository.find_by_admin(async_session, admin_id)

        assert len(plans) == 2
        assert all(p.admin_id == admin_id for p in plans)

    @pytest.mark.asyncio
    async def test_soft_delete_plan(self, async_session):
        """Teste: deletar plano (soft delete)"""
        admin_id = uuid4()
        dto = CreatePlanDTO(name="To Delete", price=Decimal("50.00"), duration_months=1)

        plan = await PlanRepository.create(async_session, admin_id, dto)
        original_id = plan.id

        success = await PlanRepository.soft_delete(async_session, original_id)
        assert success is True

        # Verificar que está marcado como deletado
        found = await PlanRepository.find_by_id(async_session, original_id)
        assert found.deleted_at is not None


class TestSubscriptionRepository:
    """Testes para SubscriptionRepository"""

    @pytest.mark.asyncio
    async def test_create_subscription(self, async_session):
        """Teste: criar assinatura"""
        student_id = uuid4()
        plan_id = uuid4()
        admin_id = uuid4()

        subscription = await SubscriptionRepository.create(
            async_session,
            student_id,
            plan_id,
            admin_id,
            "credit_card"
        )

        assert subscription.id is not None
        assert subscription.student_id == student_id
        assert subscription.status == "pending"
        assert subscription.payment_method == "credit_card"

    @pytest.mark.asyncio
    async def test_activate_subscription(self, async_session):
        """Teste: ativar assinatura"""
        student_id = uuid4()
        plan_id = uuid4()
        admin_id = uuid4()

        # Criar subscription em PENDING
        subscription = await SubscriptionRepository.create(
            async_session,
            student_id,
            plan_id,
            admin_id,
            "credit_card"
        )

        # Criar plan mock para teste
        plan = Plan(
            id=plan_id,
            admin_id=admin_id,
            name="Test",
            price=Decimal("100.00"),
            duration_months=1
        )
        async_session.add(plan)
        await async_session.flush()

        # Ativar
        success = await SubscriptionRepository.activate(
            async_session,
            subscription.id,
            "pay_mock_123",
            plan
        )

        assert success is True

        # Verificar estado
        found = await SubscriptionRepository.find_by_id(async_session, subscription.id)
        assert found.status == "active"
        assert found.started_at is not None
        assert found.expires_at is not None
        assert found.external_payment_id == "pay_mock_123"

    @pytest.mark.asyncio
    async def test_find_student_active_subscription(self, async_session):
        """Teste: buscar assinatura ativa do aluno"""
        student_id = uuid4()
        plan_id = uuid4()
        admin_id = uuid4()

        # Criar subscription
        subscription = await SubscriptionRepository.create(
            async_session,
            student_id,
            plan_id,
            admin_id,
            "pix"
        )

        # Sem estar ACTIVE, não deve retornar
        found = await SubscriptionRepository.find_student_active(async_session, student_id)
        assert found is None

        # Ativar
        plan = Plan(
            id=plan_id,
            admin_id=admin_id,
            name="Test",
            price=Decimal("100.00"),
            duration_months=1
        )
        async_session.add(plan)
        await async_session.flush()

        await SubscriptionRepository.activate(
            async_session,
            subscription.id,
            "pay_123",
            plan
        )

        # Agora deve retornar
        found = await SubscriptionRepository.find_student_active(async_session, student_id)
        assert found is not None
        assert found.status == "active"

    @pytest.mark.asyncio
    async def test_expire_subscriptions(self, async_session):
        """Teste: expirar assinaturas vencidas"""
        student_id = uuid4()
        plan_id = uuid4()
        admin_id = uuid4()

        # Criar subscription expirada
        subscription = await SubscriptionRepository.create(
            async_session,
            student_id,
            plan_id,
            admin_id,
            "credit_card"
        )

        plan = Plan(
            id=plan_id,
            admin_id=admin_id,
            name="Test",
            price=Decimal("100.00"),
            duration_months=1
        )
        async_session.add(plan)
        await async_session.flush()

        # Ativar mas já expirada (data no passado)
        await SubscriptionRepository.activate(
            async_session,
            subscription.id,
            "pay_123",
            plan
        )

        # Marcar como já expirada
        sub = await SubscriptionRepository.find_by_id(async_session, subscription.id)
        sub.expires_at = datetime.utcnow() - timedelta(days=1)
        await async_session.flush()

        # Rodar cron
        count = await SubscriptionRepository.expire_outdated(async_session)

        assert count >= 1

        # Verificar
        found = await SubscriptionRepository.find_by_id(async_session, subscription.id)
        assert found.status == "expired"


class TestPlanService:
    """Testes para PlanService"""

    @pytest.mark.asyncio
    async def test_create_plan_service(self, async_session):
        """Teste: criar plano via service"""
        admin_id = uuid4()
        dto = CreatePlanDTO(
            name="Premium",
            price=Decimal("150.00"),
            duration_months=1
        )

        result = await PlanService.create_plan(async_session, admin_id, dto)

        assert result.id is not None
        assert result.name == "Premium"
        assert result.price == Decimal("150.00")

    @pytest.mark.asyncio
    async def test_list_plans_service(self, async_session):
        """Teste: listar planos via service"""
        admin_id = uuid4()

        dto1 = CreatePlanDTO(name="Plan 1", price=Decimal("50.00"), duration_months=1)
        await PlanService.create_plan(async_session, admin_id, dto1)

        plans = await PlanService.list_plans(async_session, admin_id)

        assert len(plans) >= 1
        assert any(p.name == "Plan 1" for p in plans)


class TestSubscriptionService:
    """Testes para SubscriptionService"""

    @pytest.mark.asyncio
    async def test_create_checkout_service(self, async_session):
        """Teste: criar checkout via service"""
        admin_id = uuid4()
        student_id = uuid4()

        # Criar plan primeiro
        plan_dto = CreatePlanDTO(
            name="Premium",
            price=Decimal("150.00"),
            duration_months=1
        )
        plan = await PlanService.create_plan(async_session, admin_id, plan_dto)

        # Criar checkout
        result = await SubscriptionService.create_checkout(
            async_session,
            student_id,
            plan.id,
            "credit_card"
        )

        assert result is not None
        assert result.subscription_id is not None
        assert result.checkout_url is not None
        assert result.status == "pending"

    @pytest.mark.asyncio
    async def test_check_student_access(self, async_session):
        """Teste: verificar acesso do aluno"""
        admin_id = uuid4()
        student_id = uuid4()

        # Sem assinatura, sem acesso
        has_access = await SubscriptionService.check_student_access(async_session, student_id)
        assert has_access is False

        # Com assinatura PENDING, sem acesso
        plan_dto = CreatePlanDTO(
            name="Premium",
            price=Decimal("150.00"),
            duration_months=1
        )
        plan = await PlanService.create_plan(async_session, admin_id, plan_dto)
        await SubscriptionService.create_checkout(
            async_session,
            student_id,
            plan.id,
            "credit_card"
        )

        has_access = await SubscriptionService.check_student_access(async_session, student_id)
        assert has_access is False

        # Com assinatura ACTIVE, deve ter acesso
        sub = await SubscriptionRepository.find_student_active(async_session, student_id)
        if not sub:
            # Se não encontrou ativa, procura a pendente
            stmt = __import__("sqlalchemy").select(Subscription).where(
                Subscription.student_id == student_id
            )
            result = await async_session.execute(stmt)
            sub = result.scalars().first()

        if sub:
            plan_obj = await PlanRepository.find_by_id(async_session, sub.plan_id)
            await SubscriptionRepository.activate(
                async_session,
                sub.id,
                "pay_123",
                plan_obj
            )

            has_access = await SubscriptionService.check_student_access(async_session, student_id)
            assert has_access is True
