# 📊 Análise de PRDs Faltantes - OmniConnect Fitness

**Data da Análise:** 22 de Abril de 2026  
**Comparação:** Requisitos_OmniConnect_Fitness.pdf vs. Pasta `/docs`

---

## 📋 Resumo Executivo

| Item | Total | Cobertos | Faltantes | % Cobertura |
|------|-------|----------|-----------|-------------|
| **Módulos** | 10 | 7 | **3** | 70% ✅ |
| **Requisitos Funcionais** | 58 | 48 | **10** | 83% ✅ |
| **Requisitos Não-Funcionais** | 12 | 0 | **12** | 0% ⚠️ |

---

## ✅ PRDs Existentes e Criados (7 PRDs)

### 1. **PRD_USUARIOS.md** ✅ PRONTO
- **Status:** Aprovado
- **Módulo:** Autenticação e Perfis de Usuário (RF-01 até RF-07)
- **Responsável:** David Oliveira
- **Data de Criação:** 2026-04-14
- **Cobertura:**
  - ✅ RF-01: Cadastro via WhatsApp (conversacional)
  - ✅ RF-02: Login com email/senha + JWT
  - ✅ RF-03: Perfil com foto, nome, data, peso, altura, objetivo
  - ✅ RF-04: Diferentes níveis de acesso (Aluno, Personal, Gestor)
  - ✅ RF-05: Gerenciar contas (criar, editar, desativar)
  - ⚠️ RF-06: Recuperação de senha via email (pendente para MVP 2)
  - ✅ RF-07: Resumo de metas e métricas

---

### 2. **PRD_FICHA_TREINO.md** 📋 EM REVISÃO
- **Status:** Em Revisão
- **Módulo:** Montagem de Ficha de Treino (RF-08 até RF-14)
- **Responsável:** José Henrique
- **Data de Criação:** 2026-04-19
- **Cobertura:**
  - ✅ RF-08: Criar fichas com múltiplos exercícios
  - ✅ RF-09: Detalhes de exercício (nome, séries, reps, carga, descanso)
  - ✅ RF-10: Suporte a imagem/GIF demonstrativo
  - ⚠️ RF-11: Ficha como checklist interativo (futuro MVP 2)
  - ✅ RF-12: Atribuir fichas para dias distintos
  - ✅ RF-13: Duplicar e editar fichas
  - ✅ RF-14: Histórico de fichas

---

### 3. **PRD_CADASTRO_WHATSAPP.md** 📋 EM ESPECIFICAÇÃO
- **Status:** Em Especificação
- **Módulo:** Cadastro Inicial via WhatsApp (RF-54 até RF-58)
- **Responsável:** David Oliveira
- **Data de Criação:** 2026-04-20
- **Cobertura:**
  - ✅ RF-54: Fluxo conversacional via WhatsApp Cloud API (com OTP)
  - ✅ RF-55: Chatbot coleta dados (nome, data, peso, altura, objetivo)
  - ✅ RF-56: Criar automaticamente perfil no banco
  - ⚠️ RF-57: Notificar Gestor de novo cadastro (integra com Notificações)
  - ✅ RF-58: Sincronização <2s após conclusão

---

### 4. **PRD_LOGBOOK.md** 🟢 CRIADO
- **Status:** Em Especificação
- **Módulo:** Logbook (Diário de Treino) - RF-15 até RF-20
- **Responsável:** José Henrique
- **Data de Criação:** 2026-04-21
- **Cobertura:**
  - ✅ RF-15: Aluno registrar pesos, séries e repetições efetivamente executadas
  - ✅ RF-16: Logbook vinculado à ficha de treino ativa, pré-populando exercícios
  - ✅ RF-17: Sistema calcular e exibir evolução de carga ao longo do tempo
  - ✅ RF-18: Aluno adicionar notas livres (texto) a cada sessão registrada
  - ✅ RF-19: Personal ter acesso de leitura ao logbook dos alunos
  - ✅ RF-20: Logbook exibir calendário com dias realizados e não realizados
- **Dependências:** PRD_FICHA_TREINO (RF-16 depende de ficha ativa)
- **Complexidade:** Alta (sincronização, cálculos, permissões)

---

### 5. **PRD_METAS.md** 🟢 CRIADO
- **Status:** Em Especificação
- **Módulo:** Metas Alcançadas - RF-27 até RF-31
- **Responsável:** William
- **Data de Criação:** 2026-04-21
- **Cobertura:**
  - ✅ RF-27: Personal e Aluno definirem metas mensuráveis (ex: aumentar supino 10kg)
  - ✅ RF-28: Sistema calcular automaticamente progresso percentual
  - ✅ RF-29: Notificação comemorativa ao atingir meta (integra com Notificações)
  - ✅ RF-30: Histórico de metas concluídas e em andamento
  - ✅ RF-31: Suporte a múltiplas categorias: força, resistência, composição, frequência
- **Dependências:** PRD_LOGBOOK (dados de progresso)
- **Complexidade:** Média (CRUD + cálculos)

---

### 6. **PRD_CALCULO_CORPORAL.md** 🟢 CRIADO
- **Status:** Em Especificação
- **Módulo:** Cálculo de Composição Corporal - RF-32 até RF-36
- **Responsável:** Gabriel
- **Data de Criação:** 2026-04-21
- **Cobertura:**
  - ✅ RF-32: Sistema calcular IMC com peso e altura
  - ✅ RF-33: Sistema calcular TMB (Taxa Metabólica Basal) - Harris-Benedict/Mifflin-St Jeor
  - ✅ RF-34: Permitir registro periódico de medidas corporais (circunferências, % gordura)
  - ✅ RF-35: Exibir gráficos de evolução de peso e medidas
  - ✅ RF-36: Calcular gasto calórico diário estimado (atividade física)
- **Dependências:** PRD_USUARIOS (altura/peso no perfil)
- **Complexidade:** Média (cálculos matemáticos + gráficos)

---

### 7. **PRD_NOTIFICACOES.md** 🟢 CRIADO
- **Status:** Em Especificação
- **Módulo:** Notificações - RF-37 até RF-42
- **Responsável:** David Oliveira
- **Data de Criação:** 2026-04-21
- **Cobertura:**
  - ✅ RF-37: Enviar notificação push (FCM) para lembrar treino do dia
  - ✅ RF-38: Enviar lembretes de horários de refeições configurados
  - ✅ RF-39: Aluno configurar horários de notificações individuais
  - ✅ RF-40: Notificar Personal quando aluno não registra treino (período)
  - ✅ RF-41: Notificar Aluno quando nova ficha é atribuída
  - ✅ RF-42: Silenciar categorias de notificação granularmente
- **Stack:** Firebase Cloud Messaging (FCM)
- **Dependências:** PRD_FICHA_TREINO, PRD_LOGBOOK
- **Complexidade:** Média (integração com Firebase + agendamento)

---

## ❌ PRDs Faltantes (3 CRÍTICOS)

### **1. PRD_ANALISE_IA.md** 🔴 FALTANDO
**Módulo:** Análise de Inteligência Artificial - RF-21 até RF-26

| ID | Requisito | Prioridade |
|----|-----------|-----------|
| RF-21 | IA analisar histórico de treinos do aluno e gerar relatórios periódicos de progresso | 🔴 Alta |
| RF-22 | IA sugerir ajustes de carga ou volume com base na evolução registrada no logbook | 🔴 Alta |
| RF-23 | IA detectar padrões de estagnação (ausência de progressão de carga) e alertar o Personal | 🟡 Média |
| RF-24 | IA utilizar RAG para embasar respostas em dados reais do aluno, evitando alucinações | 🔴 Alta |
| RF-25 | Relatórios de IA devem ser acessíveis tanto pelo Aluno quanto pelo Personal/Professor | 🟡 Média |
| RF-26 | IA gerar uma análise de compatibilidade entre plano alimentar e metas do aluno | 🟢 Baixa |

**Dependências:** PRD_LOGBOOK (análise de dados históricos), PRD_METAS (comparação com metas)  
**Stack:** LangChain + RAG + pgvector (PostgreSQL)  
**Complexidade:** Muito Alta (IA/ML, prompt engineering, vector embeddings)  
**Estimativa:** 2-3 semanas (requer expertise em LLMs/RAG)

---

### **2. PRD_DASHBOARD_PROFISSIONAL.md** 🔴 FALTANDO
**Módulo:** Dashboard de Análise para Profissionais - RF-43 até RF-48

| ID | Requisito | Prioridade |
|----|-----------|-----------|
| RF-43 | Dashboard exibir lista de alunos ativos com indicadores de frequência e progresso | 🔴 Alta |
| RF-44 | Personal visualizar, por aluno, os últimos treinos registrados, metas alvo e alertas da IA | 🔴 Alta |
| RF-45 | Dashboard deve apresentar gráficos de frequência semanal/mensal por aluno | 🔴 Alta |
| RF-46 | Gestor deve ter visão consolidada de todos os alunos e profissionais da academia | 🔴 Alta |
| RF-47 | Dashboard deve permitir filtros por aluno, período e grupo de treino | 🟡 Média |
| RF-48 | Sistema deve exportar relatórios do dashboard em PDF | 🟢 Baixa |

**Dependências:** PRD_LOGBOOK, PRD_ANALISE_IA, PRD_METAS  
**Complexidade:** Alta (agregações, gráficos, múltiplas permissões)  
**Estimativa:** 1-2 semanas (após PRD_LOGBOOK e PRD_ANALISE_IA)

---

### **3. PRD_CHATBOT_DUVIDAS.md** 🔴 FALTANDO
**Módulo:** Chatbot de Dúvidas - RF-49 até RF-53

| ID | Requisito | Prioridade |
|----|-----------|-----------|
| RF-49 | Chatbot responder dúvidas dos alunos sobre exercícios, execução e nomenclatura com base na base de conhecimento da academia (RAG) | 🔴 Alta |
| RF-50 | Chatbot deve ter acesso ao perfil e ficha ativa do aluno para contextualizar suas respostas | 🔴 Alta |
| RF-51 | Chatbot deve estar disponível dentro do app e via WhatsApp | 🔴 Alta |
| RF-52 | Se não conseguir responder, chatbot deve escalar para o Personal via notificação | 🟡 Média |
| RF-53 | Histórico de conversas com o chatbot deve ser armazenado e acessível pelo aluno | 🟡 Média |

**Stack:** LangChain + RAG + WhatsApp Cloud API  
**Dependências:** PRD_CADASTRO_WHATSAPP, PRD_ANALISE_IA  
**Complexidade:** Muito Alta (IA conversacional, múltiplos canais)  
**Estimativa:** 2-3 semanas (requer expertise em LLMs + integração multi-canal)

---

## ⚠️ Requisitos Não-Funcionais (RNF) - CRÍTICOS

**Todos os 12 RNFs faltam de PRDs específicos, mas devem ser integrados em todos os módulos:**

| ID | Requisito | Prioridade | Observação | Status |
|----|-----------|-----------|-----------|--------|
| RNF-01 | Sincronização WhatsApp ↔ App <2s | 🔴 Alta | Integrado em PRD_CADASTRO_WHATSAPP | ✅ |
| RNF-02 | Backend suporta ≥200 requisições simultâneas sem degradação | 🔴 Alta | Performance engineering | ❌ |
| RNF-03 | Comunicações via HTTPS/TLS 1.3 | 🔴 Alta | Infra/DevOps | ❌ |
| RNF-04 | Senhas hash bcrypt (custo mínimo 12) | 🔴 Alta | Integrado em PRD_USUARIOS | ✅ |
| RNF-05 | JWT expira 24h; refresh token 30 dias | 🔴 Alta | Integrado em PRD_USUARIOS | ✅ |
| RNF-06 | App Flutter Android 8.0+ e iOS 13+ | 🔴 Alta | Compatibilidade | ❌ |
| RNF-07 | Disponibilidade 99,5% (máx 3,6h/mês downtime) | 🔴 Alta | SLA/Infra | ❌ |
| RNF-08 | Tempo resposta telas principais <1,5s (4G) | 🟡 Média | Otimização/Performance | ❌ |
| RNF-09 | Backup automático diário, retenção 30 dias | 🔴 Alta | Infra | ❌ |
| RNF-10 | Conformidade LGPD (dados pessoais/saúde) | 🔴 Alta | Legal/Compliance | ❌ |
| RNF-11 | Cobertura mínima 70% testes automatizados | 🟡 Média | QA/Testing | ❌ |
| RNF-12 | Deploy via LXC (Linux Containers) | 🟡 Média | DevOps/Infra | ❌ |

**⚠️ Recomendação:** Criar **PRD_REQUISITOS_NAO_FUNCIONAIS.md** com especificações de performance, segurança, infra e compliance.

---

## 🎯 Ordem de Priorização Recomendada

### **Fase 1 (MVP 1) - Semanas 1-2** ✅ PRONTO PARA IMPLEMENTAR
```
1. ✅ PRD_USUARIOS.md (PRONTO - fazer review final)
2. ✅ PRD_FICHA_TREINO.md (PRONTO - fazer review final)
3. ✅ PRD_CADASTRO_WHATSAPP.md (QUASE PRONTO - ajustes finais)
```
**Status:** 7 dias de desenvolvimento esperados

---

### **Fase 2 (MVP 2) - Semanas 3-4** ⚠️ EM ESPECIFICAÇÃO
```
4. 🟢 PRD_LOGBOOK.md (CRIADO - pronto para review)
5. 🟢 PRD_METAS.md (CRIADO - pronto para review)
6. 🟢 PRD_CALCULO_CORPORAL.md (CRIADO - pronto para review)
7. 🟢 PRD_NOTIFICACOES.md (CRIADO - pronto para review)
```
**Status:** Todos criados, aguardando review e ajustes  
**Estimativa:** 10-12 dias de desenvolvimento

---

### **Fase 3 (MVP 3) - Semanas 5-6** 🔴 FALTANDO
```
8. 🔴 PRD_ANALISE_IA.md (CRÍTICO - base para IA)
9. 🔴 PRD_DASHBOARD_PROFISSIONAL.md (Analytics para Profissionais)
10. 🔴 PRD_CHATBOT_DUVIDAS.md (IA conversacional multi-canal)
11. 📋 RNF PRD (Performance/Infra/LGPD)
```
**Status:** Ainda não criados  
**Estimativa:** 15-18 dias de desenvolvimento (requer expertise em LLMs)

---

## 📊 Mapeamento de Dependências

```
┌─────────────────────────────────────────────────────────────┐
│                    PRD_USUARIOS ✅                          │
│         (Base: Autenticação + Perfil + Roles)              │
└──────────────┬──────────────────────────────────────────────┘
               │
      ┌────────┴────────┬──────────────────────────┐
      ▼                 ▼                          ▼
┌──────────────────┐   ┌────────────────────────┐  ┌──────────────────┐
│ PRD_FICHA_TREINO │   │ PRD_CADASTRO_WHATSAPP  │  │ PRD_CALCULO_CORP │
│     ✅ (RF-08-14)│   │     ✅ (RF-54-58)      │  │   🟢 (RF-32-36)  │
└────────┬─────────┘   └────────┬───────────────┘  └──────────────────┘
         │                      │
         ▼                      ▼
    ┌──────────────────┐    ┌────────────────────┐
    │ PRD_LOGBOOK 🟢   │    │ PRD_NOTIFICACOES   │
    │  (RF-15-20)      │    │   🟢 (RF-37-42)   │
    └────┬─────────────┘    └────────────────────┘
         │                          ▲
    ┌────┴──────────────────────────┘
    ▼
┌─────────────────────┐
│ PRD_METAS 🟢        │
│  (RF-27-31)         │
└──────────┬──────────┘
           │
    ┌──────┴──────────────────────────────┐
    ▼                                     ▼
┌─────────────────────┐      ┌──────────────────────┐
│ PRD_ANALISE_IA 🔴   │      │ PRD_CHATBOT_DUVIDAS  │
│  (RF-21-26)         │      │     🔴 (RF-49-53)    │
└────┬────────────────┘      └──────┬───────────────┘
     │                              │
     └──────────────┬───────────────┘
                    ▼
          ┌──────────────────────┐
          │ PRD_DASHBOARD 🔴     │
          │  (RF-43-48)          │
          └──────────────────────┘

Legenda:
✅ = Pronto
🟢 = Criado (em especificação)
🔴 = Faltando
```

---

## 📈 Status de Cobertura por Fase

| Fase | PRDs | RF Cobertos | RNF Cobertos | % Cobertura RF | % Cobertura RNF |
|------|------|-------------|--------------|----------------|-----------------|
| MVP 1 | 3 | 23/58 | 3/12 | **40%** | 25% |
| MVP 1+2 | 7 | 48/58 | 3/12 | **83%** ✅ | 25% |
| MVP 1+2+3 | 11 | 58/58 | 3/12 | **100%** ✅ | 25% |
| Com RNF PRD | 12 | 58/58 | 12/12 | **100%** ✅ | **100%** ✅ |

---

## 📝 Próximos Passos

### ✅ Esta Semana (Até 2026-04-25)
- [ ] **Review final** PRD_USUARIOS com stakeholders
- [ ] **Review final** PRD_FICHA_TREINO com stakeholders
- [ ] **Review final** PRD_CADASTRO_WHATSAPP com stakeholders
- [ ] **Iniciar implementação** dos 3 PRDs de MVP 1
- [ ] Agendas de review com Product Owner

### 📋 Próxima Semana (2026-04-28 até 2026-05-02)
- [ ] **Review detalhado** PRD_LOGBOOK (8h)
- [ ] **Review detalhado** PRD_METAS (4h)
- [ ] **Review detalhado** PRD_CALCULO_CORPORAL (4h)
- [ ] **Review detalhado** PRD_NOTIFICACOES (6h)
- [ ] Ajustes finais baseado em feedback
- [ ] **Iniciar implementação** dos 4 PRDs de MVP 2

### 🔴 Semana 2-3 (2026-05-05 até 2026-05-16)
- [ ] **Criar PRD_ANALISE_IA.md** (requer expertise LLM)
- [ ] **Criar PRD_DASHBOARD_PROFISSIONAL.md**
- [ ] **Criar PRD_CHATBOT_DUVIDAS.md** (requer expertise LLM + multi-canal)
- [ ] **Criar PRD_REQUISITOS_NAO_FUNCIONAIS.md** (Performance, Security, Compliance)
- [ ] Definir timeline com equipe de IA
- [ ] Avaliar ferramentas LLM (LangChain, LlamaIndex, etc)

---

## 🔍 Análise de Requisitos

### RF Mapeados por Módulo

| Módulo | RFs | Status | Observações |
|--------|-----|--------|-------------|
| Usuários | RF-01 a RF-07 | ✅ 7/7 | Pronto (PRD_USUARIOS) |
| Ficha de Treino | RF-08 a RF-14 | ✅ 7/7 | Pronto (PRD_FICHA_TREINO) |
| Logbook | RF-15 a RF-20 | 🟢 6/6 | Criado (PRD_LOGBOOK) |
| Análise de IA | RF-21 a RF-26 | 🔴 0/6 | **FALTANDO** |
| Metas | RF-27 a RF-31 | 🟢 5/5 | Criado (PRD_METAS) |
| Cálculo Corporal | RF-32 a RF-36 | 🟢 5/5 | Criado (PRD_CALCULO_CORPORAL) |
| Notificações | RF-37 a RF-42 | 🟢 6/6 | Criado (PRD_NOTIFICACOES) |
| Dashboard | RF-43 a RF-48 | 🔴 0/6 | **FALTANDO** |
| Chatbot | RF-49 a RF-53 | 🔴 0/5 | **FALTANDO** |
| Cadastro WhatsApp | RF-54 a RF-58 | ✅ 5/5 | Pronto (PRD_CADASTRO_WHATSAPP) |
| **TOTAL** | **58** | **48/58** | **83% ✅** |

### RNF Críticos Não Mapeados

- ❌ RNF-02: Performance (200 req/s)
- ❌ RNF-03: HTTPS/TLS 1.3
- ❌ RNF-06: Compatibilidade Flutter
- ❌ RNF-07: Disponibilidade 99,5%
- ❌ RNF-08: Latência <1,5s (4G)
- ❌ RNF-09: Backup diário
- ❌ RNF-10: Conformidade LGPD
- ❌ RNF-11: Cobertura 70% testes
- ❌ RNF-12: Deploy LXC

---

## 💡 Recomendações Finais

### ✅ O Que Fazer

1. **Esta semana:**
   - ✅ Review rápido dos 3 PRDs prontos (MVP 1)
   - ✅ Iniciar implementação imediatamente
   - ✅ Agendar review detalhado dos 4 PRDs criados

2. **Próxima semana:**
   - ✅ Finalizar review dos 4 PRDs (MVP 2)
   - ✅ Iniciar implementação após aprovação
   - ✅ Comunicar timeline de RNFs + IA para stakeholders

3. **Comunicar a leadership:**
   - 📊 70% dos requisitos já têm PRDs especificados
   - 📊 MVP 1+2 cobre 83% dos RF (implementável em 3-4 semanas)
   - ⚠️ MVP 3 requer expertise em LLMs (RAG, prompt engineering)
   - ⚠️ RNFs devem ser abordados em paralelo (Performance, Infra, LGPD)

### ❌ O Que NÃO Fazer

- ❌ Começar PRD_ANALISE_IA sem ter PRD_LOGBOOK pronto + dados
- ❌ Pular RNFs (LGPD, Performance, Backup são críticos)
- ❌ Implementar Chatbot/IA sem RAG (vai ter alucinações)
- ❌ Dashboard sem agregações + cache (vai ficar lento)
- ❌ Ignorar Performance (200 req/s é baseline)

---

## 📞 Próximos Passos de Ação

### Imediato (Hoje - 2026-04-22)
1. Compartilhar análise com Product Owner
2. Agendar reviews dos 7 PRDs existentes
3. Definir slots de implementação

### Curto Prazo (Esta semana)
1. Executar reviews dos 3 PRDs MVP 1
2. Ajustar baseado em feedback
3. Iniciar desenvolvimento

### Médio Prazo (Próximas 2 semanas)
1. Review dos 4 PRDs MVP 2
2. Iniciar desenvolvimento
3. Começar planejamento dos 3 PRDs faltantes

### Longo Prazo (3-4 semanas)
1. Criar PRD_ANALISE_IA
2. Criar PRD_DASHBOARD_PROFISSIONAL
3. Criar PRD_CHATBOT_DUVIDAS
4. Criar PRD_REQUISITOS_NAO_FUNCIONAIS
5. Iniciar implementação MVP 3

---

*Gerado automaticamente - Claude Code*  
*Análise completa com especificações de requisitos PDF*  
**Última atualização:** 2026-04-22 às 14:32
