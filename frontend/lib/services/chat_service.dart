import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:omniconnect_fitness/config/api_config.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

// ── DTOs ──────────────────────────────────────────────────────────────────────

/// Mensagem de uma conversa retornada pelo backend.
class ChatMessageDTO {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;

  ChatMessageDTO({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  factory ChatMessageDTO.fromJson(Map<String, dynamic> json) {
    return ChatMessageDTO(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Detalhe completo de uma conversa, com mensagens.
class ConversationDetailDTO {
  final String id;
  final String status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<ChatMessageDTO> messages;

  ConversationDetailDTO({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.messages,
  });

  factory ConversationDetailDTO.fromJson(Map<String, dynamic> json) {
    final raw = (json['messages'] as List<dynamic>? ?? []);
    return ConversationDetailDTO(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'active',
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      messages: raw
          .whereType<Map<String, dynamic>>()
          .map(ChatMessageDTO.fromJson)
          .toList(),
    );
  }
}

/// Macros de um alimento registrado via áudio.
class FoodLoggedDTO {
  final String foodName;
  final double quantityG;
  final String mealName;
  final double kcal;
  final double protein;
  final double carbs;
  final double fats;
  final String logbookEntryId;
  final String foodSource;   // "taco" | "web" | "estimativa"

  FoodLoggedDTO({
    required this.foodName,
    required this.quantityG,
    required this.mealName,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.logbookEntryId,
    this.foodSource = 'taco',
  });

  factory FoodLoggedDTO.fromJson(Map<String, dynamic> json) {
    return FoodLoggedDTO(
      foodName: json['food_name'] as String? ?? '',
      quantityG: (json['quantity_g'] as num?)?.toDouble() ?? 0,
      mealName: json['meal_name'] as String? ?? '',
      kcal: (json['kcal'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fats: (json['fats'] as num?)?.toDouble() ?? 0,
      logbookEntryId: json['logbook_entry_id'] as String? ?? '',
      foodSource: json['food_source'] as String? ?? 'taco',
    );
  }
}

/// Resposta do endpoint de audio food logging.
class AudioFoodResponseDTO {
  final String messageId;
  final String conversationId;
  final String transcription;
  final String content;
  final FoodLoggedDTO? foodLogged;
  final String parseConfidence;
  final String createdAt;

  AudioFoodResponseDTO({
    required this.messageId,
    required this.conversationId,
    required this.transcription,
    required this.content,
    required this.foodLogged,
    required this.parseConfidence,
    required this.createdAt,
  });

  factory AudioFoodResponseDTO.fromJson(Map<String, dynamic> json) {
    final foodJson = json['food_logged'] as Map<String, dynamic>?;
    return AudioFoodResponseDTO(
      messageId: json['message_id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      transcription: json['transcription'] as String? ?? '',
      content: json['content'] as String? ?? '',
      foodLogged: foodJson != null ? FoodLoggedDTO.fromJson(foodJson) : null,
      parseConfidence: json['parse_confidence'] as String? ?? 'low',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

/// Resposta do endpoint de photo food logging.
class PhotoFoodResponseDTO {
  final String messageId;
  final String conversationId;
  final String description;
  final String content;
  final List<FoodLoggedDTO> foodsLogged;
  final String parseConfidence;
  final String createdAt;

  PhotoFoodResponseDTO({
    required this.messageId,
    required this.conversationId,
    required this.description,
    required this.content,
    required this.foodsLogged,
    required this.parseConfidence,
    required this.createdAt,
  });

  factory PhotoFoodResponseDTO.fromJson(Map<String, dynamic> json) {
    final foods = (json['foods_logged'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(FoodLoggedDTO.fromJson)
        .toList();
    return PhotoFoodResponseDTO(
      messageId: json['message_id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      content: json['content'] as String? ?? '',
      foodsLogged: foods,
      parseConfidence: json['parse_confidence'] as String? ?? 'low',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

// ── Service ───────────────────────────────────────────────────────────────────

/// Cliente HTTP do módulo de chat.
///
/// O envio de mensagens em tempo real continua via WebSocket
/// (chat_screen.dart). Este service cobre operações REST: carregar
/// histórico de uma conversa salva localmente, envio de áudio para
/// registro de refeições, etc.
class ChatService {
  final ApiClient _apiClient;

  ChatService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Busca o detalhe de uma conversa, incluindo todas as mensagens
  /// trocadas. Lança [NotFoundException] se a conversa não existe ou
  /// não pertence ao usuário autenticado.
  Future<ConversationDetailDTO> getConversation(String conversationId) async {
    return _apiClient.get<ConversationDetailDTO>(
      '/chat/conversations/$conversationId',
      fromJson: (data) =>
          ConversationDetailDTO.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Envia bytes de áudio para o endpoint de food logging.
  ///
  /// Aceita [Uint8List] para compatibilidade com Flutter Web (blob) e
  /// mobile (arquivo lido em bytes). O [filename] determina o Content-Type
  /// inferido pelo servidor (ex: "audio.m4a", "audio.webm").
  ///
  /// [token] deve ser o JWT atual do usuário.
  /// [conversationId] é opcional — se null, o backend cria nova conversa.
  Future<AudioFoodResponseDTO> sendAudio({
    required List<int> audioBytes,
    required String filename,
    required String token,
    String? conversationId,
  }) async {
    final now = DateTime.now();

    // Data e hora LOCAL do dispositivo — evita que o servidor salve no dia
    // errado quando o fuso horário do usuário difere do UTC do servidor.
    final logDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final localHour = now.hour.toString();

    final uri = Uri.parse(ApiConfig.chatSendAudio);
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'audio',
        audioBytes,
        filename: filename,
      ))
      ..fields['log_date'] = logDate
      ..fields['local_hour'] = localHour;

    if (conversationId != null && conversationId.isNotEmpty) {
      request.fields['conversation_id'] = conversationId;
    }

    try {
      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return AudioFoodResponseDTO.fromJson(json);
      }

      final errMsg = _extractErrorMessage(body);

      if (streamed.statusCode == 401) {
        throw UnauthorizedException(message: errMsg);
      }
      throw ApiException(message: errMsg, statusCode: streamed.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Falha ao enviar áudio: $e');
    }
  }

  /// Envia bytes de imagem para o endpoint de photo food logging.
  Future<PhotoFoodResponseDTO> sendPhoto({
    required List<int> imageBytes,
    required String filename,
    required String token,
    String? conversationId,
  }) async {
    final now = DateTime.now();
    final logDate =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final localHour = now.hour.toString();

    final uri = Uri.parse(ApiConfig.chatSendPhoto);
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(http.MultipartFile.fromBytes(
        'photo',
        imageBytes,
        filename: filename,
      ))
      ..fields['log_date'] = logDate
      ..fields['local_hour'] = localHour;

    if (conversationId != null && conversationId.isNotEmpty) {
      request.fields['conversation_id'] = conversationId;
    }

    try {
      final streamed =
          await request.send().timeout(const Duration(seconds: 60));
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode == 200) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return PhotoFoodResponseDTO.fromJson(json);
      }

      final errMsg = _extractErrorMessage(body);
      if (streamed.statusCode == 401) {
        throw UnauthorizedException(message: errMsg);
      }
      throw ApiException(message: errMsg, statusCode: streamed.statusCode);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw NetworkException(message: 'Falha ao enviar foto: $e');
    }
  }

  String _extractErrorMessage(String body) {
    try {
      if (body.isEmpty) return 'Erro desconhecido';
      final data = jsonDecode(body) as Map<String, dynamic>;
      final detail = data['detail'];
      if (detail is Map) {
        return detail['message'] as String? ?? 'Erro desconhecido';
      }
      return detail as String? ?? 'Erro desconhecido';
    } catch (_) {
      return 'Erro desconhecido';
    }
  }
}
