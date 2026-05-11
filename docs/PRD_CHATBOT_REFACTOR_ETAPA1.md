# PRD: Refatoração do Chatbot — Etapa 1: Backend Core

**Versão:** 1.0  
**Data:** 2026-05-09  
**Status:** 📋 Pronto para Implementação  
**Escopo:** Cards 18, 18.1, 18.2, 18.3, 18.4, 18.5, 18.6 + 19.3, 19.4, 19.5, 19.6, 19.7, 19.8

---

## 📋 1. Visão Geral

### Objetivo

Refatorar a infraestrutura **backend** do chatbot para corrigir problemas de funcionamento, melhorar performance (latência ≤ 2s) e garantir cobertura de testes baseada nos critérios de aceite dos cards Trello.

### Problemas Identificados no Código Atual

| # | Problema | Arquivo | Impacto |
|---|---------|---------|---------|
| 1 | **Contexto do aluno incompleto** — `active_workout_sheet` sempre `None` | `chat_service.py:238` | Respostas genéricas |
| 2 | **Sem indicador de carregamento** — resposta aparece "de uma vez" | `chat.py` (WebSocket) | UX ruim |
| 3 | **FAQ hardcoded no RAG** — regras inline no `rag_chain.py:516-536` | `rag_chain.py` | Difícil manutenção |
| 4 | **Sem controller de chat** — rota chama service diretamente | `routes/chat.py` | Quebra padrão arquitetural |
| 5 | **Performance** — embedding HuggingFace local pode ser lento | `rag_chain.py:147-150` | Latência > 2s no cold start |
| 6 | **Lógica de validação confusa** — condições elif redundantes | `rag_chain.py:568-574` | Bugs silenciosos |
| 7 | **Divergência PRD vs código** — PRD antigo mencionava Gemini/768 dims, código já usa Groq/384 dims | `settings.py` vs `PRD_CHATBOT_DUVIDAS.md` | Inconsistência documental (resolvida neste PRD) |
| 8 | **Sem dados reais** — metas, histórico de treino ausentes do contexto | `chat_service.py:211-239` | Cards 18.3/19.8 não atendidos |

---

## 📐 2. Padrões Obrigatórios

### 2.1 LLM Definido (OBRIGATÓRIO — NÃO ALTERAR)

> [!IMPORTANT]
> O modelo de linguagem para o chatbot é **Groq + Llama 3.3 70B Versatile**. Esta decisão é **final** e não deve ser alterada durante a implementação.

| Componente | Tecnologia | Justificativa |
|-----------|-----------|---------------|
| **LLM (geração)** | **Groq** — `llama-3.3-70b-versatile` | Latência ~300-800ms (hardware LPU), free tier generoso, excelente em português |
| **Embeddings** | **HuggingFace** — `all-MiniLM-L6-v2` (384 dims) | Gratuito, roda local, dimensão adequada para RAG fitness |
| **Vector DB** | **PostgreSQL + pgvector** | Já integrado, busca coseno nativa |
| **Orquestração** | **LangChain** | Já integrado, modular, permite troca futura |
| **Backend** | **FastAPI + SQLAlchemy async** | Stack do projeto |
| **Testes** | **pytest + pytest-asyncio** | Stack do projeto |

**Configuração atual em `settings.py` (manter):**
```python
GROQ_API_KEY: str = ""                    # Chave da API Groq
GROQ_MODEL: str = "llama-3.3-70b-versatile"  # Modelo LLM
RAG_EMBEDDING_DIM: int = 384             # HuggingFace all-MiniLM-L6-v2
RAG_LLM_MAX_TOKENS: int = 500            # Max tokens na resposta
RAG_LLM_TEMPERATURE: float = 0.3         # Temperatura baixa para consistência
```

> [!WARNING]
> O PRD anterior (`PRD_CHATBOT_DUVIDAS.md`) mencionava Google Gemini e embeddings de 768 dims. Isso está **desatualizado**. O provedor correto é **Groq** com embeddings de **384 dims** conforme já implementado no código.

### 2.2 Arquivos de Referência (LEITURA OBRIGATÓRIA)

- [`BRANCH_STRATEGY.md`](../BRANCH_STRATEGY.md) — Git Flow
- [`CLAUDE.md`](../CLAUDE.md) — Instruções gerais, stack
- [`COMMIT_GUIDE.md`](../COMMIT_GUIDE.md) — Conventional Commits em português
- [`IA_WORKFLOW.md`](../IA_WORKFLOW.md) — Workflow de implementação

### 2.3 Arquitetura em Camadas

```
routes/ → controllers/ → services/ → repositories/ → models/
```

**Regra:** O módulo de chat DEVE ter um `chat_controller.py` (atualmente ausente).

### 2.3 Branch e Commits

```bash
git checkout -b refactor/chatbot-backend-core
# Commits: refactor(chatbot): <descrição imperativa em português>
```

---

## 🧪 3. Regras de TDD (CRÍTICO)

> [!CAUTION]
> Estas regras são **INVIOLÁVEIS**. Qualquer violação invalida a implementação.

### 3.1 Ordem de Implementação

```
1. PRIMEIRO → Criar/refatorar TESTES baseados nos critérios de aceite
2. SEGUNDO → Verificar que os testes FALHAM (red phase)
3. TERCEIRO → Implementar código até testes PASSAREM (green phase)
4. QUARTO → Refatorar mantendo testes passando (refactor phase)
```

### 3.2 Regras de Testes

| Regra | Descrição |
|-------|-----------|
| **RT-01** | Testes escritos ANTES do código de produção |
| **RT-02** | Critérios de aceite de cada card = requisitos dos testes |
| **RT-03** | **PROIBIDO** modificar teste para fazer código passar. Código deve ser corrigido |
| **RT-04** | Verificar e **REMOVER testes duplicados** existentes antes de criar novos |
| **RT-05** | Nome descritivo em inglês explicando O QUE é testado |
| **RT-06** | Mínimo **80% cobertura** para módulos de chatbot |
| **RT-07** | Testes independentes — sem depender de ordem |
| **RT-08** | Usar fixtures do `conftest.py` existente |

### 3.3 Verificação de Duplicados (Fazer PRIMEIRO)

```bash
grep -rn "def test_" tests/test_chat_service.py tests/test_chatbot_models.py tests/test_rag_chain.py tests/test_chat_websocket.py
# Identificar testes similares → consolidar → documentar remoções
```

### 3.4 Mapeamento Card → Testes

#### Card 18 — Escolha do LLM

```python
def test_llm_provider_is_configured():
    """Settings deve ter GROQ_API_KEY e GROQ_MODEL definidos."""
def test_llm_model_supports_portuguese():
    """LLM deve gerar respostas em português brasileiro."""
def test_llm_latency_under_2_seconds():
    """Resposta do LLM deve retornar em menos de 2 segundos."""
```

#### Card 18.1 — Serviço de integração com IA

```python
def test_rag_chain_is_centralized_singleton():
    """Deve existir instância singleton do RAGChain."""
def test_rag_chain_sends_prompts_correctly():
    """Pipeline deve enviar prompts estruturados ao provedor."""
def test_rag_chain_handles_api_timeout():
    """Deve tratar timeout com fallback seguro."""
def test_rag_chain_handles_api_error():
    """Deve tratar erros de API com mensagem padrão."""
def test_rag_chain_fallback_on_unavailability():
    """Deve retornar resposta fallback quando IA indisponível."""
def test_rag_chain_is_isolated_from_other_layers():
    """RAGChain não deve importar routes, controllers ou DTOs."""
```

#### Card 18.2 — Endpoint de chatbot

```python
def test_send_message_endpoint_returns_200():
    """POST /send-message deve retornar 200."""
def test_send_message_requires_authentication():
    """Deve exigir JWT válido."""
def test_send_message_identifies_user_correctly():
    """Resposta vinculada ao user_id do token."""
def test_send_message_supports_student_context():
    """Deve funcionar com role=client."""
def test_send_message_validates_input():
    """Deve rejeitar mensagens vazias ou muito longas."""
def test_send_message_structured_response():
    """Resposta deve conter message_id, conversation_id, content, latency_ms."""
def test_send_message_handles_ai_failure():
    """Deve retornar fallback se IA falhar."""
```

#### Card 18.3 — Contexto mínimo do aluno

```python
def test_context_includes_user_profile():
    """Contexto deve incluir nome, role, peso, altura, objetivo."""
def test_context_includes_active_workout_sheet():
    """Contexto deve incluir ficha de treino ativa (não None)."""
def test_context_includes_active_goals():
    """Contexto deve incluir metas em andamento."""
def test_context_includes_recent_history():
    """Contexto deve incluir histórico recente de atividades."""
def test_context_is_optimized_size():
    """Contexto não deve exceder limite de tokens."""
def test_context_respects_user_privacy():
    """Deve acessar apenas dados do usuário autenticado."""
```

#### Card 18.4 — Dúvidas sobre treino

```python
def test_chatbot_answers_training_questions():
    """Deve responder dúvidas sobre rotina de treino."""
def test_chatbot_uses_active_sheet_context():
    """Respostas devem referenciar ficha ativa."""
def test_chatbot_rejects_out_of_scope_training():
    """Deve recusar perguntas fora do contexto de treino."""
```

#### Card 18.5 — Execução de exercícios

```python
def test_chatbot_explains_exercise_execution():
    """Deve explicar como executar exercícios da ficha."""
def test_chatbot_interprets_exercise_names():
    """Deve interpretar nomes de exercícios."""
def test_chatbot_clarifies_trainer_notes():
    """Deve esclarecer observações do personal."""
```

#### Card 18.6 — Dúvidas nutricionais

```python
def test_chatbot_answers_basic_nutrition():
    """Deve responder dúvidas nutricionais básicas."""
def test_chatbot_avoids_medical_recommendations():
    """Não deve dar recomendações médicas."""
def test_chatbot_handles_out_of_scope_nutrition():
    """Deve tratar perguntas fora do escopo nutricional."""
```

#### Cards 19.3-19.8 — RAG Pipeline

```python
def test_embeddings_generated_from_text():
    """Textos convertidos em vetores de 384 dims."""
def test_vector_db_cosine_similarity_search():
    """Busca por similaridade coseno funciona."""
def test_vector_db_performance_adequate():
    """Consulta vetorial <500ms."""
def test_langchain_builds_prompts_dynamically():
    """LangChain monta prompts dinamicamente."""
def test_langchain_rag_flow_works():
    """Fluxo RAG completo funciona."""
def test_pipeline_integrates_search_and_generation():
    """Pipeline integra busca + geração."""
def test_chatbot_prioritizes_rag_over_generic():
    """Respostas priorizam RAG sobre genérico."""
def test_context_uses_real_student_data():
    """Deve usar dados reais do aluno."""
def test_context_no_sensitive_data_exposure():
    """Não deve expor dados sensíveis."""
```

---

## 🔧 4. Tarefas Ordenadas

### Tarefa 1: Auditoria e Limpeza de Testes

1. Analisar todos os `test_chat*.py` e `test_rag*.py`
2. Remover testes duplicados
3. Documentar remoções

```bash
git commit -m "test(chatbot): remover testes duplicados e consolidar suíte"
```

### Tarefa 2: Criar Testes (RED PHASE)

1. Escrever testes conforme mapeamento seção 3.4
2. Rodar testes — novos devem FALHAR
3. Existentes que passam → manter

```bash
git commit -m "test(chatbot): adicionar testes baseados em critérios de aceite"
```

### Tarefa 3: Criar `chat_controller.py`

Seguir padrão arquitetural: routes → **controller** → services.

```bash
git commit -m "refactor(chatbot): criar chat_controller seguindo padrão do projeto"
```

### Tarefa 4: Corrigir Contexto do Aluno (Cards 18.3 + 19.8)

Refatorar `_build_user_context` para buscar dados REAIS:

- Ficha de treino ativa via `workout_sheet_repository`
- Metas em andamento via `goal_repository`
- Histórico recente via `logbook_repository`
- Dieta ativa via `diet_repository`

```bash
git commit -m "feat(chatbot): integrar dados reais do aluno no contexto RAG"
```

### Tarefa 5: Extrair FAQ para Serviço Dedicado

1. Criar `app/services/faq_service.py`
2. Carregar FAQ do `docs/FAQ_KNOWLEDGE_BASE.md`
3. Remover FAQ inline do `rag_chain.py:516-536`

```bash
git commit -m "refactor(chatbot): extrair FAQ para serviço dedicado"
```

### Tarefa 6: Otimizar Performance (≤ 2s)

1. Warm-up do modelo de embeddings na inicialização
2. Cache de embeddings de FAQ
3. Timeout configurável (abortar se > 2s, retornar fallback)
4. Adicionar `CHAT_MAX_RESPONSE_LATENCY_MS: int = 2000` ao settings

```bash
git commit -m "perf(chatbot): otimizar latência para ≤2s"
```

### Tarefa 7: Streaming no WebSocket (UX)

Enviar mensagens de status intermediárias:

```python
# 1. Recebe mensagem
await ws.send_json({"type": "status", "status": "thinking", "message": "Analisando sua pergunta..."})
# 2. Retrieve
await ws.send_json({"type": "status", "status": "searching", "message": "Buscando na base de conhecimento..."})
# 3. Generate
await ws.send_json({"type": "status", "status": "generating", "message": "Preparando sua resposta..."})
# 4. Resposta final
await ws.send_json({"type": "response", ...})
```

```bash
git commit -m "feat(chatbot): adicionar feedback de status no WebSocket"
```

### Tarefa 8: Corrigir Validação pós-geração

Simplificar bloco confuso em `rag_chain.py:560-574`.

```bash
git commit -m "fix(chatbot): corrigir lógica de validação pós-geração"
```

### Tarefa 9: Atualizar System Prompt

Incluir instruções para domínios de treino (18.4), execução (18.5) e nutrição (18.6).

```bash
git commit -m "feat(chatbot): atualizar system prompt para domínios treino/nutrição"
```

### Tarefa 10: Validar (GREEN PHASE)

```bash
pytest tests/test_chat*.py tests/test_rag*.py -v --cov
# Todos passando, cobertura ≥ 80%
```

---

## ✅ 5. Definição de Pronto

- [ ] Testes duplicados removidos
- [ ] Todos os testes dos critérios de aceite criados
- [ ] `chat_controller.py` criado
- [ ] Contexto do aluno com dados REAIS (ficha, metas, histórico, dieta)
- [ ] FAQ extraído para serviço dedicado
- [ ] Latência ≤ 2s (95th percentile)
- [ ] WebSocket envia status intermediários
- [ ] Validação pós-geração corrigida
- [ ] System prompt atualizado para 3 domínios
- [ ] Cobertura ≥ 80%, nenhum teste modificado para fazer código passar
- [ ] Branch: `refactor/chatbot-backend-core`, PR contra `develop`

---

*Próxima etapa: PRD_CHATBOT_REFACTOR_ETAPA2.md — Frontend Flutter + Histórico + Aviso Ético*
