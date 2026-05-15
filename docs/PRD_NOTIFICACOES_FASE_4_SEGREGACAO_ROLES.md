# PRD — Notificações Fase 4: Segregação de UI por Role e Preferências do Trainer

**Projeto:** OmniConnect Fitness
**Data:** 2026-05-11
**Status:** 📋 Em Especificação
**Responsável:** Anderson Chaves
**Branch:** `feat/notificacoes-fase-4-roles`
**Base:** `develop` (após Fases 1, 2, 3)
**PR contra:** `develop`

---

## 1. Problema

A tela `notifications_settings_screen.dart` atual é genérica: oferece toggles "Lembrete de Treino", "Lembrete de Refeição" e "Novas Fichas" para qualquer usuário autenticado. Trainers nunca recebem nenhum desses tipos — para eles, esses toggles são ruído e podem causar confusão ("ativei e não recebi nada").

Além disso, `student_inactivity` (lembrete enviado ao trainer quando aluno fica inativo) **não tem campo de preferência**: trainer não consegue silenciar esse tipo específico mantendo outros ligados.

---

## 2. Objetivo

Cada role vê apenas os toggles que fazem sentido pra ele, e trainers ganham controle granular sobre `student_inactivity`.

---

## 3. Escopo

### Incluído

- Novo campo `student_inactivity_enabled: bool` (default `True`) em `NotificationPreference`.
- Mapeamento `"student_inactivity": "student_inactivity_enabled"` em `_TYPE_TO_PREF_FIELD`.
- Tela específica para trainer (toggles `student_inactivity_enabled`, master switch, quiet hours).
- Tela atual do client mostra apenas o que faz sentido para client (`workout_reminder`, `meal_reminder`, `new_workout_sheet`, `achievement`).
- Roteamento condicional por role (lê `AuthProvider.user.role`).

### Fora do escopo

- Notificações para Admin (não há pushes pra admin no PRD).
- Customização de horário de inatividade (mantém `_INACTIVITY_DAYS = 7` como constante).

---

## 4. Regras de Negócio

| ID | Regra |
|----|-------|
| RN01 | `client` vê: master switch, lembrete treino, lembrete refeição, novas fichas, quiet hours, silent days |
| RN02 | `trainer` vê: master switch, alerta de aluno inativo, quiet hours, silent days |
| RN03 | `admin` é redirecionado pra home (sem tela de notificações) |
| RN04 | `student_inactivity_enabled=False` impede o disparo do tipo, mesmo se `notifications_enabled=True` |
| RN05 | Migração: rows antigas de `notification_preferences` recebem `student_inactivity_enabled=True` por default |
| RN06 | Tipos não aplicáveis ao role do user **não são exibidos**, mesmo que o backend continue aceitando o toggle (não dá pra esconder e o usuário enviar via curl — backend só "ignora" no envio porque trainer não recebe meal_reminder) |

---

## 5. Especificação Técnica

### 5.1 Backend

**`app/models/notification.py`**
- `student_inactivity_enabled = Column(Boolean, default=True, nullable=False)`.

**`app/dtos/notification_dto.py`**
- Adicionar `student_inactivity_enabled: Optional[bool] = None` em update e `bool` em response.

**`app/services/notification_service.py`**
- `_TYPE_TO_PREF_FIELD["student_inactivity"] = "student_inactivity_enabled"`.

**`app/config/database.py`** (em `init_db`)
- `ALTER TABLE notification_preferences ADD COLUMN IF NOT EXISTS student_inactivity_enabled BOOLEAN NOT NULL DEFAULT TRUE`.

### 5.2 Frontend

**`frontend/lib/screens/notifications_settings_client_screen.dart`** (novo)
- Renomeia o conteúdo atual com toggles de client.

**`frontend/lib/screens/notifications_settings_trainer_screen.dart`** (novo)
- Toggles relevantes ao trainer.

**`frontend/lib/screens/notifications_settings_screen.dart`** (despachante)
- Reads `AuthProvider.role`. Renderiza:
  - `client` → `NotificationsSettingsClientScreen`
  - `trainer` → `NotificationsSettingsTrainerScreen`
  - `admin` → redirect `/admin/dashboard`

**`frontend/lib/routes/app_routes.dart`**
- A rota `/notifications-settings` continua única; o despacho é feito dentro do widget.

---

## 6. Auditoria de Testes (OBRIGATÓRIO antes de implementar)

1. Reler `notifications_settings_screen_test.dart` — provavelmente vai precisar split em dois arquivos (client/trainer).
2. Mapear quais asserts do teste atual ainda valem para client e quais não.
3. Verificar se há teste que afirma "exibe Lembrete de Refeição" sem condicionar por role — atualizar.

---

## 7. Testes desta Fase

### Backend
- `test_student_inactivity_enabled_default_true` — pref criada tem o flag = True.
- `test_student_inactivity_pode_ser_desativado` — toggle desativa e bloqueia envio.
- `test_student_inactivity_essential_nao_aplica` — não está em `_ESSENTIAL_FIELDS`, pode desativar.

### Frontend
- `test_client_screen_exibe_apenas_toggles_de_client` — sem "Aluno Inativo".
- `test_trainer_screen_exibe_aluno_inativo_toggle`.
- `test_admin_redireciona_para_dashboard`.
- `test_despachante_le_role_correto` — mock AuthProvider com cada role.

### Cobertura
- Backend: ≥ 80% nas linhas tocadas.

---

## 8. Definição de Pronto

- [ ] Auditoria de testes documentada.
- [ ] Migração testada com `docker compose down -v && up --build`.
- [ ] `pytest -v --cov` ≥ 80%.
- [ ] `flutter test` passa em todos os arquivos.
- [ ] Manual: login como client mostra tela de client; login como trainer mostra tela de trainer.
- [ ] Trainer consegue desativar `student_inactivity_enabled` e o backend para de enviar.
- [ ] PR contra `develop`, branch `feat/notificacoes-fase-4-roles`.

---

## 9. Riscos e Mitigações

| Risco | Mitigação |
|-------|-----------|
| Migração nullable=False sem default quebra | Default `TRUE` na migração e na coluna |
| Trainer com pref antiga continua sem o flag | `init_db` aplica `ALTER ... ADD COLUMN IF NOT EXISTS ... DEFAULT TRUE` |
| Frontend mistura widgets reutilizáveis e fica confuso | Extrair `NotificationToggleTile` reutilizado nas duas telas |

---

*PRD Notificações - Fase 4: Segregação por Role*
*OmniConnect Fitness - Alpha EdTech - Turma Aurora*
