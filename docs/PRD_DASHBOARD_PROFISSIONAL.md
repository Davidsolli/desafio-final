# PRD: Dashboard de Análise para Profissionais - OmniConnect Fitness

**Versão:** 1.0  
**Data:** 2026-05-03  
**Status:** 📋 Em Especificação  
**Responsável:** Equipe de Produto

---

## 📋 1. Visão Geral

### Objetivo
Desenvolver um painel de controle (Dashboard) web e mobile para que Profissionais (Personal Trainers e Professores) e Gestores possam acompanhar o engajamento, a frequência e o progresso dos alunos da academia, cruzando dados de treinos (Logbook), dietas, e análises de Inteligência Artificial.

### Por Quê?
Atualmente, profissionais de educação física têm dificuldade em saber quais alunos estão engajados ou estagnados, agindo de forma reativa. O Dashboard trará uma visão proativa, centralizando todos os dados (RF-43 a RF-48) em uma interface rica em gráficos e alertas, ajudando a reter alunos e a otimizar prescrições.

### Escopo
✅ **Incluído neste PRD:**
- Lista consolidada de alunos ativos com status (Engajado, Risco de Evasão, Estagnado).
- Visualização detalhada 360º por aluno (últimos treinos, logbook alimentar, metas).
- Gráficos de frequência e adesão.
- Visão gerencial (Gestor visualiza todos; Personal visualiza apenas seus alunos).
- Filtros avançados e exportação de relatórios em PDF.

❌ **NÃO incluído:**
- Faturamento ou gestão financeira da academia (fora do escopo do OmniConnect atual).
- Edição direta de ficha de treino dentro do gráfico (redirecionará para o módulo correto).

---

## 📊 2. Especificação Técnica e de Dados

### 2.1 Modelagem de Dados Auxiliar (Materialized Views)
Para garantir performance (RNF-02) e evitar consultas pesadas em tempo real em tabelas massivas como `DietLogbook` e `WorkoutSession`, o Dashboard deverá utilizar **Materialized Views** ou tabelas de agregação (Analytics) atualizadas via jobs em background (Celery) ou triggers.

#### Tabela de Agregação: `StudentAnalytics`
```python
class StudentAnalytics(Base):
    __tablename__ = "student_analytics"

    user_id: UUID                 # FK Users (Aluno)
    personal_id: UUID             # FK Users (Personal)
    
    # Métricas Mensais/Semanais
    month_year: str               # Ex: "2026-05"
    total_workouts: int           # Qtd de treinos realizados
    workouts_planned: int         # Qtd de treinos planejados
    adherence_percentage: float   # (total_workouts / workouts_planned) * 100
    
    # Alertas e Status
    status: str                   # "active", "at_risk" (sem treinar há >7 dias)
    ia_alerts_count: int          # Qtd de alertas gerados pela IA no período
    
    updated_at: datetime
```

---

## 🤖 3. Fluxo de Funcionalidades e Requisitos Funcionais

### RF-43 | Lista de Alunos e Indicadores Básicos
- **Descrição:** A tela inicial do Personal exibe um grid/lista com seus alunos vinculados.
- **Métricas por card:** Nome, foto, última data de check-in/treino, status (Semaforo: Verde=Frequente, Amarelo=Atenção, Vermelho=Ausente).

### RF-44 | Visão 360º por Aluno (Drill-down)
- **Descrição:** Ao clicar no aluno, abre-se o perfil detalhado.
- **Seções:**
  1. **Logbook Recente:** Últimos treinos realizados (com pesos e cargas) vs. Ficha Prescrita.
  2. **Metas Ativas:** Progresso de % até a conclusão.
  3. **Alertas IA:** Recomendações de ajustes (ex: "Aluno estagnou a carga do Supino há 3 semanas").
  4. **Dieta & Nutrição:** Gráfico de adesão calórica (Logbook Alimentar vs TMB / Prescrição).

### RF-45 | Gráficos de Frequência e Engajamento
- **Descrição:** O sistema deve ter bibliotecas de UI de gráficos (ex: Recharts / Fl_chart em Flutter).
- **Tipos de Gráficos:**
  - *Heatmap / Calendário:* Frequência de ida à academia no mês.
  - *Linha:* Evolução de carga total levantada (Volume Load) por sessão.
  - *Radar/Aranha:* Adesão aos grupos musculares (ex: treina muito peito, falta nos treinos de perna).

### RF-46 | Visão do Gestor (Admin)
- **Descrição:** Diferente do Personal, o Gestor acessa as estatísticas globais da academia.
- **Métricas Globais:** Total de matrículas, DAU (Daily Active Users), MAU (Monthly Active Users), taxa média de adesão global.
- **Acesso:** Pode ver os mesmos gráficos detalhados de *qualquer* aluno ou profissional.

### RF-47 | Filtros e Pesquisas
- **Descrição:** Filtros globais na tela principal.
- **Critérios:** Período (Últimos 7 dias, Mês Atual, Ano), Grupo de Treino (Hipertrofia, Emagrecimento), ou por Alerta de Risco.

### RF-48 | Exportação de Relatórios (PDF)
- **Descrição:** Botão para baixar relatório executivo do aluno ou relatório global.
- **Técnica:** O backend gera o PDF utilizando bibliotecas como ReportLab ou WeasyPrint, retornando o arquivo stream.

---

## 🔌 4. Endpoints da API (Proposta)

#### GET `/api/v1/dashboard/personal/students`
**Lista de alunos do Personal logado com indicadores resumidos.**
- **Response:**
  ```json
  [
    {
      "student_id": "uuid",
      "name": "João",
      "adherence_pct": 85.5,
      "last_workout_date": "2026-05-02",
      "status": "engaged",
      "active_alerts": 0
    }
  ]
  ```

#### GET `/api/v1/dashboard/students/{student_id}/analytics`
**Busca dados da Visão 360º de um aluno específico.**

#### GET `/api/v1/dashboard/admin/overview`
**Apenas Gestor: métricas macro da academia.**

#### GET `/api/v1/dashboard/export/pdf?student_id={id}`
**Gera e baixa o PDF do relatório.**

---

## 🔐 5. Regras de Segurança e Permissões

- **Autorização (Roles):** Rotas `/dashboard/personal/*` bloqueadas para `client`. Apenas `personal_trainer` e `admin` podem acessar. Rotas `/admin/*` são exclusivas para role `admin`/`gestor`.
- **Isolamento de Dados:** Um personal trainer NÃO PODE ver dados de alunos de outro personal, a menos que o aluno esteja vinculado a ambos.
- **Privacidade (LGPD):** Dados sensíveis agregados não devem ser exportados em massa. Log do uso da rota de exportação.

---

## 📋 6. Estimativa de Esforço

| Atividade | Estimativa |
|---|---|
| Modelagem da camada Analytics e Jobs (Celery/Cron) | 16h |
| Endpoints e Queries complexas (Agregações SQL) | 24h |
| Geração de PDFs no backend | 12h |
| Frontend Flutter (Gráficos e UI do Dashboard) | 32h |
| Testes unitários e Integração (incluindo permissões) | 16h |
| **Total Estimado** | **100h (~2,5 semanas)** |

---

## 📌 Próximos Passos
1. Definir biblioteca de gráficos no Frontend (Flutter).
2. Revisar queries SQL de agregação para não causar gargalo (performance testing).
3. Aprovação deste documento com os stakeholders.
