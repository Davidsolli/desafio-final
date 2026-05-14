"""Testes de integração para o módulo de dados de saúde (FC + calorias)."""

from datetime import date, datetime, timezone

import pytest


SYNC_URL = "/api/v1/health/sync"
SUMMARY_URL = "/api/v1/health/summary"

TODAY = date.today().isoformat()

SAMPLE_PAYLOAD = {
    "date": TODAY,
    "active_calories": 350.5,
    "total_calories": 2100.0,
    "heart_rate_readings": [
        {"measured_at": f"{TODAY}T08:30:00Z", "bpm": 72},
        {"measured_at": f"{TODAY}T12:00:00Z", "bpm": 85},
        {"measured_at": f"{TODAY}T18:00:00Z", "bpm": 95},
    ],
}


class TestHealthSync:
    """Testes do endpoint POST /health/sync."""

    @pytest.mark.asyncio
    async def test_sync_requer_autenticacao(self, async_client):
        """Teste 1: Sem token retorna 401."""
        response = await async_client.post(SYNC_URL, json=SAMPLE_PAYLOAD)
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_sync_sucesso(self, auth_client, sample_user):
        """Teste 2: Sync bem-sucedido retorna 200 com confirmação."""
        response = await auth_client.post(SYNC_URL, json=SAMPLE_PAYLOAD)
        assert response.status_code == 200

        data = response.json()
        assert data["success"] is True
        assert data["heart_rate_samples_saved"] == 3
        assert data["date"] == TODAY

    @pytest.mark.asyncio
    async def test_sync_sem_frequencia_cardiaca(self, auth_client, sample_user):
        """Teste 3: Sync apenas com calorias (sem amostras de FC) é aceito."""
        payload = {
            "date": TODAY,
            "active_calories": 200.0,
            "total_calories": 1800.0,
            "heart_rate_readings": [],
        }
        response = await auth_client.post(SYNC_URL, json=payload)
        assert response.status_code == 200

        data = response.json()
        assert data["success"] is True
        assert data["heart_rate_samples_saved"] == 0

    @pytest.mark.asyncio
    async def test_sync_idempotente(self, auth_client, sample_user):
        """Teste 4: Enviar as mesmas amostras duas vezes não duplica os dados."""
        # Primeiro sync
        resp1 = await auth_client.post(SYNC_URL, json=SAMPLE_PAYLOAD)
        assert resp1.status_code == 200
        saved_first = resp1.json()["heart_rate_samples_saved"]

        # Segundo sync com os mesmos dados
        resp2 = await auth_client.post(SYNC_URL, json=SAMPLE_PAYLOAD)
        assert resp2.status_code == 200
        saved_second = resp2.json()["heart_rate_samples_saved"]

        assert saved_first == 3
        assert saved_second == 0  # Já existiam, nenhuma nova inserção

    @pytest.mark.asyncio
    async def test_sync_bpm_invalido_retorna_422(self, auth_client, sample_user):
        """Teste 5: BPM fora do intervalo (1–350) retorna 422."""
        payload = {
            "date": TODAY,
            "active_calories": 100.0,
            "total_calories": 1500.0,
            "heart_rate_readings": [
                {"measured_at": "2026-05-13T08:30:00Z", "bpm": 0},
            ],
        }
        response = await auth_client.post(SYNC_URL, json=payload)
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_sync_calorias_negativas_retorna_422(self, auth_client, sample_user):
        """Teste 6: Calorias negativas retornam 422."""
        payload = {
            "date": TODAY,
            "active_calories": -50.0,
            "total_calories": 1500.0,
            "heart_rate_readings": [],
        }
        response = await auth_client.post(SYNC_URL, json=payload)
        assert response.status_code == 422


class TestHealthSummary:
    """Testes do endpoint GET /health/summary."""

    @pytest.mark.asyncio
    async def test_summary_requer_autenticacao(self, async_client):
        """Teste 7: Sem token retorna 401."""
        response = await async_client.get(SUMMARY_URL)
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_summary_dia_sem_dados(self, auth_client, sample_user):
        """Teste 8: Dia sem dados retorna zeros, não erro."""
        response = await auth_client.get(SUMMARY_URL, params={"date": "2020-01-01"})
        assert response.status_code == 200

        data = response.json()
        assert data["average_heart_rate_bpm"] == 0.0
        assert data["active_calories"] == 0.0
        assert data["heart_rate_samples"] == 0

    @pytest.mark.asyncio
    async def test_summary_apos_sync(self, auth_client, sample_user):
        """Teste 9: Após sync, summary reflete os dados enviados."""
        await auth_client.post(SYNC_URL, json=SAMPLE_PAYLOAD)

        response = await auth_client.get(SUMMARY_URL, params={"date": TODAY})
        assert response.status_code == 200

        data = response.json()
        assert data["heart_rate_samples"] == 3
        assert data["average_heart_rate_bpm"] > 0
        assert data["active_calories"] == pytest.approx(350.5, abs=0.1)
        assert data["total_calories"] == pytest.approx(2100.0, abs=0.1)

    @pytest.mark.asyncio
    async def test_isolamento_entre_usuarios(
        self, async_client_as, sample_user, sample_personal_trainer
    ):
        """Teste 10: Dados de um usuário não aparecem no summary de outro."""
        # Usuário A faz sync
        async with await async_client_as(sample_user) as client_a:
            resp = await client_a.post(SYNC_URL, json=SAMPLE_PAYLOAD)
            assert resp.status_code == 200

        # Usuário B consulta summary do mesmo dia
        async with await async_client_as(sample_personal_trainer) as client_b:
            resp = await client_b.get(SUMMARY_URL, params={"date": TODAY})
            assert resp.status_code == 200
            data = resp.json()
            assert data["heart_rate_samples"] == 0
            assert data["active_calories"] == 0.0
