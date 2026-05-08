# PRD: Componentes Reutilizáveis (UI) - OmniConnect Fitness

**Versão:** 1.0  
**Data:** 2026-05-07  
**Status:** 📋 Em Especificação  

---

## 📋 1. Visão Geral

### Objetivo

Criar uma base de componentes reutilizáveis (widgets) no aplicativo Flutter do projeto OmniConnect Fitness, com o objetivo de padronizar a interface, aplicar o Design System atual e evitar duplicação de código nas telas.

### Por Quê?

- **Manutenção:** Atualizar um estilo visual num só lugar afeta todo o app.
- **Padronização:** Garante que botões, inputs, loaders e cards tenham exatamente a mesma margem, borda e cor em todas as telas.
- **Velocidade:** O desenvolvimento das próximas features (ex: novas telas de treino e perfil) será mais rápido usando blocos prontos.

### Escopo

✅ **Incluído neste PRD:**

- Criação da pasta `frontend/lib/shared/widgets/`
- Componente `OmniButton` (botão primário, secundário e outline)
- Componente `OmniTextField` (input de texto com validação e obscure text)
- Componente `OmniCard` (container padrão com sombra e bordas arredondadas)
- Componente `OmniLoader` (indicador de carregamento circular estilizado)
- Componente `OmniAppBar` (AppBar padronizada com botão de voltar/ações)
- **Criação de Testes de Widget** para cada um dos novos componentes (garantindo que não quebrem no futuro).
- Refatoração de **todas as telas do sistema** (Auth, Student, Trainer e Admin) para usarem os novos componentes de forma padronizada.

❌ **NÃO incluído:**

- Alteração no modelo de cores base (devemos usar os arquivos existentes `theme/app_colors.dart` e `theme/theme_colors.dart`).
- Criação de telas inteiras não previstas no MVP.

---

## 📊 2. Especificação Técnica dos Componentes

Todos os arquivos devem ser criados na pasta `frontend/lib/shared/widgets/`.

### 2.1 OmniButton (`omni_button.dart`)

- **Parâmetros:** `String text`, `VoidCallback onPressed`, `bool isLoading`, `bool isOutlined`, `Color? color`.
- **Comportamento:** Se `isLoading == true`, exibe o `OmniLoader` interno e desativa o botão.
- **Estilo:** Usa `AppColors.primary` como fundo padrão. Possui bordas arredondadas baseadas no `AppTheme`.

### 2.2 OmniTextField (`omni_text_field.dart`)

- **Parâmetros:** `TextEditingController controller`, `String labelText`, `String? hintText`, `bool obscureText`, `IconData? prefixIcon`, `Widget? suffixIcon`, `String? Function(String?)? validator`.
- **Comportamento:** Gerencia a digitação de dados.
- **Estilo:** Border radius uniforme, borda muda de cor com foco.

### 2.3 OmniCard (`omni_card.dart`)

- **Parâmetros:** `Widget child`, `EdgeInsetsGeometry? padding`, `Color? backgroundColor`, `double? elevation`.
- **Comportamento:** Um container envolvendo o `child`.
- **Estilo:** Borda suave, sombra (box-shadow) muito leve e elegante (premium design).

### 2.4 OmniLoader (`omni_loader.dart`)

- **Parâmetros:** `Color? color`, `double size`.
- **Comportamento:** Componente de spin `CircularProgressIndicator` centralizado.
- **Estilo:** Usa a cor primária por padrão, ou cor branca quando estiver sobre botões azuis.

### 2.5 OmniAppBar (`omni_app_bar.dart`)

- **Parâmetros:** `String title`, `List<Widget>? actions`, `bool showBackButton`.
- **Comportamento:** Implementa `PreferredSizeWidget`. Se `showBackButton` é true, adiciona um IconButton para voltar.

---

## 🎯 3. Refatoração Esperada

Após criar os componentes, TODAS as telas do aplicativo devem ser adaptadas (diretórios `auth/`, `student/`, `trainer/` e `admin/`). Os principais alvos são:

1. **Telas de Autenticação (`login_screen.dart`, `register_screen.dart`, etc.)**
   - Substituir `ElevatedButton` e `OutlinedButton` por `OmniButton`.
   - Substituir `TextField` por `OmniTextField`.
   - Substituir lógicas de "loading" manual por `isLoading: true`.

2. **Telas de Estudantes (`student/`)**
   - Refatorar formulários de metas, perfil e inputs de logbook.
   - Usar `OmniCard` para envolver cards de treinos e métricas.
   - Padronizar AppBar usando `OmniAppBar`.

3. **Telas de Trainer e Admin (`trainer/` e `admin/`)**
   - Refatorar tabelas, cards de alunos e formulários de criação/edição.
   - Adicionar `OmniLoader` onde houver busca de dados da API.

---

## 🗂️ 4. Padrões e Arquitetura

Conforme as regras em `IA_WORKFLOW.md`, `CLAUDE.md`, e `BRANCH_STRATEGY.md`:

- **Nomenclatura de Arquivos:** `snake_case` para os nomes de arquivo (ex: `omni_button.dart`).
- **Nomenclatura de Classes:** `PascalCase` para as classes de Widget (ex: `class OmniButton extends StatelessWidget`).
- **Gerenciamento de Estado:** Não é necessário gerenciar estado complexo dentro do componente visual (eles são na maioria `StatelessWidget`, com exceção de campos com senha).
- **Testes:** Todo novo componente deve possuir seu respectivo arquivo de teste na pasta `frontend/test/widgets/`. Exemplo: `omni_button_test.dart`.
- **Semântica de Commits (`COMMIT_GUIDE.md`):**
  - Criação: `feat(ui): criar componentes base reutilizáveis`
  - Refatoração: `refactor(ui): aplicar componentes reutilizáveis em todas as telas do app`
- **Branch:** ⚠️ O desenvolvimento **NÃO deve ser feito na `main` ou `develop`**. Crie e trabalhe em uma nova branch chamada `feat/componentes-reutilizaveis`.

---

## 🧪 5. Definição de Pronto (DoD)

- [ ] Pasta `frontend/lib/shared/widgets/` criada e populada com todos os componentes descritos.
- [ ] Testes de Widget implementados para cada componente criado (`frontend/test/widgets/`).
- [ ] TODAS as telas do app (Auth, Student, Trainer, Admin) refatoradas para usarem os componentes.
- [ ] O app compila e as telas renderizam corretamente sem quebra de layout, sendo responsivas em diferentes tamanhos de tela.
- [ ] A navegação, inputs e botões de `loading` funcionam perfeitamente em todas as áreas refatoradas.
- [ ] Código fonte não possui duplicação desnecessária de estilos.
- [ ] Commits no padrão do projeto.
