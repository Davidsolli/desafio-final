import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;

import 'package:animate_do/animate_do.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/api_config.dart';
import '../../services/api_client.dart';
import '../../services/chat_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';

/// Chave usada para persistir o id da conversa ativa entre saídas e
/// retornos à tela de chat.
const String _kConversationIdPrefsKey = 'chat_active_conversation_id';

// ── Tipos de mensagem internos ────────────────────────────────────────────────

/// Tipo da bolha exibida na lista de mensagens.
enum _MsgType { text, food }

/// Representação interna de uma mensagem da lista.
class _ChatMsg {
  final String role;       // 'user' | 'assistant'
  final _MsgType type;
  final String text;
  final String time;
  final FoodLoggedDTO? food;   // não-nulo apenas quando type == food

  const _ChatMsg({
    required this.role,
    required this.type,
    required this.text,
    required this.time,
    this.food,
  });

  factory _ChatMsg.text({
    required String role,
    required String text,
    required String time,
  }) =>
      _ChatMsg(role: role, type: _MsgType.text, text: text, time: time);

  factory _ChatMsg.food({
    required FoodLoggedDTO food,
    required String transcription,
    required String time,
  }) =>
      _ChatMsg(
        role: 'assistant',
        type: _MsgType.food,
        text: transcription,
        time: time,
        food: food,
      );
}

// ── Tela principal ────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMsg> _messages = [];

  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isTyping = false;
  String _typingStatus = '';
  String? _conversationId;

  // ── Áudio ──────────────────────────────────────────────────────────────────
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isSendingAudio = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadStoredConversation();
    if (!mounted) return;
    await _connectWebSocket();
  }

  // ── Histórico ──────────────────────────────────────────────────────────────

  Future<void> _loadStoredConversation() async {
    final chatService = context.read<ChatService>();
    final prefs = await SharedPreferences.getInstance();
    final storedId = prefs.getString(_kConversationIdPrefsKey);
    if (storedId == null || storedId.isEmpty) return;

    try {
      final detail = await chatService.getConversation(storedId);
      if (!mounted) return;
      setState(() {
        _conversationId = detail.id;
        _messages.addAll(detail.messages.map((m) => _ChatMsg.text(
              role: m.role,
              text: m.content,
              time: _formatTimeFrom(m.createdAt),
            )));
      });
      _scrollToBottom();
    } on NotFoundException {
      await prefs.remove(_kConversationIdPrefsKey);
    } on UnauthorizedException {
      await prefs.remove(_kConversationIdPrefsKey);
    } catch (_) {}
  }

  Future<void> _persistConversationId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kConversationIdPrefsKey, id);
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────

  Future<void> _connectWebSocket() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null || token.isEmpty) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMsg.text(
            role: 'assistant',
            text: 'Erro de autenticação. Por favor, faça login novamente.',
            time: _formatTime(),
          ));
        });
      }
      return;
    }

    final wsBaseUrl = ApiConfig.wsBaseUrl;
    if (wsBaseUrl == null) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse('$wsBaseUrl/api/v1/chat/ws'));
      _channel!.stream.listen(
        (message) async {
          final data = jsonDecode(message as String) as Map<String, dynamic>;

          if (data['type'] == 'auth_success') {
            if (mounted) {
              setState(() {
                _isConnected = true;
                if (_messages.isEmpty) {
                  _messages.add(_ChatMsg.text(
                    role: 'assistant',
                    text: 'Olá! Eu sou o Vitali, assistente da FitLoop. Como posso te ajudar hoje?',
                    time: _formatTime(),
                  ));
                }
              });
              _scrollToBottom();
            }
          } else if (data['type'] == 'auth_error') {
            if (mounted) {
              setState(() {
                _isConnected = false;
                _messages.add(_ChatMsg.text(
                  role: 'assistant',
                  text: 'Erro de autenticação: ${data['error'] ?? 'Desconhecido'}',
                  time: _formatTime(),
                ));
              });
            }
            _channel?.sink.close();
          } else if (data['type'] == 'status') {
            if (mounted) {
              setState(() {
                _isTyping = true;
                _typingStatus = (data['message'] as String?) ?? 'Processando...';
              });
              _scrollToBottom();
            }
          } else if (data['type'] == 'response') {
            final newId = data['conversation_id'] as String?;
            if (newId != null) {
              _conversationId = newId;
              await _persistConversationId(newId);
            }
            if (mounted) {
              setState(() {
                _isTyping = false;
                _typingStatus = '';
                _messages.add(_ChatMsg.text(
                  role: 'assistant',
                  text: data['content'] as String? ?? '',
                  time: _formatTime(),
                ));
              });
              _scrollToBottom();
            }
          } else if (data['type'] == 'error' || data['type'] == 'timeout') {
            if (mounted) {
              setState(() {
                _isTyping = false;
                _typingStatus = '';
                _messages.add(_ChatMsg.text(
                  role: 'assistant',
                  text: 'Desculpe, ocorreu um erro: ${data['error'] ?? 'Desconhecido'}',
                  time: _formatTime(),
                ));
              });
              _scrollToBottom();
            }
            if (data['type'] == 'timeout') _channel?.sink.close();
          }
        },
        onDone: () {
          if (mounted) setState(() { _isConnected = false; _isTyping = false; });
        },
        onError: (_) {
          if (mounted) {
            setState(() {
              _isConnected = false;
              _isTyping = false;
              _messages.add(_ChatMsg.text(
                role: 'assistant',
                text: 'Erro de conexão com o servidor.',
                time: _formatTime(),
              ));
            });
          }
        },
      );

      await Future.delayed(const Duration(milliseconds: 100));
      _channel!.sink.add(jsonEncode({'type': 'auth', 'token': token}));
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnected = false;
          _messages.add(_ChatMsg.text(
            role: 'assistant',
            text: 'Falha ao conectar no servidor: $e',
            time: _formatTime(),
          ));
        });
      }
    }
  }

  // ── Envio de texto ─────────────────────────────────────────────────────────

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isTyping) return;

    setState(() {
      _messages.add(_ChatMsg.text(role: 'user', text: text, time: _formatTime()));
      _isTyping = true;
      _typingStatus = 'Analisando sua pergunta...';
    });
    _scrollToBottom();

    if (_isConnected && _channel != null) {
      final payload = <String, dynamic>{'type': 'message', 'content': text};
      if (_conversationId != null) payload['conversation_id'] = _conversationId;
      _channel!.sink.add(jsonEncode(payload));
    } else {
      setState(() {
        _isTyping = false;
        _messages.add(_ChatMsg.text(
          role: 'assistant',
          text: 'Você está desconectado. Reinicie o aplicativo para tentar novamente.',
          time: _formatTime(),
        ));
      });
      _scrollToBottom();
    }

    _messageController.clear();
  }

  // ── Gravação de áudio ──────────────────────────────────────────────────────

  /// Solicita permissão de microfone no mobile.
  /// No web o browser gerencia a permissão automaticamente via getUserMedia,
  /// então pulamos essa etapa para não chamar plugin não suportado.
  Future<bool> _requestMicPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permissão de microfone necessária para gravar refeições por voz.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    return false;
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isSendingAudio) return;
    if (!await _requestMicPermission()) return;

    // path é obrigatório pelo record v5:
    //   - web: valor ignorado internamente, passamos string vazia
    //   - mobile: caminho real no diretório temporário do SO
    final String audioPath;
    if (kIsWeb) {
      audioPath = 'audio_${DateTime.now().millisecondsSinceEpoch}.webm';
    } else {
      final dir = await getTemporaryDirectory();  // não executa no web
      audioPath =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }

    await _recorder.start(
      RecordConfig(
        // Web só suporta opus/webm; mobile usa AAC
        encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc,
        sampleRate: 16000,
      ),
      path: audioPath,
    );

    _recordingSeconds = 0;
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingSeconds++);
      if (_recordingSeconds >= 60) _stopAndSendRecording();
    });

    setState(() => _isRecording = true);
    _scrollToBottom();
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _recorder.cancel();
    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;
    _recordingTimer?.cancel();
    _recordingTimer = null;

    // stop() retorna:
    //   mobile → caminho do arquivo temporário  (ex: /data/.../tmp/audio.m4a)
    //   web    → blob URL                       (ex: blob:http://localhost/…)
    final result = await _recorder.stop();
    setState(() { _isRecording = false; _recordingSeconds = 0; });

    if (result == null || result.isEmpty) return;

    // Converter resultado em bytes + nome de arquivo
    List<int> bytes;
    final String filename;
    try {
      if (kIsWeb) {
        // No web, result é um blob URL; http.get via BrowserClient acessa blobs
        final blobResp = await http.get(Uri.parse(result));
        bytes = blobResp.bodyBytes;
        filename = 'audio.webm';
      } else {
        // No mobile, result é caminho de arquivo — dart:io File funciona
        bytes = await File(result).readAsBytes();  // guard: !kIsWeb
        filename = 'audio.m4a';
        try { File(result).deleteSync(); } catch (_) {}
      }
    } catch (e) {
      debugPrint('[chat] Erro ao ler bytes do áudio: $e');
      return;
    }

    await _sendAudioBytes(bytes, filename);
  }

  Future<void> _sendAudioBytes(List<int> bytes, String filename) async {
    // Captura context-dependents antes de qualquer await
    final chatService = context.read<ChatService>();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return;

    setState(() {
      _isSendingAudio = true;
      _isTyping = true;
      _typingStatus = 'Transcrevendo áudio...';
      _messages.add(_ChatMsg.text(
        role: 'user',
        text: '🎤 Enviando áudio...',
        time: _formatTime(),
      ));
    });
    _scrollToBottom();

    try {
      final response = await chatService.sendAudio(
        audioBytes: bytes,
        filename: filename,
        token: token,
        conversationId: _conversationId,
      );

      // Atualizar balão do usuário com a transcrição real
      setState(() {
        final idx = _messages.lastIndexWhere((m) => m.role == 'user');
        if (idx >= 0) {
          _messages[idx] = _ChatMsg.text(
            role: 'user',
            text: '🎤 ${response.transcription}',
            time: _messages[idx].time,
          );
        }
      });

      if (response.conversationId.isNotEmpty) {
        _conversationId = response.conversationId;
        await _persistConversationId(response.conversationId);
      }

      if (response.foodLogged != null) {
        setState(() {
          _isTyping = false;
          _isSendingAudio = false;
          _messages.add(_ChatMsg.food(
            food: response.foodLogged!,
            transcription: response.transcription,
            time: _formatTime(),
          ));
        });
      } else {
        setState(() {
          _isTyping = false;
          _isSendingAudio = false;
          _messages.add(_ChatMsg.text(
            role: 'assistant',
            text: response.content,
            time: _formatTime(),
          ));
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _isTyping = false;
        _isSendingAudio = false;
        _messages.add(_ChatMsg.text(
          role: 'assistant',
          text: '❌ ${e.message}',
          time: _formatTime(),
        ));
      });
    } catch (e) {
      setState(() {
        _isTyping = false;
        _isSendingAudio = false;
        _messages.add(_ChatMsg.text(
          role: 'assistant',
          text: '❌ Falha ao processar o áudio. Tente novamente.',
          time: _formatTime(),
        ));
      });
    }

    _scrollToBottom();
  }

  // ── Utilitários ────────────────────────────────────────────────────────────

  String _formatTime() => _formatTimeFrom(DateTime.now());

  String _formatTimeFrom(DateTime dt) {
    final l = dt.toLocal();
    return '${l.hour}:${l.minute.toString().padLeft(2, '0')}';
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
    _recordingTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
              child: const Icon(Icons.fitness_center,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Vitali',
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
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Lista de mensagens ───────────────────────────────────────
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

                  if (msg.type == _MsgType.food && msg.food != null) {
                    return FadeInUp(
                      delay: Duration(milliseconds: index * 50),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _FoodCard(food: msg.food!, time: msg.time),
                      ),
                    );
                  }

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
                            maxWidth:
                                MediaQuery.of(context).size.width * 0.75,
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

            // ── Indicador de gravação ────────────────────────────────────
            if (_isRecording) _RecordingBar(
              seconds: _recordingSeconds,
              onCancel: _cancelRecording,
            ),

            // ── Barra de input ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border(
                    top: BorderSide(color: context.colors.border, width: 1)),
              ),
              child: Row(
                children: [
                  // Botão microfone
                  _MicButton(
                    isRecording: _isRecording,
                    isBusy: _isTyping || _isSendingAudio,
                    onTapDown: _startRecording,
                    onTapUp: _stopAndSendRecording,
                    onTapCancel: _cancelRecording,
                  ),

                  const SizedBox(width: 8),

                  // Campo de texto
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: _isConnected && !_isTyping && !_isRecording && !_isSendingAudio,
                      decoration: InputDecoration(
                        hintText: _isRecording
                            ? 'Gravando...'
                            : _isSendingAudio
                                ? 'Processando áudio...'
                                : (!_isConnected
                                    ? 'Conectando...'
                                    : (_isTyping
                                        ? 'Aguardando resposta...'
                                        : 'Pergunte algo...')),
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

                  const SizedBox(width: 8),

                  // Botão enviar
                  Container(
                    decoration: BoxDecoration(
                      color: (_isConnected && !_isTyping && !_isRecording && !_isSendingAudio)
                          ? AppColors.primary
                          : Colors.grey,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send,
                          color: Colors.white, size: 20),
                      onPressed:
                          (_isConnected && !_isTyping && !_isRecording && !_isSendingAudio)
                              ? _sendMessage
                              : null,
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

// ── Widgets auxiliares ─────────────────────────────────────────────────────────

/// Botão de microfone press-and-hold com 4 estados visuais distintos:
///
///   IDLE      — verde, ícone de mic, sombra suave
///   PRESSED   — verde escuro, escala 88%, sombra pulsante (antes de gravar iniciar)
///   RECORDING — vermelho, ícone stop, pulsa 1.0→1.12 em loop, glow vermelho
///   BUSY      — cinza, desabilitado (enquanto IA responde ou áudio é processado)
class _MicButton extends StatefulWidget {
  final bool isRecording;
  final bool isBusy;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;

  const _MicButton({
    required this.isRecording,
    required this.isBusy,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
  });

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  // Animação de pulso usada durante a gravação
  late final AnimationController _pulse;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.13).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_MicButton old) {
    super.didUpdateWidget(old);
    // Inicia o pulso ao entrar no estado de gravação; para ao sair
    if (widget.isRecording && !old.isRecording) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isRecording && old.isRecording) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    HapticFeedback.mediumImpact();
    widget.onTapDown();
  }

  void _handleTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    widget.onTapUp();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    widget.onTapCancel();
  }

  @override
  Widget build(BuildContext context) {
    final active = !widget.isBusy;

    // Cor varia por estado
    final Color color;
    if (!active) {
      color = Colors.grey.shade400;
    } else if (widget.isRecording) {
      color = Colors.red;
    } else if (_isPressed) {
      color = AppColors.primaryDark;   // verde mais escuro no press
    } else {
      color = AppColors.primary;
    }

    // Sombra contextual: vermelho intenso em gravação, verde suave em idle
    final List<BoxShadow> shadows;
    if (widget.isRecording) {
      shadows = [
        BoxShadow(
          color: Colors.red.withValues(alpha: 0.45),
          blurRadius: 12,
          spreadRadius: 1,
        )
      ];
    } else if (_isPressed) {
      shadows = [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.5),
          blurRadius: 8,
          spreadRadius: 1,
        )
      ];
    } else if (active) {
      shadows = [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.18),
          blurRadius: 4,
          spreadRadius: 0,
        )
      ];
    } else {
      shadows = [];
    }

    // Escala imediata no press (antes de isRecording virar true)
    final double scale = (_isPressed && !widget.isRecording) ? 0.87 : 1.0;

    return Tooltip(
      message: widget.isRecording
          ? 'Solte para enviar'
          : (active ? 'Segure para gravar' : ''),
      child: GestureDetector(
        onTapDown: active ? _handleTapDown : null,
        onTapUp: active ? _handleTapUp : null,
        onTapCancel: active ? _handleTapCancel : null,
        child: ScaleTransition(
          // Pulso durante gravação; escala manual no press
          scale: widget.isRecording
              ? _pulseScale
              : AlwaysStoppedAnimation(scale),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            curve: Curves.easeOut,
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: widget.isRecording
                    ? 0.18
                    : (_isPressed ? 0.22 : 0.12),
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color,
                width: widget.isRecording || _isPressed ? 2.0 : 1.5,
              ),
              boxShadow: shadows,
            ),
            child: Icon(
              widget.isRecording ? Icons.stop_rounded : Icons.mic_rounded,
              color: color,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra vermelha exibida no topo do input durante a gravação.
class _RecordingBar extends StatelessWidget {
  final int seconds;
  final VoidCallback onCancel;

  const _RecordingBar({required this.seconds, required this.onCancel});

  String get _formatted {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
          const SizedBox(width: 8),
          Text(
            'Gravando $_formatted — solte para enviar',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onCancel,
            child: const Icon(Icons.close, color: Colors.red, size: 18),
          ),
        ],
      ),
    );
  }
}

/// Card de confirmação de refeição registrada via áudio.
class _FoodCard extends StatelessWidget {
  final FoodLoggedDTO food;
  final String time;

  const _FoodCard({required this.food, required this.time});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35), width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabeçalho
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    food.mealName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  time,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.colors.textMuted,
                        fontSize: 10,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Nome do alimento + quantidade
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text('✅ ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    '${food.quantityG.toStringAsFixed(0)}g de ${food.foodName}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.textPrimary,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Grid de macros
            _MacroGrid(food: food),
          ],
        ),
      ),
    );
  }
}

/// Grid 2×2 com os macros do alimento registrado.
class _MacroGrid extends StatelessWidget {
  final FoodLoggedDTO food;

  const _MacroGrid({required this.food});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MacroChip(
          label: 'Kcal',
          value: food.kcal.toStringAsFixed(0),
          color: Colors.orange,
        ),
        const SizedBox(width: 6),
        _MacroChip(
          label: 'Prot',
          value: '${food.protein.toStringAsFixed(1)}g',
          color: Colors.blue,
        ),
        const SizedBox(width: 6),
        _MacroChip(
          label: 'Carbs',
          value: '${food.carbs.toStringAsFixed(1)}g',
          color: AppColors.primary,
        ),
        const SizedBox(width: 6),
        _MacroChip(
          label: 'Gord',
          value: '${food.fats.toStringAsFixed(1)}g',
          color: Colors.purple,
        ),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MacroChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Indicador de digitando ────────────────────────────────────────────────────

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
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border.all(color: context.colors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final t = (_controller.value + i * 0.2) % 1.0;
                    final scale =
                        0.6 + (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0) * 0.6;
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
