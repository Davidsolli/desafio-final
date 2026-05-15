# PRD: Módulo de Evolução, Progressão de Carga e Frequência Temporal

## 1. Visão Geral

Este documento especifica a implementação das funcionalidades de acompanhamento e progressão do aluno no sistema **FitLoop**. O objetivo central é fornecer ferramentas visuais e métricas que permitam tanto ao aluno quanto ao personal trainer acompanharem, a curto e longo prazo, a adesão ao treinamento (frequência) e a evolução de performance (cargas e volume de treino).

## 2. Padrões e Fluxo de Trabalho (Diretrizes do Projeto)

Antes de iniciar o desenvolvimento, a implementação DEVE seguir rigorosamente as diretrizes documentadas no projeto:

- **Estratégia de Branch (`BRANCH_STRATEGY.md`):** O desenvolvimento será feito em uma nova branch criada a partir de `develop` com o padrão `feat/`. Exemplo: `feat/dashboards-evolucao`. Jamais commitar diretamente em `develop` ou `main`.
- **Commits (`COMMIT_GUIDE.md`):** Os commits devem seguir o padrão Conventional Commits em português e no imperativo. Exemplo: `feat(dashboards): implementar agrupamento de frequencia`. Não usar `Co-Authored-By`.
- **Arquitetura:** Seguir a arquitetura em camadas do FastAPI (`routes` -> `controllers` -> `services` -> `repositories` -> `models`/`dtos`).
- **Testes:** Todo o código novo no backend deve ser coberto por testes via `pytest` (almejando >= 80% de cobertura) rodando dentro do container Docker.
- **Pull Request:** Ao finalizar, fazer push com `git push -u origin feat/dashboards-evolucao`, verificar a sincronização remota, e criar o PR contra a branch `develop` (via GitHub web ou `gh pr create --base develop`).

## 3. Escopo e Critérios de Aceite (Cards do Trello)

### Card 13: Calcular evolução de carga por exercício

- **Critérios de Aceite:**
  - O sistema calcula a evolução de carga para cada exercício.
  - O cálculo compara sessões anteriores e atuais do logbook.
  - O sistema identifica corretamente o exercício ao longo do tempo.
  - A evolução pode indicar aumento, manutenção ou redução de carga.
  - Os dados são consistentes com o histórico de treinos do aluno.
  - O resultado pode ser utilizado em dashboards e métricas.
  - O sistema trata casos com poucos ou nenhum histórico.
  - A funcionalidade foi testada com diferentes cenários de evolução.

### Card 13.1: Criar histórico temporal de evolução

- **Critérios de Aceite:**
  - O sistema organiza dados de evolução em formato temporal.
  - Os registros são agrupados por períodos (semana, mês ou data).
  - A estrutura permite identificar tendências de evolução.
  - Os dados são consistentes com o logbook e histórico de treinos.
  - O sistema suporta múltiplos exercícios ao longo do tempo.
  - A base de dados está preparada para uso em gráficos.
  - O processamento não gera duplicações ou inconsistências.
  - A funcionalidade foi testada com diferentes períodos.

### Card 13.3: Criar gráfico de evolução de carga no Flutter

- **Critérios de Aceite:**
  - O gráfico exibe a evolução de carga ao longo do tempo.
  - Os dados são consumidos corretamente do endpoint de progresso.
  - O gráfico permite visualização clara da progressão por exercício.
  - O sistema trata casos com poucos ou nenhum dado histórico.
  - A interface mantém consistência visual com o aplicativo.
  - Os valores exibidos correspondem ao histórico real do aluno.
  - O gráfico é atualizado conforme novos dados são registrados.
  - A funcionalidade foi testada no aplicativo e funciona corretamente.

### Card 13.4: Exibir progresso por exercício

- **Critérios de Aceite:**
  - O sistema exibe progresso individual por exercício.
  - Cada exercício possui seu próprio indicador de evolução.
  - O progresso considera histórico de sessões anteriores.
  - Os dados incluem variações de carga e desempenho.
  - A visualização é clara e fácil de interpretar.
  - O sistema trata corretamente exercícios sem histórico suficiente.
  - Os dados exibidos correspondem ao logbook do aluno.
  - A funcionalidade foi testada e validada no aplicativo.

### Card 13.5: Exibir frequência semanal

- **Critérios de Aceite:**
  - O sistema calcula corretamente a quantidade de treinos por semana.
  - Os dados são baseados no logbook ou sessões concluídas.
  - A frequência é exibida de forma clara no aplicativo.
  - O sistema agrupa corretamente os dados por semana.
  - O cálculo considera apenas o usuário autenticado.
  - A interface permite fácil interpretação da frequência.
  - O sistema trata semanas sem registros de treino.
  - A funcionalidade foi testada com diferentes períodos de dados.

### Card 13.6: Exibir frequência mensal

- **Critérios de Aceite:**
  - O sistema calcula corretamente a quantidade de treinos por mês.
  - Os dados são baseados no logbook ou sessões concluídas.
  - A frequência mensal é exibida de forma clara no aplicativo.
  - O sistema agrupa corretamente os dados por mês.
  - O cálculo considera apenas o usuário autenticado.
  - A interface permite fácil interpretação da frequência mensal.
  - O sistema trata meses sem registros de treino.
  - A funcionalidade foi testada com diferentes períodos de dados.

## 4. Análise do Estado Atual (As-Is)

- **Backend (FastAPI):** Já existe um endpoint funcional (`GET /api/v1/logbook/progression/{exercise_id}`) que atende à regra de negócio base do Card 13.
- **Frontend (Flutter):** O app tem a infraestrutura de serviços (como `DashboardService`), mas **carece** de chamadas às APIs de progressão e das visões gráficas de evolução e frequência.

## 5. Requisitos de Backend (To-Be)

### 5.1. Refatoração de Histórico Temporal (Card 13.1)

- **Funcionalidade:** Adicionar parâmetros de agrupamento (Time Bucket) `group_by="week"` e `group_by="month"` no endpoint de progressão (e potencialmente suporte a requisições de visão global) para permitir gráficos consolidados temporais sem sobrecarregar o cliente.

### 5.2. Novo Endpoint: Frequência Semanal e Mensal (Cards 13.5 e 13.6)

- **Rota Proposta:** `GET /api/v1/logbook/frequency`
- **Parâmetros:** `period` (weekly / monthly), `limit` (ex: últimas 12 semanas ou últimos 6 meses), `user_id` (se for acessado pelo personal).
- **Resposta:** Lista contendo datas de referência (início da semana/mês) e a contagem (`count`) de sessões de treino com `status = 'completed'` naquele intervalo. O endpoint deve garantir que semanas/meses zerados também sejam retornados na lista para evitar falhas no eixo do gráfico.

## 6. Requisitos de Frontend (To-Be)

### 6.1. Integração de Serviços (API Client)

- Adicionar no `DashboardService` os métodos:
  - `getExerciseProgression(exercise_id, group_by)`
  - `getWorkoutFrequency(period, limit)`

### 6.2. Componentes Gráficos (Cards 13.3, 13.5 e 13.6)

- Instalar e configurar a biblioteca **`fl_chart`**.
- **`ProgressionLineChart`:** Gráfico de linhas (Eixo X = Data/Período, Eixo Y = Carga/Volume).
- **`FrequencyBarChart`:** Gráfico de barras (Eixo X = Semanas ou Meses, Eixo Y = Total de Treinos).

### 6.3. Interface de Progresso por Exercício (Card 13.4)

- **Visualização Detalhada:** Criar um Card ou Modal quando o usuário abrir o detalhe de um exercício, exibindo:
  - O `ProgressionLineChart`.
  - Estatísticas de resumo (Volume Total, Carga Máxima, Aumento/Redução %).
  - Layout de `EmptyState` se a API retornar lista vazia ("Complete este exercício mais vezes para ver seu progresso").

## 7. Casos de Uso / Fluxos

1. **Visão Geral (Aba Meu Progresso):**
   - O App chama `/frequency?period=weekly` e `/frequency?period=monthly`.
   - O App renderiza os dois gráficos de barras. Semanas ou meses sem treinos mostram a barra zerada.
2. **Visão Detalhada (Exercício):**
   - O usuário seleciona "Supino".
   - O App chama `/progression/{id}?group_by=week`.
   - O App constrói a linha do tempo do supino indicando o ganho de força.

## 8. Plano de Execução (Fases)

**Fase 1: Preparação**

- Criar a branch `feat/dashboards-evolucao`.

**Fase 2: Backend (Agrupamento e Frequência)**

- Implementar as consultas agrupadas via SQLAlchemy (`func.date_trunc` ou equivalentes no `LogbookRepository`).
- Criar o endpoint `/frequency` no `logbook.py`.
- Ajustar validações DTO e adicionar os testes necessários em `test_logbook.py`.
- Commit seguindo o padrão.

**Fase 3: Frontend (Integração e UI)**

- Instalar `fl_chart`.
- Criar as telas e componentes visuais (`ProgressionLineChart`, `FrequencyBarChart`).
- Conectar os componentes ao `DashboardService`.
- Tratar cenários vazios ou de erro.
- Commit e testes locais.

**Fase 4: Finalização**

- Verificar cobertura de testes.
- Push da branch e criação do Pull Request contra `develop` descrevendo todos os cards atendidos.
