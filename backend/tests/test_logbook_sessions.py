"""
Testes de integração do módulo Logbook.

Cobertura dos 17 cenários descritos no PRD_LOGBOOK.md, seção 5.1.
Utiliza banco SQLite em memória + httpx async client.
"""

from datetime import datetime, timedelta
from uuid import uuid4

import pytest
import pytest_asyncio
from httpx import ASGITransport
import httpx
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker

import main as main_module
from main import app as fastapi_app
from app.config.database import get_db
from app.models.user import Base  # inclui logbook via import em conftest
import app.models.logbook  # noqa: F401 — garante tabelas no metadata

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

TEST_DATABASE_URL = "sqlite+aiosqlite:///:memory:"


@pytest_asyncio.fixture
async def test_engine_logbook():
    """Engine de teste com todas as tabelas (users + logbook)."""
    engine = create_async_engine(
        TEST_DATABASE_URL,
        echo=False,
        connect_args={"check_same_thread": False},
    )
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest_asyncio.fixture
async def test_db_logbook(test_engine_logbook):
    """Sessão de banco para testes de logbook."""
    session_factory = async_sessionmaker(
        test_engine_logbook,
        class_=AsyncSession,
        expire_on_commit=False,
        future=True,
    )
    async with session_factory() as session:
        yield session


@pytest_asyncio.fixture
async def async_client_logbook(test_db_logbook):
    """Cliente HTTP assíncrono com banco de teste injetado."""

    async def override_get_db():
        yield test_db_logbook

    fastapi_app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=fastapi_app)
    async with httpx.AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac
    fastapi_app.dependency_overrides.clear()


# IDs fixos para os testes
USER_ID = str(uuid4())
PERSONAL_ID = str(uuid4())
SHEET_ID = str(uuid4())
EXERCISE_ID = str(uuid4())
EXERCISE_ID_2 = str(uuid4())

STUDENT_HEADERS = {"X-User-Id": USER_ID, "X-User-Role": "client"}
PERSONAL_HEADERS = {"X-User-Id": PERSONAL_ID, "X-User-Role": "personal_trainer"}


def past_date(days: int = 1) -> str:
    """Retorna datetime ISO no passado."""
    return (datetime.utcnow() - timedelta(days=days)).isoformat()


# ---------------------------------------------------------------------------
# Teste 1: Criar sessão com sucesso
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_criar_sessao_sucesso(async_client_logbook):
    """Teste 1: POST /sessions cria sessão com status 'in_progress'."""
    response = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date()},
        headers=STUDENT_HEADERS,
    )
    assert response.status_code == 201
    data = response.json()
    assert data["status"] == "in_progress"
    assert data["user_id"] == USER_ID
    assert data["workout_sheet_id"] == SHEET_ID
    assert "id" in data
    assert data["session_exercises"] == []


# ---------------------------------------------------------------------------
# Teste 2: Não pode criar sessão se já existe em progresso
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_nao_criar_segunda_sessao_em_progresso(async_client_logbook):
    """Teste 2: Segunda sessão retorna 409 se já existe uma em progresso."""
    await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date()},
        headers=STUDENT_HEADERS,
    )
    response = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date(2)},
        headers=STUDENT_HEADERS,
    )
    assert response.status_code == 409
    assert "progresso" in response.json()["detail"].lower()


# ---------------------------------------------------------------------------
# Teste 3: Adicionar exercício à sessão
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_adicionar_exercicio_sessao(async_client_logbook):
    """Teste 3: Adicionar exercício retorna 200 com dados completos."""
    r_session = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date()},
        headers=STUDENT_HEADERS,
    )
    session_id = r_session.json()["id"]

    response = await async_client_logbook.post(
        f"/api/v1/logbook/sessions/{session_id}/exercises",
        json={
            "exercise_id": EXERCISE_ID,
            "actual_series": 4,
            "actual_repetitions": 8,
            "actual_load_kg": 80.0,
            "status": "completed",
        },
        headers=STUDENT_HEADERS,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["exercise_id"] == EXERCISE_ID
    assert data["actual_series"] == 4
    assert data["actual_repetitions"] == 8
    assert data["actual_load_kg"] == 80.0


# ---------------------------------------------------------------------------
# Teste 4: Atualizar exercício (upsert)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_atualizar_exercicio_upsert(async_client_logbook):
    """Teste 4: Re-enviar exercise_id já existente atualiza em vez de duplicar."""
    r_session = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date()},
        headers=STUDENT_HEADERS,
    )
    session_id = r_session.json()["id"]

    # Primeiro registro
    await async_client_logbook.post(
        f"/api/v1/logbook/sessions/{session_id}/exercises",
        json={"exercise_id": EXERCISE_ID, "actual_series": 3, "actual_repetitions": 10, "actual_load_kg": 70.0, "status": "completed"},
        headers=STUDENT_HEADERS,
    )

    # Segundo envio com mesmo exercise_id → deve atualizar
    response = await async_client_logbook.post(
        f"/api/v1/logbook/sessions/{session_id}/exercises",
        json={"exercise_id": EXERCISE_ID, "actual_series": 4, "actual_repetitions": 8, "actual_load_kg": 75.0, "status": "completed"},
        headers=STUDENT_HEADERS,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["actual_series"] == 4
    assert data["actual_load_kg"] == 75.0

    # Verificar que existe apenas 1 exercício na sessão
    r_get = await async_client_logbook.get(
        f"/api/v1/logbook/sessions/{session_id}",
        headers=STUDENT_HEADERS,
    )
    assert len(r_get.json()["session_exercises"]) == 1


# ---------------------------------------------------------------------------
# Teste 5: Finalizar sessão com sucesso
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_finalizar_sessao_sucesso(async_client_logbook):
    """Teste 5: PUT /sessions/{id} com status=completed finaliza sessão."""
    r_session = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date()},
        headers=STUDENT_HEADERS,
    )
    session_id = r_session.json()["id"]

    await async_client_logbook.post(
        f"/api/v1/logbook/sessions/{session_id}/exercises",
        json={"exercise_id": EXERCISE_ID, "actual_series": 3, "actual_repetitions": 10, "actual_load_kg": 60.0, "status": "completed"},
        headers=STUDENT_HEADERS,
    )

    response = await async_client_logbook.put(
        f"/api/v1/logbook/sessions/{session_id}",
        json={"status": "completed", "general_notes": "Treino ótimo", "difficulty_level": 7, "mood": "great"},
        headers=STUDENT_HEADERS,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "completed"
    assert data["completed_at"] is not None
    assert data["general_notes"] == "Treino ótimo"
    assert data["difficulty_level"] == 7
    assert data["mood"] == "great"


# ---------------------------------------------------------------------------
# Teste 6: Não pode finalizar sessão sem exercícios
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_nao_finalizar_sessao_sem_exercicios(async_client_logbook):
    """Teste 6: Sessão vazia não pode ser completada."""
    r_session = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date()},
        headers=STUDENT_HEADERS,
    )
    session_id = r_session.json()["id"]

    response = await async_client_logbook.put(
        f"/api/v1/logbook/sessions/{session_id}",
        json={"status": "completed"},
        headers=STUDENT_HEADERS,
    )
    assert response.status_code == 422
    assert "exercício" in response.json()["detail"].lower()


# ---------------------------------------------------------------------------
# Teste 7: Listar sessões com paginação
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_listar_sessoes_paginacao(async_client_logbook):
    """Teste 7: Listar sessões retorna paginação correta."""
    # Criar 3 sessões (em datas diferentes)
    other_user = str(uuid4())
    headers = {"X-User-Id": other_user, "X-User-Role": "client"}

    for i in range(3):
        await async_client_logbook.post(
            "/api/v1/logbook/sessions",
            json={"workout_sheet_id": SHEET_ID, "session_date": past_date(i + 1)},
            headers=headers,
        )
        # Finalizar para poder criar a próxima
        r_list = await async_client_logbook.get(
            "/api/v1/logbook/sessions",
            headers=headers,
        )
        sessions = r_list.json()["data"]
        if sessions:
            in_progress = [s for s in sessions if s["status"] == "in_progress"]
            if in_progress:
                sid = in_progress[0]["id"]
                await async_client_logbook.post(
                    f"/api/v1/logbook/sessions/{sid}/exercises",
                    json={"exercise_id": EXERCISE_ID, "actual_series": 3, "actual_repetitions": 10, "actual_load_kg": 60.0, "status": "completed"},
                    headers=headers,
                )
                await async_client_logbook.put(
                    f"/api/v1/logbook/sessions/{sid}",
                    json={"status": "completed"},
                    headers=headers,
                )

    response = await async_client_logbook.get(
        "/api/v1/logbook/sessions?page=1&limit=2",
        headers=headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total"] >= 1
    assert data["page"] == 1
    assert data["limit"] == 2
    assert "data" in data


# ---------------------------------------------------------------------------
# Teste 8: Filtrar sessões por período
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_filtrar_sessoes_por_periodo(async_client_logbook):
    """Teste 8: Filtro por start_date e end_date retorna só sessões do período."""
    u = str(uuid4())
    h = {"X-User-Id": u, "X-User-Role": "client"}

    await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date(30)},
        headers=h,
    )

    today = datetime.utcnow()
    start = (today - timedelta(days=40)).isoformat()
    end = (today - timedelta(days=20)).isoformat()

    response = await async_client_logbook.get(
        f"/api/v1/logbook/sessions?start_date={start}&end_date={end}",
        headers=h,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["total"] >= 1
    for item in data["data"]:
        session_dt = datetime.fromisoformat(item["session_date"])
        assert session_dt >= datetime.fromisoformat(start)
        assert session_dt <= datetime.fromisoformat(end)


# ---------------------------------------------------------------------------
# Teste 9: Buscar sessão específica com exercícios
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_buscar_sessao_com_exercicios(async_client_logbook):
    """Teste 9: GET /sessions/{id} retorna sessão com exercícios."""
    u = str(uuid4())
    h = {"X-User-Id": u, "X-User-Role": "client"}

    r_session = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date()},
        headers=h,
    )
    session_id = r_session.json()["id"]

    await async_client_logbook.post(
        f"/api/v1/logbook/sessions/{session_id}/exercises",
        json={"exercise_id": EXERCISE_ID, "actual_series": 3, "actual_repetitions": 12, "actual_load_kg": 50.0, "status": "completed"},
        headers=h,
    )

    response = await async_client_logbook.get(
        f"/api/v1/logbook/sessions/{session_id}",
        headers=h,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == session_id
    assert len(data["session_exercises"]) == 1
    ex = data["session_exercises"][0]
    assert ex["actual_series"] == 3
    assert ex["actual_load_kg"] == 50.0


# ---------------------------------------------------------------------------
# Teste 10: Visualizar calendário do mês
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_calendario_mensal(async_client_logbook):
    """Teste 10: GET /calendar retorna dias com status e summary."""
    u = str(uuid4())
    h = {"X-User-Id": u, "X-User-Role": "client"}

    now = datetime.utcnow()
    await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={
            "workout_sheet_id": SHEET_ID,
            "session_date": datetime(now.year, now.month, 1, 10).isoformat(),
        },
        headers=h,
    )

    response = await async_client_logbook.get(
        f"/api/v1/logbook/calendar?year={now.year}&month={now.month}",
        headers=h,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["year"] == now.year
    assert data["month"] == now.month
    assert "days" in data
    assert "summary" in data
    assert len(data["days"]) >= 28
    statuses = {d["status"] for d in data["days"]}
    assert statuses.issubset({"completed", "incomplete", "skipped", "no_plan", "in_progress"})


# ---------------------------------------------------------------------------
# Teste 11: Progressão de exercício
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_progressao_exercicio(async_client_logbook):
    """Teste 11: GET /progression/{exercise_id} retorna evolução de carga."""
    u = str(uuid4())
    h = {"X-User-Id": u, "X-User-Role": "client"}

    loads = [60.0, 65.0, 70.0]
    for i, load in enumerate(loads):
        r_s = await async_client_logbook.post(
            "/api/v1/logbook/sessions",
            json={"workout_sheet_id": SHEET_ID, "session_date": past_date(10 - i * 3)},
            headers=h,
        )
        sid = r_s.json()["id"]
        await async_client_logbook.post(
            f"/api/v1/logbook/sessions/{sid}/exercises",
            json={"exercise_id": EXERCISE_ID, "actual_series": 3, "actual_repetitions": 10, "actual_load_kg": load, "status": "completed"},
            headers=h,
        )
        await async_client_logbook.put(
            f"/api/v1/logbook/sessions/{sid}",
            json={"status": "completed"},
            headers=h,
        )

    response = await async_client_logbook.get(
        f"/api/v1/logbook/progression/{EXERCISE_ID}?weeks=12",
        headers=h,
    )
    assert response.status_code == 200
    data = response.json()
    assert data["exercise_id"] == EXERCISE_ID
    assert len(data["data_points"]) == 3
    assert data["statistics"]["trend"] == "increasing"
    assert data["statistics"]["max_load_kg"] == 70.0
    assert data["statistics"]["min_load_kg"] == 60.0


# ---------------------------------------------------------------------------
# Teste 12: Controle de acesso — Aluno vs Personal
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_controle_acesso_aluno_vs_personal(async_client_logbook):
    """Teste 12: Personal pode ler mas não editar sessão do aluno."""
    u = str(uuid4())
    p = str(uuid4())
    h_aluno = {"X-User-Id": u, "X-User-Role": "client"}
    h_personal = {"X-User-Id": p, "X-User-Role": "personal_trainer"}

    r_session = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date()},
        headers=h_aluno,
    )
    session_id = r_session.json()["id"]

    # Personal pode ler (GET)
    r_get = await async_client_logbook.get(
        f"/api/v1/logbook/sessions/{session_id}",
        headers=h_personal,
    )
    assert r_get.status_code == 200

    # Personal NÃO pode editar (PUT) — deve retornar 403
    r_put = await async_client_logbook.put(
        f"/api/v1/logbook/sessions/{session_id}",
        json={"general_notes": "Editando como personal"},
        headers=h_personal,
    )
    assert r_put.status_code == 403

    # Personal NÃO pode deletar — deve retornar 403
    r_del = await async_client_logbook.delete(
        f"/api/v1/logbook/sessions/{session_id}",
        headers=h_personal,
    )
    assert r_del.status_code == 403


# ---------------------------------------------------------------------------
# Teste 13: Deletar sessão (soft delete)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_soft_delete_sessao(async_client_logbook):
    """Teste 13: DELETE marca sessão como deletada; GET retorna 404."""
    u = str(uuid4())
    h = {"X-User-Id": u, "X-User-Role": "client"}

    r_session = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date()},
        headers=h,
    )
    session_id = r_session.json()["id"]

    # Adicionar exercício e finalizar
    await async_client_logbook.post(
        f"/api/v1/logbook/sessions/{session_id}/exercises",
        json={"exercise_id": EXERCISE_ID, "actual_series": 3, "actual_repetitions": 10, "actual_load_kg": 60.0, "status": "completed"},
        headers=h,
    )
    await async_client_logbook.put(
        f"/api/v1/logbook/sessions/{session_id}",
        json={"status": "completed"},
        headers=h,
    )

    # Soft delete
    r_del = await async_client_logbook.delete(
        f"/api/v1/logbook/sessions/{session_id}",
        headers=h,
    )
    assert r_del.status_code == 204

    # GET deve retornar 404
    r_get = await async_client_logbook.get(
        f"/api/v1/logbook/sessions/{session_id}",
        headers=h,
    )
    assert r_get.status_code == 404


# ---------------------------------------------------------------------------
# Teste 14: Validação de dados
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_validacao_dados_invalidos(async_client_logbook):
    """Teste 14: Dados inválidos retornam 422."""
    u = str(uuid4())
    h = {"X-User-Id": u, "X-User-Role": "client"}

    r_session = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date()},
        headers=h,
    )
    session_id = r_session.json()["id"]

    # Série = 0 → erro
    r = await async_client_logbook.post(
        f"/api/v1/logbook/sessions/{session_id}/exercises",
        json={"exercise_id": EXERCISE_ID, "actual_series": 0, "actual_repetitions": 10, "actual_load_kg": 60.0, "status": "completed"},
        headers=h,
    )
    assert r.status_code == 422

    # Carga negativa → erro
    r = await async_client_logbook.post(
        f"/api/v1/logbook/sessions/{session_id}/exercises",
        json={"exercise_id": EXERCISE_ID, "actual_series": 3, "actual_repetitions": 10, "actual_load_kg": -10.0, "status": "completed"},
        headers=h,
    )
    assert r.status_code == 422

    # Mood inválido → erro
    r = await async_client_logbook.put(
        f"/api/v1/logbook/sessions/{session_id}",
        json={"mood": "super_happy"},
        headers=h,
    )
    assert r.status_code == 422

    # session_date futura → erro
    future = (datetime.utcnow() + timedelta(days=1)).isoformat()
    r = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": future},
        headers=h,
    )
    assert r.status_code == 422


# ---------------------------------------------------------------------------
# Teste 15: Dor/Incômodo — description obrigatória
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_dor_sem_description_retorna_422(async_client_logbook):
    """Teste 15: pain_or_discomfort=True sem description → 422."""
    u = str(uuid4())
    h = {"X-User-Id": u, "X-User-Role": "client"}

    r_session = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date()},
        headers=h,
    )
    session_id = r_session.json()["id"]

    # Sem description → deve falhar
    r = await async_client_logbook.post(
        f"/api/v1/logbook/sessions/{session_id}/exercises",
        json={"exercise_id": EXERCISE_ID, "actual_series": 3, "actual_repetitions": 10, "actual_load_kg": 60.0, "status": "completed", "pain_or_discomfort": True},
        headers=h,
    )
    assert r.status_code == 422

    # Com description → deve funcionar
    r2 = await async_client_logbook.post(
        f"/api/v1/logbook/sessions/{session_id}/exercises",
        json={"exercise_id": EXERCISE_ID, "actual_series": 3, "actual_repetitions": 10, "actual_load_kg": 60.0, "status": "completed", "pain_or_discomfort": True, "pain_description": "Dor no ombro"},
        headers=h,
    )
    assert r2.status_code == 200
    assert r2.json()["pain_or_discomfort"] is True


# ---------------------------------------------------------------------------
# Teste 16: Múltiplos exercícios em uma sessão
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_multiplos_exercicios_sessao(async_client_logbook):
    """Teste 16: Adicionar 5 exercícios diferentes e buscar todos."""
    u = str(uuid4())
    h = {"X-User-Id": u, "X-User-Role": "client"}

    r_session = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date()},
        headers=h,
    )
    session_id = r_session.json()["id"]

    exercise_ids = [str(uuid4()) for _ in range(5)]
    for eid in exercise_ids:
        await async_client_logbook.post(
            f"/api/v1/logbook/sessions/{session_id}/exercises",
            json={"exercise_id": eid, "actual_series": 3, "actual_repetitions": 10, "actual_load_kg": 50.0, "status": "completed"},
            headers=h,
        )

    r_get = await async_client_logbook.get(
        f"/api/v1/logbook/sessions/{session_id}",
        headers=h,
    )
    assert r_get.status_code == 200
    data = r_get.json()
    assert len(data["session_exercises"]) == 5


# ---------------------------------------------------------------------------
# Teste 17: Series details (JSON por série)
# ---------------------------------------------------------------------------


@pytest.mark.asyncio
async def test_series_details(async_client_logbook):
    """Teste 17: Exercício com series_details armazena e retorna corretamente."""
    u = str(uuid4())
    h = {"X-User-Id": u, "X-User-Role": "client"}

    r_session = await async_client_logbook.post(
        "/api/v1/logbook/sessions",
        json={"workout_sheet_id": SHEET_ID, "session_date": past_date()},
        headers=h,
    )
    session_id = r_session.json()["id"]

    series_details = [
        {"series": 1, "reps": 8, "load": 80},
        {"series": 2, "reps": 8, "load": 80},
        {"series": 3, "reps": 6, "load": 85},
    ]

    r = await async_client_logbook.post(
        f"/api/v1/logbook/sessions/{session_id}/exercises",
        json={
            "exercise_id": EXERCISE_ID,
            "actual_series": 3,
            "actual_repetitions": 8,
            "actual_load_kg": 80.0,
            "series_details": series_details,
            "status": "completed",
        },
        headers=h,
    )
    assert r.status_code == 200
    data = r.json()
    assert data["series_details"] is not None
    assert len(data["series_details"]) == 3
    assert data["series_details"][2]["load"] == 85
