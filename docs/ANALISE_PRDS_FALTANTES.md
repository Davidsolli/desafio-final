# 📊 Análise de PRDs Faltantes - OmniConnect Fitness

**Data da Análise:** 21 de Abril de 2026  
**Comparação:** Requisitos_OmniConnect_Fitness.pdf vs. Pasta `/docs`

---

## 📋 Resumo Executivo

| Item | Total | Cobertos | Faltantes | % Cobertura |
|------|-------|----------|-----------|-------------|
| **Módulos** | 10 | 3 | **7** | 30% |
| **Requisitos Funcionais** | 58 | 18 | **40** | 31% |
| **Requisitos Não-Funcionais** | 12 | 0 | **12** | 0% |

---

## ✅ PRDs Existentes

### 1. **PRD_USUARIOS.md** ✅ PRONTO
- **Status:** Aprovado
- **Módulo:** Autenticação e Perfis de Usuário (RF-01 até RF-07)
- **Cobertura:**
  - ✅ RF-01: Cadastro via WhatsApp (conversacional)
  - ✅ RF-02: Login com email/senha + JWT
  - ✅ RF-03: Perfil com foto, nome, data, peso, altura, objetivo
  - ✅ RF-04: Diferentes níveis de acesso (Aluno, Personal, Gestor)
  - ✅ RF-05: Gerenciar contas (criar, editar, desativar)
  - ⚠️ RF-06: Recuperação de senha via email (pendente)
  - ✅ RF-07: Resumo de metas e métricas

### 2. **PRD_FICHA_TREINO.md** 📋 EM REVISÃO
- **Status:** Em Revisão
- **Módulo:** Montagem de Ficha de Treino (RF-08 até RF-14)
- **Cobertura:**
  - ✅ RF-08: Criar fichas com múltiplos exercícios
  - ✅ RF-09: Detalhes de exercício (nome, séries, reps, carga, descanso)
  - ✅ RF-10: Suporte a imagem/GIF demonstrativo
  - ⚠️ RF-11: Ficha como checklist interativo (futuro MVP 2)
  - ✅ RF-12: Atribuir fichas para dias distintos
  - ✅ RF-13: Duplicar e editar fichas
  - ✅ RF-14: Histórico de fichas

### 3. **PRD_CADASTRO_WHATSAPP.md** 📋 EM ESPECIFICAÇÃO
- **Status:** Em Especificação
- **Módulo:** Cadastro Inicial via WhatsApp (RF-54 até RF-58)
- **Cobertura:**
  - ✅ RF-54: Fluxo conversacional via WhatsApp Cloud API
  - ✅ RF-55: Chatbot coleta dados (nome, data, peso, altura, objetivo)
  - ✅ RF-56: Criar automaticamente perfil no banco
  - ⚠️ RF-57: Notificar Gestor de novo cadastro (futuro)
  - ✅ RF-58: Sincronização <2s após conclusão

---

## ❌ PRDs Faltantes (Críticos)

### **1. PRD_LOGBOOK.md** 🔴 FALTANDO
**Módulo:** Logbook (Diário de Treino) - RF-15 até RF-20

| ID | Requisito | Prioridade |
|----|-----------|-----------|
| RF-15 | Aluno registrar pesos, séries e repetições efetivamente executadas | 🔴 Alta |
| RF-16 | Logbook vinculado à ficha de treino ativa, pré-populando exercícios | 🔴 Alta |
| RF-17 | Sistema calcular e exibir evolução de carga ao longo do tempo | 🔴 Alta |
| RF-18 | Aluno adicionar notas livres (texto) a cada sessão registrada | 🟡 Média |
| RF-19 | Personal ter acesso de leitura ao logbook dos alunos | 🔴 Alta |
| RF-20 | Logbook exibir calendário com dias realizados e não realizados | 🟡 Média |

**Dependências:** PRD_FICHA_TREINO (RF-16 depende de ficha ativa)  
**Complexidade:** Alta (sincronização, cálculos, permissões)

---

### **2. PRD_ANALISE_IA.md** 🔴 FALTANDO
**Módulo:** Análise de Inteligência Artificial - RF-21 até RF-26

| ID | Requisito | Prioridade |
|----|-----------|-----------|
| RF-21 | IA analisar histórico de treinos e gerar relatórios periódicos | 🔴 Alta |
| RF-22 | IA sugerir ajustes de carga ou volume com base na evolução | 🔴 Alta |
| RF-23 | IA detectar padrões de estagnação e alertar Personal | 🟡 Média |
| RF-24 | IA utilizar RAG para consultar base de conhecimento (evitar alucinações) | 🔴 Alta |
| RF-25 | Relatórios acessíveis por Aluno e Personal/Professor | 🟡 Média |
| RF-26 | IA gerar análise de compatibilidade entre plano alimentar e metas | 🟢 Baixa |

**Dependências:** PRD_LOGBOOK (análise de dados históricos)  
**Stack:** LangChain + RAG + pgvector (PostgreSQL)  
**Complexidade:** Muito Alta (IA/ML, prompt engineering, vector embeddings)

---

### **3. PRD_METAS.md** 🔴 FALTANDO
**Módulo:** Metas Alcançadas - RF-27 até RF-31

| ID | Requisito | Prioridade |
|----|-----------|-----------|
| RF-27 | Personal e Aluno definirem metas mensuráveis (ex: aumentar supino 10kg) | 🔴 Alta |
| RF-28 | Sistema calcular automaticamente progresso percentual | 🔴 Alta |
| RF-29 | Notificação comemorativa ao atingir meta | 🔴 Alta |
| RF-30 | Histórico de metas concluídas e em andamento | 🟡 Média |
| RF-31 | Suporte a múltiplas categorias: força, resistência, composição, frequência | 🟡 Média |

**Dependências:** PRD_LOGBOOK (dados de progresso)  
**Complexidade:** Média (CRUD + cálculos)

---

### **4. PRD_CALCULO_CORPORAL.md** 🔴 FALTANDO
**Módulo:** Cálculo de Composição Corporal - RF-32 até RF-36

| ID | Requisito | Prioridade |
|----|-----------|-----------|
| RF-32 | Sistema calcular IMC com peso e altura | 🔴 Alta |
| RF-33 | Sistema calcular TMB (Taxa Metabólica Basal) - Harris-Benedict/Mifflin-St Jeor | 🔴 Alta |
| RF-34 | Permitir registro periódico de medidas corporais (circunferências, % gordura) | 🔴 Alta |
| RF-35 | Exibir gráficos de evolução de peso e medidas | 🔴 Alta |
| RF-36 | Calcular gasto calórico diário estimado (atividade física) | 🟡 Média |

**Dependências:** PRD_USUARIOS (altura/peso no perfil)  
**Complexidade:** Média (cálculos matemáticos + gráficos)

---

### **5. PRD_NOTIFICACOES.md** 🔴 FALTANDO
**Módulo:** Notificações - RF-37 até RF-42

| ID | Requisito | Prioridade |
|----|-----------|-----------|
| RF-37 | Enviar notificação push (FCM) para lembrar treino do dia | 🔴 Alta |
| RF-38 | Enviar lembretes de horários de refeições configurados | 🔴 Alta |
| RF-39 | Aluno configurar horários de notificações individuais | 🟡 Média |
| RF-40 | Notificar Personal quando aluno não registra treino (período) | 🟡 Média |
| RF-41 | Notificar Aluno quando nova ficha é atribuída | 🔴 Alta |
| RF-42 | Silenciar categorias de notificação granularmente | 🟢 Baixa |

**Stack:** Firebase Cloud Messaging (FCM)  
**Dependências:** PRD_FICHA_TREINO, PRD_LOGBOOK  
**Complexidade:** Média (integração com Firebase + agendamento)

---

### **6. PRD_DASHBOARD_PROFISSIONAL.md** 🔴 FALTANDO
**Módulo:** Dashboard de Análise para Profissionais - RF-43 até RF-48

| ID | Requisito | Prioridade |
|----|-----------|-----------|
| RF-43 | Dashboard exibir lista de alunos ativos com frequência e progresso | 🔴 Alta |
| RF-44 | Personal visualizar últimos treinos registrados, metas e alertas IA | 🔴 Alta |
| RF-45 | Gráficos de frequência semanal/mensal por aluno | 🔴 Alta |
| RF-46 | Gestor ver visão consolidada de todos os alunos e profissionais | 🔴 Alta |
| RF-47 | Filtros por aluno, período e grupo de treino | 🟡 Média |
| RF-48 | Exportar relatórios em PDF | 🟢 Baixa |

**Dependências:** PRD_LOGBOOK, PRD_ANALISE_IA  
**Complexity:** Alta (agregações, gráficos, múltiplas permissões)

---

### **7. PRD_CHATBOT_DUVIDAS.md** 🔴 FALTANDO
**Módulo:** Chatbot de Dúvidas - RF-49 até RF-53

| ID | Requisito | Prioridade |
|----|-----------|-----------|
| RF-49 | Chatbot responder dúvidas sobre exercícios (base de conhecimento RAG) | 🔴 Alta |
| RF-50 | Chatbot ter acesso ao perfil e ficha ativa para contextualizar respostas | 🔴 Alta |
| RF-51 | Disponível dentro do app e via WhatsApp | 🔴 Alta |
| RF-52 | Escalar para Personal via notificação se não conseguir responder | 🟡 Média |
| RF-53 | Histórico de conversas armazenado e acessível pelo aluno | 🟡 Média |

**Stack:** LangChain + RAG + WhatsApp Cloud API  
**Dependências:** PRD_CADASTRO_WHATSAPP, PRD_ANALISE_IA  
**Complexity:** Muito Alta (IA conversacional, múltiplos canais)

---

## ⚠️ Requisitos Não-Funcionais (RNF) - CRÍTICOS

**Todos os 12 RNFs faltam de PRDs específicos, mas devem ser integrados em todos os módulos:**

| ID | Requisito | Prioridade | Observação |
|----|-----------|-----------|-----------|
| RNF-01 | Sincronização WhatsApp ↔ App <2s | 🔴 Alta | Integrado em PRD_CADASTRO_WHATSAPP |
| RNF-02 | Backend suporta ≥200 requisições simultâneas sem degradação | 🔴 Alta | Performance engineering |
| RNF-03 | Comunicações via HTTPS/TLS 1.3 | 🔴 Alta | Infra/DevOps |
| RNF-04 | Senhas hash bcrypt (custo mínimo 12) | 🔴 Alta | Integrado em PRD_USUARIOS |
| RNF-05 | JWT expira 24h; refresh token 30 dias | 🔴 Alta | Integrado em PRD_USUARIOS |
| RNF-06 | App Flutter Android 8.0+ e iOS 13+ | 🔴 Alta | Compatibilidade |
| RNF-07 | Disponibilidade 99,5% (máx 3,6h/mês downtime) | 🔴 Alta | SLA/Infra |
| RNF-08 | Tempo resposta telas principais <1,5s (4G) | 🟡 Média | Otimização/Performance |
| RNF-09 | Backup automático diário, retenção 30 dias | 🔴 Alta | Infra |
| RNF-10 | Conformidade LGPD (dados pessoais/saúde) | 🔴 Alta | Legal/Compliance |
| RNF-11 | Cobertura mínima 70% testes automatizados | 🟡 Média | QA/Testing |
| RNF-12 | Deploy via LXC (Linux Containers) | 🟡 Média | DevOps/Infra |

---

## 🎯 Ordem de Priorização Recomendada

### **Fase 1 (MVP 1) - Semanas 1-2**
```
1. ✅ PRD_USUARIOS.md (PRONTO - fazer review final)
2. ✅ PRD_FICHA_TREINO.md (PRONTO - fazer review final)
3. ✅ PRD_CADASTRO_WHATSAPP.md (QUASE PRONTO - ajustes finais)
```

### **Fase 2 (MVP 2) - Semanas 3-4**
```
4. 🔴 PRD_LOGBOOK.md (CRÍTICO - base para IA e análise)
5. 🔴 PRD_METAS.md (COMPLEMENTO do logbook)
6. 🔴 PRD_CALCULO_CORPORAL.md (STANDALONE)
```

### **Fase 3 (MVP 3) - Semanas 5-6**
```
7. 🔴 PRD_NOTIFICACOES.md (Integração Firebase)
8. 🔴 PRD_DASHBOARD_PROFISSIONAL.md (Analytics)
9. 🔴 PRD_CHATBOT_DUVIDAS.md (IA conversacional)
10. 📋 RNF PRD (Performance/Infra/LGPD)
```

---

## 📊 Mapeamento de Dependências

```
┌─────────────────────────────────────────────────────────────┐
│                    PRD_USUARIOS ✅                          │
│         (Base: Autenticação + Perfil + Roles)              │
└──────────────┬──────────────────────────────────────────────┘
               │
      ┌────────┴────────┐
      ▼                 ▼
┌──────────────────┐   ┌────────────────────────┐
│ PRD_FICHA_TREINO │   │ PRD_CADASTRO_WHATSAPP  │
│     (RF-08-14)   │   │     (RF-54-58)         │
└────────┬─────────┘   └────────────────────────┘
         │
         ▼
    ┌──────────────────┐
    │ PRD_LOGBOOK ❌   │◄─── CRÍTICO: Depende de ficha ativa
    │  (RF-15-20)      │
    └────┬─────────────┘
         │
    ┌────┴──────────────────────────────┐
    ▼                                   ▼
┌─────────────────────┐      ┌──────────────────────┐
│ PRD_METAS ❌        │      │ PRD_ANALISA_IA ❌    │◄─── CRÍTICO
│  (RF-27-31)         │      │   (RF-21-26)         │
└─────────────────────┘      └──────┬───────────────┘
                                    │
                    ┌───────────────┴──────────────┐
                    ▼                              ▼
            ┌──────────────────┐      ┌───────────────────────┐
            │ PRD_DASHBOARD ❌  │      │ PRD_CHATBOT_DUVIDAS ❌ │
            │  (RF-43-48)       │      │    (RF-49-53)         │
            └──────────────────┘      └───────────────────────┘

┌─────────────────────────────────────────────────────┐
│ PRD_CALCULO_CORPORAL ❌ (RF-32-36)                 │
│ PRD_NOTIFICACOES ❌ (RF-37-42)                     │
│ Podem ser paralelos (pouca interdependência)       │
└─────────────────────────────────────────────────────┘
```

---

## 📝 Recomendações

### ✅ O Que Fazer

1. **Esta semana:**
   - [ ] Revisar PRD_USUARIOS.md com equipe
   - [ ] Revisar PRD_FICHA_TREINO.md com equipe
   - [ ] Finalizar PRD_CADASTRO_WHATSAPP.md
   - [ ] Começar implementação dos 3 primeiros

2. **Próxima semana:**
   - [ ] Criar PRD_LOGBOOK.md (CRÍTICO)
   - [ ] Criar PRD_METAS.md
   - [ ] Criar PRD_CALCULO_CORPORAL.md

3. **Comunicar stakeholders:**
   - PRD_ANALISA_IA e PRD_CHATBOT_DUVIDAS requerem expertise em LLMs/RAG
   - Avaliar se vai usar LangChain ou outra stack
   - Definir budget/timeline para IA

### ❌ O Que NÃO Fazer

- ❌ Começar PRD_ANALISA_IA sem ter PRD_LOGBOOK pronto
- ❌ Pular RNFs (Performance, LGPD, Backup)
- ❌ Implementar Chatbot sem RAG (vai ter alucinações)
- ❌ Dashboard sem agregações (vai ficar lento)

---

## 📞 Próximos Passos

1. **Validar** este análise com Product Owner
2. **Priorizar** os 7 PRDs faltantes com a equipe
3. **Alocar** recursos para cada PRD
4. **Criar sprint backlog** baseado na ordem recomendada

---

*Gerado automaticamente - Claude Code*  
*Comparação completa do PDF vs. Pasta /docs*
