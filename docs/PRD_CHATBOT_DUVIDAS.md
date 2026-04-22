# PRD: Chatbot de Dúvidas Inteligente - OmniConnect Fitness

**Versão:** 1.0  
**Data:** 2026-04-22  
**Status:** 📋 Em Especificação  
**Responsável:** Anderson Chaves

---

## 📋 1. Visão Geral

### Objetivo
Criar um chatbot inteligente in-app que:
- ✅ Responda dúvidas dos alunos sobre exercícios, execução e nomenclatura
- ✅ Use RAG (Retrieval-Augmented Generation) para consultar base de conhecimento da academia
- ✅ Tenha contexto do perfil e ficha ativa do aluno
- ✅ Escale automaticamente para Personal quando necessário
- ✅ Armazene histórico de conversas acessível pelo aluno
- ✅ Evite alucinações (usando RAG + validações)
- ✅ Arquitetura preparada para suportar WhatsApp futuramente (MVP 2)

### Por Quê?
- **Suporte 24/7:** Alunos não precisam esperar resposta de Personal para dúvidas simples
- **Redução de Suporte:** 60-70% das dúvidas são repetidas → economia de tempo
- **Engajamento:** Resposta rápida aumenta confiança no app
- **Contexto:** Chatbot sabe ficha ativa → respostas personalizadas
- **Escalabilidade:** Personal só vê dúvidas complexas
- **Base de Conhecimento:** RAG impede alucinações (baseado em dados reais da academia)

### Escopo
✅ **Incluído neste PRD:**
- Chatbot conversacional via LangChain + RAG
- Múltiplos canais: in-app + WhatsApp
- Acesso ao perfil e ficha ativa do aluno
- Escalação automática para Personal
- Histórico de conversas (aluno + personal)
- Moderação e validação de respostas
- Rastreamento de conversas para análise

❌ **NÃO incluído (futuro PRD):**
- Integração com WhatsApp (MVP 2) - arquitetura pronta, será ativada depois
- Análise de sentimentos para detectar insatisfação
- Sugestões automáticas de aula
- Integração com Firebase Predictions
- Voice/Áudio (MVP 2)
- Video chat com Personal (fora de escopo)

---

## 📊 2. Especificação Técnica

### 2.1 Modelo de Dados

#### Tabela: KnowledgeBase (Base de Conhecimento)
```python
class KnowledgeBase(Base):
    """Base de conhecimento da academia para RAG"""
    
    __tablename__ = "knowledge_base"
    
    id: UUID                      # Identificador único
    academy_id: UUID              # Academia proprietária (FK Academies)
    
    # Conteúdo
    title: str                    # "Como fazer Supino Reto"
    content: str                  # Texto completo (markdown)
    category: str                 # "exercicio", "forma", "nutricao", "periodizacao"
    
    # Vector embedding para RAG
    embedding: List[float]        # pgvector (1536 dims com OpenAI/Claude)
    embedding_model: str          # "openai:text-embedding-3-small"
    
    # Metadados
    exercise_id: UUID             # FK Exercises (se for exercício)
    muscle_group: str             # "Peito", "Costas", etc
    difficulty_level: str         # "iniciante", "intermediario", "avancado"
    
    # Controle
    created_by_id: UUID           # Personal/Gestor que criou
    created_at: datetime
    updated_at: datetime
    is_active: bool               # Ativo na RAG
    
    # Auditoria
    views_count: int              # Quantas vezes consultada
    helpful_count: int            # Quantas vezes marcada como útil
```

#### Tabela: ChatConversation (Conversa)
```python
class ChatConversation(Base):
    """Conversa do chatbot"""
    
    __tablename__ = "chat_conversations"
    
    id: UUID
    user_id: UUID                 # Aluno (FK Users)
    academy_id: UUID              # Academia (FK Academies)
    
    # Metadados da conversa
    channel: str                  # "app" ou "whatsapp"
    started_at: datetime
    ended_at: datetime            # NULL se aberta
    status: str                   # "active", "escalated", "closed"
    
    # Escalação
    escalated_to_personal_id: UUID  # Personal que pegou (nullable)
    escalation_reason: str        # "too_complex", "user_requested", etc
    escalated_at: datetime
    
    # Satisfação
    rating: int                   # 1-5 (nullable se não avaliado)
    feedback: str                 # Comentário (opcional)
    
    # Relações
    messages: List[ChatMessage]   # Mensagens da conversa
    
    created_at: datetime
    updated_at: datetime
```

#### Tabela: ChatMessage (Mensagem)
```python
class ChatMessage(Base):
    """Uma mensagem na conversa"""
    
    __tablename__ = "chat_messages"
    
    id: UUID
    conversation_id: UUID         # FK ChatConversations
    
    # Conteúdo
    role: str                     # "user" ou "assistant"
    content: str                  # Texto da mensagem
    
    # Contexto para IA
    context_data: dict            # JSON com contexto fornecido ao model
    # Exemplo:
    # {
    #   "user_profile": {...},
    #   "active_workout_sheet": {...},
    #   "retrieved_documents": [{id, title, relevance_score}, ...]
    # }
    
    # Canal (preparado para multi-canal futuro)
    channel: str                  # "app" (MVP 1), "whatsapp" (MVP 2)
    
    # Rastreamento
    model_used: str               # "claude-3-sonnet", etc
    tokens_used: int              # Input + output tokens
    latency_ms: int               # Tempo resposta
    
    # Validação
    is_human_reviewed: bool       # Se foi revisada por Personal
    reviewed_by_id: UUID          # Personal que revisou
    needs_human_review: bool      # Flag se requer review
    
    # Metadados
    created_at: datetime
```

#### Tabela: ChatFeedback (Feedback)
```python
class ChatFeedback(Base):
    """Feedback do usuário sobre resposta do chatbot"""
    
    __tablename__ = "chat_feedback"
    
    id: UUID
    message_id: UUID              # FK ChatMessages
    user_id: UUID                 # Aluno que deixou feedback
    
    # Feedback
    was_helpful: bool             # Verdadeiro/Falso
    feedback_type: str            # "irrelevant", "incorrect", "incomplete", "good"
    comment: str                  # Comentário opcional
    
    created_at: datetime
```

---

## 🤖 3. Fluxo de Funcionamento

### 3.1 Pipeline RAG (Retrieval-Augmented Generation)

```
┌─────────────────────────────────────┐
│   Pergunta do Usuário (in-app/WA)   │
│  "Como faço supino com halteres?"   │
└────────────┬────────────────────────┘
             │
             ▼
┌──────────────────────────────────────┐
│  1. RETRIEVE: Buscar documentos RAG  │
│  - Query embedding (embedding model) │
│  - pgvector similarity search        │
│  - Top 3-5 documentos relevantes     │
│  - Score de relevância ≥ 0.7        │
└────────────┬─────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────┐
│  2. AUGMENT: Montar contexto                 │
│  - Documentos recuperados                    │
│  - Perfil do aluno (nível, objetivo)         │
│  - Ficha ativa (exercícios, volume)          │
│  - Histórico de conversas (80 tokens)        │
└────────────┬─────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────┐
│  3. GENERATE: LLM gera resposta              │
│  - Prompt: instruções + contexto + pergunta  │
│  - Model: Claude 3.5 Sonnet (ou equivalente) │
│  - Max tokens: 500                           │
│  - Temperature: 0.3 (consistência)           │
└────────────┬─────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────┐
│  4. VALIDATE: Validar resposta               │
│  - Resposta tem referência aos docs? ✓       │
│  - Não tem alucinações (cross-check)? ✓      │
│  - Tons e formato corretos? ✓                │
│  - Se falhar: escalar para Personal          │
└────────────┬─────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────┐
│  5. RESPOND: Enviar resposta                 │
│  - In-app: WebSocket + HTTP fallback         │
│  - WhatsApp: Queue + Async (max 2s)          │
│  - Log em ChatMessage (rastreamento)         │
└──────────────────────────────────────────────┘
```

### 3.2 Fluxo de Escalação

```
┌─────────────────────────┐
│ Pergunta complexa ou    │
│ "Preciso falar com      │
│  meu Personal"          │
└────────────┬────────────┘
             │
             ▼
┌────────────────────────────────────────┐
│ Chatbot detecta escala (confidence<0.5)│
│ ou usuário solicita Personal explícito │
└────────────┬─────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────┐
│ 1. Criar ChatConversation escalada   │
│ 2. Notificar Personal do aluno       │
│ 3. Enviar contexto para Personal     │
│    - Pergunta original               │
│    - Ficha ativa do aluno            │
│    - Histórico de conversa           │
└────────────┬─────────────────────────┘
             │
             ▼
┌──────────────────────────────────────┐
│ Personal ve conversa no dashboard:   │
│ - 🔴 "João perguntou sobre supino"   │
│ - Clica e vê histórico completo      │
│ - Responde diretamente ao aluno      │
└──────────────────────────────────────┘
```

---

## 🔌 4. Endpoints da API

### ChatBot Endpoints

#### POST `/api/v1/chat/send-message`
**Enviar mensagem para chatbot (in-app)**

```json
{
  "conversation_id": "uuid | null",
  "message": "Como faço supino reto?"
}
```

**Note:** Campo `channel` é fixado como `"app"` no MVP 1. Será parametrizável no MVP 2 quando adicionarmos WhatsApp.

**Resposta (200 OK):**
```json
{
  "message_id": "uuid",
  "conversation_id": "uuid",
  "role": "assistant",
  "content": "Supino reto é um exercício...",
  "retrieved_documents": [
    {
      "id": "uuid",
      "title": "Como fazer Supino Reto",
      "relevance_score": 0.92,
      "url": "https://..."
    }
  ],
  "escalation": null,
  "latency_ms": 1234,
  "created_at": "2026-04-22T14:30:00Z"
}
```

---

#### GET `/api/v1/chat/conversations`
**Listar conversas do aluno**

```json
Response (200 OK):
{
  "conversations": [
    {
      "id": "uuid",
      "started_at": "2026-04-22T10:00:00Z",
      "status": "closed",
      "rating": 5,
      "escalated": false,
      "message_count": 4
    }
  ],
  "total": 12,
  "page": 1
}
```

---

#### GET `/api/v1/chat/conversations/{id}`
**Obter detalhes de conversa**

```json
Response (200 OK):
{
  "id": "uuid",
  "started_at": "2026-04-22T10:00:00Z",
  "ended_at": "2026-04-22T10:15:00Z",
  "status": "closed",
  "escalated": false,
  "messages": [
    {
      "role": "user",
      "content": "Como faço supino?",
      "created_at": "2026-04-22T10:00:00Z"
    },
    {
      "role": "assistant",
      "content": "Supino é...",
      "retrieved_documents": [...],
      "created_at": "2026-04-22T10:00:05Z"
    }
  ],
  "rating": 5,
  "feedback": "Muito útil!"
}
```

---

#### POST `/api/v1/chat/conversations/{id}/rate`
**Avaliar conversa**

```json
{
  "rating": 5,
  "feedback": "Resposta excelente!"
}
```

**Resposta (200 OK):**
```json
{
  "success": true,
  "message": "Feedback registrado"
}
```

---

#### POST `/api/v1/chat/messages/{id}/feedback`
**Deixar feedback em mensagem específica**

```json
{
  "was_helpful": true,
  "feedback_type": "good",
  "comment": "Ajudou muito!"
}
```

---

### Admin/Personal Endpoints

#### GET `/api/v1/chat/admin/escalated`
**Listar conversas escaladas (para Personal)**

```json
Response (200 OK):
{
  "escalated_conversations": [
    {
      "id": "uuid",
      "student_id": "uuid",
      "student_name": "João Silva",
      "reason": "too_complex",
      "original_question": "Como adaptar supino se tenho lesão no ombro?",
      "escalated_at": "2026-04-22T14:30:00Z",
      "messages": [...]
    }
  ],
  "total": 3
}
```

---

#### POST `/api/v1/chat/admin/knowledge-base`
**Criar documento na base de conhecimento (Personal/Gestor)**

```json
{
  "title": "Como fazer Supino Reto",
  "content": "# Supino Reto\n\nO supino reto é um exercício...",
  "category": "exercicio",
  "exercise_id": "uuid",
  "muscle_group": "Peito",
  "difficulty_level": "intermediario"
}
```

---

#### GET `/api/v1/chat/admin/knowledge-base`
**Listar base de conhecimento (com métricas)**

```json
Response (200 OK):
{
  "documents": [
    {
      "id": "uuid",
      "title": "Como fazer Supino Reto",
      "category": "exercicio",
      "views_count": 45,
      "helpful_count": 42,
      "helpfulness_rate": 0.93,
      "created_at": "2026-03-15T10:00:00Z"
    }
  ]
}
```

---

## 🎯 5. Regras de Negócio

### 5.1 Conversas

| Regra | Descrição |
|-------|-----------|
| **RN-01** | Toda mensagem deve ser armazenada em ChatMessage para auditoria |
| **RN-02** | Conversa é auto-encerrada se inatividade > 24h (status: "closed") |
| **RN-03** | Aluno pode reabrir conversa anterior (não cria nova) |
| **RN-04** | Personal só vê conversas escaladas ou se é o Personal do aluno |
| **RN-05** | Histórico ≤ 80 tokens para context window (ultras são removidas) |

### 5.2 RAG e Retrieval

| Regra | Descrição |
|-------|-----------|
| **RN-06** | Mínimo 0.7 de relevância (similarity score) para usar documento |
| **RN-07** | Se relevância < 0.6: escalar para Personal (não responder) |
| **RN-08** | Sempre incluir fontes (retrieved_documents) na resposta |
| **RN-09** | Base de conhecimento atualizada 1x/semana (refresh embeddings) |
| **RN-10** | Apenas Personal/Gestor pode criar/editar documentos |

### 5.3 Escalação

| Regra | Descrição |
|-------|-----------|
| **RN-11** | Escalar automaticamente se confidence < 0.5 |
| **RN-12** | Escalar se usuário disser "falar com Personal", "não entendi", etc |
| **RN-13** | Notificar Personal em <5s (push + in-app) |
| **RN-14** | Personal tem 24h para responder escalação |
| **RN-15** | Se Personal não responde em 24h → enviar reminder |

### 5.4 Segurança e Validação

| Regra | Descrição |
|-------|-----------|
| **RN-16** | Rate limit: Max 30 mensagens/hora por usuário |
| **RN-17** | Não responder sobre saúde crítica ("tenho dor no peito") → escalado |
| **RN-18** | Prompt injection prevention: sanitizar entrada |
| **RN-19** | Respostas devem ser validadas (cross-check com docs) |
| **RN-20** | Log todas as conversas para compliance/LGPD |

### 5.5 Feedback e Iteração

| Regra | Descrição |
|-------|-----------|
| **RN-21** | Coletar feedback em toda resposta (was_helpful) |
| **RN-22** | Se helpful_rate < 0.6 para documento → avisar Personal |
| **RN-23** | Manter métricas de satisfação (views, helpfulness) |
| **RN-24** | Usar feedback para retreinar modelos (futura melhoria) |

---

## 🔐 6. Segurança

### 6.1 Autenticação e Autorização
- ✅ JWT token obrigatório em todos endpoints
- ✅ Aluno só acessa suas conversas
- ✅ Personal só acessa conversas escaladas ou de seus alunos
- ✅ Gestor acessa todas (admin)

### 6.2 Validação de Entrada
```python
# Regras de sanitização
- Max 500 caracteres por mensagem
- Não permitir URLs (exceto em respostas do bot)
- Sanitizar HTML/markdown inject
- Bloquear SQL/prompt injection patterns
```

### 6.3 Rate Limiting
```python
# Rate limits
- 30 mensagens/hora por usuário
- 100 mensagens/hora por academia
- Burst: 3 mensagens em 10 segundos
```

### 6.4 Conformidade LGPD
- ✅ Dados de saúde (exercícios) são sensíveis → backup encriptado
- ✅ Histórico de [conversa anônimo após 90 dias de inatividade
- ✅ Direito ao esquecimento: deletar todas conversas em 30 dias
- ✅ Logging de acesso por Personal/Admin

---

## 📊 7. Especificação de Integração

### 7.1 In-App Integration (WebSocket - MVP 1)

```javascript
// Cliente Flutter/Web
const ws = WebSocket('/api/v1/chat/ws')
ws.send(JSON.stringify({
  type: 'message',
  conversation_id: 'uuid',
  content: 'Como faço supino?'
}))

ws.onmessage = (event) => {
  const response = JSON.parse(event.data)
  // {
  //   message_id, role, content, 
  //   retrieved_documents, latency_ms
  // }
}
```

### 7.2 WhatsApp Integration (MVP 2 - Futuro)

**Será implementado após MVP 1 com a seguinte arquitetura:**

```python
# Webhook recebe mensagem do WhatsApp (MVP 2)
POST /webhooks/whatsapp/messages
{
    "messaging_product": "whatsapp",
    "entry": [{
        "changes": [{
            "value": {
                "messages": [{
                    "from": "5511999999999",
                    "id": "wamid.xxx",
                    "text": {"body": "Como faço supino?"}
                }]
            }
        }]
    }]
}

# Flow (MVP 2):
1. Validar signature (Meta webhook)
2. Extrair número + mensagem
3. Buscar user_id por whatsapp_phone
4. Enviar para chatbot pipeline (mesmo pipeline in-app)
5. Responder via WhatsApp Cloud API (max 2s)
```

**Notas para implementação futura:**
- Reutilizar mesmo pipeline RAG + LLM
- Apenas adicionar camada de transformação WhatsApp → ChatMessage
- Histórico unificado (aluno vê conversas de ambos canais)
- Rate limiting mantém-se igual (por usuário, não por canal)

---

## 🧪 8. Testes

### 8.1 Testes Unitários

```python
# tests/test_chatbot.py

def test_retrieve_documents_success():
    """Deve recuperar documentos similares"""
    # Given: base de conhecimento com documentos
    # When: fazer query RAG
    # Then: retornar top 3 docs com score > 0.7

def test_retrieve_documents_no_match():
    """Deve escalar se score < 0.6"""
    # Given: query muito diferente da base
    # When: fazer query RAG
    # Then: retornar escalation=true

def test_generate_response_with_context():
    """Deve gerar resposta com contexto do aluno"""
    # Given: aluno com ficha ativa
    # When: enviar mensagem
    # Then: resposta personalizada com ficha em contexto

def test_rate_limiting():
    """Deve bloquear após 30 mensagens/hora"""
    # Given: usuário com 30 mensagens enviadas
    # When: enviar 31ª mensagem
    # Then: retornar 429 Too Many Requests

def test_escalation_notification():
    """Deve notificar Personal em <5s"""
    # Given: conversa escalada
    # When: escalação criada
    # Then: Personal recebe push em <5s

def test_message_sanitization():
    """Deve sanitizar input"""
    # Given: input com HTML injection
    # When: processar mensagem
    # Then: remover scripts/tags perigosas
```

### 8.2 Testes de Integração

```python
def test_full_conversation_flow():
    """Teste end-to-end completo"""
    # 1. Aluno envia mensagem
    # 2. Chatbot recupera documentos
    # 3. Gera resposta
    # 4. Armazena em banco
    # 5. Retorna para aluno

def test_whatsapp_webhook():
    """Teste de receção WhatsApp"""
    # 1. Simular webhook da Meta
    # 2. Chatbot processa
    # 3. Responde via WhatsApp API

def test_escalation_flow():
    """Teste de escalação completo"""
    # 1. Mensagem complexa
    # 2. Detecta necessidade escalação
    # 3. Notifica Personal
    # 4. Personal responde
    # 5. Aluno recebe resposta
```

---

## 📈 9. Performance e SLA

| Métrica | Target | Observação |
|---------|--------|-----------|
| **Latência Resposta** | <2s | 95th percentile |
| **Disponibilidade** | 99% | 7,2h downtime/mês |
| **Throughput** | 50 msg/s | Pico esperado |
| **PDV (Confidence Avg)** | >0.75 | Qualidade de respostas |
| **Taxa Escalação** | <15% | Conversas escaladas |
| **Taxa Satisfação** | >0.8 | Feedback positivo |

---

## 🗂️ 10. Dependências e Stack

### Stack Técnico
- **LLM:** Claude 3.5 Sonnet (via API Anthropic)
- **RAG Framework:** LangChain v0.1+
- **Vector DB:** PostgreSQL + pgvector
- **Embedding Model:** OpenAI text-embedding-3-small (1536 dims)
- **Cache:** Redis (conversas recentes)
- **Messaging:** WhatsApp Cloud API (Meta)
- **Notificações:** Firebase FCM

### Dependências de PRD
- ✅ PRD_USUARIOS (autenticação, roles)
- ✅ PRD_NOTIFICACOES (notificar Personal)
- ⚠️ PRD_FICHA_TREINO (contexto - obter ficha ativa)
- ⚠️ PRD_CADASTRO_WHATSAPP (integração WhatsApp no MVP 2)
- ⚠️ PRD_LOGBOOK (contexto potencial futuro)

---

## 📋 11. Estimativa de Esforço

| Componente | Horas | Notas |
|-----------|-------|-------|
| Setup LangChain + RAG | 16h | Setup initial, config embeddings |
| Backend (endpoints) | 24h | CRUD conversas, escalação |
| WhatsApp Webhook | 12h | Integração com Meta API |
| Frontend (in-app) | 20h | UI chat, histórico, feedback |
| Testes (unit + integration) | 20h | 70%+ cobertura |
| Documentação | 8h | API docs, user guide |
| **TOTAL** | **100h** | ~2.5 semanas (1 dev full-time) |

---

## 🗒️ 12.Observações e Considerações Futuras

### MVP 1 (Escopo Atual)
- ✅ Chatbot básico com RAG
- ✅ Integração in-app (WebSocket)
- ✅ Escalação manual para Personal
- ✅ Histórico de conversas
- ✅ Arquitetura preparada para WhatsApp (field `channel` nos modelos)

### MVP 2 (Futuro)
- 📱 Integração com WhatsApp (ativar webhook + adaptar transformação)
- 📊 Analytics de perguntas mais comuns
- 🎯 Sugestões automáticas baseadas em ficha ativa
- 🔄 Retreinamento de modelos com feedback
- 📞 Integração com Voice (áudio WhatsApp)

### MVP 3 (Longo Prazo)
- 🤖 Auto-responder simples (FAQ) sem LLM
- 📈 Análise de sentimentos
- 🎨 Personalização de respostas por perfil
- 🌐 Suporte multilíngue

---

## ✅ Checklist de Implementação

**MVP 1 (In-App apenas):**
- [ ] Setup LangChain + LLM integration
- [ ] Setup pgvector + embeddings
- [ ] Criar tabelas (KnowledgeBase, ChatConversation, ChatMessage)
- [ ] Implementar pipeline RAG (retrieve → augment → generate → validate)
- [ ] Endpoints de chatbot
- [ ] WebSocket para in-app
- [ ] Escalação de conversas
- [ ] Notificações para Personal
- [ ] Testes unitários
- [ ] Testes de integração
- [ ] Rate limiting
- [ ] Sanitização de input
- [ ] Logging e auditoria
- [ ] Documentação API
- [ ] Deploy

**MVP 2 (Adicionar WhatsApp - Futuro):**
- [ ] Setup webhook WhatsApp
- [ ] Adaptar transformação de eventos WhatsApp
- [ ] Testes com WhatsApp
- [ ] Deploy WhatsApp

---

*Versão Inicial: 2026-04-22*  
*Responsável: David Oliveira*  
*Status: Pronto para Review*
