"""
Testes para o módulo de métricas administrativas.

Cobre:
- Lógica pura do serviço (funções de scoring e categorização)
- Endpoints da API com dados no banco (integração)
- Acesso negado para não-admins
"""

import pytest
import pytest_asyncio
from datetime import datetime, date, timezone

from app.models.logbook import WorkoutSession
from app.models.diet_logbook import DietLogbook
from app.models.step_log import StepLog
from app.models.goal import Goal
from app.models.chatbot import ChatConversation, ChatMessage, ChatFeedback
from app.models.invitation import Invitation
from app.models.user import User
from app.services.admin_metrics_service import (
    _adherence_category,
    _risk_score,
    _risk_level,
    _days_since,
)
from app.dtos.user_dto import CreateUserDTO
from app.services.user_service import UserService
from app.services.invitation_service import InvitationService


# ────────────────────────────────────────────────────────────────
# FIXTURES
# ────────────────────────────────────────────────────────────────

@pytest_asyncio.fixture
async def admin_user(test_db_session):
    """Cria um usuário admin no banco."""
    service = UserService(test_db_session)
    dto = CreateUserDTO(
        name="Admin Teste",
        email="admin.metrics@example.com",
        password="SenhaForte123!",
        role="admin",
    )
    response = await service.create(dto)
    return await test_db_session.get(User, response.id)


@pytest_asyncio.fixture
async def trainer_user(test_db_session):
    """Cria um personal trainer no banco."""
    service = UserService(test_db_session)
    dto = CreateUserDTO(
        name="Trainer Metricas",
        email="trainer.metrics@example.com",
        password="SenhaForte123!",
        role="personal_trainer",
    )
    response = await service.create(dto)
    return await test_db_session.get(User, response.id)


@pytest_asyncio.fixture
async def student_user(test_db_session, trainer_user):
    """Cria um aluno vinculado ao trainer_user."""
    user_service = UserService(test_db_session)
    inv_service = InvitationService(test_db_session)

    inv = await inv_service.generate(trainer_user.id)
    dto = CreateUserDTO(
        name="Aluno Metricas",
        email="aluno.metrics@example.com",
        password="SenhaForte123!",
        role="client",
        invitation_code=inv.code,
    )
    response = await user_service.create(dto)
    await test_db_session.commit()
    return await test_db_session.get(User, response.id)


@pytest_asyncio.fixture
async def workout_session_completed(test_db_session, student_user):
    """Cria uma sessão de treino completada para o aluno."""
    from uuid import uuid4
    session = WorkoutSession(
        user_id=student_user.id,
        workout_sheet_id=uuid4(),
        session_date=datetime.now(timezone.utc),
        status="completed",
    )
    test_db_session.add(session)
    await test_db_session.commit()
    return session


@pytest_asyncio.fixture
async def diet_log(test_db_session, student_user):
    """Cria um registro de dieta para o aluno."""
    log = DietLogbook(
        user_id=student_user.id,
        date=date.today(),
        total_kcal=2000.0,
        total_protein=150.0,
        total_carbs=200.0,
        total_fats=70.0,
    )
    test_db_session.add(log)
    await test_db_session.commit()
    return log


# ────────────────────────────────────────────────────────────────
# TESTES UNITÁRIOS (lógica pura — sem banco)
# ────────────────────────────────────────────────────────────────

class TestAdherenceCategory:
    """Testa a categorização de aderência."""

    def test_high_adherence(self):
        assert _adherence_category(85.0) == "high"

    def test_high_adherence_boundary(self):
        assert _adherence_category(80.0) == "high"

    def test_medium_adherence(self):
        assert _adherence_category(65.0) == "medium"

    def test_medium_adherence_lower_boundary(self):
        assert _adherence_category(50.0) == "medium"

    def test_low_adherence(self):
        assert _adherence_category(30.0) == "low"

    def test_zero_adherence(self):
        assert _adherence_category(0.0) == "low"


class TestRiskScoring:
    """Testa o scoring de risco de churn."""

    def test_no_risk(self):
        score = _risk_score(90.0, 0)
        assert score == 0
        assert _risk_level(score) == "low"

    def test_medium_risk_low_adherence(self):
        score = _risk_score(45.0, 1)
        assert score == 3
        assert _risk_level(score) == "medium"

    def test_high_risk_inactive(self):
        # aderência < 30% (5) + inativo > 7 dias (3) = 8
        score = _risk_score(25.0, 10)
        assert score == 8
        assert _risk_level(score) == "critical"

    def test_risk_only_from_inactivity(self):
        # boa aderência mas inativo há 10 dias
        score = _risk_score(85.0, 10)
        assert score == 3
        assert _risk_level(score) == "medium"

    def test_critical_all_signals(self):
        score = _risk_score(10.0, 15)
        assert score >= 7
        assert _risk_level(score) == "critical"


class TestDaysSince:
    """Testa o cálculo de dias desde última atividade."""

    def test_none_returns_999(self):
        assert _days_since(None) == 999

    def test_today_returns_zero(self):
        assert _days_since(datetime.now(timezone.utc)) == 0

    def test_yesterday_returns_one(self):
        from datetime import timedelta
        yesterday = datetime.now(timezone.utc) - timedelta(days=1)
        assert _days_since(yesterday) == 1


# ────────────────────────────────────────────────────────────────
# TESTES DE INTEGRAÇÃO (endpoints + banco SQLite in-memory)
# ────────────────────────────────────────────────────────────────

class TestStudentMetricsEndpoint:
    """Testes do endpoint GET /api/v1/admin/metrics/students."""

    @pytest.mark.asyncio
    async def test_returns_200_for_admin(
        self, async_client_as, admin_user, student_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/students")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_response_structure(
        self, async_client_as, admin_user, student_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/students")
        data = response.json()
        assert "total" in data
        assert "page" in data
        assert "limit" in data
        assert "data" in data
        assert "summary" in data

    @pytest.mark.asyncio
    async def test_student_item_has_required_fields(
        self, async_client_as, admin_user, student_user, workout_session_completed
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/students")
        data = response.json()
        assert data["total"] >= 1
        item = data["data"][0]
        assert "user_id" in item
        assert "user_name" in item
        assert "adherence_rate" in item
        assert "adherence_category" in item
        assert "risk_level" in item
        assert "risk_score" in item
        assert "days_inactive" in item
        assert "sessions_completed" in item
        assert "sessions_total" in item

    @pytest.mark.asyncio
    async def test_forbidden_for_non_admin(
        self, async_client_as, trainer_user
    ):
        async with await async_client_as(trainer_user) as client:
            response = await client.get("/api/v1/admin/metrics/students")
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_filter_by_trainer_id(
        self, async_client_as, admin_user, student_user, trainer_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get(
                f"/api/v1/admin/metrics/students?trainer_id={trainer_user.id}"
            )
        assert response.status_code == 200
        data = response.json()
        # Todos os alunos retornados devem pertencer ao trainer
        for item in data["data"]:
            assert item["trainer_id"] == str(trainer_user.id)

    @pytest.mark.asyncio
    async def test_adherence_calculated_with_completed_sessions(
        self, async_client_as, admin_user, student_user, workout_session_completed
    ):
        from uuid import uuid4
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/students")
        data = response.json()
        student_item = next(
            (i for i in data["data"] if i["user_id"] == str(student_user.id)), None
        )
        assert student_item is not None
        assert student_item["sessions_completed"] >= 1
        assert student_item["adherence_rate"] > 0

    @pytest.mark.asyncio
    async def test_summary_counts_are_consistent(
        self, async_client_as, admin_user, student_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/students")
        data = response.json()
        summary = data["summary"]
        assert summary["total_students"] >= 0

        # Contagens de aderência devem refletir TODOS os alunos, não só a página
        total_categorized = (
            summary["high_adherence_count"]
            + summary["medium_adherence_count"]
            + summary["low_adherence_count"]
        )
        assert total_categorized == summary["total_students"]

        # Contagens de risco também devem somar o total global
        total_at_risk = (
            summary["at_risk_critical"]
            + summary["at_risk_high"]
            + summary["at_risk_medium"]
            + summary["at_risk_low"]
        )
        assert total_at_risk == summary["total_students"]

    @pytest.mark.asyncio
    async def test_pagination_works(
        self, async_client_as, admin_user, student_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get(
                "/api/v1/admin/metrics/students?page=1&limit=5"
            )
        data = response.json()
        assert data["page"] == 1
        assert data["limit"] == 5
        assert len(data["data"]) <= 5


class TestTrainerMetricsEndpoint:
    """Testes do endpoint GET /api/v1/admin/metrics/trainers."""

    @pytest.mark.asyncio
    async def test_returns_200_for_admin(
        self, async_client_as, admin_user, trainer_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/trainers")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_response_structure(
        self, async_client_as, admin_user, trainer_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/trainers")
        data = response.json()
        assert "total" in data
        assert "page" in data
        assert "limit" in data
        assert "data" in data

    @pytest.mark.asyncio
    async def test_trainer_item_has_required_fields(
        self, async_client_as, admin_user, trainer_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/trainers")
        data = response.json()
        assert data["total"] >= 1
        item = data["data"][0]
        assert "trainer_id" in item
        assert "trainer_name" in item
        assert "total_students" in item
        assert "active_students" in item
        assert "at_risk_students" in item
        assert "portfolio_health" in item
        assert "conversion_rate" in item
        assert "invites_generated" in item
        assert "invites_used" in item

    @pytest.mark.asyncio
    async def test_student_count_correct(
        self, async_client_as, admin_user, trainer_user, student_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/trainers")
        data = response.json()
        trainer_item = next(
            (i for i in data["data"] if i["trainer_id"] == str(trainer_user.id)), None
        )
        assert trainer_item is not None
        assert trainer_item["total_students"] >= 1

    @pytest.mark.asyncio
    async def test_forbidden_for_non_admin(
        self, async_client_as, student_user
    ):
        async with await async_client_as(student_user) as client:
            response = await client.get("/api/v1/admin/metrics/trainers")
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_conversion_rate_with_used_invitation(
        self, async_client_as, admin_user, trainer_user, student_user
    ):
        # O student_user foi criado com um convite do trainer → invites_used deve ser >= 1
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/trainers")
        data = response.json()
        trainer_item = next(
            (i for i in data["data"] if i["trainer_id"] == str(trainer_user.id)), None
        )
        assert trainer_item is not None
        assert trainer_item["invites_used"] >= 1
        assert trainer_item["conversion_rate"] > 0


class TestSystemMetricsEndpoint:
    """Testes do endpoint GET /api/v1/admin/metrics/system."""

    @pytest.mark.asyncio
    async def test_returns_200_for_admin(
        self, async_client_as, admin_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/system")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_response_has_all_fields(
        self, async_client_as, admin_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/system")
        data = response.json()
        required = [
            "period_days", "total_users", "active_users", "new_users_in_period",
            "total_trainers", "total_students", "dau", "mau", "dau_mau_ratio",
            "total_workouts_completed", "total_diet_logs",
            "chatbot_adoption_rate", "chatbot_quality_score",
        ]
        for field in required:
            assert field in data, f"Campo ausente: {field}"

    @pytest.mark.asyncio
    async def test_period_days_reflected_in_response(
        self, async_client_as, admin_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/system?days=7")
        assert response.json()["period_days"] == 7

    @pytest.mark.asyncio
    async def test_dau_mau_ratio_is_non_negative(
        self, async_client_as, admin_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/system")
        assert response.json()["dau_mau_ratio"] >= 0

    @pytest.mark.asyncio
    async def test_workout_count_increments_with_session(
        self, async_client_as, admin_user, workout_session_completed
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/system")
        assert response.json()["total_workouts_completed"] >= 1

    @pytest.mark.asyncio
    async def test_forbidden_for_student(
        self, async_client_as, student_user
    ):
        async with await async_client_as(student_user) as client:
            response = await client.get("/api/v1/admin/metrics/system")
        assert response.status_code == 403


class TestAIAnalyticsEndpoint:
    """Testes do endpoint GET /api/v1/admin/metrics/ai."""

    @pytest.mark.asyncio
    async def test_returns_200_for_admin(
        self, async_client_as, admin_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/ai")
        assert response.status_code == 200

    @pytest.mark.asyncio
    async def test_response_has_all_fields(
        self, async_client_as, admin_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/ai")
        data = response.json()
        required = [
            "period_days", "total_messages", "total_tokens",
            "avg_tokens_per_message", "avg_latency_ms",
            "quality_score", "by_model",
        ]
        for field in required:
            assert field in data, f"Campo ausente: {field}"

    @pytest.mark.asyncio
    async def test_empty_by_model_when_no_messages(
        self, async_client_as, admin_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/ai")
        data = response.json()
        # sem mensagens no banco → by_model vazio, totais zerados
        assert isinstance(data["by_model"], list)
        assert data["total_messages"] == 0
        assert data["total_tokens"] == 0

    @pytest.mark.asyncio
    async def test_forbidden_for_trainer(
        self, async_client_as, trainer_user
    ):
        async with await async_client_as(trainer_user) as client:
            response = await client.get("/api/v1/admin/metrics/ai")
        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_period_days_reflected_in_response(
        self, async_client_as, admin_user
    ):
        async with await async_client_as(admin_user) as client:
            response = await client.get("/api/v1/admin/metrics/ai?days=14")
        assert response.json()["period_days"] == 14
