import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../config/api_config.dart';
import '../../services/api_client.dart';
import '../../services/chat_service.dart';

/// Chave usada para persistir o id da conversa ativa entre saídas e
/// retornos à tela de chat. Sem isto, cada visita à tela criava uma
/// nova conversa no backend e perdia todo o histórico.
const String _kConversationIdPrefsKey = 'chat_active_conversation_id';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, String>> _messages = [];
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isTyping = false;
  String _typingStatus = '';
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  /// Tenta carregar o histórico da última conversa antes de abrir o
  /// WebSocket. Se não houver conversa salva (ou o id não for mais
  /// válido — usuário trocou de conta, conversa removida etc.), segue
  /// para o WebSocket sem mensagens prévias.
  Future<void> _bootstrap() async {
    await _loadStoredConversation();
    if (!mounted) return;
    await _connectWebSocket();
  }

  Future<void> _loadStoredConversation() async {
    // Capturado de forma síncrona antes de qualquer await — não é
    // seguro tocar em context após gaps assíncronos.
    final chatService = context.read<ChatService>();

    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString(_kConversationIdPrefsKey);
    debugPrint('[chat] _loadStoredConversation lido: $storedId');
    if (storedId == null || storedId.isEmpty) return;

    try {
      final detail = await chatService.getConversation(storedId);
      if (!mounted) return;
      debugPrint(
          '[chat] historico carregado: id=${detail.id}, msgs=${detail.messages.length}');
      setState(() {
        _conversationId = detail.id;
        _messages.addAll(detail.messages.map((m) => {
              'role': m.role,
              'text': m.content,
              'time': _formatTimeFrom(m.createdAt),
            }));
      });
      _scrollToBottom();
    } on NotFoundException {
      debugPrint('[chat] conversa $storedId 404 — limpando id salvo');
      await prefs.remove(_kConversationIdPrefsKey);
    } on UnauthorizedException {
      debugPrint('[chat] conversa $storedId 401 — limpando id salvo');
      await prefs.remove(_kConversationIdPrefsKey);
    } catch (e, st) {
      debugPrint('[chat] erro ao carregar historico: $e\n$st');
    }
  }

  Future<void> _persistConversationId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConversationIdPrefsKey, id);
    debugPrint('[chat] conversation_id salvo: $id');
  }

  Future<void> _connectWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');

    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _messages.add({
            'role': 'assistant',
            'text': 'Erro de autenticação. Por favor, faça login novamente.',
            'time': _formatTime(),
          });
        });
      }
      return;
    }

    // Usa ApiConfig para URL base (não hardcoded)
    final wsBaseUrl = ApiConfig.wsBaseUrl;
    if (wsBaseUrl == null) return;

    final wsUrl = Uri.parse('$wsBaseUrl/api/v1/chat/ws');

    try {
      _channel = WebSocketChannel.connect(wsUrl);

      // Aguarda confirmação de conexão e envia autenticação
      _channel!.stream.listen(
        (message) async {
          final data = jsonDecode(message);

          // Responde ao handshake de autenticação
          if (data['type'] == 'auth_success') {
            if (mounted) {
              setState(() {
                _isConnected = true;
                // Só mostra a saudação inicial se não houver histórico
                // recuperado (caso contrário ela apareceria toda vez
                // que o usuário voltasse à tela).
                if (_messages.isEmpty) {
                  _messages.add({
                    'role': 'assistant',
                    'text': 'Olá! Eu sou o Vitali, assistente da FitLoop. Como posso te ajudar hoje?',
                    'time': _formatTime(),
                  });
                }
              });
              _scrollToBottom();
            }
          } else if (data['type'] == 'auth_error') {
            if (mounted) {
              setState(() {
                _isConnected = false;
                _messages.add({
                  'role': 'assistant',
                  'text': 'Erro de autenticação: ${data['error'] ?? 'Desconhecido'}',
                  'time': _formatTime(),
                });
              });
            }
            _channel?.sink.close();
          } else if (data['type'] == 'status') {
            // Indicador de carregamento intermediário (thinking/searching/generating)
            if (mounted) {
              setState(() {
                _isTyping = true;
                _typingStatus = (data['message'] as String?) ?? 'Processando...';
              });
              _scrollToBottom();
            }
          } else if (data['type'] == 'response') {
            final newId = data['conversation_id'] as String?;
            debugPrint('[chat] response recebida com conversation_id=$newId');
            if (newId != null) {
              _conversationId = newId;
              // Save sincrono (await) para garantir flush em disco antes
              // do dispose; unawaited podia perder a corrida se o usuario
              // saisse da tela imediatamente apos receber a resposta.
              await _persistConversationId(newId);
            }
            if (mounted) {
              setState(() {
                _isTyping = false;
                _typingStatus = '';
                _messages.add({
                  'role': 'assistant',
                  'text': data['content'] ?? '',
                  'time': _formatTime(),
                });
              });
              _scrollToBottom();
            }
          } else if (data['type'] == 'error' || data['type'] == 'timeout') {
            if (mounted) {
              setState(() {
                _isTyping = false;
                _typingStatus = '';
                _messages.add({
                  'role': 'assistant',
                  'text': 'Desculpe, ocorreu um erro: ${data['error'] ?? 'Desconhecido'}',
                  'time': _formatTime(),
                });
              });
              _scrollToBottom();
            }
            if (data['type'] == 'timeout') {
              _channel?.sink.close();
            }
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isConnected = false;
              _isTyping = false;
              _typingStatus = '';
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isConnected = false;
              _isTyping = false;
              _typingStatus = '';
              _messages.add({
                'role': 'assistant',
                'text': 'Erro de conexão com o servidor: $error',
                'time': _formatTime(),
              });
            });
          }
        },
      );

      // Envia autenticação na primeira mensagem (após slight delay para garantir que stream está listening)
      await Future.delayed(const Duration(milliseconds: 100));
      final authMsg = jsonEncode({'type': 'auth', 'token': token});
      _channel!.sink.add(authMsg);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _messages.add({
            'role': 'assistant',
            'text': 'Falha ao conectar no servidor: $e',
            'time': _formatTime(),
          });
        });
      }
    }
  }

  String _formatTime() => _formatTimeFrom(DateTime.now());

  String _formatTimeFrom(DateTime dt) {
    final local = dt.toLocal();
    return '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    if (_isTyping) return; // evita enviar enquanto IA está respondendo

    final text = _messageController.text.trim();

    setState(() {
      _messages.add({
        'role': 'user',
        'text': text,
        'time': _formatTime(),
      });
      // Mostrar indicador imediatamente: o backend só envia 'thinking'
      // depois de processar input; um feedback otimista evita silêncio
      // visual no intervalo entre o envio e o primeiro evento de status.
      _isTyping = true;
      _typingStatus = 'Analisando sua pergunta...';
    });
    _scrollToBottom();

    if (_isConnected && _channel != null) {
      final payload = {
        'type': 'message',
        'content': text,
      };

      if (_conversationId != null) {
        payload['conversation_id'] = _conversationId!;
      }

      _channel!.sink.add(jsonEncode(payload));
    } else {
      setState(() {
        _isTyping = false;
        _typingStatus = '';
        _messages.add({
          'role': 'assistant',
          'text': 'Você está desconectado. Reinicie o aplicativo para tentar novamente.',
          'time': _formatTime(),
        });
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
              // Halter como identidade visual da academia (Vitali =
              // assistente fitness). Leitura imediata para o aluno.
              child: const Icon(Icons.fitness_center, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vitali',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  _isConnected ? 'Online' : 'Desconectado',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _isConnected ? Colors.green : context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                // +1 quando _isTyping para reservar espaço do indicador
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isTyping && index == _messages.length) {
                    return _TypingIndicator(status: _typingStatus);
                  }

                  final msg = _messages[index];
                  final isUser = msg['role'] == 'user';

                  return FadeInUp(
                    delay: Duration(milliseconds: index * 50),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isUser ? AppColors.primary : context.colors.surface,
                            border: isUser ? null : Border.all(color: context.colors.border, width: 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg['text']!,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: isUser ? Colors.white : context.colors.textPrimary,
                                      height: 1.4,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                msg['time']!,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: isUser ? Colors.white.withValues(alpha: 0.7) : context.colors.textMuted,
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
                border: Border(top: BorderSide(color: context.colors.border, width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: _isConnected && !_isTyping,
                      decoration: InputDecoration(
                        hintText: !_isConnected
                            ? 'Conectando...'
                            : (_isTyping ? 'Aguardando resposta...' : 'Pergunte algo...'),
                        hintStyle: TextStyle(color: context.colors.textMuted),
                        filled: true,
                        fillColor: context.colors.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                      color: (_isConnected && !_isTyping) ? AppColors.primary : Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: (_isConnected && !_isTyping) ? _sendMessage : null,
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

/// Indicador de "digitando" com 3 bolinhas pulsantes + texto de status.
/// Renderizado abaixo das mensagens enquanto a IA processa a resposta.
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
      duration: const Duration(milliseconds: 1100),
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
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border.all(color: context.colors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_controller.value + i * 0.2) % 1.0;
                    final scale = 0.6 + (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0) * 0.6;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.status.isEmpty ? 'Pensando...' : widget.status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                        fontSize: 12,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
