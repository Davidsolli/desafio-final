# PRD — Notificações Fase 3: Qualidade de Código e Segurança

**Projeto:** OmniConnect Fitness
**Data:** 2026-05-11
**Status:** 📋 Em Especificação
**Responsável:** Anderson Chaves
**Branch:** `chore/notificacoes-fase-3-cleanup`
**Base:** `develop` (após Fases 1 e 2)
**PR contra:** `develop`

---

## 1. Problema

Após resolver bugs funcionais (Fases 1 e 2), o módulo ainda tem dívidas técnicas e um pequeno problema de segurança:

1. **`Colors.grey.withOpacity(...)`** (deprecated desde Flutter 3.27) usado em `notifications_settings_screen.dart:115,163`, enquanto o restante do arquivo já usa `withValues(alpha:)`.
2. **`Key? key`** em vez de `super.key` em ambas as telas (lint warning).
3. **Imports não usados** em `app/models/notification.py` (`Any`, `Dict`).
4. **Param `type`** sombreia builtin Python em `notification_controller.py:42` (deve ser `notification_type`).
5. **Tipos inconsistentes para `data`**: `Dict[str, str]` no service, `Dict[str, Any]` no FCM e no DTO.
6. **`google-services.json` commitado** (`frontend/android/app/google-services.json`), mesmo estando no `.gitignore` (foi commitado antes do gitignore — git ainda tracka).
7. **Sem rate limit** em `/api/v1/notifications/token` — endpoint authenticated mas suscetível a flood.

---

## 2. Objetivo

Levar o módulo de notificações ao mesmo padrão de qualidade dos demais (Auth, Goals, Logbook): sem warnings de lint, tipos coerentes, segredos fora do repo e endpoints sensíveis com rate limit.

---

## 3. Escopo

### Incluído

- Substituir `withOpacity` → `withValues(alpha:)`.
- Substituir `Key? key` → `super.key`.
- Limpar imports não usados.
- Renomear param `type` → `notification_type` no controller (manter compatibilidade do query param: aceitar ambos com `Query(alias=...)` ou apenas trocar e atualizar frontend).
- Padronizar tipos de `data` em `Optional[Dict[str, Any]]` em todos os pontos.
- `git rm --cached frontend/android/app/google-services.json` + adicionar `frontend/android/app/google-services.json.example` (template sem keys).
- Restringir a API key vazada no console Firebase (escopo de package + SHA1).
- Aplicar `@limiter.limit("60/minute")` em `/api/v1/notifications/token` (slowapi já está em `main.py`).

### Fora do escopo

- Rotacionar a API key (decisão do squad — pode invalidar builds em circulação).
- Mudar `firebase-credentials.json` (já está fora do git).

---

## 4. Regras de Negócio

| ID | Regra |
|----|-------|
| RN01 | Nenhum warning de `flutter analyze` no módulo de notificações. |
| RN02 | Nenhum lint do backend (ruff/flake8 se configurado) nas linhas tocadas. |
| RN03 | `google-services.json` não fica versionado; build local lê do path local. |
| RN04 | Endpoint `/notifications/token` retorna 429 acima do limite. |
| RN05 | Renomear `type` → `notification_type` é uma quebra de contrato; frontend precisa ser atualizado no mesmo PR. |

---

## 5. Especificação Técnica

### 5.1 Frontend

**`frontend/lib/screens/notifications_settings_screen.dart`**
- Linhas 115 e 163: `withOpacity(0.1)` → `withValues(alpha: 0.1)`. Idem 0.05.
- Linha 7: `const NotificationsSettingsScreen({Key? key}) : super(key: key);` → `const NotificationsSettingsScreen({super.key});`.

**`frontend/lib/screens/notifications_screen.dart`**
- Linha 9: idem `super.key`.

**`frontend/lib/services/notification_service_mobile.dart` / `_stub.dart`**
- Se chamar com `notification_type` em vez de `type` (sincronizar com backend).

**`frontend/android/app/google-services.json.example`**
- Template com `project_id: "REPLACE_ME"`, `api_key: "REPLACE_ME"`.

**`frontend/android/.gitignore` ou raiz** — confirmar regra `google-services.json`.

### 5.2 Backend

**`app/models/notification.py`**
- Remover `from typing import Any, Dict` se não usado.

**`app/controllers/notification_controller.py`**
- Renomear param `type` → `notification_type` no endpoint `get_history`.

**`app/services/notification_service.py`**
- Tipo de `data` em `send_notification`: `Optional[Dict[str, Any]]`.

**`app/services/fcm_service.py`**
- Manter `Optional[Dict[str, Any]]` (já está).

**`app/routes/notification.py`**
- Em `/token`: `@limiter.limit("60/minute")` na rota.

**Operação git**
- `git rm --cached frontend/android/app/google-services.json`.
- Confirmar `.gitignore` cobre o caminho.
- Renomear o existente para `*.example`, com chaves placeholder.

---

## 6. Auditoria de Testes (OBRIGATÓRIO antes de implementar)

1. Verificar se há teste que faz `GET /history?type=...` — atualizar para `notification_type=...`.
2. Verificar se há teste que afirma `data: Dict[str, str]` — relaxar para `Any`.
3. Adicionar 1 teste de rate limit (61 chamadas em 60s → 429).
4. Nenhuma mudança em testes de UI deve ser necessária (só lint).

---

## 7. Testes desta Fase

### Backend
- `test_get_history_aceita_query_notification_type` — substitui o uso de `type=`.
- `test_token_endpoint_rate_limit_60_por_min` — 61º request no mesmo minuto retorna 429.

### Frontend
- Rodar `flutter analyze` no diretório do módulo: zero warnings.
- Os testes existentes devem continuar passando inalterados.

---

## 8. Definição de Pronto

- [ ] Auditoria de testes feita.
- [ ] `flutter analyze` zero warnings em `lib/screens/notifications*.dart` e `lib/services/notification_service*.dart`.
- [ ] `pytest -v` passa, incluindo o teste novo de rate limit.
- [ ] `git ls-files | grep google-services.json` retorna apenas `*.example`.
- [ ] `frontend/android/app/google-services.json` existe localmente mas não no git.
- [ ] README do `frontend/` (ou novo `SETUP_FCM.md`) explica como gerar/colocar o `google-services.json`.
- [ ] PR menciona explicitamente que API key foi restringida no console Firebase (ou abre task pra fazer).
- [ ] Branch `chore/notificacoes-fase-3-cleanup`, PR contra `develop`.

---

## 9. Riscos e Mitigações

| Risco | Mitigação |
|-------|-----------|
| Renomear `type` quebra integração existente | Mudar backend e frontend no mesmo PR; testar manualmente |
| Remover `google-services.json` quebra build Android local de outros devs | README explicando + manter `.example` no repo |
| Rate limit muito agressivo afeta refresh de token FCM | 60/min é folgado pra refresh (acontece raramente) |

---

*PRD Notificações - Fase 3: Qualidade & Segurança*
*OmniConnect Fitness - Alpha EdTech - Turma Aurora*
