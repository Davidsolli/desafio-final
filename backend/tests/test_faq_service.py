"""
Testes do FAQ Service (Tarefa 5 do PRD_CHATBOT_REFACTOR_ETAPA1).

Valida:
- O serviço de FAQ é uma camada dedicada (separada do RAGChain)
- Retorna respostas para perguntas conhecidas (horário, toalhas, mensalidade...)
- Retorna None para perguntas desconhecidas
- O RAGChain NÃO contém mais a lista hardcoded de regras de FAQ
"""

from __future__ import annotations

import inspect

import pytest

from app.ai import rag_chain as rag_chain_module


class TestFAQServiceContract:
    """O FAQService deve estar disponível como módulo separado e ter API esperada."""

    def test_faq_service_module_exists(self):
        """app/services/faq_service.py deve existir."""
        from importlib import import_module

        try:
            mod = import_module("app.services.faq_service")
        except ModuleNotFoundError as exc:
            pytest.fail(f"Módulo app.services.faq_service não encontrado: {exc}")

        assert hasattr(mod, "FAQService"), "Classe FAQService deve estar exportada"

    def test_faq_service_has_match_method(self):
        """FAQService deve expor método match(query) -> str | None."""
        from app.services.faq_service import FAQService

        service = FAQService()
        assert hasattr(service, "match")
        sig = inspect.signature(service.match)
        assert "query" in sig.parameters


class TestFAQResponses:
    """O FAQService deve cobrir as perguntas frequentes operacionais."""

    @pytest.fixture
    def faq(self):
        from app.services.faq_service import FAQService

        return FAQService()

    def test_faq_returns_response_for_schedule(self, faq):
        result = faq.match("Qual o horário da academia?")
        assert result is not None
        assert "06:00" in result or "06h" in result.lower()

    def test_faq_returns_response_for_towels(self, faq):
        result = faq.match("vocês fornecem toalha?")
        assert result is not None
        assert "toalha" in result.lower()

    def test_faq_returns_response_for_assessment_booking(self, faq):
        result = faq.match("como agendo minha avaliação física?")
        assert result is not None
        assert "avalia" in result.lower()

    def test_faq_returns_response_for_workouts_listing(self, faq):
        result = faq.match("onde encontro meu treino de hoje?")
        assert result is not None
        assert "treino" in result.lower()

    def test_faq_returns_response_for_payment(self, faq):
        result = faq.match("como vejo a mensalidade?")
        assert result is not None
        assert "mensalidade" in result.lower() or "assinatura" in result.lower()

    def test_faq_returns_response_for_wifi(self, faq):
        result = faq.match("qual a senha do wi-fi?")
        assert result is not None
        assert "wi-fi" in result.lower() or "wifi" in result.lower()

    def test_faq_returns_response_for_cancellation(self, faq):
        result = faq.match("como cancelo minha matrícula?")
        assert result is not None
        assert "cancel" in result.lower() or "trancar" in result.lower()

    def test_faq_returns_none_for_unknown_question(self, faq):
        """Pergunta fora do escopo do FAQ deve retornar None (cai no RAG)."""
        result = faq.match("explique a teoria das supercordas")
        assert result is None

    def test_faq_returns_none_for_empty_query(self, faq):
        result = faq.match("")
        assert result is None


class TestRAGChainNoLongerHasInlineFAQ:
    """Tarefa 5: rag_chain.py NÃO deve mais conter regras hardcoded de FAQ."""

    def test_rag_chain_module_has_no_inline_faq_rules(self):
        """O nome 'faq_rules' não deve aparecer como variável local em rag_chain.py."""
        source = inspect.getsource(rag_chain_module)
        # Permitimos comentários sobre 'FAQ' (referência conceitual), mas não a estrutura inline
        assert "faq_rules = [" not in source, (
            "rag_chain.py deve usar app.services.faq_service em vez de definir 'faq_rules' inline"
        )

    def test_rag_chain_imports_faq_service(self):
        """rag_chain.py deve usar (importar ou referenciar) o FAQService."""
        source = inspect.getsource(rag_chain_module)
        assert "faq_service" in source.lower() or "FAQService" in source, (
            "rag_chain.py deve consumir FAQService"
        )
