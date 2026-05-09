# Auditoria de Testes Flutter — Etapa 2 do Chatbot

**Data:** 2026-05-09
**Branch:** `feat/chatbot-completo`
**Escopo:** preparar a estrutura de testes do chatbot (frontend) antes de
implementar Cards 18.7, 18.10 e 19.9.

---

## 1. Inventário atual (`frontend/test/`)

```
frontend/test/
├── theme_provider_test.dart                        # 9 tests
├── widget_test.dart                                # 1 test (smoke)
├── models/
│   └── workout_sheet_model_test.dart               # 22 tests
├── services/
│   └── workout_sheet_service_test.dart             # 4 tests
└── widgets/
    ├── omni_app_bar_test.dart                      # 8 tests
    ├── omni_avatar_test.dart                       # 5 tests
    ├── omni_button_test.dart                       # 6 tests
    ├── omni_card_test.dart                         # 6 tests
    ├── omni_empty_state_test.dart                  # 5 tests
    ├── omni_error_state_test.dart                  # 5 tests
    ├── omni_info_chip_test.dart                    # 5 tests
    ├── omni_loader_test.dart                       # 7 tests
    ├── omni_progress_bar_test.dart                 # 5 tests
    ├── omni_section_header_test.dart               # 5 tests
    ├── omni_stat_card_test.dart                    # 6 tests
    ├── omni_status_badge_test.dart                 # 3 tests
    └── omni_text_field_test.dart                   # 6 tests
```

## 2. Testes relacionados ao chatbot encontrados

**Nenhum.** A pasta `frontend/test/screens/student/` ainda não existe.
Não há testes para `chat_screen.dart`, histórico de conversas, banner de
disclaimer ou serviço de API de chat.

## 3. Duplicidades identificadas

**Nenhuma duplicidade entre testes existentes e os novos da Etapa 2.**
Os testes existentes cobrem widgets compartilhados (`omni_*`), tema e
modelos de ficha de treino — escopos completamente disjuntos do chatbot.

A regra **RT-04** (remover testes duplicados antes de criar novos) é
trivialmente satisfeita pela ausência de duplicatas.

## 4. Estrutura criada para os novos testes

```
frontend/test/
├── screens/
│   └── student/
│       ├── chat_screen_test.dart            # Card 18.7
│       ├── chat_history_screen_test.dart    # Card 18.10
│       └── chat_disclaimer_test.dart        # Card 19.9
└── services/
    └── chat_api_service_test.dart           # apoio dos cards 18.10
```

## 5. Convenções adotadas

- Nomes em **inglês** (mesmo padrão dos testes em `widgets/`).
- `testWidgets` para widget tests (Cards 18.7, 18.10, 19.9).
- `test` para unit tests do `ChatApiService` (modelos `Conversation`,
  `ConversationDetail`, parsing de JSON).
- Mock do WebSocket via `web_socket_channel/io.dart` em modo memory
  quando aplicável; testes que dependem de WebSocket real são marcados
  com comentário `// Manual: requer backend real` e validados via
  testes de modelo (parse de mensagens) em vez de tráfego real.
- Mock do `ApiClient` via `MockApiClient` minimalista (sem libs
  adicionais — segue o padrão de `workout_sheet_service_test.dart`).

## 6. Próximos passos

1. Commit `test(chatbot-ui): auditar e preparar estrutura de testes`
2. Criar testes RED conforme PRD seção 3.2 (cards 18.7, 18.10, 19.9).
3. Implementar até GREEN, sem modificar testes para forçar passagem.
