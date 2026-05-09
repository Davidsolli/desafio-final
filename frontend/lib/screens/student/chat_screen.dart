import 'dart:async';
import 'dart:convert';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/api_config.dart';
import '../../routes/app_routes.dart';
import '../../services/chat_api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';

/// Tela do chatbot do aluno.
///
/// Suporta 3 modos:
/// - Conversa nova: instancia, conecta WS, primeira pergunta cria conversa.
/// - Conversa existente: passar `conversationId` para retomar.
/// - Testes: passar `channelFactory` (e opcionalmente `jwtToken`) para
///   evitar a leitura de `SharedPreferences` e usar um canal fake.
class ChatScreen extends StatefulWidget {
  final String? conversationId;

  /// Fábrica de WebSocketChannel — apenas para testes.
  @visibleForTesting
  final WebSocketChannel Function(Uri uri)? channelFactory;

  /// Token JWT injetado — apenas para testes (sem `SharedPreferences`).
  @visibleForTesting
  final String? jwtToken;

  /// Serviço para carregar histórico ao abrir uma conversa existente.
  ///
  /// Se `null`, usa o `ChatApiService` registrado no `Provider`.
  final ChatApiService? apiService;

  const ChatScreen({
    super.key,
    this.conversationId,
    this.channelFactory,
    this.jwtToken,
    this.apiService,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatMsg {
  final String role;
  final String text;
  final String time;
  _ChatMsg({required this.role, required this.text, required this.time});
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMsg> _messages = [];

  WebSocketChannel? _channel;
  bool _isConnected = false;
  String? _conversationId;

  // Indicador de carregamento (Card 18.7)
  bool _isTyping = false;
  String _typingStatus = '';

  /// Rola para o fim da lista após o próximo frame.
  ///
  /// Usado depois de `setState` que adiciona ou troca uma mensagem
  /// para garantir que o usuário sempre veja o conteúdo mais recente.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    if (_conversationId != null) {
      _loadHistory(_conversationId!);
    }
    _connectWebSocket();
  }

  Future<void> _loadHistory(String conversationId) async {
    final service = widget.apiService ??
        (_tryReadProvider<ChatApiService>());
    if (service == null) return;

    try {
      final detail = await service.getConversation(conversationId);
      if (!mounted) return;
      setState(() {
        for (final m in detail.messages) {
          _messages.add(_ChatMsg(
            role: m.role,
            text: m.content,
            time: _formatTimeFrom(m.createdAt),
          ));
        }
      });
      _scrollToBottom();
    } catch (_) {
      // Silencioso: a conexão WS continua e o aluno pode prosseguir.
    }
  }

  T? _tryReadProvider<T>() {
    try {
      return context.read<T>();
    } catch (_) {
      return null;
    }
  }

  String _formatTimeFrom(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _connectWebSocket() async {
    final token = widget.jwtToken ?? await _readToken();

    if (token == null || token.isEmpty) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMsg(
          role: 'assistant',
          text: 'Erro de autenticação. Por favor, faça login novamente.',
          time: _formatTime(),
        ));
      });
      return;
    }

    final wsUri = _resolveWsUri();
    if (wsUri == null) return;

    try {
      _channel = (widget.channelFactory ?? WebSocketChannel.connect)(wsUri);

      _channel!.stream.listen(
        _handleServerMessage,
        onDone: () {
          if (!mounted) return;
          setState(() => _isConnected = false);
        },
        onError: (error) {
          if (!mounted) return;
          setState(() {
            _isConnected = false;
            _messages.add(_ChatMsg(
              role: 'assistant',
              text: 'Erro de conexão com o servidor: $error',
              time: _formatTime(),
            ));
          });
        },
      );

      // Pequeno delay para garantir que o stream está em listening antes do auth
      await Future<void>.delayed(const Duration(milliseconds: 50));
      _channel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnected = false;
        _messages.add(_ChatMsg(
          role: 'assistant',
          text: 'Falha ao conectar no servidor: $e',
          time: _formatTime(),
        ));
      });
    }
  }

  Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Uri? _resolveWsUri() {
    final wsBase = ApiConfig.wsBaseUrl;
    if (wsBase == null) return null;
    return Uri.parse('$wsBase/api/v1/chat/ws');
  }

  void _handleServerMessage(dynamic raw) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (!mounted) return;

    final type = data['type'] as String?;
    switch (type) {
      case 'auth_success':
        setState(() {
          _isConnected = true;
          if (_messages.isEmpty) {
            _messages.add(_ChatMsg(
              role: 'assistant',
              text:
                  'Olá! 👋 Sou seu assistente fitness conectado. Como posso te ajudar hoje?',
              time: _formatTime(),
            ));
          }
        });
        _scrollToBottom();
        break;

      case 'auth_error':
        setState(() {
          _isConnected = false;
          _messages.add(_ChatMsg(
            role: 'assistant',
            text:
                'Erro de autenticação: ${data['error'] ?? 'Desconhecido'}',
            time: _formatTime(),
          ));
        });
        _scrollToBottom();
        _channel?.sink.close();
        break;

      case 'status':
        setState(() {
          _isTyping = true;
          _typingStatus =
              (data['message'] as String?) ?? 'Pensando...';
        });
        _scrollToBottom();
        break;

      case 'response':
        if (data['conversation_id'] != null) {
          _conversationId = data['conversation_id'] as String;
        }
        setState(() {
          _isTyping = false;
          _typingStatus = '';
          _messages.add(_ChatMsg(
            role: 'assistant',
            text: (data['content'] as String?) ?? '',
            time: _formatTime(),
          ));
        });
        _scrollToBottom();
        break;

      case 'error':
      case 'timeout':
        setState(() {
          _isTyping = false;
          _typingStatus = '';
          _messages.add(_ChatMsg(
            role: 'assistant',
            text:
                'Desculpe, ocorreu um erro: ${data['error'] ?? 'Desconhecido'}',
            time: _formatTime(),
          ));
        });
        _scrollToBottom();
        if (type == 'timeout') _channel?.sink.close();
        break;
    }
  }

  String _formatTime() {
    final now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMsg(
        role: 'user',
        text: text,
        time: _formatTime(),
      ));
      // Mostra indicador imediatamente — não esperar status do servidor
      _isTyping = true;
      _typingStatus = 'Analisando sua pergunta...';
    });
    _scrollToBottom();

    if (_isConnected && _channel != null) {
      final payload = <String, dynamic>{'type': 'message', 'content': text};
      if (_conversationId != null) {
        payload['conversation_id'] = _conversationId!;
      }
      _channel!.sink.add(jsonEncode(payload));
    } else {
      setState(() {
        _isTyping = false;
        _typingStatus = '';
        _messages.add(_ChatMsg(
          role: 'assistant',
          text:
              'Você está desconectado. Reinicie o aplicativo para tentar novamente.',
          time: _formatTime(),
        ));
      });
      _scrollToBottom();
    }

    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.android,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assistente IA',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  _isConnected ? 'Online' : 'Desconectado',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: _isConnected
                            ? Colors.green
                            : context.colors.textSecondary,
                      ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Histórico',
            icon: const Icon(Icons.history),
            onPressed: () => context.push(AppRoutes.chatHistory),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _ProfessionalDisclaimer(),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isTyping && index == _messages.length) {
                    return _TypingIndicator(status: _typingStatus);
                  }
                  final msg = _messages[index];
                  final isUser = msg.role == 'user';
                  return FadeInUp(
                    delay: Duration(milliseconds: index * 50),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser
                                ? AppColors.primary
                                : context.colors.surface,
                            border: isUser
                                ? null
                                : Border.all(
                                    color: context.colors.border, width: 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: isUser
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.text,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: isUser
                                          ? Colors.white
                                          : context.colors.textPrimary,
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg.time,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: isUser
                                          ? Colors.white
                                              .withValues(alpha: 0.7)
                                          : context.colors.textMuted,
                                      fontSize: 10,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(
                    top: BorderSide(color: context.colors.border, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: _isConnected,
                      decoration: InputDecoration(
                        hintText:
                            _isConnected ? 'Pergunte algo...' : 'Conectando...',
                        hintStyle:
                            TextStyle(color: context.colors.textMuted),
                        filled: true,
                        fillColor: context.colors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                      style: TextStyle(color: context.colors.textPrimary),
                      minLines: 1,
                      maxLines: 3,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: _isConnected ? AppColors.primary : Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send,
                          color: Colors.white, size: 20),
                      onPressed: _isConnected ? _sendMessage : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner persistente do Card 19.9: lembra que o assistente é informativo.
class _ProfessionalDisclaimer extends StatelessWidget {
  const _ProfessionalDisclaimer();

  static const String text =
      'Este assistente é informativo e não substitui a orientação do seu '
      'Personal Trainer ou Nutricionista.';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentWarning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accentWarning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline,
              color: AppColors.accentWarning, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: context.colors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador animado "o bot está pensando".
///
/// Exibe ícone do bot + 3 pontos pulsando + texto de status.
class _TypingIndicator extends StatefulWidget {
  final String status;
  const _TypingIndicator({required this.status});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border:
                Border.all(color: context.colors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.android,
                    color: AppColors.primary, size: 16),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (_, __) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(3, (i) {
                        final t =
                            (_controller.value * 3 - i).clamp(0.0, 1.0);
                        final opacity =
                            (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.2, 1.0);
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Opacity(
                            opacity: opacity,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.status,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
