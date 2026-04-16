# 🤖 Como Trabalhar com Claude (IA) - Guia da Equipe

**Objetivo:** Aprender a pedir coisas pro Claude de forma efetiva para acelerar desenvolvimento.

---

## 🎯 TL;DR (Resumo Rápido)

```
1. Você escreve um PRD claro
2. Você dispara um Prompt efetivo pra IA
3. IA implementa tudo (modelos, services, rotas, testes)
4. Você revisa e aprova
5. Done! Feature pronta em 5 minutos.
```

**Tempo economizado:** De 3-4 horas para 20 minutos! ⚡

---

## 📋 Passo a Passo: Do Pedido à Implementação

### Passo 1️⃣: Preparar um PRD (Product Requirements Document)

**Leia:** [`docs/PRD_USUARIOS.md`](./docs/PRD_USUARIOS.md) como exemplo

Um PRD claro = Implementação precisa

**Mínimo necessário:**
```
- O que fazer (objetivo)
- Campos/dados envolvidos
- Endpoints HTTP (se API)
- Validações
- Testes esperados
- Definição de "Pronto"
```

**Exemplo PRD Mini:**
```markdown
# PRD: Endpoint de Treinos

## Objetivo
Criar CRUD de treinos (Create, Read, Update, Delete)

## Campos
- id (UUID)
- name (string, obrigatório)
- duration_minutes (int, >0)
- calories_burned (int)
- created_at / updated_at (automático)

## Endpoints
- POST /api/v1/workouts → Criar (201)
- GET /api/v1/workouts → Listar com paginação (200)
- GET /api/v1/workouts/{id} → Buscar (200/404)
- PUT /api/v1/workouts/{id} → Atualizar (200/404)
- DELETE /api/v1/workouts/{id} → Deletar (204/404)

## Validações
- name: obrigatório, 3-255 chars
- duration_minutes: > 0

## Testes
- ≥8 testes de integração
- ≥5 testes unitários
- ≥80% cobertura

## Definição de Pronto
- ✅ 5 endpoints funcionando
- ✅ Validações ok
- ✅ Testes passando (≥80% cobertura)
- ✅ No Swagger (/docs)
```

---

### Passo 2️⃣: Estruturar o Prompt Efetivo

**UM BOM PROMPT É 50% DO SUCESSO!**

#### ❌ Pedido Ruim (Vago)
```
"Claude, cria um endpoint de treinos pra mim"
```

#### ✅ Pedido Bom (Específico)
```
Claude, implemente o módulo de treinos conforme o PRD em docs/PRD_TREINOS.md

Stack:
- FastAPI + SQLAlchemy + PostgreSQL
- Python 3.11+
- Arquitetura em camadas: routes → controllers → services → repositories → models

Requisitos:
- Todos os 5 endpoints funcionando (POST, GET /, GET /{id}, PUT, DELETE)
- Validações com Pydantic (name obrigatório, duration > 0)
- Testes: ≥8 integração + ≥5 unitários (≥80% cobertura)
- Senhas hasheadas com bcrypt (se aplicável)
- No Swagger (/docs)
- Sem Co-Author nos commits

Seguir padrão do projeto:
- Convenção: snake_case arquivos, PascalCase classes
- Async/await em todos os métodos
- Imports organizados
- Sem hardcodes (tudo em config)

Output esperado:
1. Todos os arquivos criados/modificados
2. Testes rodando: pytest -v
3. Swagger funcionando
4. Commit com conventional commits (feat: implementar módulo de treinos)
5. Branch: feat/treinos-crud (ou similar)
```

---

## 🎓 Estrutura de um Prompt Efetivo

### Template Base (Copiar-Colar)

```
Claude, implemente [O QUÊ] conforme o PRD em [CAMINHO_DO_PRD]

STACK:
- [Framework/Linguagem/Versões]
- [Dependências principais]

REQUISITOS:
- [Obrigação 1]
- [Obrigação 2]
- [Obrigação 3]

PADRÕES DO PROJETO:
- [Convenção de nomes]
- [Padrão de código]
- [Sem coisas indevidas]

OUTPUT ESPERADO:
1. [Arquivo 1 criado]
2. [Arquivo 2 criado]
3. [Testes rodando]
4. [Commit feito]
```

### Exemplo Prático: Autenticação com JWT

```
Claude, implemente autenticação JWT conforme o PRD em docs/PRD_AUTH.md

STACK:
- FastAPI + SQLAlchemy + PostgreSQL
- python-jose (JWT)
- bcrypt (senhas)

REQUISITOS:
- Endpoint POST /api/v1/auth/login (email + password)
- Validações: email válido, senha forte
- Retorna: token JWT válido por 24h
- Endpoint POST /api/v1/auth/logout (marca token como inválido)
- Token na header: Authorization: Bearer {token}
- Testes: ≥10 testes de integração

PADRÕES:
- Seguir padrão do projeto (routes → controllers → services → repositories)
- Sem hardcodes, tudo em config/.env
- Async/await sempre
- Commits em português: feat(auth): ...

OUTPUT:
1. models/auth.py
2. services/auth_service.py
3. routes/auth.py
4. tests/test_auth.py
5. Testes passando (pytest -v)
6. Commit: feat(auth): implementar autenticação JWT
7. Branch: feat/auth-jwt
```

---

## 🚀 Exemplos Reais de Prompts

### Exemplo 1: Feature Completa (Treinos CRUD)

```
Claude, implemente o módulo de treinos conforme PRD em docs/PRD_TREINOS.md

Stack: FastAPI + SQLAlchemy + PostgreSQL

Requisitos:
✅ 5 endpoints CRUD funcionando
✅ Model: Workout com id, name, duration, calories, created_at, updated_at
✅ DTOs com validações Pydantic
✅ Service com lógica de negócio
✅ Repository com ORM queries (sem SQL bruto)
✅ Testes: ≥8 integração, ≥5 unitários (≥80% cobertura)
✅ Paginação em GET /workouts?page=1&limit=10
✅ Responses: 201 (create), 200 (read/update/list), 204 (delete), 4xx (erros)
✅ Documentação automática no Swagger

Padrões:
- Arquitetura em camadas: routes → controllers → services → repositories
- Async/await em tudo
- Sem Co-Author (removido em settings.json)
- Conventional commits em português

Output:
- Todos os arquivos criados
- Testes rodando (pytest -v --cov)
- Commitment com feat(treinos): implementar CRUD
- Branch: feat/treinos-crud
```

### Exemplo 2: Bug Fix (Problema de Validação)

```
Claude, corrija o bug de validação de email.

Problema:
- Endpoint POST /api/v1/users aceita emails inválidos
- Regex atual não valida "user@domain" (sem extensão)
- Testes falhando em test_email_validation

Localização:
- app/dtos/user_dto.py (validador de email)
- app/services/user_service.py (se houver lógica adicional)

Requisitos:
- Email deve ser válido (RFC 5322 simplificado)
- Testar: email válido, email inválido, email duplicado
- Adicionar/atualizar testes

Output:
- Arquivo(s) modificado(s)
- Testes: pytest tests/test_user_validation.py -v (todos passando)
- Commit: fix(usuarios): corrigir validação de email
- Branch: fix/email-validation
```

### Exemplo 3: Refatoração

```
Claude, refatore o user_service.py para remover duplicação.

Contexto:
- 3 métodos diferentes fazem validação de email
- Código repetido em validate_email(), create_user(), update_user()

Requisitos:
- Criar método único validate_email() reutilizável
- Reduzir duplicação
- Sem mudança de comportamento (testes devem passar)
- Manter ≥80% cobertura

Output:
- app/services/user_service.py (refatorado)
- Testes: pytest tests/unit/test_user_service.py -v (todos passando)
- Commit: refactor(user-service): consolidar validação de email
```

### Exemplo 4: Documentação

```
Claude, crie um documento de guia de API (Swagger/OpenAPI).

Conteúdo esperado:
- Overview (para que serve)
- Autenticação (como usar JWT)
- Endpoints documentados (todos em /api/v1/)
- Exemplos de request/response
- Códigos de erro possíveis
- Rate limiting (se houver)

Output:
- docs/API_GUIDE.md (markdown claro)
- Ou atualizar docstrings em rotas (que geram Swagger)
- Commit: docs(api): documentar endpoints
```

---

## ⚡ Prompts Curtos vs Detalhados

### Opção 1: Prompt Curto (Quando IA Sabe o Contexto)
```
Claude, implemente testes de integração para o módulo de usuários.

Referência: docs/PRD_USUARIOS.md
Cobertura esperada: ≥80%
```

**Quando usar:** PRD já está bem claro, padrão é bem conhecido

---

### Opção 2: Prompt Longo (Mais Seguro)
```
Claude, implemente [tudo bem explicado como nos exemplos acima]
```

**Quando usar:** Feature complexa, primeira implementação, risco alto

---

## 🎯 O Que Pedir (E Não Pedir)

### ✅ PEDIR PARA IA FAZER

- ✅ Implementar features novas
- ✅ Criar testes
- ✅ Refatorar código
- ✅ Corrigir bugs
- ✅ Documentação
- ✅ Melhorias de performance
- ✅ Adicionar validações
- ✅ Fazer commits

### ❌ NÃO PEDIR (Ou Pedir com Cuidado)

- ❌ Decisões arquiteturais críticas (você decide, IA implementa)
- ❌ Features que não estão bem definidas (crie PRD primeiro)
- ❌ Remover código sem entender (sempre revisar)
- ❌ Mudar dependências sem razão clara
- ❌ Contornar padrões do projeto

---

## 🔄 Fluxo de Trabalho Completo

```
┌─ Você cria PRD
│  (30 minutos)
│
├─ Você estrutura Prompt
│  (5 minutos)
│
├─ Você dispara Claude Agent
│  (Claude roda por 5-10 minutos)
│
├─ Claude retorna:
│  ✅ Código implementado
│  ✅ Testes criados
│  ✅ Commit feito
│  ✅ Branch pronta
│
├─ Você revisa:
│  (10 minutos - ler código, rodar vagrant docker, testar)
│
├─ Você aprova ou pede ajustes
│  (Claude corrige em 2 minutos se necessário)
│
└─ Merge na main ✅
   (Feature pronta em 1 hora vs 4 horas manual!)
```

---

## 📊 Comparação: Manual vs Com IA

| Tarefa | Manual | Com IA | Economia |
|--------|--------|--------|----------|
| Feature CRUD | 3-4 horas | 20 min | 90% ⚡ |
| Testes | 1-2 horas | 5 min | 90% ⚡ |
| Refatoração | 1 hora | 5 min | 92% ⚡ |
| Bug fix | 1-2 horas | 10 min | 85% ⚡ |
| Documentação | 1 hora | 5 min | 92% ⚡ |
| **TOTAL/SPRINT** | **40 horas** | **4 horas** | **90% ⚡** |

---

## 🛠️ Skills Úteis do Claude

### Skill 1: `/commit`
Prepara commits automaticamente (sem Co-Author)

```bash
# Você termina de implementar
/commit

# Claude:
# ✅ Verifica arquivos modificados
# ✅ Entende o que você fez
# ✅ Faz commit em português (conventional commits)
# ✅ Sem Co-Author
```

### Skill 2: `/review-pr`
Revisa PRs automaticamente

```bash
/review-pr 123

# Claude:
# ✅ Lê PR inteira
# ✅ Valida padrão
# ✅ Aponta problemas
# ✅ Suggestiona melhorias
```

### Skill 3: `/simplify`
Limpa código de duplicatas

```bash
/simplify

# Claude:
# ✅ Remove código duplicado
# ✅ Refatora
# ✅ Propõe melhorias
```

---

## 🎓 Exemplo Completo: Do Pedido à Produção

### 1️⃣ Você Cria o PRD (30 min)
```markdown
# PRD: Sistema de Metas Fitness

## O que
Usuários definem metas (peso alvo, exercícios por semana, etc)

## Campos
- goal_type: "weight", "exercise_frequency", "calories"
- target_value: número
- deadline: data
- progress: % realizado

## Endpoints
- POST /api/v1/goals (criar)
- GET /api/v1/goals (listar)
- ...etc
```

### 2️⃣ Você Pede pra IA (5 min)
```
Claude, implemente o módulo de goals conforme PRD em docs/PRD_GOALS.md

Stack: FastAPI + SQLAlchemy + PostgreSQL
Requisitos: 5 endpoints, validações, ≥8 testes, ≥80% cobertura
Padrão: arquitetura em camadas, async/await, sem Co-Author
Output: código funcional, testes passando, commit feito, branch feat/goals
```

### 3️⃣ IA Implementa (10 min)
```
✅ app/models/goal.py
✅ app/dtos/goal_dto.py
✅ app/services/goal_service.py
✅ app/repositories/goal_repository.py
✅ app/controllers/goal_controller.py
✅ app/routes/goal.py
✅ tests/test_goals.py (14 testes)
✅ Commit: feat(goals): implementar CRUD de metas
✅ Branch: feat/goals-crud
```

### 4️⃣ Você Revisa (15 min)
```bash
# Ver código
gh pr view feat/goals-crud

# Rodar localmente
docker compose up
pytest tests/ -v --cov

# Testa no Swagger
http://localhost:8000/docs

# Aprova
gh pr merge
```

### 5️⃣ PRONTO! 🎉
Feature em produção em ~1 hora total (vs 4 horas manual)

---

## 💡 Dicas Profissionais para Pedir

### 1️⃣ **Seja Específico**
```
❌ "Cria um endpoint"
✅ "Cria endpoint POST /api/v1/goals com validação de deadline"
```

### 2️⃣ **Dê Contexto do Projeto**
```
❌ "Implementar autenticação"
✅ "Implementar autenticação JWT seguindo padrão do projeto em FastAPI/SQLAlchemy"
```

### 3️⃣ **Referencie Exemplos**
```
✅ "Seguindo o padrão do módulo de usuários (vê app/models/user.py)"
✅ "Testes devem ser como test_users.py"
```

### 4️⃣ **Seja Claro no Output Esperado**
```
✅ Output esperado:
1. Todos os arquivos criados
2. Testes rodando (pytest -v)
3. Swagger funcionando
4. Commit: feat(...):...
5. Branch: feat/...
```

### 5️⃣ **Mencione Restrições**
```
✅ "Sem dependencies externas extras"
✅ "Sem mudança de API existente"
✅ "Manter retrocompatibilidade"
```

---

## 🔍 Checklist: Antes de Disparar um Prompt

- [ ] Tenho um PRD claro?
- [ ] PRD está em um arquivo (docs/PRD_*.md)?
- [ ] Meu prompt é específico e detalhado?
- [ ] Mencionei o stack (FastAPI, SQLAlchemy, etc)?
- [ ] Lembrei de mencionar padrões do projeto?
- [ ] Defini o output esperado?
- [ ] Criei uma branch pra isso (feat/meu-recurso)?
- [ ] Estou em uma branch, não em main?

---

## 🎞️ Vídeo Mental: Como Claude Funciona

1. **Você dá um prompt** ("implemente treinos CRUD")
2. **Claude lê seu projeto** (entende estrutura, padrões)
3. **Claude faz um plano** (quais arquivos vai criar)
4. **Claude implementa** (code, testes, commits)
5. **Claude retorna** (tudo pronto pro seu git)

**Tempo total:** 5-10 minutos!

---

## 📞 Exemplos de Prompts para Copiar-Colar

### Template 1: Feature Nova
```
Claude, implemente [FEATURE] conforme o PRD em docs/PRD_[FEATURE].md

Stack: FastAPI + SQLAlchemy + PostgreSQL

Requisitos:
- [Req 1]
- [Req 2]
- [Req 3]

Padrão do projeto:
- Arquitetura em camadas
- Async/await sempre
- Sem Co-Author nos commits

Output:
- Arquivos criados/modificados
- Testes: pytest -v --cov (≥80%)
- Commit: feat([modulo]): [descrição]
- Branch: feat/[modulo]
```

### Template 2: Bug Fix
```
Claude, corrija o bug: [DESCRIÇÃO]

Problema:
- [Detalhe do problema]
- [Onde pega]
- [Por que é ruim]

Requisitos:
- Corrigir sem quebrar testes existentes
- Adicionar testes pro bug
- Manter lógica igual (sem refatoração)

Output:
- Arquivo(s) modificado(s)
- Testes passando
- Commit: fix([modulo]): [descrição]
```

### Template 3: Refatoração
```
Claude, refatore [ARQUIVO]: [PROBLEMA]

Contexto:
- [O que está errado]
- [Onde está]
- [Por que mudar]

Requisitos:
- Sem mudança de comportamento (testes devem passar)
- Reduzir duplicação/complexidade
- Manter performance

Output:
- Arquivo(s) refatorado(s)
- Testes: pytest -v (todos passando)
- Commit: refactor([modulo]): [descrição]
```

---

## 🚨 Erros Comuns ao Pedir pra IA

### ❌ Erro 1: Prompt Muito Vago
```
"Claude, faz um endpoint"

😞 Resultado: IA faz algo genérico, não é o que você quer
```

**Solução:** Seja específico!

### ❌ Erro 2: Sem Contexto do Projeto
```
"Cria CRUD de usuários"

😞 Resultado: IA não sabe seu padrão (poderia ser Django, não FastAPI)
```

**Solução:** Sempre mencione stack e padrão!

### ❌ Erro 3: Feature Mal Definida
```
"Implementa sistema de recomendações"

😞 Resultado: IA não sabe o que recomendar, como funciona, etc
```

**Solução:** Crie um PRD antes!

### ❌ Erro 4: Não Revisar Output
```
IA implementa, você não testa, mergeia com problemas
```

**Solução:** Sempre revise, rode localmente, teste!

---

## ✅ Resumo Final

**Para trabalhar bem com IA:**

1. **Crie um PRD claro** (30 min)
2. **Estruture um prompt específico** (5 min)
3. **Dispare o Claude Agent** (10 min de processamento)
4. **IA implementa tudo** (código + testes + commits)
5. **Você revisa e aprova** (15 min)

**Resultado:** Feature pronta em 1 hora (vs 4 horas manual) ⚡

---

*Criado para: OmniConnect Fitness - Alpha EdTech*  
*Como trabalhar efetivamente com Claude (IA)*  
*Economize 90% do tempo em desenvolvimento! 🚀*
