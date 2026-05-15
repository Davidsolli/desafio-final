# PRD: Componentes Reutilizáveis (UI) - OmniConnect Fitness

**Versão:** 2.0  
**Data:** 2026-05-07  
**Status:** 🚧 Em Desenvolvimento  

---

## 📋 1. Visão Geral

### Objetivo

Criar uma base completa de componentes reutilizáveis (widgets) no aplicativo Flutter do projeto OmniConnect Fitness, com o objetivo de padronizar a interface, aplicar o Design System atual e eliminar duplicação de código nas telas.

### Por Quê?

- **Manutenção:** Atualizar um estilo visual num só lugar afeta todo o app.
- **Padronização:** Garante que botões, inputs, loaders, cards, estados de erro e estados vazios tenham exatamente a mesma aparência em todas as telas.
- **Velocidade:** O desenvolvimento das próximas features será mais rápido usando blocos prontos.
- **Auditoria:** A v1.0 criou 5 componentes base. A auditoria do código identificou **8 padrões adicionais** copiados entre 5 a 12 arquivos cada (~150 ocorrências duplicadas), justificando a expansão para v2.0.

### Escopo

✅ **Incluído neste PRD:**

**v1.0 — Componentes Base (já implementados)**
- `OmniButton`, `OmniTextField`, `OmniCard`, `OmniLoader`, `OmniAppBar`

**v2.0 — Componentes de Composição (novos)**
- `OmniErrorState` — estado de erro padronizado
- `OmniEmptyState` — estado vazio de lista padronizado
- `OmniStatCard` — card de métrica/estatística
- `OmniSectionHeader` — cabeçalho de seção
- `OmniAvatar` — avatar com iniciais do usuário
- `OmniStatusBadge` — badge colorido de status
- `OmniProgressBar` — barra de progresso com labels
- `OmniInfoChip` — chip de informação compacto
- **Testes de Widget** para todos os novos componentes
- Refatoração de **12 telas** para eliminar os padrões duplicados

❌ **NÃO incluído:**

- Alteração no modelo de cores base (`theme/app_colors.dart` e `theme/theme_colors.dart`).
- Criação de telas inteiras não previstas no MVP.

---

## 📊 2. Especificação Técnica dos Componentes

Todos os arquivos ficam em `frontend/lib/shared/widgets/`.

---

### 2.1 OmniButton (`omni_button.dart`) ✅

- **Parâmetros:** `String text`, `VoidCallback? onPressed`, `bool isLoading`, `bool isOutlined`, `Color? color`, `double? width`, `double? height`.
- **Comportamento:** `onPressed == null` ou `isLoading == true` desativa o botão visualmente.
- **Estilo:** `AppColors.primary` como fundo padrão. Bordas arredondadas 12px.

---

### 2.2 OmniTextField (`omni_text_field.dart`) ✅

- **Parâmetros:** `TextEditingController controller`, `String labelText`, `String? hintText`, `bool obscureText`, `IconData? prefixIcon`, `Widget? suffixIcon`, `String? Function(String?)? validator`, `TextCapitalization textCapitalization`, `TextAlign textAlign`, `TextStyle? style`.
- **Comportamento:** Toggle de visibilidade automático para obscureText.
- **Estilo:** Border radius 12px, borda muda de cor com foco/erro.

---

### 2.3 OmniCard (`omni_card.dart`) ✅

- **Parâmetros:** `Widget child`, `EdgeInsetsGeometry? padding`, `Color? backgroundColor`, `double? elevation`, `double borderRadius`.
- **Estilo:** Sombra leve, bordas arredondadas 12px.

---

### 2.4 OmniLoader (`omni_loader.dart`) ✅

- **Parâmetros:** `Color? color`, `double size`.
- **Comportamento:** `CircularProgressIndicator` centralizado. Cor primária por padrão, branca sobre botões.

---

### 2.5 OmniAppBar (`omni_app_bar.dart`) ✅

- **Parâmetros:** `String title`, `List<Widget>? actions`, `bool showBackButton`, `VoidCallback? onBackPressed`, `Color? backgroundColor`.
- **Comportamento:** Implementa `PreferredSizeWidget`.

---

### 2.6 OmniErrorState (`omni_error_state.dart`) 🆕

- **Parâmetros:** `String message`, `VoidCallback? onRetry`, `IconData icon`, `String retryLabel`.
- **Defaults:** `icon = Icons.error_outline`, `retryLabel = 'Tentar novamente'`.
- **Comportamento:** Se `onRetry == null`, não exibe o botão.
- **Estilo:** `Center > Column > Icon(48, accentError) + Text + OmniButton?`
- **Substitui:** 7 implementações manuais espalhadas (home, goals, workouts, logbook, trainer_home, trainer_students, admin_dashboard).

---

### 2.7 OmniEmptyState (`omni_empty_state.dart`) 🆕

- **Parâmetros:** `IconData icon`, `String title`, `String? subtitle`, `String? actionLabel`, `VoidCallback? onAction`.
- **Comportamento:** Se `onAction == null`, não exibe o botão.
- **Estilo:** `Center > Column > Icon(48, textMuted) + Text(title) + Text?(subtitle) + OmniButton?`
- **Substitui:** 7 implementações manuais (goals, workouts, logbook, home, trainer_home, trainer_students, admin_dashboard).

---

### 2.8 OmniStatCard (`omni_stat_card.dart`) 🆕

- **Parâmetros:** `String value`, `String label`, `IconData? icon`, `String? unit`, `Color? iconColor`, `Color? valueColor`, `VoidCallback? onTap`, `bool isSelected`.
- **Defaults:** `iconColor = AppColors.primary`, `isSelected = false`.
- **Comportamento:** Se `onTap != null`, envolve em `GestureDetector`. `isSelected` aplica highlight de borda e fundo primário transparente.
- **Estilo:** `Container(border, borderRadius 12) > Column > Icon? + Text(value, headlineMedium bold) + Text(label, labelSmall textMuted)`.
- **Substitui:** 6 implementações diferentes (home_screen, profile_stats_cards, metrics_screen, trainer_home, trainer_students, admin_dashboard).

---

### 2.9 OmniSectionHeader (`omni_section_header.dart`) 🆕

- **Parâmetros:** `String title`, `String? subtitle`, `Widget? action`.
- **Comportamento:** Se `action != null`, coloca `Spacer` + widget à direita.
- **Estilo:** `Column(crossStart) > Text(title, headlineSmall bold) + Text?(subtitle, bodyMedium textSecondary)`. Quando tem `action`: `Row > Column + Spacer + action`.
- **Substitui:** 9 implementações (home, goals, logbook, metrics, trainer_home, trainer_students, admin_dashboard, workouts).

---

### 2.10 OmniAvatar (`omni_avatar.dart`) 🆕

- **Parâmetros:** `String name`, `double size`, `bool useGradient`.
- **Defaults:** `size = 44`, `useGradient = false`.
- **Comportamento:** Exibe `name[0].toUpperCase()`. Se `name` for vazio, usa `'?'`.
- **Estilo:** Sólido: `CircleAvatar(AppColors.primary, texto branco)`. Gradient: `Container(LinearGradient primary→primaryLight, borderRadius size/2)`.
- **Substitui:** 8 implementações (trainer_home, trainer_students, trainer_student_detail, admin_dashboard, notifications, invite_code).

---

### 2.11 OmniStatusBadge (`omni_status_badge.dart`) 🆕

- **Parâmetros:** `String label`, `Color color`, `bool isPill`.
- **Defaults:** `isPill = false`.
- **Comportamento:** `isPill = false` → borderRadius 6 sem borda. `isPill = true` → borderRadius 20 com borda `color.withValues(alpha: 0.3)`.
- **Estilo:** `Container(padding h8v4, color.withValues(alpha:0.15)) > Text(labelSmall, w600, color)`.
- **Substitui:** 6 implementações (goals, goal_detail, trainer_student_detail, admin_dashboard, notifications).

---

### 2.12 OmniProgressBar (`omni_progress_bar.dart`) 🆕

- **Parâmetros:** `double value`, `String? label`, `String? trailingLabel`, `double height`, `Color? progressColor`.
- **Defaults:** `height = 6`, `progressColor = AppColors.primary`.
- **Comportamento:** `value` de 0.0 a 1.0, sempre `clamp(0.0, 1.0)`.
- **Estilo:** `Column > Row?(label + Spacer + trailingLabel) + SizedBox(4) + ClipRRect > LinearProgressIndicator(minHeight: height)`.
- **Substitui:** 5 implementações (goals, home, workouts, goal_detail, trainer_home).

---

### 2.13 OmniInfoChip (`omni_info_chip.dart`) 🆕

- **Parâmetros:** `String label`, `IconData? icon`, `Color? textColor`, `VoidCallback? onTap`.
- **Defaults:** `textColor = context.colors.textMuted`.
- **Comportamento:** Se `onTap != null`, envolve em `GestureDetector`.
- **Estilo:** `Container(surfaceLight, borderRadius 6, padding h8v4) > Row > Icon?(14px, primary) + SizedBox?(4) + Text(labelSmall)`.
- **Substitui:** 5 implementações (workouts, home, goal_detail).

---

## 🎯 3. Refatoração Esperada

### 3.1 Telas de Autenticação (`auth/`) — v1.0 ✅

- `login_screen.dart` — `OmniTextField`, `OmniButton`
- `register_screen.dart` — `OmniTextField`, `OmniButton`
- `invite_code_screen.dart` — `OmniTextField`, `OmniButton`

### 3.2 Telas de Estudantes (`student/`) — v1.0 parcial + v2.0 🆕

- `home_screen.dart` — `OmniErrorState`, `OmniStatCard`, `OmniSectionHeader`, `OmniProgressBar`, `OmniInfoChip`
- `goals_screen.dart` — `OmniErrorState`, `OmniEmptyState`, `OmniProgressBar`, `OmniStatusBadge`
- `goal_detail_screen.dart` — `OmniStatusBadge` (pill), `OmniInfoChip`, `OmniProgressBar`
- `workouts_screen.dart` — `OmniEmptyState`, `OmniProgressBar`, `OmniInfoChip`
- `logbook_screen.dart` — `OmniErrorState`, `OmniEmptyState`
- `metrics_screen.dart` — `OmniErrorState`, `OmniStatCard`, `OmniSectionHeader`
- `widgets/profile_stats_cards.dart` — `OmniStatCard`

### 3.3 Telas de Trainer (`trainer/`) — v1.0 parcial + v2.0 🆕

- `trainer_home_screen.dart` — `OmniErrorState`, `OmniEmptyState`, `OmniStatCard`, `OmniAvatar`
- `trainer_students_screen.dart` — `OmniErrorState`, `OmniEmptyState`, `OmniAvatar`, `OmniStatCard`
- `trainer_student_detail.dart` — `OmniErrorState`, `OmniEmptyState`, `OmniStatusBadge`, `OmniAvatar`, `OmniProgressBar`

### 3.4 Telas de Admin e Notificações (`admin/`) — v1.0 parcial + v2.0 🆕

- `admin_dashboard_screen.dart` — `OmniErrorState`, `OmniEmptyState`, `OmniStatCard`, `OmniSectionHeader`, `OmniStatusBadge`, `OmniAvatar`
- `notifications_screen.dart` — `OmniAvatar`, `OmniStatusBadge`

---

## 🗂️ 4. Padrões e Arquitetura

- **Nomenclatura de Arquivos:** `snake_case` (ex: `omni_error_state.dart`).
- **Nomenclatura de Classes:** `PascalCase` (ex: `class OmniErrorState extends StatelessWidget`).
- **Gerenciamento de Estado:** Todos `StatelessWidget`. Exceção: `OmniTextField` é `StatefulWidget` (toggle obscureText).
- **Import único:** `import '../../shared/widgets/index.dart';` exporta todos os componentes.
- **Testes:** Cada componente tem seu arquivo em `frontend/test/widgets/`.
- **Branch de desenvolvimento:** `feat/componentes-reutilizaveis` (nunca `main` ou `develop`).
- **Commits:**
  - `feat(ui): adicionar 8 novos componentes reutilizáveis ao design system`
  - `refactor(ui): aplicar novos componentes em todas as telas afetadas`
  - `docs(ui): atualizar PRD com especificação dos novos componentes`

---

## 🧪 5. Definição de Pronto (DoD)

**v1.0 — Componentes Base**
- [x] Pasta `frontend/lib/shared/widgets/` criada com OmniButton, OmniTextField, OmniCard, OmniLoader, OmniAppBar.
- [x] Testes de widget para os 5 componentes base.
- [x] Telas de Auth refatoradas.
- [x] Telas de Student, Trainer e Admin com OmniButton, OmniTextField e OmniLoader aplicados.

**v2.0 — Componentes de Composição**
- [ ] 8 novos componentes criados em `frontend/lib/shared/widgets/`.
- [ ] `index.dart` exporta todos os 13 componentes.
- [ ] Testes de widget criados para os 8 novos componentes (`frontend/test/widgets/`).
- [ ] 12 telas refatoradas eliminando os padrões duplicados identificados.
- [ ] O app compila sem erros (`flutter analyze` — 0 errors).
- [ ] Responsividade mantida em todas as telas refatoradas.
- [ ] Navegação, estados de loading, erro e vazio funcionam corretamente.
- [ ] Código fonte sem duplicação de padrões visuais.
- [ ] Commits no padrão Conventional Commits em Português.
