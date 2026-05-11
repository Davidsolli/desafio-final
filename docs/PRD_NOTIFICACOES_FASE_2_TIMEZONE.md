# PRD — Notificações Fase 2: Timezone, Idempotência e Coerência de Horários

**Projeto:** OmniConnect Fitness
**Data:** 2026-05-11
**Status:** 📋 Em Especificação
**Responsável:** Anderson Chaves
**Branch:** `fix/notificacoes-fase-2-timezone`
**Base:** `develop` (após merge da Fase 1)
**PR contra:** `develop`

---

## 1. Problema

A Fase 1 destrava o módulo, mas mantém bugs lógicos que afetam usuários reais:

1. **Quiet hours / silent days comparados em UTC.** O PRD original diz "horário local", mas `notification_service.py:109,124` usa `datetime.now(timezone.utc)`. Aluno em SP (UTC-3) configurando "silenciar 22:00–07:00" será silenciado das 19:00 às 04:00 horário local.
2. **`meal_reminder_time` comparado em UTC.** O scheduler (`scheduler.py:122`) admite no comentário que "o frontend deve converter para UTC", mas o frontend não converte.
3. **`WorkoutSession.session_date` é `DateTime` naive**, comparado com `cutoff` tz-aware no job de inatividade — coerção ambígua no PostgreSQL, risco de erro silencioso (capturado pelo `except Exception` genérico).
4. **`meal_reminder` pode disparar 2× no mesmo dia** — janela de ±3 min com cron a cada 5 min, sem idempotência.
5. **Inatividade não filtra `status`** — sessões `deleted` ou `skipped` contam como atividade.
6. **Trainer não tem `NotificationPreference`** — não consegue silenciar `student_inactivity` via toggle.

---

## 2. Objetivo

Tornar as notificações **corretas no fuso horário do usuário**, **idempotentes por dia** e **coerentes com o estado real** dos dados (não contando sessões deletadas, não duplicando lembretes).

---

## 3. Escopo

### Incluído

- Coluna `timezone` em `User` (string IANA, default `"America/Sao_Paulo"`).
- Conversão de UTC → fuso do usuário em todos os guards (`quiet_hours`, `silent_days`).
- Conversão de UTC → fuso do usuário ao comparar `meal_reminder_time` no scheduler.
- Migração de `WorkoutSession.session_date` para `DateTime(timezone=True)` + ALTER TABLE em `init_db`.
- Idempotência diária para `meal_reminder`: checar se já existe `NotificationLog` do dia (no fuso do usuário) antes de enviar.
- Filtro de `status in ("completed", "in_progress")` na query de inatividade.
- Auto-criação de `NotificationPreference` para trainers no primeiro acesso ao endpoint de prefs (já é o comportamento, mas garantir que o GET commita — herdado da Fase 1).
- Endpoint `PUT /api/v1/users/me/timezone` para o usuário atualizar seu fuso (ou expor via DTO de perfil).

### Fora do escopo

- Detecção automática de fuso pelo IP / dispositivo (ficaria pra fase futura).
- Migração massiva de logs já gravados (irrelevante — só timestamps de criação).
- Reescrever o scheduler em UTC totalmente diferente: mantém UTC como base e converte sob demanda.

---

## 4. Regras de Negócio

| ID | Regra |
|----|-------|
| RN01 | Todo `NotificationPreference.quiet_hours_*` e `silent_days` é interpretado no fuso do `User.timezone` |
| RN02 | `NotificationPreference.meal_reminder_time` é interpretado no fuso do `User.timezone` |
| RN03 | Falta de `User.timezone` (NULL) cai no default `"America/Sao_Paulo"` |
| RN04 | Fuso inválido (string não-IANA) é rejeitado pelo PUT com 400 |
| RN05 | `meal_reminder` dispara no máximo 1× por dia por usuário (medido no fuso dele) |
| RN06 | `student_inactivity` só conta `WorkoutSession` com `status in ("completed", "in_progress")` |
| RN07 | `WorkoutSession.session_date` é sempre persistido com timezone (UTC); comparações usam `cutoff` tz-aware sem coerção |
| RN08 | Job de meal reminder NÃO escreve `NotificationLog` se já houver um do mesmo dia/usuário/tipo no fuso do user |

---

## 5. Especificação Técnica

### 5.1 Backend — Modelos & Migração

**`app/models/user.py`**
- Adicionar `timezone = Column(String(50), nullable=True, default=None)`.

**`app/models/logbook.py`**
- Trocar `session_date = Column(DateTime, nullable=False, ...)` por `Column(DateTime(timezone=True), nullable=False, ...)`.
- Idem para `created_at`, `updated_at`, `completed_at` se também forem naive.

**`app/config/database.py`** (em `init_db`)
- `ALTER TABLE users ADD COLUMN IF NOT EXISTS timezone VARCHAR(50)`.
- `ALTER TABLE workout_sessions ALTER COLUMN session_date TYPE TIMESTAMPTZ USING session_date AT TIME ZONE 'UTC'` (e equivalentes).

### 5.2 Backend — Serviço

**`app/services/notification_service.py`**
- Helper `_user_local_now(user) -> datetime` — usa `zoneinfo.ZoneInfo(user.timezone or "America/Sao_Paulo")`.
- Substituir `datetime.now(timezone.utc).time()` por `_user_local_now(user).time()` no guard de quiet hours.
- Substituir `datetime.now(timezone.utc).weekday()` por `_user_local_now(user).weekday()` no guard de silent days.
- Carregar o `User` antes dos guards (uma vez só) e passar para os helpers.

**`app/tasks/notification_scheduler.py`**
- `check_and_send_meal_reminders`: para cada `pref`, buscar o `User`, calcular `now_local = _user_local_now(user)`, comparar `meal_reminder_time` com `now_local.time()`.
- Antes de chamar `send_notification`, verificar via repository: existe `NotificationLog` do tipo `meal_reminder` para esse `user_id` cujo `created_at` cai no mesmo dia local? Se sim, `continue`.
- `check_student_inactivity`: query com `WorkoutSession.status.in_(["completed", "in_progress"])`.

### 5.3 Backend — DTO/Endpoint de timezone

**`app/dtos/user_dto.py`**
- Adicionar campo opcional `timezone` no DTO de update do usuário (validação: `ZoneInfo(value)` não levanta).

**`app/routes/user.py`** ou similar
- Aceitar `timezone` no PUT existente do perfil. Se não houver, criar `PUT /api/v1/users/me/timezone`.

### 5.4 Frontend

**`frontend/lib/screens/notifications_settings_screen.dart`**
- Adicionar dropdown de fuso (lista curta: SP, BSB, AC, Manaus, BR-leste etc., + "Detectar do dispositivo").
- "Detectar" usa `DateTime.now().timeZoneName` ou `package:intl` para mapear (best-effort).
- Atualiza via service ao usuário trocar.

**`frontend/lib/services/notification_service_*.dart`**
- Adicionar `Future<bool> updateTimezone(String tz)` chamando o endpoint.

---

## 6. Auditoria de Testes (OBRIGATÓRIO antes de implementar)

1. Reler `backend/tests/test_notifications.py` após Fase 1 mergeada.
2. Identificar testes que assumem UTC (ex.: `test_send_notification_bloqueada_por_quiet_hours` com 00:00–23:59 — vai continuar passando, mas é frágil).
3. Listar testes que precisam mock de `User.timezone`. Criar fixture compartilhada `_make_user_with_tz(tz="America/Sao_Paulo")`.
4. Mapear cobertura atual para RN01–RN08; listar lacunas; escrever testes failing primeiro.

---

## 7. Testes desta Fase

### Backend
- `test_quiet_hours_respeita_timezone_brasil` — user em SP, UTC=03:00, local=00:00, quiet 22:00–07:00 → bloqueia.
- `test_quiet_hours_respeita_timezone_manaus` — user UTC-4, mesmo cenário.
- `test_silent_day_usa_weekday_local` — quinta UTC pode ser quarta local; preferência silencia quarta → bloqueia.
- `test_meal_reminder_dispara_uma_vez_por_dia` — dois ticks no mesmo dia local, um envia, segundo é skipped.
- `test_meal_reminder_dispara_dois_dias_seguidos` — dia muda, novo envio.
- `test_inactivity_ignora_sessoes_deleted` — aluno com 1 sessão `deleted` há 1 dia é considerado inativo.
- `test_inactivity_considera_sessao_in_progress` — aluno com 1 sessão `in_progress` há 1 dia é ativo.
- `test_workout_session_session_date_tz_aware` — coluna nova é tz-aware, comparação não levanta.
- `test_user_timezone_default_sao_paulo` — user sem timezone usa SP.
- `test_user_timezone_invalido_400` — PUT com tz inválido retorna 400.

### Frontend
- `test_settings_screen_dropdown_timezone_renderiza`.
- `test_settings_screen_atualiza_timezone_chama_service`.

### Cobertura
- Backend: ≥ 80% nas linhas tocadas.

---

## 8. Definição de Pronto

- [ ] Auditoria de testes documentada no PR.
- [ ] Testes failing escritos antes do código (commits `test(...)` precedem `feat(...)/fix(...)`).
- [ ] Migração de `session_date` testada com `docker compose down -v && up --build`.
- [ ] `pytest -v --cov` ≥ 80%.
- [ ] `flutter test` passa.
- [ ] Manual: cliente em SP configura quiet 22:00–07:00 e às 21:00 local **recebe** push, às 22:00 **não** recebe.
- [ ] Manual: meal reminder configurado às 12:00 local dispara 1×, mesmo com cron a cada 5 min.
- [ ] PR contra `develop`, branch `fix/notificacoes-fase-2-timezone`.

---

## 9. Riscos e Mitigações

| Risco | Mitigação |
|-------|-----------|
| Migração de `session_date` falha em produção (dados existentes) | Usar `IF EXISTS` + `USING ... AT TIME ZONE 'UTC'`; testar em base populada |
| Lista de fusos no frontend desatualiza | Lista curta + opção "outro" com input livre validado pelo backend |
| Idempotência de meal reminder ignora reinstalações de app | Aceitável — reenviar se realmente houve perda é trade-off pequeno |

---

*PRD Notificações - Fase 2: Timezone & Coerência*
*OmniConnect Fitness - Alpha EdTech - Turma Aurora*
