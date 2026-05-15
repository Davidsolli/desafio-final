# 📋 Plano de Implementação & Compliance Regulatório: Personal Trainer × Nutricionista

Este documento estabelece o plano estratégico e técnico para adequar a plataforma **OmniConnect Fitness** às exigências regulatórias do mercado brasileiro (CONFEF e CFN) e expandir o modelo de negócios para um ecossistema de saúde multidisciplinar.

---

## 🏛️ Contexto Jurídico e de Negócios

No Brasil, a regulamentação profissional define fronteiras estritas de atuação:
- **CFN (Conselho Federal de Nutricionistas - Res. 600/2018)**: A prescrição de planos alimentares individualizados com cálculo de gramaturas exatas e fins de tratamento clínico é atividade privativa do Nutricionista.
- **CONFEF (Conselho Federal de Educação Física)**: O Profissional de Educação Física possui respaldo para fornecer orientações nutricionais gerais (incentivo à alimentação saudável, horários de refeição pré/pós-treino e sugestão de suplementos esportivos não-medicamentosos).

Para fins educacionais, de apresentação de TCC e atração de investidores, demonstrar esse nível de governança e adequação de produto eleva imensamente a nota e a percepção de valor do software.

---

## 🟢 Opção 1: Ajuste de Comunicação e UX (MVP Imediato)

**Foco**: Entrega rápida, zero risco técnico na reta final e adequação imediata para a apresentação.

### 1.1. Alterações Visuais (Frontend Flutter)
Como a plataforma já utiliza termos genéricos em suas rotas e controladores (`/trainer`, `trainer_shell`), o ajuste concentra-se nas strings de interface:
- **Telas de Dieta e Prescrição**:
  - Substituir `Prescrever Plano Nutricional` por `Plano Alimentar Sugerido` ou `Orientação Nutricional`.
  - Substituir `Prescrição Diária` por `Guia de Consumo Diário` ou `Metas de Macronutrientes`.
- **Identidade do Profissional**:
  - No cabeçalho e perfil, adotar nomenclaturas integradas como `Treinador Multidisciplinar`, `Consultor de Saúde`, `Coach Wellness` ou manter a palavra `Treinador`.

### 1.2. Estratégia de Apresentação (O Pitch Comercial)
Durante a demonstração do produto, o modelo de negócios deve ser posicionado da seguinte maneira:
> *"A OmniConnect atua como um ecossistema SaaS para Consultorias Wellness e Estúdios Multidisciplinares. Muitas vezes, um Personal Trainer atua em parceria comercial com uma Nutricionista; ambos utilizam a mesma conta de `TRAINER` na plataforma para cadastrar os treinos e as sugestões alimentares pactuadas com o aluno, mantendo todo o histórico unificado em um só lugar."*

---

## 🔵 Opção 2: Desmembramento de Roles e RBAC (Roadmap / Implementação Futura)

**Foco**: Evolução da arquitetura para suporte nativo a equipes multidisciplinares com contas segregadas (Personal + Nutri + Aluno).

```
┌────────────────────────────────────────────────────────┐
│                  HUB MULTIDISCIPLINAR                  │
├───────────────────────────┬────────────────────────────┤
│     ROLE: TRAINER         │     ROLE: NUTRITIONIST     │
│  (Acesso a Treinos/Passos)│  (Acesso a Planos/Análise) │
└───────────────────────────┴────────────────────────────┘
                             │
                             ▼
                     ROLE: STUDENT (Aluno)
```

### 2.1. Backend (FastAPI / SQLAlchemy)
1. **Atualização do Modelo de Usuário (`app/models/user.py`)**:
   ```python
   class UserRole(str, enum.Enum):
       STUDENT = "STUDENT"
       TRAINER = "TRAINER"
       NUTRITIONIST = "NUTRITIONIST"  # [NOVO]
       ADMIN = "ADMIN"
   ```
2. **Ajuste nos Middlewares e Decoradores de Permissão**:
   - Em `app/routes/diet.py`: atualizar decoradores para `@require_role([UserRole.TRAINER, UserRole.NUTRITIONIST, UserRole.ADMIN])`.
   - Em `app/routes/workout.py`: garantir acesso exclusivo a `TRAINER` e `ADMIN`.
3. **Módulo de Administração (`app/controllers/admin_controller.py`)**:
   - Ajustar o endpoint de criação de profissionais no dashboard do Admin para permitir selecionar no dropdown se o novo usuário é `Personal Trainer` (`TRAINER`) ou `Nutricionista` (`NUTRITIONIST`).

### 2.2. Frontend (Flutter / Dart)
1. **Atualização do Modelo Local (`user_model.dart`)**:
   - Adicionar o valor `nutritionist` no parser do enum de roles.
2. **Reestruturação do Shell (`trainer_shell.dart` -> `professional_shell.dart`)**:
   - Implementar renderização condicional da `BottomNavigationBar` e das abas de detalhes do aluno (`trainer_student_detail.dart`):
     - **Se `role == nutritionist`**: Ocultar a aba de `Fichas de Treino` e exibir apenas `Perfil do Aluno`, `Nutrição` e `Análise`.
     - **Se `role == trainer`**: Ocultar a aba de `Plano Nutricional` (ou mantê-la apenas em modo leitura para visualização do consumo).
3. **Painel do Admin (`admin_screen.dart`)**:
   - No modal de cadastro de novo profissional, adicionar o botão de seleção (Radio Button / Dropdown) para o Admin escolher a especialidade.

---

## 🚀 Roteiro de Apresentação e Defesa na Banca

Para obter a pontuação máxima no quesito de visão de produto e arquitetura de software, utilize o seguinte roteiro ao defender o projeto:

1. **Apresente o MVP Atual (Opção 1)**: Mostre a fluidez do app e como a nomenclatura de `Plano Sugerido` atende perfeitamente ao formato de consultorias integradas.
2. **Introduza a Barreira Regulatória**: Explique à banca que a equipe mapeou ativamente a legislação do CONFEF e CFN.
3. **Demonstre a Preparação Arquitetural (Opção 2)**: Explique que o banco de dados já possui controle de acesso baseado em funções (RBAC - Role-Based Access Control) e que a introdução da role `NUTRITIONIST` faz parte do roadmap de curto prazo, transformando a OmniConnect no primeiro ecossistema colaborativo 360º para profissionais de saúde e esporte.
