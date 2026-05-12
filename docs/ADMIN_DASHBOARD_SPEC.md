# 📊 Dashboard Admin OmniConnect Fitness - Especificação Técnica

**Versão:** 1.0  
**Data:** 2026-05-12  
**Autor:** Admin Strategy Team  
**Status:** ✅ Aprovado para Implementação

---

## 📖 Introdução

Este documento consolida a **visão estratégica e técnica** do painel de controle administrativo do OmniConnect Fitness. Ele detalha as métricas essenciais que definem:

- **Retenção de Alunos** (vida útil dos clientes)
- **Escala de Trainers** (capacidade de vendas e atendimento)
- **Saúde Operacional** (custos vs. receita, engajamento tecnológico)

Todas as métricas estão **100% mapeadas a dados existentes** no PostgreSQL e prontas para implementação via API REST.

---

## 🎯 Glossário Executivo

| Termo | Definição | Impacto |
|-------|-----------|--------|
| **Taxa de Adesão** | % de sessões completadas vs planejadas | Alto (preditor de churn) |
| **Aluno em Risco** | Aderência < 50% por 14 dias consecutivos | Alto (oportunidade de intervenção) |
| **DAU** | Daily Active Users (≥1 ação/dia) | Médio (engagement indicator) |
| **MAU** | Monthly Active Users (≥1 ação/mês) | Médio (retention indicator) |
| **Conversion Rate** | Convites resgatados / Convites gerados | Alto (eficácia de vendas) |
| **Custo de IA** | Total tokens × preço modelo | Médio (economia de operação) |

---

# 🎓 SEÇÃO 1: MÉTRICAS DE ALUNO (Retenção e Entrega de Resultado)

## 📌 Contexto Estratégico

O sucesso financeiro do OmniConnect depende de **alunos retidos que batem metas**. Um aluno que vê resultados continua assinado. Um aluno com baixa adesão faz churn. Por isso, estas métricas monitoram a vida útil do cliente.

---

## 1.1 Taxa de Adesão (Adherence Rate)

### O que é?
% de sessões de treino **E** dieta completadas vs planejadas, medido em período específico.

### Por que importa?
- Alunos com adherence > 80% tendem a bater metas e renovar
- Alunos com adherence < 50% estão em risco iminente de churn
- É o principal indicador de satisfação e resultado

### Fórmula
```
Adherence_Rate = (Sessões_Completadas + Refeições_Registradas) / (Sessões_Planejadas + Refeições_Planejadas) × 100

Componentes:
- Sessões_Completadas: COUNT(logbook WHERE status = 'completed')
- Sessões_Planejadas: COUNT(workout_sheet WHERE is_active = true) por período
- Refeições_Registradas: COUNT(diet_logbook WHERE date = date_filtered)
- Refeições_Planejadas: Estimado em 3 por dia para alunos com dieta ativa
```

### Fonte de Dados
| Tabela | Campo | Descrição |
|--------|-------|-----------|
| `logbook` | status, session_date, user_id | Cada sessão de treino |
| `diet_logbook` | date, user_id, total_kcal | Cada dia de log alimentar |
| `workout_sheet` | is_active | Rotinas planejadas |

### Granularidade e Filtros

**Temporal:**
- Por dia (last 24h)
- Por semana (last 7d)
- Por mês (last 30d)
- Por período customizado

**Por Usuário:**
- Por aluno individual (user_id)
- Por trainer (aggregação de todos seus alunos)
- Por status de adesão (high: >80%, medium: 50-80%, low: <50%)

### Exemplo de Payload (Resposta API)

```json
{
  "period": "30d",
  "data": [
    {
      "user_id": "uuid-123",
      "user_name": "João Silva",
      "adherence_rate": 85.3,
      "category": "high",
      "sessions_completed": 12,
      "sessions_planned": 14,
      "meals_logged": 87,
      "meals_planned": 90,
      "trend": "stable",
      "last_activity": "2026-05-12T14:30:00Z"
    }
  ],
  "summary": {
    "average_adherence": 76.5,
    "high_count": 145,
    "medium_count": 89,
    "low_count": 34
  }
}
```

---

## 1.2 Alunos em Risco (At-Risk Students)

### O que é?
Identificação automática de alunos que podem fazer **churn nos próximos 30 dias**, baseada em sinais comportamentais.

### Por que importa?
- Permite intervenção proativa (reminder, contato PT)
- Reduz churn rate (retenção é 10x mais barata que aquisição)
- Identifica alunos que precisam de suporte pedagógico

### Sinais de Risco (Scoring)

```
risk_level = (5 if adherence < 30%) + (3 if days_inactive > 7) + (2 if sessions_skipped > 3)
```

| Sinal | Peso | Impacto |
|-------|------|--------|
| Aderência < 30% | 5 | Crítico — possível dropout |
| Inatividade > 7 dias | 3 | Alto — perda de interesse |
| Sessões puladas > 3 seguidas | 2 | Médio — falta de motivação |
| Sem logs de dieta > 14 dias | 2 | Médio — abandono de metas |

### Categorias

- **🔴 Crítico** (score ≥ 8): Risco de churn em 7 dias
- **🟠 Alto** (score 5-7): Risco de churn em 14 dias
- **🟡 Médio** (score 2-4): Risco de churn em 30 dias
- **🟢 Baixo** (score < 2): Engajado

### Ações Recomendadas

| Categoria | Ação Imediata | Executor |
|-----------|---------------|----------|
| Crítico | Notificação admin + SMS ao PT | Admin/Sistema |
| Alto | Email automático + reminder no app | Sistema |
| Médio | Badge no dashboard + recomendação | Dashboard |

### Exemplo de Payload

```json
{
  "date": "2026-05-12",
  "at_risk_count": 34,
  "breakdown": {
    "critical": 8,
    "high": 12,
    "medium": 14
  },
  "students": [
    {
      "user_id": "uuid-456",
      "user_name": "Maria Santos",
      "risk_level": "critical",
      "score": 9,
      "adherence_rate": 22.5,
      "days_inactive": 8,
      "last_login": "2026-05-04T10:00:00Z",
      "trainer_id": "uuid-trainer-123",
      "recommended_action": "Contact PT immediately"
    }
  ]
}
```

---

## 1.3 Progresso Real de Metas (Goal Progress)

### O que é?
Rastreamento de avanço dos alunos rumo aos seus objetivos (peso, força, resistência, etc.).

### Por que importa?
- **Prova social:** Mostrar progresso justifica a permanência na plataforma
- **Motivação:** Metas próximas de completar reforçam hábito
- **Retenção:** Alunos que veem resultados não cancelam

### Fórmula

```
Progress_Percentage = (current_value - initial_value) / (target_value - initial_value) × 100

Exemplo: Meta de perder 10 kg (começou em 90kg, meta 80kg, agora em 85kg)
Progress = (90 - 85) / (90 - 80) × 100 = 50% completo
```

### Fonte de Dados

| Tabela | Campo | Descrição |
|--------|-------|-----------|
| `goal` | initial_value, current_value, target_value, target_date | Meta configurada |
| `goal_progress_entries` | current_value, recorded_at, notes | Histórico de progresso |

### Dimensões de Análise

```json
{
  "by_status": {
    "completed": 156,          // Metas 100% atingidas
    "on_track": 289,           // Progresso normal (velocity ok)
    "at_risk": 45,             // Velocidade baixa (risco de não atingir)
    "stalled": 12              // Sem progresso > 30 dias
  },
  
  "by_category": {
    "weight_loss": { completed: 45, total: 120 },
    "muscle_gain": { completed: 67, total: 145 },
    "endurance": { completed: 34, total: 89 },
    "flexibility": { completed: 10, total: 35 }
  }
}
```

### Insights Derivados

1. **Momentum Score:** Velocity da meta (kg/week, rep/week) — indica se estão no caminho
2. **Time to Completion:** Estimativa de quando atingirá a meta (baseada em velocity)
3. **Completion Rate:** % de alunos que completaram metas de forma geral

---

## 1.4 Engajamento Diário (Daily Activity)

### O que é?
Mede interação do aluno com a plataforma **fora do treino formal** (passos, app opens, chats).

### Por que importa?
- Gamificação mantém usuário ativo mesmo em dias sem academia
- Aumenta DAU (Daily Active Users) → mais oportunidades de monetização
- Sistema de handicap garante streaks mesmo em baixa atividade

### Métricas

```
DAU = COUNT(DISTINCT user_id WHERE any_activity >= 1 ON date)
MAU = COUNT(DISTINCT user_id WHERE any_activity >= 1 ON month)

Activity Types:
- Login (app open)
- Completar workout
- Registrar refeição
- Registrar passos (qualquer valor > 0)
- Enviar mensagem no chat
- Visualizar recomendação de treino
```

### Fonte de Dados

| Tabela | Campo | Descrição |
|--------|-------|-----------|
| `step_log` | steps, date, user_id | Passos diários (gamificado) |
| `notification_log` | clicked_at, user_id | Interações com notificações |
| `auth logs` | last_login, user_id | Últimos acessos |

### Exemplo de Payload

```json
{
  "period": "30d",
  "dau_stats": {
    "today": 234,
    "average_30d": 198,
    "trend": "up",
    "change_percent": 8.5
  },
  "mau": 412,
  "dau_mau_ratio": 0.57,
  "activity_breakdown": {
    "workouts": 45000,
    "meals": 38000,
    "steps": 92000,
    "chats": 12000
  }
}
```

---

# 💼 SEÇÃO 2: MÉTRICAS DE PERSONAL TRAINER (Escala e Eficiência de Vendas)

## 📌 Contexto Estratégico

O Personal Trainer é o **motor de aquisição** do app. Estas métricas mostram a ele que está:
- Ganhando dinheiro (escala de alunos)
- Vendendo melhor (conversion funnel)
- Operando de forma saudável (alunos retidos)

---

## 2.1 Funil de Vendas (Sales Funnel)

### O que é?
Rastreamento de **convites gerados vs. resgates** por trainer.

### Por que importa?
- Identifica trainers "top performers" (alta conversão)
- Sinaliza trainers que precisam de suporte de vendas
- Mostra ROI do programa de indicações

### Fórmula

```
Conversion_Rate = (Invites_Used / Invites_Generated) × 100

Exemplo: PT gerou 50 convites, 35 foram resgatados
Conversion = (35 / 50) × 100 = 70%
```

### Fonte de Dados

| Tabela | Campo | Descrição |
|--------|-------|-----------|
| `invitation` | trainer_id, created_at, used_at, used_by_id | Convite gerado e resgato |
| `user` | created_at, trainer_id | Vinculação do novo aluno |

### Dimensões de Análise

```json
{
  "trainers": [
    {
      "trainer_id": "uuid-trainer-1",
      "trainer_name": "Carlos",
      "invites_generated": 50,
      "invites_used": 35,
      "conversion_rate": 70,
      "conversion_category": "high",
      "avg_days_to_conversion": 3.2,
      "active_students_from_invites": 28
    }
  ],
  "benchmark": {
    "avg_conversion_rate": 55,
    "top_conversion_rate": 75,
    "bottom_conversion_rate": 25
  }
}
```

---

## 2.2 Capacidade de Atendimento (Client Portfolio)

### O que é?
Volume e qualidade de alunos gerenciados por cada Personal Trainer.

### Por que importa?
- Identifica trainers sobrecarregados (burn-out risk)
- Revela treinadores que estão escalando bem (pronto para mais clientes)
- Base para decisões de contratação / alocação

### Métricas Principais

```
Total_Students = COUNT(user WHERE trainer_id = X AND is_active = true)

Active_Students = COUNT(user WHERE 
  trainer_id = X AND 
  adherence_rate_30d > 30% AND 
  last_login < 7 days ago)

AtRisk_Students = COUNT(user WHERE 
  trainer_id = X AND 
  adherence_rate_30d < 50%)

Healthy_Portfolio_Score = (Active / Total) × 100
```

### Fonte de Dados

| Tabela | Campo | Descrição |
|--------|-------|-----------|
| `user` | trainer_id, is_active | Vínculo PT-Aluno |
| `logbook` | user_id, status, session_date | Aderência |
| `diet_logbook` | user_id, date | Engajamento em dieta |

### Exemplo de Payload

```json
{
  "trainers": [
    {
      "trainer_id": "uuid-trainer-1",
      "trainer_name": "Ana Silva",
      "total_students": 45,
      "active_students": 38,
      "at_risk_students": 8,
      "portfolio_health": 84.4,
      "avg_student_adherence": 72.3,
      "churn_risk_students": ["uuid-aluno-1", "uuid-aluno-2"]
    }
  ]
}
```

---

# 🖥️ SEÇÃO 3: MÉTRICAS DE NEGÓCIO E SISTEMA (Operacional e IA)

## 📌 Contexto Estratégico

O Admin precisa saber se:
- A plataforma está crescendo (DAU/MAU trends)
- Os custos de tecnologia não estão engolindo margem (custo IA)
- Os usuários estão adoptando novos recursos (chatbot adoption)

---

## 3.1 Saúde do Sistema (System Health)

### O que é?
Visão geral da saúde da plataforma (crescimento, engajamento, retenção).

### Por que importa?
- **DAU/MAU ratio** indica saúde geral (crescimento vs estagnação)
- Tendências detectam churn em massa
- Fundadores e investidores monitoram essas métricas

### Métricas

```
DAU = Usuários com ≥1 ação no dia
MAU = Usuários com ≥1 ação no mês
DAU/MAU Ratio = DAU / MAU

Interpretação:
- 0.5+: Saúde excelente (50% dos MAU voltam diariamente)
- 0.3-0.5: Saúde boa (30-50% dos MAU voltam)
- 0.1-0.3: Saúde em risco (baixa retorno)
```

### Fonte de Dados

Agregação de múltiplas ações:
- Logins (auth logs)
- Completar workout (logbook)
- Registrar refeição (diet_logbook)
- Registrar passos (step_log)
- Enviar mensagem (chat_message)

### Exemplo de Payload

```json
{
  "date": "2026-05-12",
  "dau": 312,
  "mau": 487,
  "dau_mau_ratio": 0.64,
  "trend_30d": "stable",
  "user_growth": {
    "new_users_today": 5,
    "new_users_30d": 145,
    "monthly_growth_rate": 12.3
  }
}
```

---

## 3.2 Adoção de Chatbot (IA Adoption)

### O que é?
% de usuários que usaram o chatbot e qualidade das respostas.

### Por que importa?
- Mostra o **ROI do investimento em IA**
- Mede **autonomia do aluno** (menos tickets para PT)
- Base para decisões de expanding IA (mais features vs custo)

### Métricas

```
Adoption_Rate = (Users_Interacted_With_Chatbot / Total_Active_Users) × 100

Quality_Score = (Helpful_Responses / Total_Responses) × 100

Engagement = Avg_Messages_Per_User_Per_Day
```

### Fonte de Dados

| Tabela | Campo | Descrição |
|--------|-------|-----------|
| `chat_conversation` | user_id | Usuário usou chat |
| `chat_feedback` | was_helpful | Resposta foi útil? |
| `chat_message` | user_id, created_at | Volume de interações |

### Exemplo de Payload

```json
{
  "period": "30d",
  "adoption_rate": 34.5,
  "quality_score": 82.3,
  "total_conversations": 567,
  "total_messages": 2341,
  "avg_messages_per_user": 3.2,
  "helpful_responses": 1918,
  "unhelpful_responses": 423,
  "trending_topics": ["exercício para costas", "cálculo de macros", "dor no joelho"]
}
```

---

## 3.3 Custo Operacional de IA (IA Economics)

### O que é?
Rastreamento detalhado de custos de processamento de IA (tokens, latência, modelo).

### Por que importa?
- **Margem de lucro:** IA está comendo nossas receitas?
- **Decisões de modelo:** Vale usar GPT-4 ou Claude? Qual é mais barato?
- **Pricing:** Precisamos cobrar mais ou otimizar o modelo?

### Fórmulas

```
Token_Cost = Total_Tokens_Used × (Model_Price_Per_1K_Tokens / 1000)

Cost_Per_Interaction = Token_Cost / Number_Of_Messages

Cost_Per_User = Sum(Token_Cost) / Distinct(User_Count)

ROI_AI = (Value_From_Support_Reduction) / (Total_AI_Cost)
```

### Modelos de Preço (Exemplo)

| Modelo | Input | Output | Custo/1M tokens |
|--------|-------|--------|-----------------|
| Claude 3.5 Sonnet | $3/1M | $15/1M | $3.80 (avg) |
| GPT-4 Turbo | $10/1M | $30/1M | $12.33 (avg) |
| GPT-4o | $5/1M | $15/1M | $6.67 (avg) |

### Fonte de Dados

| Tabela | Campo | Descrição |
|--------|-------|-----------|
| `chat_message` | tokens_used, latency_ms, model | Cada requisição rastreada |
| `chat_conversation` | user_id | Para agregar por usuário |

### Exemplo de Payload

```json
{
  "period": "30d",
  "summary": {
    "total_tokens": 1234567,
    "total_cost_usd": 234.56,
    "cost_per_interaction": 0.10,
    "cost_per_user": 1.23,
    "avg_latency_ms": 1240
  },
  "by_model": {
    "claude-sonnet": {
      "tokens": 800000,
      "cost_usd": 152.00,
      "percent": 65,
      "avg_quality": 8.5
    },
    "gpt-4": {
      "tokens": 434567,
      "cost_usd": 82.56,
      "percent": 35,
      "avg_quality": 8.2
    }
  },
  "cost_vs_revenue": {
    "ai_cost_percent_of_revenue": 8.5,
    "recommendation": "Current model is sustainable"
  }
}
```

---

# 🔗 Mapeamento de Banco de Dados

| Métrica | Tabelas Envolvidas | Campos Principais | Complexidade |
|---------|-------------------|------------------|--------------|
| Taxa de Adesão | logbook, diet_logbook, workout_sheet | status, date, user_id | **Alta** (agregação) |
| Alunos em Risco | logbook, diet_logbook, user | status, date, last_login | **Alta** (scoring) |
| Progresso de Metas | goal, goal_progress_entries | current_value, target_value | **Média** (cálculo simples) |
| Engajamento Diário | step_log, logbook, auth logs | date, user_id | **Média** (contagem) |
| Funil de Vendas | invitation, user | created_at, used_at, trainer_id | **Baixa** (contagem) |
| Portfolio de Trainers | user, logbook, diet_logbook | trainer_id, is_active | **Alta** (múltiplos joins) |
| Saúde do Sistema | logbook, diet_logbook, step_log, auth logs | date, user_id | **Média** (agregação por dia) |
| Adoção de Chatbot | chat_conversation, chat_feedback | user_id, was_helpful | **Baixa** (contagem) |
| Custo de IA | chat_message | tokens_used, model, latency_ms | **Baixa** (soma) |

---

# 🚀 Roadmap Futuro

### Fase 2 (Q3 2026)
- [ ] Exportação de relatórios em PDF com gráficos
- [ ] Alertas automáticos por email/SMS
- [ ] Dashboards personalizáveis por usuário
- [ ] Cache Redis para queries pesadas

### Fase 3 (Q4 2026)
- [ ] Previsão de churn com ML (XGBoost)
- [ ] Análise de cohort (quando os alunos foram adquiridos)
- [ ] LTV (Lifetime Value) por cohort e trainer
- [ ] CAC (Customer Acquisition Cost) por canal

### Fase 4 (Q1 2027)
- [ ] Relatórios automáticos (email semanal/mensal)
- [ ] Webhook de alertas para Slack/Teams
- [ ] Integração com BI tools (Metabase, Looker)
- [ ] API pública para partners analisarem dados

---

# 📞 Perguntas Frequentes

**P: Por que não rastreamos MRR/Receita?**  
R: Não há modelo Payment no banco de dados atual. Isto é out-of-scope até integração com gateway (Stripe, PagSeguro).

**P: Como definimos "plano" para dieta se nem todo aluno tem dieta?**  
R: Alunos sem dieta ativa não entram na métrica de Adherence (excluem-se da agregação).

**P: Qual é a frequência de atualização das métricas?**  
R: Agregações são calculadas **on-demand** via API (sem cache inicial). Futura: atualizar a cada 1 hora.

**P: Podemos enviar alertas automáticos?**  
R: Sim, Fase 1 inclui notificações via FCM. Futura: SMS, email, Slack.

---

**Próximas Ações:**
1. ✅ Especificação validada
2. ⏳ Implementar endpoints backend (`admin_metrics.py`)
3. ⏳ Implementar dashboard frontend
4. ⏳ Testes integrados

