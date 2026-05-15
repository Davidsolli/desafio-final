# 📊 Análise de PRDs Faltantes - OmniConnect Fitness

**Data da Análise:** 03 de Maio de 2026  
**Comparação:** Requisitos_OmniConnect_Fitness.pdf vs. Pasta `/docs`

---

## 📋 Resumo Executivo

| Item | Total | Cobertos | Faltantes | % Cobertura |
|------|-------|----------|-----------|-------------|
| **Módulos (Base)** | 10 | 8 | **2** | 80% ✅ |
| **Módulos (Extras Adicionados)** | 1 | 1 | **0** | 100% ✅ |
| **Requisitos Funcionais Base** | 58 | 46 | **12** | 79% ✅ |
| **Requisitos Não-Funcionais** | 12 | 0 | **12** | 0% ⚠️ |

---

## ✅ PRDs Existentes e Criados (9 PRDs)

### 1. **PRD_USUARIOS.md** ✅ PRONTO
- **Status:** Aprovado
- **Módulo:** Autenticação e Perfis de Usuário (RF-01 até RF-07)
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
- **Cobertura:**
  - ✅ RF-15: Aluno registrar pesos, séries e repetições efetivamente executadas
  - ✅ RF-16: Logbook vinculado à ficha de treino ativa, pré-populando exercícios
  - ✅ RF-17: Sistema calcular e exibir evolução de carga ao longo do tempo
  - ✅ RF-18: Aluno adicionar notas livres (texto) a cada sessão registrada
  - ✅ RF-19: Personal ter acesso de leitura ao logbook dos alunos
  - ✅ RF-20: Logbook exibir calendário com dias realizados e não realizados

---

### 5. **PRD_METAS.md** 🟢 CRIADO
- **Status:** Em Especificação
- **Módulo:** Metas Alcançadas - RF-27 até RF-31
- **Cobertura:**
  - ✅ RF-27: Personal e Aluno definirem metas mensuráveis (ex: aumentar supino 10kg)
  - ✅ RF-28: Sistema calcular automaticamente progresso percentual
  - ✅ RF-29: Notificação comemorativa ao atingir meta (integra com Notificações)
  - ✅ RF-30: Histórico de metas concluídas e em andamento
  - ✅ RF-31: Suporte a múltiplas categorias: força, resistência, composição, frequência

---

### 6. **PRD_CALCULO_CORPORAL.md** 🟢 CRIADO
- **Status:** Em Especificação
- **Módulo:** Cálculo de Composição Corporal - RF-32 até RF-36
- **Cobertura:**
  - ✅ RF-32: Sistema calcular IMC com peso e altura
  - ✅ RF-33: Sistema calcular TMB (Taxa Metabólica Basal)
  - ✅ RF-34: Permitir registro periódico de medidas corporais (circunferências, % gordura)
  - ✅ RF-35: Exibir gráficos de evolução de peso e medidas
  - ✅ RF-36: Calcular gasto calórico diário estimado (atividade física)

---

### 7. **PRD_NOTIFICACOES.md** 🟢 CRIADO
- **Status:** Em Especificação
- **Módulo:** Notificações - RF-37 até RF-42
- **Cobertura:**
  - ✅ RF-37: Enviar notificação push (FCM) para lembrar treino do dia
  - ✅ RF-38: Enviar lembretes de horários de refeições configurados
  - ✅ RF-39: Aluno configurar horários de notificações individuais
  - ✅ RF-40: Notificar Personal quando aluno não registra treino (período)
  - ✅ RF-41: Notificar Aluno quando nova ficha é atribuída
  - ✅ RF-42: Silenciar categorias de notificação granularmente

---

### 8. **PRD_CHATBOT_DUVIDAS.md** 🟢 CRIADO
- **Status:** Em Especificação
- **Módulo:** Chatbot de Dúvidas - RF-49 até RF-53
- **Cobertura:**
  - ✅ RF-49: Chatbot responder dúvidas dos alunos sobre exercícios com base na base de conhecimento (RAG)
  - ✅ RF-50: Chatbot deve ter acesso ao perfil e ficha ativa do aluno para contexto
  - ✅ RF-51: Chatbot deve estar disponível dentro do app e via WhatsApp
  - ⚠️ RF-52: Se não conseguir responder, chatbot deve escalar para o Personal via notificação
  - ⚠️ RF-53: Histórico de conversas com o chatbot deve ser armazenado e acessível

---

### 9. **PRD_DIETA.md** 🟢 CRIADO (Módulo Extra)
- **Status:** Implementado ✅
- **Módulo:** Dieta e Nutrição (Extra ao escopo original de RFs numéricos)
- **Cobertura:**
  - ✅ Criação e gerenciamento de Dietas prescritas e customizadas
  - ✅ Integração com tabela TACO (Food Catalog)
  - ✅ Adição de alimentos customizados (Custom Foods)
  - ✅ Logbook Alimentar (Diário Alimentar para acompanhamento de macros)
  - ✅ Busca unificada de catálogo alimentar

---

## ❌ PRDs Faltantes (2 CRÍTICOS)

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

**Dependências:** PRD_LOGBOOK (análise de dados históricos), PRD_METAS, PRD_DIETA  
**Stack:** LangChain + RAG + pgvector (PostgreSQL)  
**Complexidade:** Muito Alta (IA/ML, prompt engineering, vector embeddings)  

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

**Dependências:** PRD_LOGBOOK, PRD_ANALISE_IA, PRD_METAS, PRD_DIETA  
**Complexidade:** Alta (agregações, gráficos, múltiplas permissões)  

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

## 📊 Mapeamento de Dependências (Atualizado)

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
┌─────────────────────┐       ┌──────────────────────┐
│ PRD_METAS 🟢        │       │ PRD_DIETA 🟢         │
│  (RF-27-31)         │       │ (Módulo Extra Nutri) │
└──────────┬──────────┘       └─────────┬────────────┘
           │                            │
    ┌──────┴────────────────────────────┴─┐
    ▼                                     ▼
┌─────────────────────┐      ┌──────────────────────┐
│ PRD_ANALISE_IA 🔴   │      │ PRD_CHATBOT_DUVIDAS  │
│  (RF-21-26)         │      │     🟢 (RF-49-53)    │
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
🟢 = Criado (em especificação/implementado)
🔴 = Faltando
```

---

## 🔍 Análise de Requisitos (Status Atualizado)

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
| Chatbot | RF-49 a RF-53 | 🟢 5/5 | Criado (PRD_CHATBOT_DUVIDAS) |
| Cadastro WhatsApp | RF-54 a RF-58 | ✅ 5/5 | Pronto (PRD_CADASTRO_WHATSAPP) |
| Dieta & Logbook Alimentar | (Extras) | ✅ N/A | Criado (PRD_DIETA) |
| **TOTAL** | **58** | **46/58** | **79% ✅** |

---

## 💡 Próximos Passos de Ação

1. **Prioridade Máxima:**
   - Elaborar o **`PRD_ANALISE_IA.md`** (RF-21 a RF-26)
   - Elaborar o **`PRD_DASHBOARD_PROFISSIONAL.md`** (RF-43 a RF-48)
   
2. **Requisitos Não Funcionais:**
   - Elaborar o **`PRD_REQUISITOS_NAO_FUNCIONAIS.md`** mapeando as necessidades de infraestrutura, segurança (LGPD), performance e deploy estipuladas nos RNF-02 a RNF-12.

3. **Status do Projeto:**
   - A especificação já ultrapassa 80% do sistema base planejado. Com o módulo extra de Dieta concluído, a fundação de dados para o Dashboard e para a IA RAG já se encontra pronta para ser consumida.
