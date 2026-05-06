import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../config/api_config.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = [];
  WebSocketChannel? _channel;
  bool _isConnected = false;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
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
    final wsBaseUrl = ApiConfig.wsBaseUrl ?? 'ws://localhost:8000';
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
                _messages.add({
                  'role': 'assistant',
                  'text': 'Olá! 👋 Sou seu assistente fitness conectado. Como posso te ajudar hoje?',
                  'time': _formatTime(),
                });
              });
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
          } else if (data['type'] == 'response') {
            if (data['conversation_id'] != null) {
              _conversationId = data['conversation_id'];
            }
            if (mounted) {
              setState(() {
                _messages.add({
                  'role': 'assistant',
                  'text': data['content'] ?? '',
                  'time': _formatTime(),
                });
              });
            }
          } else if (data['type'] == 'error' || data['type'] == 'timeout') {
            if (mounted) {
              setState(() {
                _messages.add({
                  'role': 'assistant',
                  'text': 'Desculpe, ocorreu um erro: ${data['error'] ?? 'Desconhecido'}',
                  'time': _formatTime(),
                });
              });
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
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isConnected = false;
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

  String _formatTime() {
    final now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _channel?.sink.close();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final text = _messageController.text.trim();
    
    setState(() {
      _messages.add({
        'role': 'user',
        'text': text,
        'time': _formatTime(),
      });
    });

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
        _messages.add({
          'role': 'assistant',
          'text': 'Você está desconectado. Reinicie o aplicativo para tentar novamente.',
          'time': _formatTime(),
        });
      });
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
              child: const Icon(Icons.android, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assistente IA',
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
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
                      enabled: _isConnected,
                      decoration: InputDecoration(
                        hintText: _isConnected ? 'Pergunte algo...' : 'Conectando...',
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
                      color: _isConnected ? AppColors.primary : Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
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
