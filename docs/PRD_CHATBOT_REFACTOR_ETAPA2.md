# PRD: Refatoração do Chatbot — Etapa 2: Frontend + Histórico + UX

**Versão:** 1.0  
**Data:** 2026-05-09  
**Status:** 📋 Pronto para Implementação (após Etapa 1)  
**Escopo:** Cards 18.7, 18.9, 18.10, 19.9  
**Dependência:** PRD_CHATBOT_REFACTOR_ETAPA1.md deve estar concluído

---

## 📋 1. Visão Geral

### Objetivo
Refatorar o **frontend Flutter** do chatbot para implementar feedback visual de carregamento, consulta de histórico de conversas, e aviso de responsabilidade profissional. Também corrigir a persistência do histórico no backend.

### Problemas Identificados

| # | Problema | Arquivo | Impacto |
|---|---------|---------|---------|
| 1 | **Sem indicador "pensando..."** — tela fica parada enquanto IA processa | `chat_screen.dart` | UX terrível |
| 2 | **Sem tela de histórico** — aluno não vê conversas anteriores | Não existe | Card 18.10 não atendido |
| 3 | **Sem aviso de responsabilidade** — nada informa que IA ≠ profissional | `chat_screen.dart` | Card 19.9 não atendido |
| 4 | **Sem scroll automático** — novas mensagens não rolam para baixo | `chat_screen.dart` | UX ruim |
| 5 | **Status intermediários não consumidos** — backend (Etapa 1) vai enviar `type: status` mas Flutter não trata | `chat_screen.dart` | Feedback não aparece |

---

## 📐 2. Padrões Obrigatórios

### 2.1 Arquivos de Referência
- [`BRANCH_STRATEGY.md`](../BRANCH_STRATEGY.md)
- [`COMMIT_GUIDE.md`](../COMMIT_GUIDE.md)

### 2.2 Branch
```bash
git checkout -b refactor/chatbot-frontend-ux
```

### 2.3 Commits
```
refactor(chatbot-ui): <descrição em português>
feat(chatbot-ui): <descrição em português>
test(chatbot-ui): <descrição em português>
```

---

## 🧪 3. Regras de TDD

> [!CAUTION]
> As mesmas regras da Etapa 1 se aplicam. Testes PRIMEIRO, código DEPOIS. PROIBIDO modificar testes para fazer código passar.

### 3.1 Verificação de Duplicados (Flutter)

```bash
grep -rn "test(" frontend/test/ --include="*.dart"
# Identificar duplicatas → remover → documentar
```

### 3.2 Mapeamento Card → Testes

#### Card 18.7 — Tela de chatbot no app
```dart
// test/screens/student/chat_screen_test.dart

testWidgets('chat screen exists and renders', (tester) async {
  // Deve existir tela dedicada ao chatbot
});

testWidgets('user can type and send message', (tester) async {
  // Usuário consegue enviar mensagens
});

testWidgets('ai responses displayed in chat format', (tester) async {
  // Respostas da IA exibidas em formato de conversa
});

testWidgets('message history maintained during session', (tester) async {
  // Histórico mantido durante a sessão
});

testWidgets('loading indicator shown while ai responds', (tester) async {
  // Indicador de carregamento enquanto IA responde
  // CRÍTICO: deve mostrar "Analisando...", "Buscando...", "Preparando..."
});

testWidgets('user and bot messages visually distinct', (tester) async {
  // Mensagens do usuário e bot visualmente distintas
});

testWidgets('layout is responsive', (tester) async {
  // Layout responsivo
});

testWidgets('screen consumes chatbot endpoint correctly', (tester) async {
  // Consome endpoint de chatbot via WebSocket
});
```

#### Card 18.9 — Salvar histórico (Backend)
```python
# tests/test_chat_service.py

def test_all_messages_are_saved():
    """Sistema salva todas as mensagens do chatbot."""

def test_conversations_linked_to_correct_user():
    """Conversas vinculadas ao usuário correto."""

def test_history_organized_by_session():
    """Histórico organizado por sessão/thread."""

def test_history_retrievable_from_backend():
    """Backend permite recuperação do histórico."""

def test_history_usable_as_context():
    """Histórico pode ser usado como contexto para novas respostas."""

def test_history_storage_performance():
    """Armazenamento não impacta performance."""
```

#### Card 18.10 — Consultar histórico no app
```dart
// test/screens/student/chat_history_screen_test.dart

testWidgets('app displays chat history', (tester) async {
  // App exibe histórico de conversas
});

testWidgets('messages loaded from backend correctly', (tester) async {
  // Mensagens carregadas do backend
});

testWidgets('history displayed by session chronologically', (tester) async {
  // Histórico por sessão/ordem cronológica
});

testWidgets('respects authenticated user', (tester) async {
  // Respeita usuário autenticado
});

testWidgets('handles empty history state', (tester) async {
  // Trata casos sem histórico
});

testWidgets('maintains chat interface pattern', (tester) async {
  // Layout mantém padrão de interface de chat
});
```

#### Card 19.9 — Aviso de responsabilidade
```dart
// test/screens/student/chat_disclaimer_test.dart

testWidgets('disclaimer is displayed in chat interface', (tester) async {
  // Aviso exibido na interface do chat
});

testWidgets('disclaimer appears on first message or start', (tester) async {
  // Aviso aparece na abertura ou primeira mensagem
});

testWidgets('disclaimer text is clear and objective', (tester) async {
  // Texto claro, objetivo e compreensível
});

testWidgets('disclaimer does not block user experience', (tester) async {
  // Aviso não interfere negativamente na UX
});
```

```python
# tests/test_chat_service.py — Backend
def test_disclaimer_consistent_across_channels():
    """Aviso consistente em app e WhatsApp."""
```

---

## 🔧 4. Tarefas Ordenadas

### Tarefa 1: Auditoria de Testes Flutter

1. Verificar testes existentes em `frontend/test/`
2. Remover duplicatas
3. Criar estrutura para testes de chat

```bash
git commit -m "test(chatbot-ui): auditar e preparar estrutura de testes"
```

### Tarefa 2: Criar Testes Flutter (RED PHASE)

1. Criar testes conforme mapeamento seção 3.2
2. Todos devem FALHAR inicialmente

```bash
git commit -m "test(chatbot-ui): adicionar testes dos critérios de aceite"
```

### Tarefa 3: Implementar Indicador de Carregamento (CRÍTICO)

**Problema atual:** Quando o usuário faz uma pergunta, a tela fica parada por vários segundos sem feedback. A resposta aparece "de uma vez", como se nada estivesse acontecendo.

**Solução:** Consumir os status intermediários do WebSocket (implementados na Etapa 1).

```dart
// Novo estado no _ChatScreenState
bool _isTyping = false;
String _typingStatus = '';

// No listener do WebSocket, tratar 'status':
if (data['type'] == 'status') {
  setState(() {
    _isTyping = true;
    _typingStatus = data['message'] ?? 'Pensando...';
  });
} else if (data['type'] == 'response') {
  setState(() {
    _isTyping = false;
    _typingStatus = '';
    _messages.add({...});
  });
}
```

**Widget de indicador (animado):**
```dart
// Exibir quando _isTyping == true, abaixo das mensagens
Widget _buildTypingIndicator() {
  return AnimatedContainer(
    duration: Duration(milliseconds: 300),
    child: Row(
      children: [
        // Ícone do bot
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.android, size: 18),
        ),
        SizedBox(width: 8),
        // Bolhas animadas + texto de status
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPulsingDots(),  // 3 pontos animados
            Text(_typingStatus, style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ],
    ),
  );
}
```

**Comportamento esperado:**
1. Usuário envia mensagem → aparece imediatamente na tela
2. **Instantaneamente** aparece indicador: `🤖 Analisando sua pergunta...` (com pontos animados)
3. Muda para: `🔍 Buscando na base de conhecimento...`
4. Muda para: `✍️ Preparando sua resposta...`
5. Indicador desaparece → resposta do bot aparece com animação suave

```bash
git commit -m "feat(chatbot-ui): implementar indicador de carregamento animado"
```

### Tarefa 4: Implementar Auto-Scroll

```dart
final ScrollController _scrollController = ScrollController();

void _scrollToBottom() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  });
}

// Chamar após cada setState que adiciona mensagem
```

```bash
git commit -m "feat(chatbot-ui): adicionar auto-scroll ao receber mensagens"
```

### Tarefa 5: Implementar Aviso de Responsabilidade (Card 19.9)

**Aviso persistente no topo do chat:**

```dart
Widget _buildDisclaimer() {
  return Container(
    margin: EdgeInsets.all(16),
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.amber.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.amber.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, color: Colors.amber, size: 18),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Este assistente é informativo e não substitui a orientação do seu Personal Trainer ou Nutricionista.',
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ),
      ],
    ),
  );
}
```

**Backend:** Incluir aviso na primeira resposta de cada conversa nova.

```bash
git commit -m "feat(chatbot-ui): adicionar aviso de não substituição profissional"
```

### Tarefa 6: Criar Tela de Histórico (Card 18.10)

**Nova tela: `chat_history_screen.dart`**

1. Lista de conversas anteriores (carregadas de `GET /api/v1/chat/conversations`)
2. Cada item mostra: data, status, preview da primeira mensagem, contagem
3. Ao clicar → abre conversa completa (reusa `ChatScreen` com `conversation_id`)
4. Estado vazio: "Você ainda não tem conversas. Comece perguntando algo!"

**Criar serviço de API:**
```dart
// lib/services/chat_api_service.dart
class ChatApiService {
  Future<List<Conversation>> getConversations({int page = 1, int limit = 20});
  Future<ConversationDetail> getConversation(String conversationId);
}
```

```bash
git commit -m "feat(chatbot-ui): criar tela de histórico de conversas"
```

### Tarefa 7: Melhorar UX da Tela de Chat

1. **Mensagem de boas-vindas** mais contextual (usar nome do aluno)
2. **Sugestões rápidas** — botões com perguntas frequentes abaixo do campo de input
3. **Timestamp** melhorado (ex: "Hoje 14:30" vs "14:30")
4. **Reconexão automática** se WebSocket desconectar

```bash
git commit -m "feat(chatbot-ui): melhorar UX com sugestões e reconexão"
```

### Tarefa 8: Testes de Histórico no Backend (Card 18.9)

Verificar que `chat_service.py` já salva corretamente:
1. Todas as mensagens (user + assistant) → verificar
2. Vinculação ao usuário → verificar
3. Organização por sessão → verificar
4. Performance → verificar com volume

```bash
git commit -m "test(chatbot): validar persistência de histórico"
```

### Tarefa 9: Validar (GREEN PHASE)

```bash
# Backend
pytest tests/test_chat*.py -v --cov

# Frontend
cd frontend && flutter test test/screens/student/chat*.dart
```

---

## ✅ 5. Definição de Pronto

- [ ] Indicador de carregamento animado funcionando ("Analisando...", "Buscando...", "Preparando...")
- [ ] Auto-scroll implementado
- [ ] Aviso de não substituição profissional visível
- [ ] Tela de histórico de conversas criada e funcional
- [ ] Serviço de API de chat criado no Flutter
- [ ] Sugestões rápidas implementadas
- [ ] Reconexão automática de WebSocket
- [ ] Testes Flutter criados e passando
- [ ] Testes de histórico no backend validados
- [ ] Nenhum teste modificado para fazer código passar
- [ ] Branch: `refactor/chatbot-frontend-ux`, PR contra `develop`

---

## 📊 6. Estimativa

| Tarefa | Tempo Estimado |
|--------|---------------|
| Auditoria testes Flutter | 20 min |
| Criar testes (red) | 45 min |
| Indicador de carregamento | 45 min |
| Auto-scroll | 15 min |
| Aviso de responsabilidade | 20 min |
| Tela de histórico | 1h |
| Melhorias de UX | 45 min |
| Testes backend histórico | 30 min |
| Validação final | 30 min |
| **TOTAL** | **~5h** |

---

*Próxima etapa: PRD_CHATBOT_REFACTOR_ETAPA3.md — WhatsApp + Escalação + Base de Conhecimento*
