# PRD: Refatoração do Chatbot — Etapa 3: WhatsApp + Escalação + Knowledge Base

**Versão:** 2.0
**Data:** 2026-05-09
**Status:** 📋 Pronto para Implementação (Etapas 1 e 2 concluídas, develop mesclada na branch)
**Escopo:** Cards 18.8, 19, 19.1, 19.2, 19.10
**Dependência:** Etapas 1 e 2 concluídas. Branch `refactor/chatbot-completo` já contém merge da `develop`.

---

## 📋 1. Visão Geral

### Objetivo
Completar o módulo de chatbot com:
1. **Integração WhatsApp + Chatbot** — rotear mensagens de usuários **já cadastrados** para o pipeline RAG (sem quebrar o fluxo de pré-cadastro existente)
2. **Base de conhecimento** — organizar, converter e ingerir documentos para RAG
3. **Escalação inteligente** — regra robusta de escalonamento para Personal Trainer

### Estado Atual Relevante (após merge `develop` em `refactor/chatbot-completo`)

| Componente | Status | Arquivo / Localização |
|-----------|--------|---------|
| Webhook WhatsApp (recepção) | ✅ Implementado e validado (assinatura HMAC) | `routes/webhooks.py` |
| `WhatsAppService` (envio + fluxo de pré-cadastro) | ✅ Implementado pela equipe | `services/whatsapp_service.py` |
| Fluxo de pré-cadastro WhatsApp (states `awaiting_name` → `awaiting_email` → `pending_approval` → `approved`) | ✅ Implementado | `services/whatsapp_service.py:114-158` |
| Modelo `WhatsAppPreRegistration` | ✅ Existe | `models/whatsapp_pre_registration.py` |
| Coluna `phone_whatsapp` em `users` | ✅ Existe (migrada em `init_db`) | `models/user.py:86` + `config/database.py:91` |
| Tela admin de aprovação WhatsApp | ✅ Existe | `frontend/lib/screens/admin/admin_whatsapp_screen.dart` |
| `WhatsAppService.handle_message` roteado ao webhook | ✅ Apenas pré-cadastro (sem chat) | `routes/webhooks.py:122` |
| `ChatService.send_message` aceita `channel` | ❌ Hardcoded `channel="app"` na criação de `ChatMessage` | `services/chat_service.py:438` |
| `ChatConversation.channel` no modelo | ✅ Aceita `app` ou `whatsapp` | `models/chatbot.py:172` |
| Escalação | ✅ Parcial — keywords + score baixo | `ai/rag_chain.py:406-437` |
| Knowledge Base (`KnowledgeBase` + `knowledge_base` table) | ✅ Modelo existe, sem seed | `models/chatbot.py:39` |
| Documentos organizados | ❌ Ingestão não existe | — |
| Seed de KB | ❌ Não existe | — |
| Mensagens de escalação contextuais | ❌ Mensagem genérica única | `ai/rag_chain.py:577-584` |

> [!IMPORTANT]
> **A integração inicial WhatsApp + chatbot tem dois caminhos a coexistir:**
> 1. Telefone **não vinculado a um `User` cadastrado** → mantém fluxo de pré-cadastro (`WhatsAppService.handle_message` atual).
> 2. Telefone **vinculado a um `User` ativo** → roteia para `ChatService.send_message(channel="whatsapp")`.
>
> A Etapa 3 **não deve quebrar** o fluxo de pré-cadastro já entregue; apenas adicionar o ramo de chat.

---

## 📐 2. Padrões Obrigatórios

### 2.1 Referências
- [`BRANCH_STRATEGY.md`](../BRANCH_STRATEGY.md)
- [`COMMIT_GUIDE.md`](../COMMIT_GUIDE.md) — Conventional Commits em PT-BR, sem Co-Author
- [`CLAUDE.md`](../CLAUDE.md) — Instruções gerais
- [`WHATSAPP_SETUP.md`](../WHATSAPP_SETUP.md)
- [`PRD_CHATBOT_REFACTOR_ETAPA1.md`](./PRD_CHATBOT_REFACTOR_ETAPA1.md) — Backend Core (concluído)
- [`PRD_CHATBOT_REFACTOR_ETAPA2.md`](./PRD_CHATBOT_REFACTOR_ETAPA2.md) — Frontend + UX (concluído)

### 2.2 Branch
A Etapa 3 continuará na **mesma branch** `refactor/chatbot-completo` (já contém o merge da `develop`).
Não criar uma nova branch — todo o esforço de chatbot é coeso e tem PR único contra `develop`.

```bash
git checkout refactor/chatbot-completo
git pull origin refactor/chatbot-completo
```

> [!CAUTION]
> **NÃO faça push direto na `develop` ou `main`.** O PR final desta branch deve ser aberto contra `develop` (PR #60 — `refactor(chatbot): refatoração completa do módulo de chatbot`).

### 2.3 Padrão de Commits
Conforme `COMMIT_GUIDE.md`:
```
feat(chatbot): conectar pipeline RAG ao canal WhatsApp
feat(chatbot): criar script de seed da base de conhecimento
docs(chatbot): adicionar documentos da KB de exercícios
test(chatbot): adicionar testes de WhatsApp + KB + escalação
fix(chatbot): robustecer detecção de escalação
```

---

## 🧪 3. Regras de TDD

> [!CAUTION]
> Mesmas regras das Etapas 1 e 2: **Testes PRIMEIRO**. PROIBIDO modificar testes para fazer código passar. Remover duplicados primeiro.

### 3.0 Auditoria de Testes Existentes (PRIMEIRO PASSO)

```bash
# Identificar duplicados ou conflitos com testes já existentes
docker exec omniconnect-api pytest tests/test_chat*.py tests/test_rag*.py -v --collect-only
ls backend/tests/ | grep -E "whatsapp|webhook|knowledge|escalation"
```

**Atenção:** Testes a possíveis duplicar/consolidar:
- `tests/test_webhooks.py` (se existir) — pode ter testes de pré-cadastro WhatsApp
- `tests/test_chat_acceptance.py` — pode ter testes de escalação a serem reutilizados
- `tests/test_rag_chain.py` — pode ter testes de score/threshold

### 3.1 Mapeamento Card → Testes

#### Card 18.8 — Integração WhatsApp ↔ Chatbot
```python
# tests/test_whatsapp_chat.py — NOVO arquivo

def test_whatsapp_message_from_registered_user_routes_to_chat():
    """Mensagem de número vinculado a User ativo é roteada ao ChatService."""

def test_whatsapp_message_from_unregistered_user_routes_to_pre_registration():
    """Mensagem de número não vinculado mantém fluxo de pré-cadastro existente."""

def test_whatsapp_chat_reuses_same_rag_pipeline():
    """Pipeline RAG é o mesmo do app (mesmo ChatService, mesmo rag_chain)."""

def test_whatsapp_chat_persists_with_channel_whatsapp():
    """ChatMessage e ChatConversation salvos com channel='whatsapp'."""

def test_whatsapp_chat_maintains_student_context():
    """Contexto do aluno (ficha, metas, histórico) é incluído no prompt."""

def test_whatsapp_chat_response_time_under_2_seconds():
    """Resposta gerada em ≤ 2s (95th percentile, mocked LLM)."""

def test_whatsapp_chat_handles_invalid_or_empty_messages():
    """Mensagens vazias/inválidas tratadas sem crash."""

def test_whatsapp_user_identified_by_phone_whatsapp():
    """Identificação via `User.phone_whatsapp` (sanitizado)."""

def test_whatsapp_chat_reply_sent_via_cloud_api():
    """Resposta enviada de volta usando `WhatsAppService.send_message`."""

def test_whatsapp_pre_registration_flow_unaffected():
    """Fluxo de pré-cadastro existente continua funcionando inalterado."""
```

#### Card 19 — Documentos da base de conhecimento
```python
# tests/test_knowledge_base_seed.py — NOVO arquivo

def test_knowledge_documents_are_defined():
    """Lista `KNOWLEDGE_DOCUMENTS` definida com ≥25 itens."""

def test_knowledge_categories_match_rag_filter():
    """Categorias usam apenas valores aceitos pelo RAG (exercicio, forma, nutricao, periodizacao, sistema)."""

def test_knowledge_sources_are_documented():
    """Cada documento tem fonte/origem documentada nos comentários do seed."""

def test_knowledge_covers_main_user_flows():
    """Cobre treino, execução, nutrição, sistema (sem lacunas óbvias)."""

def test_knowledge_ready_for_rag_ingestion():
    """Cada documento tem title, content, category compatível com `KnowledgeBase`."""
```

#### Card 19.1 — Organizar documentos
```python
def test_no_duplicate_documents_in_seed():
    """Sem títulos ou contents idênticos no seed."""

def test_documents_follow_consistent_structure():
    """Cada doc tem title, content, category, e campos opcionais coerentes."""

def test_no_conflicting_information_between_docs():
    """Análise manual + assertion mínima de contradição (smoke check)."""

def test_documents_naming_consistent():
    """Padrão de nomes: 'Exercício: <Nome>', 'Nutrição: <Tema>', 'Sistema: <Tema>'."""
```

#### Card 19.2 — Transformar documentos em texto
```python
def test_seed_inserts_records_in_knowledge_base():
    """`seed_knowledge_base()` cria registros em `knowledge_base` table."""

def test_seed_generates_embeddings_with_correct_dim():
    """Embeddings gerados têm dimensão 384 (HuggingFace all-MiniLM-L6-v2)."""

def test_seed_is_idempotent():
    """Rodar `seed_knowledge_base()` duas vezes não duplica registros."""

def test_seed_force_flag_replaces_existing():
    """`force=True` substitui registros existentes."""

def test_text_content_clean():
    """Sem ruído (HTML, markdown excessivo) — texto pronto para embedding."""

def test_no_information_loss():
    """Validar que todos os campos importantes do dict são gravados no DB."""
```

#### Card 19.10 — Escalação para Personal
```python
# tests/test_escalation.py — NOVO arquivo

def test_escalation_triggers_on_explicit_user_request():
    """'Quero falar com personal' → escala com reason=user_requested."""

def test_escalation_triggers_on_health_risk_keyword():
    """'Estou com dor no peito' → escala imediatamente."""

def test_escalation_triggers_on_no_documents_retrieved():
    """RAG vazio → escala com reason=low_confidence."""

def test_escalation_triggers_on_low_relevance_score():
    """Melhor score < ESCALATE_THRESHOLD → escala com reason=too_complex."""

def test_escalation_triggers_on_validation_failure():
    """Resposta gerada falha em validação pós-geração → escala com reason=validation_failed."""

def test_escalation_message_differentiates_by_reason():
    """Mensagem ao usuário difere por tipo de escalação (user_requested ≠ health_risk ≠ too_complex)."""

def test_escalation_records_context_on_conversation():
    """Conversa marcada como escalada inclui contexto: pergunta, score, motivo."""

def test_escalation_visible_in_admin_endpoint():
    """`GET /admin/escalated` retorna conversas escaladas com contexto."""

def test_escalation_avoids_generic_or_incorrect_answers():
    """Em todos os reasons de escalação, a mensagem ao aluno NÃO é a resposta gerada pela IA."""
```

---

## 🔧 4. Tarefas Ordenadas

### Tarefa 1: Auditoria + Testes (RED PHASE)

1. Listar testes existentes relacionados (webhooks, escalação, KB).
2. Remover duplicados se houver.
3. Criar arquivos novos: `test_whatsapp_chat.py`, `test_knowledge_base_seed.py`, `test_escalation.py`.
4. Rodar suíte — novos devem **falhar**.

```bash
git commit -m "test(chatbot): adicionar testes de WhatsApp, KB e escalação"
```

---

### Tarefa 2: Adicionar parâmetro `channel` em `ChatService.send_message`

**Por quê?** Hoje a linha `chat_service.py:438` cria `ChatMessage(channel="app")` hardcoded. Para diferenciar mensagens de WhatsApp e App, precisamos do parâmetro.

**Mudanças:**

```python
# backend/app/services/chat_service.py

ALLOWED_CHANNELS = ("app", "whatsapp")

class ChatService:
    async def send_message(
        self,
        user_id: UUID,
        message: str,
        conversation_id: UUID | None = None,
        academy_id: UUID | None = None,
        on_status: StatusCallback | None = None,
        channel: str = "app",  # ← NOVO
    ) -> dict[str, Any]:
        if channel not in ALLOWED_CHANNELS:
            raise ValueError(f"channel inválido: {channel!r}")
        # ...
        user_msg = ChatMessage(
            conversation_id=conversation.id,
            role="user",
            content=clean_message,
            channel=channel,  # ← parametrizado
        )
        # ...
        # Garantir que assistant também usa o mesmo channel
        assistant_msg = ChatMessage(
            conversation_id=conversation.id,
            role="assistant",
            content=...,
            channel=channel,  # ← parametrizado
        )
```

**Atualizar `ChatController.send_message`** para repassar `channel`.

**Atualizar `_get_or_create_conversation`** para definir `ChatConversation.channel` no momento da criação.

```bash
git commit -m "feat(chatbot): parametrizar canal (app|whatsapp) em ChatService"
```

---

### Tarefa 3: Conectar Webhook WhatsApp ao Pipeline de Chat (Card 18.8)

**Estado atual:** `webhooks.py:122` chama `WhatsAppService.handle_message(phone, text)` que apenas executa o fluxo de pré-cadastro.

**Estratégia:** Adicionar um **roteamento** dentro de `WhatsAppService.handle_message`. Manter a assinatura intacta para não quebrar o webhook.

```python
# backend/app/services/whatsapp_service.py

from app.models.user import User
from app.services.chat_service import ChatService
# ... imports existentes ...

class WhatsAppService:
    # ... código existente ...

    async def handle_message(self, phone: str, text: str) -> None:
        """
        Roteia a mensagem:
            1. Se o telefone está vinculado a um User ativo → encaminhar ao ChatService
            2. Se não, mantém o fluxo de pré-cadastro existente (state machine)
        """
        text = text.strip()
        if not text:
            return

        user = await self._find_user_by_phone(phone)
        if user is not None and user.is_active:
            await self._handle_chat_message(user=user, phone=phone, text=text)
            return

        # Fluxo de pré-cadastro existente — INALTERADO
        await self._handle_pre_registration(phone, text)

    async def _find_user_by_phone(self, phone: str) -> User | None:
        normalized = self._normalize_phone(phone)
        result = await self.session.execute(
            select(User).where(User.phone_whatsapp == normalized)
        )
        return result.scalar_one_or_none()

    @staticmethod
    def _normalize_phone(phone: str) -> str:
        """Remove caracteres não-numéricos. Manter consistência com `users.phone_whatsapp`."""
        return re.sub(r"\D", "", phone or "")

    async def _handle_chat_message(self, user: User, phone: str, text: str) -> None:
        """Roteia mensagem do WhatsApp ao ChatService e responde via Cloud API."""
        chat_service = ChatService(self.session)
        try:
            result = await chat_service.send_message(
                user_id=user.id,
                message=text,
                channel="whatsapp",
            )
            await self.send_message(phone, result["content"])
        except RateLimitExceededError:
            await self.send_message(phone,
                "Você atingiu o limite de mensagens por hora. Tente novamente em breve.")
        except MessageTooLongError:
            await self.send_message(phone,
                "Sua mensagem é muito longa. Tente reformular em até 500 caracteres.")
        except Exception:
            logger.exception("Erro ao processar mensagem WhatsApp para user %s", user.id)
            await self.send_message(phone,
                "Tive um problema ao processar sua mensagem. Tente novamente!")

    async def _handle_pre_registration(self, phone: str, text: str) -> None:
        """Fluxo original de pré-cadastro — extraído para método auxiliar."""
        # Conteúdo atual de handle_message (de awaiting_name até pending_approval)
        # mantido sem mudanças funcionais.
```

**Pontos de atenção:**
- `_normalize_phone` deve ser usado tanto na busca quanto, idealmente, na escrita do `phone_whatsapp` ao criar o User (validar com a equipe).
- A Tarefa 2 garante que `channel="whatsapp"` é aceito.
- Em caso de erro, **NUNCA** vazar stacktrace ao usuário — apenas mensagem amigável.

```bash
git commit -m "feat(chatbot): rotear WhatsApp ao pipeline de chat para usuários cadastrados"
```

---

### Tarefa 4: Criar Conteúdo da Base de Conhecimento (Cards 19, 19.1, 19.2)

**Objetivo:** Popular `knowledge_base` com **≥25 documentos** estruturados.

#### 4.1 Criar `docs/KNOWLEDGE_BASE_CONTENT.md` (fonte humana)

Conteúdo organizado por categoria. Cada seção lista os documentos que serão importados.

**Categorias obrigatórias:**
- `exercicio` — Execução de exercícios (≥15 docs)
- `forma` — Técnica e erros comuns (≥3 docs)
- `nutricao` — Conceitos básicos (≥5 docs)
- `periodizacao` — Frequência, divisões (≥2 docs)
- `sistema` — Operacional (≥5 docs)

#### 4.2 Criar `backend/scripts/seed_knowledge_base.py`

```python
"""Seed da base de conhecimento RAG (categoria/embeddings)."""
from app.models.chatbot import KnowledgeBase
from app.ai.rag_chain import rag_chain  # gerar embeddings via mesmo modelo

KNOWLEDGE_DOCUMENTS = [
    {"title": "Exercício: Supino Reto",
     "content": "...", "category": "exercicio",
     "muscle_group": "Peito", "difficulty_level": "intermediario"},
    # ... ≥25 documentos categorizados
]

async def seed(force: bool = False) -> int:
    """Insere documentos com embeddings. Retorna quantidade gravada."""
    # 1. Se force=False e já há registros, sair
    # 2. Para cada doc: gerar embedding (384 dims) e inserir
    # 3. Logar total
```

#### 4.3 Integrar Seed ao `init_db`

Adicionar em `backend/app/config/database.py:init_db`:

```python
try:
    from scripts.seed_knowledge_base import seed as seed_knowledge_base
    await seed_knowledge_base(force=False)
    logger.info("✓ Verificação/Seed da base de conhecimento concluída")
except Exception as exc:
    logger.warning("Erro ao popular base de conhecimento: %s", exc)
```

```bash
git commit -m "docs(chatbot): criar documentos da base de conhecimento"
git commit -m "feat(chatbot): criar script de seed da base de conhecimento"
git commit -m "feat(chatbot): integrar seed de KB na inicialização do banco"
```

---

### Tarefa 5: Robustecer Escalação (Card 19.10)

**Estado atual:** `rag_chain.py:406-437` detecta `user_requested`, `low_confidence`, `too_complex`. A mensagem ao usuário é genérica.

**Mudanças:**

1. **Mensagens contextualizadas** em `rag_chain.py`:

```python
ESCALATION_MESSAGES = {
    "user_requested":
        "Entendi! Vou encaminhar sua dúvida para o seu Personal Trainer. "
        "Ele receberá uma notificação e poderá te responder em breve! 🎯",
    "low_confidence":
        "Essa é uma ótima pergunta! Para garantir a melhor resposta, "
        "estou encaminhando para o seu Personal Trainer. 💪",
    "too_complex":
        "Essa dúvida requer atenção especializada. Seu Personal Trainer "
        "será notificado para te ajudar pessoalmente! 📋",
    "health_risk":
        "⚠️ Por segurança, como isso pode envolver risco à saúde, "
        "recomendo consultar um profissional. Seu Personal foi notificado.",
    "validation_failed":
        "Não encontrei informações suficientes na base. "
        "Seu Personal poderá te ajudar melhor! 🤝",
    "timeout":
        "Estamos com lentidão na resposta. Encaminhei sua pergunta "
        "ao seu Personal para garantir uma resposta correta! ⏳",
    "generation_error":
        "Tive um problema técnico ao gerar a resposta. "
        "Seu Personal foi notificado e te ajudará em breve! 🛠️",
}
```

2. **Distinguir `health_risk` de `user_requested`** dentro de `_should_escalate` (atualmente ambos retornam `user_requested`):

```python
HEALTH_RISK_KEYWORDS = {"dor no peito", "tontura", "desmaio", "fratura", "lesão"}
EXPLICIT_REQUEST_KEYWORDS = {"falar com personal", "falar com profissional", "humano"}

def _should_escalate(self, query, retrieved_docs):
    q = query.lower()
    if any(k in q for k in HEALTH_RISK_KEYWORDS):
        return True, "health_risk"
    if any(k in q for k in EXPLICIT_REQUEST_KEYWORDS):
        return True, "user_requested"
    if not retrieved_docs:
        return True, "low_confidence"
    if max(d.relevance_score for d in retrieved_docs) < ESCALATE_THRESHOLD:
        return True, "too_complex"
    return False, ""
```

3. **Persistir contexto da escalação** em `ChatService` quando `RAGResult.should_escalate`:

```python
# Em chat_service.py, após receber RAGResult escalado
if rag_result.should_escalate:
    conversation.status = "escalated"
    conversation.escalation_data = {  # campo JSON existente ou criar
        "original_question": clean_message,
        "rag_best_score": rag_result.best_score,
        "reason": rag_result.escalation_reason,
        "user_context_summary": user_context.short_summary(),
    }
```

> **NOTA:** Verificar se `ChatConversation` já tem campo JSON de contexto de escalação. Se não, adicionar via ALTER TABLE no `init_db` (seguindo padrão do projeto).

4. **Endpoint admin de escalações** (`GET /admin/chat/escalated`) — verificar se já existe; expor `escalation_data` na resposta.

```bash
git commit -m "feat(chatbot): diferenciar tipos de escalação com mensagens contextualizadas"
git commit -m "feat(chatbot): persistir contexto da escalação na conversa"
```

---

### Tarefa 6: Testes Adicionais e Validação (GREEN PHASE)

```bash
docker compose up -d
docker exec omniconnect-api pytest tests/test_chat*.py tests/test_rag*.py \
    tests/test_whatsapp_chat.py tests/test_knowledge_base_seed.py \
    tests/test_escalation.py -v --cov=app --cov-report=term-missing

# Verificar seed manualmente
docker exec omniconnect-api python -c "
import asyncio
from scripts.seed_knowledge_base import seed
print('Inseridos:', asyncio.run(seed()))
"

# Smoke test do webhook (com User cadastrado e phone_whatsapp setado)
# 1. Criar usuário com phone_whatsapp = "5511999999999"
# 2. Simular POST /api/v1/webhooks/whatsapp com from=5511999999999, body="como faço supino?"
# 3. Esperar log: "Mensagem roteada ao ChatService"
```

**Critérios de cobertura:**
- `test_whatsapp_chat.py` ≥ 80% das linhas tocadas
- `test_escalation.py` cobre todos os 7 reasons documentados
- `test_knowledge_base_seed.py` valida ≥25 docs e idempotência

```bash
git commit -m "test(chatbot): atingir cobertura ≥80% nos novos módulos"
```

---

## 🚦 5. Validação Final e PR

### 5.1 Antes do push
```bash
# 1. Checar testes
docker exec omniconnect-api pytest -v

# 2. Verificar que pré-cadastro WhatsApp continua funcionando
#    (smoke test: número novo recebe mensagem de welcome)

# 3. Verificar que admin/whatsapp screen carrega normalmente
#    cd frontend && flutter run -d chrome  → /admin/whatsapp
```

### 5.2 Push e PR
```bash
git push origin refactor/chatbot-completo
git branch -vv   # confirmar [origin/refactor/chatbot-completo]

gh pr view 60 || gh pr create \
  --title "refactor(chatbot): refatoração completa do módulo de chatbot" \
  --base develop \
  --body "Etapas 1, 2 e 3 do PRD de refatoração do chatbot. Inclui merge da develop com integração WhatsApp."
```

> [!IMPORTANT]
> Se PR #60 já existe, **NÃO criar novo** — apenas atualizar com push.

---

## ✅ 6. Definição de Pronto

### Backend
- [ ] `ChatService.send_message` aceita `channel` (`app` | `whatsapp`)
- [ ] `WhatsAppService.handle_message` roteia usuários cadastrados ao chat
- [ ] Fluxo de pré-cadastro existente **continua intacto**
- [ ] Identificação por `User.phone_whatsapp` (com normalização)
- [ ] Resposta enviada via `WhatsAppService.send_message`
- [ ] Erros tratados sem expor stacktrace ao usuário

### Knowledge Base
- [ ] `docs/KNOWLEDGE_BASE_CONTENT.md` com ≥25 documentos
- [ ] `scripts/seed_knowledge_base.py` idempotente, gera embeddings 384 dims
- [ ] Seed integrado ao `init_db`
- [ ] Categorias compatíveis com filtro do RAG

### Escalação
- [ ] 7 reasons distintos: `user_requested`, `health_risk`, `low_confidence`, `too_complex`, `validation_failed`, `timeout`, `generation_error`
- [ ] Mensagens contextualizadas por reason
- [ ] `escalation_data` persistido na conversa
- [ ] Endpoint admin expõe contexto

### Testes
- [ ] `test_whatsapp_chat.py`, `test_knowledge_base_seed.py`, `test_escalation.py` criados
- [ ] Cobertura ≥ 80% no módulo de chatbot
- [ ] Nenhum teste modificado para fazer código passar (RT-03)
- [ ] Pré-cadastro WhatsApp validado manualmente

### Git / PR
- [ ] Branch: `refactor/chatbot-completo` (já contém merge `develop`)
- [ ] Commits seguem `COMMIT_GUIDE.md` (PT-BR, sem Co-Author)
- [ ] PR #60 contra `develop`

---

## 📊 7. Estimativa

| Tarefa | Tempo Estimado |
|--------|---------------|
| Auditoria + Testes (red) | 50 min |
| Parametrizar `channel` | 30 min |
| Roteamento WhatsApp ↔ Chat | 1h30 |
| Conteúdo KB + Seed + Init | 2h |
| Robustecer Escalação | 1h |
| Validação (green) | 40 min |
| **TOTAL** | **~6h30** |

---

## 📊 8. Resumo das 3 Etapas

| Etapa | Escopo | Cards | Branch | Tempo | Status |
|-------|--------|-------|--------|-------|--------|
| **1** | Backend Core (RAG, contexto, performance) | 18-18.6, 19.3-19.8 | `refactor/chatbot-completo` | ~6h | ✅ Concluído |
| **2** | Frontend Flutter (UX, histórico, aviso) | 18.7, 18.9, 18.10, 19.9 | `refactor/chatbot-completo` | ~5h | ✅ Concluído |
| **3** | WhatsApp + KB + Escalação | 18.8, 19-19.2, 19.10 | `refactor/chatbot-completo` | ~6h30 | 📋 Pronto |

> [!IMPORTANT]
> Todas as etapas do refactor estão na **mesma branch** `refactor/chatbot-completo` para coesão do PR final. A `develop` já foi mesclada nesta branch para incorporar o trabalho do colega de WhatsApp (pré-cadastro). Não há conflitos pendentes.
