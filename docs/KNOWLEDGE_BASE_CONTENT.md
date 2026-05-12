# Base de Conhecimento — OmniConnect Fitness

**Versão:** 1.0
**Data:** 2026-05-10
**Escopo:** Etapa 3 do refactor do chatbot (Cards 19, 19.1, 19.2)
**Fonte humana** dos documentos seedados em `backend/scripts/seed_knowledge_base.py`.

---

## 1. Categorias

| Categoria | Conteúdo | Min. Docs |
|-----------|----------|-----------|
| `exercicio` | Execução técnica de exercícios (cargas, séries, postura) | 15 |
| `forma` | Erros comuns de execução e correções | 3 |
| `nutricao` | Conceitos básicos de nutrição esportiva | 5 |
| `periodizacao` | Frequência, divisões de treino, ciclos | 2 |
| `sistema` | Operacional do app (avaliações, agenda, recursos) | 5 |

> Total mínimo: **30** documentos. Cada doc segue o padrão:
> `Título: <prefixo>: <tema>` — `<prefixo>` derivado da categoria.

---

## 2. Documentos por Categoria

### 2.1 `exercicio` — Execução técnica

Os documentos de exercício seguem a estrutura: `nome do exercício →
músculos primários → execução passo a passo → cuidados`.

1. **Exercício: Supino Reto com Barra** — peito; postura, escápulas retraídas, descida controlada.
2. **Exercício: Supino Inclinado com Halteres** — peito superior; angulação 30-45°.
3. **Exercício: Crucifixo com Halteres** — peito; arco constante, evitar travamento de cotovelo.
4. **Exercício: Agachamento Livre** — quadríceps + glúteo; profundidade, joelho alinhado, core ativo.
5. **Exercício: Leg Press 45°** — quadríceps + glúteo; pés na largura do quadril, sem hiperextensão.
6. **Exercício: Levantamento Terra** — posterior + lombar + glúteo; barra colada, lombar neutra.
7. **Exercício: Stiff** — posteriores; quadril para trás, leve flexão de joelho.
8. **Exercício: Cadeira Extensora** — quadríceps; ajuste do banco, amplitude completa.
9. **Exercício: Cadeira Flexora** — posteriores; movimento controlado.
10. **Exercício: Puxada Frontal** — costas; cotovelo descendo na linha do tronco.
11. **Exercício: Remada Curvada** — costas + posterior do ombro; tronco a 45°, cotovelo colado.
12. **Exercício: Barra Fixa** — costas; pegada pronada, pull com escápula.
13. **Exercício: Desenvolvimento com Halteres** — ombro; cotovelos no plano frontal.
14. **Exercício: Elevação Lateral** — deltóide medial; tronco fixo, elevação até a altura do ombro.
15. **Exercício: Rosca Direta** — bíceps; cotovelo fixo, sem balanço.
16. **Exercício: Tríceps Pulley** — tríceps; cotovelo travado próximo ao corpo.
17. **Exercício: Mergulho em Banco** — tríceps; sem ombro à frente da linha.

### 2.2 `forma` — Erros comuns e correções

1. **Forma: Erros comuns no Agachamento** — joelho valgo, profundidade incompleta, lombar curvada.
2. **Forma: Erros comuns no Supino** — escápulas soltas, descida pelo quadril em vez do peito.
3. **Forma: Como respirar nos exercícios compostos** — Manobra de Valsalva e quando usar.

### 2.3 `nutricao` — Conceitos esportivos

1. **Nutrição: Macronutrientes (proteína, carboidrato, gordura)** — visão geral e papel no treino.
2. **Nutrição: Hidratação durante o treino** — quantidade média, sinais de desidratação.
3. **Nutrição: Janela anabólica e refeição pós-treino** — o que é, evidências atuais.
4. **Nutrição: Pré-treino básico (refeições 1-2h antes)** — combinações práticas e timing.
5. **Nutrição: Suplementos populares (whey, creatina, BCAA)** — orientação geral, limites do app.

### 2.4 `periodizacao` — Frequência e divisão

1. **Periodização: Divisão ABC, ABCDE e Full-Body** — quando cada uma faz sentido.
2. **Periodização: Frequência semanal por grupo muscular** — referências para hipertrofia (10-20 séries/semana).

### 2.5 `sistema` — Operacional do OmniConnect

1. **Sistema: Horário de funcionamento e reservas** — segunda a sexta 06h-23h, sábado 08h-18h.
2. **Sistema: Como agendar avaliação física** — aba 'Avaliações' do app ou recepção.
3. **Sistema: Toalha e higiene** — toalhas fornecidas na recepção, uso obrigatório.
4. **Sistema: O que é falha concêntrica** — definição prática para registro de série.
5. **Sistema: Cardio antes ou depois da musculação** — recomendação por objetivo (força/hipertrofia → depois).

---

## 3. Origem e Curadoria

- Conteúdo redigido pela equipe Aurora (Alpha EdTech) com base em literatura
  introdutória de hipertrofia (Schoenfeld, ACSM Guidelines), e em diretrizes
  operacionais internas do OmniConnect.
- Cada bloco foi escrito como texto puro (sem HTML/Markdown excessivo) para
  facilitar a geração de embeddings com `sentence-transformers/all-MiniLM-L6-v2`.
- O seed grava o conteúdo em `knowledge_base.content` e gera o vetor de
  embedding (384 dims) automaticamente. Veja `scripts/seed_knowledge_base.py`.

---

## 4. Como expandir a base

1. Adicionar entrada nova em `KNOWLEDGE_DOCUMENTS` no script de seed.
2. Garantir que o título seguirá o prefixo da categoria.
3. Rodar `python scripts/seed_knowledge_base.py --force` no container para
   reindexar.
4. Testes em `tests/test_knowledge_base_seed.py` validam o lote (≥25, sem
   duplicados, embeddings 384, naming consistente).
