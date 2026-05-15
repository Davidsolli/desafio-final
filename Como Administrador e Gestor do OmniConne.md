# 📊 Painel de Controle Estratégico - OmniConnect Fitness

**Status:** ✅ Validado e Refatorado  
**Data:** 2026-05-12  
**Documento Técnico Completo:** [ADMIN_DASHBOARD_SPEC.md](docs/ADMIN_DASHBOARD_SPEC.md)

---

## 🎯 Visão Executiva

Como Administrador e Gestor do OmniConnect Fitness, consolidei aqui o **"Painel de Controle Estratégico"** que governa a saúde do negócio.

**Temos 3 focos estratégicos:**
1. ✅ **Retenção de Alunos** → Alunos com metas batidas = clientes retidos
2. ✅ **Escala de Trainers** → Trainers com volume saudável = receita crescente
3. ✅ **Saúde Operacional** → Custos de IA vs. Receita = rentabilidade

**Status da Infraestrutura:** 💯 100% dos dados existem no banco. Prontos para APIs e dashboards.

---

## 🎓 SEÇÃO 1: MÉTRICAS DE ALUNO (Retenção e Resultado)

### 1.1 Taxa de Adesão (Adherence Rate) ⭐ CRÍTICA

**O que é:** % de sessões de treino **E** dieta completadas vs planejadas.

**Por que importa:**
- Alunos com adherence > 80% batem metas e renovam ✅
- Alunos com adherence < 50% fazem churn ❌
- É o **#1 preditor** de satisfação e permanência

**Fórmula:**
```
Adherence_Rate = (Sessões_Completadas + Refeições_Registradas) 
                 / (Sessões_Planejadas + Refeições_Planejadas) × 100
```

**Fonte:** 
- `logbook.status = 'completed'` → treinos realizados
- `diet_logbook.date` → refeições registradas
- `workout_sheet` → planejamento

**Onde rastrear:**
- ✅ Painel do Admin (média por período)
- ✅ Perfil do Aluno (rastreamento individual)
- ✅ Perfil do Trainer (média dos seus alunos)

---

### 1.2 Alunos em Risco (At-Risk Students) 🚨 PRIORIDADE

**O que é:** Identificação automática de quem vai fazer **churn em 30 dias**.

**Sinais de Risco:**
- Adherence < 50% por 14 dias consecutivos
- Último login > 7 dias atrás
- Sessões puladas 3x seguidas

**Por que importa:** Intervenção proativa reduz churn em até 40%.

**Categoria de Risco:**
- 🔴 **Crítico** (≤30% aderência) → Risco em 7 dias
- 🟠 **Alto** (30-50% aderência) → Risco em 14 dias
- 🟡 **Médio** (50-70% aderência) → Risco em 30 dias

**Ações Recomendadas:**
| Risco | Ação | Responsável |
|-------|------|-------------|
| Crítico | Notif + SMS ao PT | Admin/Sistema |
| Alto | Email automático | Sistema |
| Médio | Badge no dashboard | Dashboard |

---

### 1.3 Progresso de Metas (Goal Progress) ✨ PROVA SOCIAL

**O que é:** % de avanço rumo ao objetivo final (peso, força, resistência).

**Fórmula:**
```
Progress = (valor_atual - valor_inicial) / (valor_meta - valor_inicial) × 100
```

**Insights derivados:**
- Metas 100% completas (sucesso!)
- Metas no ritmo (velocity ok)
- Metas paradas >30 dias (em risco)

**Por que importa:** Mostrar progresso justifica permanência na plataforma.

---

### 1.4 Engajamento Diário (Daily Activity) 📱 ENGAGEMENT

**O que é:** Interação fora do treino formal (passos, app opens, chats).

**Métrica:** DAU (Daily Active Users) — usuários com ≥1 ação/dia

**Por que importa:**
- Gamificação mantém usuário ativo mesmo sem academia
- ↑ DAU = ↑ oportunidades de monetização
- Sistema de handicap garante streaks

**Fonte:** `step_log`, `notification_log`, auth logs

---

## 💼 SEÇÃO 2: MÉTRICAS DE PERSONAL TRAINER (Escala e Vendas)

### 2.1 Funil de Vendas (Sales Funnel) 🎯 TOP PERFORMER

**O que é:** Convites gerados vs. resgates por trainer.

**Fórmula:**
```
Conversion_Rate = (Convites_Usados / Convites_Gerados) × 100
```

**Exemplo:**
- PT gerou 50 convites
- 35 foram resgatados
- Conversion = 70% ✅

**Por que importa:**
- Identifica "top performers"
- Sinaliza quem precisa de suporte de vendas
- Mostra ROI do programa de indicações

**Fonte:** `invitation` table (created_at, used_at, trainer_id)

---

### 2.2 Capacidade de Atendimento (Portfolio) 👥 ESCALA

**O que é:** Volume de alunos ativos gerenciados por trainer.

**Métricas:**
- Total Students: quantos alunos tem
- Active Students: com aderência > 30% últimos 14 dias
- At-Risk Students: aderência < 50% (precisam atenção)

**Health Score:**
```
Portfolio_Health = (Active_Students / Total_Students) × 100
```

**Benchmarks:**
- ✅ > 80% = portfolio saudável
- ⚠️ 50-80% = precisa atenção
- ❌ < 50% = crítico (churn em massa)

---

## 🖥️ SEÇÃO 3: MÉTRICAS DE NEGÓCIO (Sistema e IA)

### 3.1 Saúde do Sistema (System Health) 📈 GROWTH

**Métricas principais:**
- **DAU** = Daily Active Users
- **MAU** = Monthly Active Users
- **DAU/MAU Ratio** = indicador de saúde

**Interpretação:**
- 0.5+ = excelente (50% dos MAU voltam todo dia)
- 0.3-0.5 = bom
- < 0.3 = em risco (baixa retorno)

**Trend:** Detecta crescimento ou churn em massa

---

### 3.2 Adoção de IA (Chatbot Adoption) 🤖 ROI

**Métrica:** % de usuários que usaram chatbot × Qualidade das respostas

**Fórmula:**
```
Adoption_Rate = (Usuários_Com_Chat / Total_Usuários) × 100
Quality_Score = (Respostas_Úteis / Total_Respostas) × 100
```

**Por que importa:**
- Mostra ROI do investimento em IA
- Mede autonomia do aluno (menos tickets para PT)
- Base para decisões de expansão

---

### 3.3 Custo de IA (IA Economics) 💰 MARGIN

**O que rastreamos:**
- `chat_message.tokens_used` → custo por requisição
- `chat_message.latency_ms` → performance
- `chat_message.model` → qual modelo está sendo usado

**Cálculos:**
```
Custo_Por_Interação = (Total_Tokens × Preço_Modelo) / Número_Mensagens
Custo_Por_Usuário = Soma_Tokens / Usuários_Distintos
```

**Modelos (exemplo de preço):**
| Modelo | Custo/1M tokens |
|--------|-----------------|
| Claude 3.5 Sonnet | $3.80 |
| GPT-4 Turbo | $12.33 |
| GPT-4o | $6.67 |

**Alerta:** Se custo/user > X, revisar modelo ou pricing.

---

## ✅ Status de Implementação

| Métrica | BD | API | Dashboard |
|---------|----|----|-----------|
| Taxa de Adesão | ✅ | ⏳ | ⏳ |
| Alunos em Risco | ✅ | ⏳ | ⏳ |
| Progresso de Metas | ✅ | ⏳ | ⏳ |
| Engajamento Diário | ✅ | ⏳ | ⏳ |
| Funil de Vendas | ✅ | ⏳ | ⏳ |
| Portfolio de Trainers | ✅ | ⏳ | ⏳ |
| Saúde do Sistema | ✅ | ⏳ | ⏳ |
| Adoção de IA | ✅ | ⏳ | ⏳ |
| Custo de IA | ✅ | ⏳ | ⏳ |

**BD** = Banco de dados (modelos + campos)  
**API** = Endpoints REST para servir dados  
**Dashboard** = UI para visualizar e filtrar

---

## 📞 Próximas Ações

### Fase 1 (Hoje) ✅
- [x] Especificação técnica validada
- [x] Documento refatorado com fórmulas e fontes
- [ ] Revisão final com time

### Fase 2 (Esta semana)
- [ ] Implementar 4 endpoints backend:
  - `GET /api/v1/admin/metrics/students`
  - `GET /api/v1/admin/metrics/trainers`
  - `GET /api/v1/admin/metrics/system`
  - `GET /api/v1/admin/metrics/ai-analytics`
- [ ] Testes integrados (≥75% cobertura)

### Fase 3 (Próxima semana)
- [ ] Dashboard frontend com 4 cards
- [ ] Filtros avançados
- [ ] Exportação CSV
- [ ] Sistema de alertas

---

## 📖 Documentação Completa

**Para detalhes técnicos completos, consulte:**  
👉 [docs/ADMIN_DASHBOARD_SPEC.md](docs/ADMIN_DASHBOARD_SPEC.md)

---

## 🎯 Resumo Executivo

✅ **O OmniConnect Fitness já está capacitado tecnicamente para:**
- Medir engajamento e retenção comportamental
- Rastrear performance de trainers
- Analisar custos operacionais de IA
- Fornecer insights poderosos ao admin

❌ **Ausentes para fechar ciclo de negócio (Fase 2):**
- MRR, Receita, Status de Pagamento (requer integração bancária)
- Webhooks para alertas externos (Slack, SMS)
- Cache Redis para otimizar queries
- ML para previsão de churn