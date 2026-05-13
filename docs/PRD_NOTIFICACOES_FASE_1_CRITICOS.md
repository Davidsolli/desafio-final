# PRD — Notificações Fase 1: Correção de Bugs Críticos

**Projeto:** OmniConnect Fitness
**Data:** 2026-05-11
**Status:** 📋 Em Especificação
**Responsável:** Anderson Chaves
**Branch:** `fix/notificacoes-fase-1-criticos`
**Base:** `develop`
**PR contra:** `develop`

---

## 1. Problema

O módulo de notificações foi mergeado em `develop` (PR #53) com bugs críticos que impedem o uso real da feature:

1. A tela `notifications_screen.dart` ainda renderiza `mock_data.dart` em vez de chamar o histórico real da API.
2. Em build Web, `NotificationService` não é registrado no `MultiProvider`, causando `ProviderNotFoundException` ao abrir as configurações.
3. A tabela `workout_reminder_schedules` é lida pelo scheduler, mas nenhum código da aplicação a popula — o lembrete configurado nunca dispara.
4. Os tipos `new_workout_sheet`, `achievement` e `performance_report` existem em DTO/modelo/mapeamento, mas **nada no backend chama `NotificationService.send_notification` com esses tipos**. Três dos cinco tipos prometidos pelo PRD são código morto.
5. `NotificationController.get_preferences` chama `get_or_create_preferences` que faz `flush()` mas o controller não chama `db.commit()` — a row criada é descartada no rollback.

Sem essas correções, o módulo só "funciona" em testes unitários — em ambiente real **nada chega ao usuário**.

---

## 2. Objetivo

Destravar funcionalmente o módulo de notificações: histórico real na tela, settings funcional em todas as plataformas, lembretes que efetivamente disparam e os 5 tipos de notificação integrados aos seus respectivos pontos de origem.

---

## 3. Escopo

### Incluído nesta fase

- Tela de listagem de notificações consumindo `GET /api/v1/notifications/history` e marcando como lida via `POST /api/v1/notifications/mark-read`.
- Registro do Provider `NotificationService` no Web (usando `notification_service_stub.dart`, que já existe e tem as chamadas HTTP).
- Persistência idempotente da preferência criada pelo `get_preferences` (commit no controller).
- Geração de `WorkoutReminderSchedule` ao atualizar `workout_reminder_time` na preferência (horizonte de 7 dias, respeitando `silent_days`).
- Job diário (00:30 UTC) que repõe o horizonte de 7 dias dos schedules.
- Disparo de `send_notification(type="new_workout_sheet")` quando `WorkoutSheet` é criada/atribuída a um aluno.
- Disparo de `send_notification(type="achievement")` quando uma `Goal` é marcada como completada.

### Fora do escopo (vai pra Fase 2 ou depois)

- Correção de timezone (UTC vs horário local) → **Fase 2**
- Idempotência do meal reminder, filtros de status no inactivity → **Fase 2**
- Limpezas de lint/cosméticos (withOpacity, super.key, imports) → **Fase 3**
- `git rm --cached google-services.json` e rate limit → **Fase 3**
- Segregação de UI por role → **Fase 4**
- `performance_report` (ainda não há gerador de relatórios no projeto)

---

## 4. Regras de Negócio

| ID | Regra |
|----|-------|
| RN01 | A tela de notificações sempre busca do backend; nada de mock |
| RN02 | Toque em uma notificação não-lida dispara `mark-read` e atualiza o badge local |
| RN03 | Em Web, o stub do `NotificationService` é injetado normalmente; só `initialize()` (FCM) é pulado |
| RN04 | `get_preferences` cria a row na primeira chamada e **commita** — chamadas subsequentes só leem |
| RN05 | Atualizar `workout_reminder_time` regenera os 7 schedules futuros (delete dos pendentes + insert) |
| RN06 | `silent_days` é respeitado na geração: dias silenciosos não criam schedule |
| RN07 | Job `replenish_workout_schedules` roda 00:30 UTC e mantém sempre 7 dias de horizonte |
| RN08 | Criar uma `WorkoutSheet` com `student_id` definido dispara notificação `new_workout_sheet` para o aluno |
| RN09 | Marcar uma `Goal` como completada dispara notificação `achievement` para o dono da meta |
| RN10 | Falha em enviar a notificação **não** deve fazer rollback da operação principal (criar ficha / completar meta) — logar e seguir |

---

## 5. Especificação Técnica

### 5.1 Backend

**`app/controllers/notification_controller.py`**
- `get_preferences`: adicionar `await db.commit()` após `service.get_or_create_preferences(...)` quando uma row foi criada.

**`app/services/notification_service.py`**
- Novo método: `regenerate_workout_schedules(user_id, workout_reminder_time, silent_days)`:
  - Deleta `WorkoutReminderSchedule` pendentes (`sent=False`) com `scheduled_date >= today` do usuário.
  - Para cada dia em `[today, today+6]`, se `weekday() not in silent_days`, insere um schedule.
- `update_preferences`: se `update_data` contém `workout_reminder_time` ou `silent_days`, chamar `regenerate_workout_schedules` ao final.
- Novo método público `notify_new_workout_sheet(user_id, sheet_id, sheet_name)` que faz `send_notification(type="new_workout_sheet", ...)` com try/except interno (não propaga falha).
- Novo método público `notify_achievement(user_id, goal_title, goal_id)` análogo.

**`app/tasks/notification_scheduler.py`**
- Adicionar job `replenish_workout_schedules` com `CronTrigger(hour=0, minute=30)`.
- Para cada `NotificationPreference` com `workout_reminder_enabled=True` e `workout_reminder_time` definido, chamar `NotificationService.regenerate_workout_schedules`.

**`app/services/workout_sheet_service.py`** (existe, ler antes)
- No método de criação/atribuição: após commit, chamar `NotificationService(session).notify_new_workout_sheet(...)` envolvido em try/except (log apenas).

**`app/services/goal_service.py`** (existe, ler antes)
- No método que marca meta como completed: após commit, chamar `NotificationService(session).notify_achievement(...)` envolvido em try/except.

### 5.2 Frontend

**`frontend/lib/services/notification_service_mobile.dart` e `notification_service_stub.dart`**
- Adicionar `Future<List<Map<String, dynamic>>> getHistory({String? type, int limit = 20})` — chama `GET /api/v1/notifications/history`.
- Adicionar `Future<bool> markAsRead(String notificationId)` — chama `POST /api/v1/notifications/mark-read`.
- Manter assinaturas idênticas entre stub e mobile (são intercambiáveis via `notification_service.dart`).

**`frontend/lib/main.dart`**
- Sempre criar `NotificationService(apiClient: apiClient)`. Em `kIsWeb`, **pular apenas `initialize()`** (FCM).
- Remover o `if (notificationService != null)` do Provider — registrar incondicionalmente.

**`frontend/lib/screens/notifications_screen.dart`**
- Substituir `import '../models/mock_data.dart'` e `notifications` const pela chamada real:
  - `StatefulWidget` com `_loadHistory()` em `initState`.
  - Loading state, empty state, error state.
  - Mapear cada item do JSON para um modelo local (`title`, `body`, `created_at`, `read_at`, `notification_type`, `id`).
  - Toque em item não-lido (`read_at == null`) chama `service.markAsRead(id)` e atualiza UI.

### 5.3 Modelo de dados

Sem migrations nesta fase — os modelos já existem.

---

## 6. Auditoria de Testes (OBRIGATÓRIO antes de implementar)

> **Regra de fluxo do projeto:** todo desenvolvimento começa pela auditoria dos testes existentes e cria/ajusta testes ANTES de tocar no código de produção (TDD).

**Passos:**
1. Listar todos os testes do módulo: `backend/tests/test_notifications.py` + `frontend/test/screens/notifications_settings_screen_test.dart` + `frontend/test/services/notification_service_test.dart`.
2. Identificar duplicados ou que cobrem o mesmo cenário sob nomes diferentes — consolidar.
3. Identificar testes que validam comportamento agora obsoleto (ex.: que assumiam mock data) — remover ou atualizar.
4. Mapear cobertura atual para os 9 itens de RN — listar lacunas.
5. **Antes de tocar em código de produção**, escrever os testes faltantes (failing tests).
6. Implementar o código de produção até os testes passarem.

---

## 7. Testes desta Fase

### Backend (pytest)
- `test_get_preferences_commits_new_row` — garante que após GET a preferência persiste.
- `test_regenerate_schedules_create_7_days` — atualizar `workout_reminder_time` cria 7 schedules.
- `test_regenerate_schedules_respeita_silent_days` — silent_days=[0,6] só cria schedules em dias úteis dentro da janela.
- `test_regenerate_schedules_deleta_pendentes_anteriores` — segunda atualização não duplica.
- `test_replenish_job_mantem_horizonte` — job adiciona schedules para o 7º dia futuro.
- `test_notify_new_workout_sheet_dispara_send` — criar `WorkoutSheet` chama o service (mock do FCM).
- `test_notify_new_workout_sheet_falha_silenciosa` — exceção no FCM não quebra criação da ficha.
- `test_notify_achievement_dispara_send` — completar `Goal` chama o service.

### Frontend (flutter_test)
- `test_notifications_screen_carrega_historico_da_api` — service mock retorna lista, UI exibe.
- `test_notifications_screen_estado_vazio` — service retorna `[]`, UI mostra empty state.
- `test_notifications_screen_estado_erro` — service lança, UI mostra erro.
- `test_notifications_screen_marca_como_lida_ao_tocar` — toque em item não-lido chama `markAsRead`.
- `test_provider_registrado_em_web` — em ambiente kIsWeb, `context.read<NotificationService>()` resolve.

### Cobertura mínima
- Backend: ≥ 80% nas linhas adicionadas/modificadas.
- Frontend: cada novo widget tem ≥ 1 teste de comportamento.

---

## 8. Definição de Pronto

- [ ] Auditoria de testes feita e documentada no PR (lista de duplicados removidos / lacunas cobertas).
- [ ] Todos os testes novos escritos antes do código de produção (commits separados: `test(...)` antes de `feat(...)/fix(...)`).
- [ ] `pytest -v` passa, cobertura ≥ 80% das linhas tocadas.
- [ ] `flutter test` passa em todos os arquivos.
- [ ] Tela de notificações exibe histórico real (testado manualmente em dev com `docker compose up`).
- [ ] Settings funciona em build Web sem `ProviderNotFoundException`.
- [ ] Criar uma ficha de treino atribuída a um aluno gera um `NotificationLog` para o aluno.
- [ ] Completar uma meta gera um `NotificationLog` para o usuário.
- [ ] PR contra `develop` (não main).
- [ ] Branch `fix/notificacoes-fase-1-criticos`.
- [ ] Commits seguem `COMMIT_GUIDE.md` (português, conventional, sem Co-Author).

---

## 9. Riscos e Mitigações

| Risco | Mitigação |
|-------|-----------|
| Falha de FCM derruba criação de ficha | `notify_*` envolve em try/except, loga e segue |
| Job de replenish duplica schedules | Sempre deletar pendentes futuros antes de gerar |
| Mock data deletado quebra outras telas | Buscar usos de `mock_data.notifications` e isolar somente o array dessa feature |
| Stub Web não tem FCM token | `update_token` simplesmente não é chamado em Web (já é o caso hoje) |

---

*PRD Notificações - Fase 1: Bugs Críticos*
*OmniConnect Fitness - Alpha EdTech - Turma Aurora*
