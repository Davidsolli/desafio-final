# Auditoria de Testes do Chatbot

**Data:** 2026-05-09
**Branch:** `refactor/chatbot-completo`
**Etapa:** 1 — Backend Core
**Documento de referência:** `PRD_CHATBOT_REFACTOR_ETAPA1.md` seção 3.3

## 📊 Inventário Inicial

| Arquivo | Tests | Classes |
|--------|------|---------|
| `tests/test_chat_service.py` | 30 | 7 |
| `tests/test_chatbot_models.py` | 18 | 4 |
| `tests/test_rag_chain.py` | 26 | 7 |
| `tests/test_chat_websocket.py` | 9 | 0 |
| **TOTAL** | **83** | **18** |

## ❌ Testes Quebrados (referenciam stack obsoleta Gemini)

Estes testes patcheiam classes inexistentes em `app.ai.rag_chain` (que hoje usa Groq + HuggingFace, não Gemini). Eles **falhariam imediatamente** se executados.

| # | Arquivo | Linha | Teste | Problema |
|---|--------|-------|-------|----------|
| 1 | `tests/test_rag_chain.py` | 91-100 | `TestLazyInit::test_get_embeddings_creates_once` | `@patch("app.ai.rag_chain.GoogleGenerativeAIEmbeddings")` → atributo inexistente |
| 2 | `tests/test_rag_chain.py` | 102-114 | `TestLazyInit::test_get_llm_creates_once` | `@patch("app.ai.rag_chain.ChatGoogleGenerativeAI")` → atributo inexistente |

**Ação:** Removidos. Serão substituídos por novos testes (lazy init de `HuggingFaceEmbeddings` e `ChatGroq`) na fase RED.

## 🔄 Dados de Fixtures Desatualizados

Valores de `model_used="gemini-1.5-flash"` e dimensões de embedding `768` (Gemini) ainda aparecem em fixtures e mocks. A stack atual usa **Groq + Llama 3.3 70B Versatile** e embeddings de **384 dims** (`all-MiniLM-L6-v2`).

| Arquivo | Linhas | Conteúdo desatualizado |
|---------|-------|------------------------|
| `tests/test_chat_service.py` | 108 | `model_used="gemini-1.5-flash"` → `"llama-3.3-70b-versatile"` |
| `tests/test_chat_service.py` | 657 | `[0.1] * 768` → `[0.1] * 384` |
| `tests/test_chatbot_models.py` | 92 | `embedding_model="google:text-embedding-004"` → `"huggingface:all-MiniLM-L6-v2"` |
| `tests/test_chatbot_models.py` | 111 | `[0.1] * 768` → `[0.1] * 384` |
| `tests/test_chatbot_models.py` | 375, 388 | `"gemini-1.5-flash"` → `"llama-3.3-70b-versatile"` |
| `tests/test_rag_chain.py` | 129, 163, 197, 210 | `[0.1] * 768` → `[0.1] * 384` |
| `tests/test_rag_chain.py` | 429, 442, 509 | `"gemini-1.5-flash"` → `"llama-3.3-70b-versatile"` |

**Ação:** Atualizar valores literais (são apenas dados de fixture/mock, não lógica de teste). Esta atualização **não viola RT-03** (proibido modificar teste para fazer código passar) — o código já espera estes valores; a fixture é que estava desatualizada.

## 🟢 Testes Sem Necessidade de Mudança

Os demais testes estão alinhados com a stack atual e cobrem regras de negócio relevantes (RN-02, RN-05, RN-06, RN-07, RN-12, RN-16, RN-17, RN-18, RN-21, RN-23). Mantêm-se **sem alteração**.

## 🆕 Lacunas Identificadas (a cobrir na fase RED)

Mapeamento dos novos testes (PRD Etapa 1, seção 3.4) que **ainda não existem**:

### Card 18 — Escolha do LLM
- `test_llm_provider_is_configured`
- `test_llm_model_supports_portuguese`
- `test_llm_latency_under_2_seconds`

### Card 18.1 — Serviço de integração com IA
- `test_rag_chain_is_centralized_singleton`
- `test_rag_chain_handles_api_timeout`
- `test_rag_chain_fallback_on_unavailability`
- `test_rag_chain_is_isolated_from_other_layers`

### Card 18.2 — Endpoint de chatbot
- `test_send_message_endpoint_returns_200`
- `test_send_message_requires_authentication`
- `test_send_message_handles_ai_failure`

### Card 18.3 — Contexto mínimo do aluno (CRÍTICO — atualmente ausente)
- `test_context_includes_user_profile`
- `test_context_includes_active_workout_sheet` (atualmente sempre `None`)
- `test_context_includes_active_goals`
- `test_context_includes_recent_history`
- `test_context_is_optimized_size`
- `test_context_respects_user_privacy`

### Card 18.4–18.6 — Domínios (treino, execução, nutrição)
- `test_chatbot_uses_active_sheet_context`
- `test_chatbot_rejects_out_of_scope_training`
- `test_chatbot_avoids_medical_recommendations`

### Cards 19.3–19.8 — RAG Pipeline
- `test_embeddings_generated_from_text` (HuggingFace, 384 dims)
- `test_pipeline_integrates_search_and_generation`
- `test_context_uses_real_student_data`

### Performance (Card 18 + 19.5)
- `test_chat_response_under_2_seconds`
- `test_embedding_warm_up_on_init`

### WebSocket Streaming (Tarefa 7 do PRD)
- `test_websocket_sends_status_thinking`
- `test_websocket_sends_status_searching`
- `test_websocket_sends_status_generating`
- `test_websocket_sends_response_after_status`

### Validação (Tarefa 8 — corrigir lógica confusa)
- `test_validation_no_invalid_state_after_success`
- `test_validation_does_not_double_escalate`

### FAQ Service (Tarefa 5)
- `test_faq_service_loaded_independently`
- `test_faq_service_returns_response_for_known_question`
- `test_faq_service_returns_none_for_unknown_question`
- `test_rag_chain_does_not_have_inline_faq`

## ✅ Resumo da Auditoria

- **2 testes removidos** (quebrados — Gemini patches inexistentes)
- **9 fixtures atualizadas** (valores literais de modelo/dimensão)
- **30+ testes a criar** na fase RED para cumprir critérios de aceite

A suíte consolidada terá ~110 testes ao final, todos alinhados com a stack Groq + HuggingFace + pgvector.
