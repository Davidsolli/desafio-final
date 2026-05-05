"""
Testes de integração do Dashboard Profissional (RF-43 a RF-48).

Cobre:
- Acesso por personal_trainer (apenas seus alunos)
- Acesso por admin (visão global)
- Bloqueio de role client (403)
- Filtros de status e período (RF-47)
- Visão 360° com guard de isolamento (LGPD)
- Admin overview (RF-46)
- Exportação de PDF (RF-48)
"""

from datetime import datetime
from uuid import uuid4

import pytest
import pytest_asyncio

from app.dtos.user_dto import CreateUserDTO
from app.models.user import User
from app.models.workout_sheet import WorkoutSheet
from app.services.user_service import UserService


# ---------------------------------------------------------------------------
# Fixtures específicas do dashboard
# ---------------------------------------------------------------------------


@pytest_asyncio.fixture
async def personal_trainer(test_db_session):
    service = UserService(test_db_session)
    dto = CreateUserDTO(
        name="Carlos Personal",
        email="carlos.personal@test.com",
        password="SenhaForte123!",
        role="personal_trainer",
        phone_whatsapp="+55 11 91111-1111",
    )
    response = await service.create(dto)
    return await test_db_session.get(User, response.id)


@pytest_asyncio.fixture
async def other_personal(test_db_session):
    service = UserService(test_db_session)
    dto = CreateUserDTO(
        name="Outro Personal",
        email="outro.personal@test.com",
        password="SenhaForte123!",
        role="personal_trainer",
        phone_whatsapp="+55 11 92222-2222",
    )
    response = await service.create(dto)
    return await test_db_session.get(User, response.id)


@pytest_asyncio.fixture
async def admin_user(test_db_session):
    service = UserService(test_db_session)
    dto = CreateUserDTO(
        name="Admin Gestor",
        email="admin@test.com",
        password="SenhaForte123!",
        role="admin",
        phone_whatsapp="+55 11 93333-3333",
    )
    response = await service.create(dto)
    return await test_db_session.get(User, response.id)


@pytest_asyncio.fixture
async def student_user(test_db_session):
    service = UserService(test_db_session)
    dto = CreateUserDTO(
        name="Aluno Teste",
        email="aluno@test.com",
        password="SenhaForte123!",
        role="client",
        phone_whatsapp="+55 11 94444-4444",
    )
    response = await service.create(dto)
    return await test_db_session.get(User, response.id)


@pytest_asyncio.fixture
async def student_with_sheet(test_db_session, personal_trainer, student_user):
    """Vincula aluno ao personal via WorkoutSheet ativa."""
    sheet = WorkoutSheet(
        user_id=student_user.id,
        personal_trainer_id=personal_trainer.id,
        name="Treino A - Peito",
        day_of_week=1,
        is_active=True,
    )
    test_db_session.add(sheet)
    await test_db_session.commit()
    return student_user


# ---------------------------------------------------------------------------
# RF-43: Lista de alunos do personal
# ---------------------------------------------------------------------------


class TestListStudents:
    @pytest.mark.asyncio
    async def test_personal_lists_own_students(
        self, async_client_as, personal_trainer, student_with_sheet
    ):
        """Personal vê apenas seus alunos vinculados por ficha."""
        async with await async_client_as(personal_trainer) as client:
            resp = await client.get("/api/v1/dashboard/personal/students")

        assert resp.status_code == 200
        data = resp.json()
        assert data["total"] == 1
        assert data["data"][0]["student_id"] == str(student_with_sheet.id)

    @pytest.mark.asyncio
    async def test_personal_empty_list_no_students(
        self, async_client_as, other_personal, student_with_sheet
    ):
        """Personal sem alunos vinculados recebe lista vazia."""
        async with await async_client_as(other_personal) as client:
            resp = await client.get("/api/v1/dashboard/personal/students")

        assert resp.status_code == 200
        assert resp.json()["total"] == 0

    @pytest.mark.asyncio
    async def test_admin_sees_all_students(
        self, async_client_as, admin_user, student_with_sheet
    ):
        """Admin vê todos os alunos ativos da academia."""
        async with await async_client_as(admin_user) as client:
            resp = await client.get("/api/v1/dashboard/personal/students")

        assert resp.status_code == 200
        assert resp.json()["total"] >= 1

    @pytest.mark.asyncio
    async def test_client_blocked_403(
        self, async_client_as, student_user
    ):
        """Role 'client' não tem acesso ao dashboard."""
        async with await async_client_as(student_user) as client:
            resp = await client.get("/api/v1/dashboard/personal/students")

        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_filter_by_status_inactive(
        self, async_client_as, personal_trainer, student_with_sheet
    ):
        """Filtro status=inactive retorna apenas alunos sem treino recente."""
        async with await async_client_as(personal_trainer) as client:
            resp = await client.get(
                "/api/v1/dashboard/personal/students?status=inactive"
            )

        assert resp.status_code == 200
        data = resp.json()
        # Aluno sem treinos cadastrados deve ser 'inactive'
        for item in data["data"]:
            assert item["status"] == "inactive"

    @pytest.mark.asyncio
    async def test_pagination_params(
        self, async_client_as, admin_user, student_with_sheet
    ):
        """Pagination: page e limit funcionam corretamente."""
        async with await async_client_as(admin_user) as client:
            resp = await client.get(
                "/api/v1/dashboard/personal/students?page=1&limit=5"
            )

        assert resp.status_code == 200
        data = resp.json()
        assert data["page"] == 1
        assert data["limit"] == 5


# ---------------------------------------------------------------------------
# RF-44: Visão 360° do aluno
# ---------------------------------------------------------------------------


class TestStudent360:
    @pytest.mark.asyncio
    async def test_personal_views_own_student(
        self, async_client_as, personal_trainer, student_with_sheet
    ):
        """Personal visualiza 360° do próprio aluno."""
        async with await async_client_as(personal_trainer) as client:
            resp = await client.get(
                f"/api/v1/dashboard/students/{student_with_sheet.id}/360"
            )

        assert resp.status_code == 200
        data = resp.json()
        assert data["student_id"] == str(student_with_sheet.id)
        assert data["name"] == student_with_sheet.name
        assert "status" in data
        assert "adherence_percentage" in data
        assert "recent_workouts" in data
        assert "active_goals" in data

    @pytest.mark.asyncio
    async def test_personal_blocked_from_other_student(
        self, async_client_as, other_personal, student_with_sheet
    ):
        """Personal não pode ver aluno vinculado a outro personal."""
        async with await async_client_as(other_personal) as client:
            resp = await client.get(
                f"/api/v1/dashboard/students/{student_with_sheet.id}/360"
            )

        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_admin_views_any_student(
        self, async_client_as, admin_user, student_with_sheet
    ):
        """Admin pode ver 360° de qualquer aluno."""
        async with await async_client_as(admin_user) as client:
            resp = await client.get(
                f"/api/v1/dashboard/students/{student_with_sheet.id}/360"
            )

        assert resp.status_code == 200

    @pytest.mark.asyncio
    async def test_student_not_found_returns_404(
        self, async_client_as, admin_user
    ):
        """ID inexistente retorna 404."""
        fake_id = uuid4()
        async with await async_client_as(admin_user) as client:
            resp = await client.get(f"/api/v1/dashboard/students/{fake_id}/360")

        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_client_blocked_360(
        self, async_client_as, student_user, student_with_sheet
    ):
        """Client não acessa visão 360°."""
        async with await async_client_as(student_user) as client:
            resp = await client.get(
                f"/api/v1/dashboard/students/{student_with_sheet.id}/360"
            )

        assert resp.status_code == 403


# ---------------------------------------------------------------------------
# RF-46: Admin Overview
# ---------------------------------------------------------------------------


class TestAdminOverview:
    @pytest.mark.asyncio
    async def test_admin_can_access_overview(
        self, async_client_as, admin_user
    ):
        """Admin acessa overview com métricas globais."""
        async with await async_client_as(admin_user) as client:
            resp = await client.get("/api/v1/dashboard/admin/overview")

        assert resp.status_code == 200
        data = resp.json()
        assert "total_active_students" in data
        assert "dau" in data
        assert "mau" in data
        assert "global_adherence_avg" in data
        assert "students_engaged" in data
        assert "students_at_risk" in data
        assert "students_inactive" in data

    @pytest.mark.asyncio
    async def test_personal_blocked_from_overview(
        self, async_client_as, personal_trainer
    ):
        """Personal trainer não tem acesso ao overview administrativo."""
        async with await async_client_as(personal_trainer) as client:
            resp = await client.get("/api/v1/dashboard/admin/overview")

        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_client_blocked_from_overview(
        self, async_client_as, student_user
    ):
        async with await async_client_as(student_user) as client:
            resp = await client.get("/api/v1/dashboard/admin/overview")

        assert resp.status_code == 403


# ---------------------------------------------------------------------------
# RF-48: Exportação de PDF
# ---------------------------------------------------------------------------


class TestPDFExport:
    @pytest.mark.asyncio
    async def test_pdf_export_returns_pdf_content_type(
        self, async_client_as, personal_trainer, student_with_sheet
    ):
        """PDF gerado retorna Content-Type correto e header de download."""
        async with await async_client_as(personal_trainer) as client:
            resp = await client.get(
                f"/api/v1/dashboard/export/pdf?student_id={student_with_sheet.id}"
            )

        assert resp.status_code == 200
        assert resp.headers["content-type"] == "application/pdf"
        assert "attachment" in resp.headers.get("content-disposition", "")
        assert len(resp.content) > 0

    @pytest.mark.asyncio
    async def test_pdf_export_student_not_found(
        self, async_client_as, admin_user
    ):
        fake_id = uuid4()
        async with await async_client_as(admin_user) as client:
            resp = await client.get(f"/api/v1/dashboard/export/pdf?student_id={fake_id}")

        assert resp.status_code == 404

    @pytest.mark.asyncio
    async def test_pdf_export_forbidden_for_other_personal(
        self, async_client_as, other_personal, student_with_sheet
    ):
        async with await async_client_as(other_personal) as client:
            resp = await client.get(
                f"/api/v1/dashboard/export/pdf?student_id={student_with_sheet.id}"
            )

        assert resp.status_code == 403

    @pytest.mark.asyncio
    async def test_client_blocked_from_pdf(
        self, async_client_as, student_user, student_with_sheet
    ):
        async with await async_client_as(student_user) as client:
            resp = await client.get(
                f"/api/v1/dashboard/export/pdf?student_id={student_with_sheet.id}"
            )

        assert resp.status_code == 403
