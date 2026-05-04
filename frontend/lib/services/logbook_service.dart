import 'package:flutter/material.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Exercício registrado em uma sessão de logbook
class ExerciseLogResponse {
  final String id;
  final String exerciseName;
  final int sets;
  final int reps;
  final double weight;
  final int restTime;
  final String? notes;

  ExerciseLogResponse({
    required this.id,
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.weight,
    required this.restTime,
    this.notes,
  });

  factory ExerciseLogResponse.fromJson(Map<String, dynamic> json) {
    return ExerciseLogResponse(
      id: (json['id'] as String?) ?? '',
      exerciseName: (json['exercise_name'] as String?) ??
          (json['exerciseName'] as String?) ??
          'Exercício',
      sets: (json['actual_series'] as int?) ??
          (json['planned_series'] as int?) ??
          (json['sets'] as int?) ??
          0,
      reps: (json['actual_repetitions'] as int?) ??
          (json['planned_repetitions'] as int?) ??
          (json['reps'] as int?) ??
          0,
      weight: ((json['actual_load_kg'] ?? json['planned_load_kg'] ?? json['weight'] ?? 0) as num)
          .toDouble(),
      restTime: (json['rest_time'] as int?) ?? 60,
      notes: json['exercise_notes'] as String? ?? json['notes'] as String?,
    );
  }
}

/// Sessão de treino no logbook (mapeada a partir do backend SessionListItemDTO/SessionResponseDTO)
class LogbookResponse {
  final String id;
  final String userId;
  final String workoutName;
  final DateTime sessionDate;
  final int durationMinutes;
  final double caloriesBurned;
  final String intensity;
  final List<ExerciseLogResponse> exercises;
  final String? notes;
  final DateTime createdAt;

  LogbookResponse({
    required this.id,
    required this.userId,
    required this.workoutName,
    required this.sessionDate,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.intensity,
    required this.exercises,
    this.notes,
    required this.createdAt,
  });

  factory LogbookResponse.fromJson(Map<String, dynamic> json) {
    final exerciseList = <ExerciseLogResponse>[];
    final rawExercises = json['session_exercises'] ?? json['exercises'];
    if (rawExercises is List) {
      for (final e in rawExercises) {
        if (e is Map<String, dynamic>) {
          exerciseList.add(ExerciseLogResponse.fromJson(e));
        }
      }
    }

    return LogbookResponse(
      id: json['id'] as String,
      userId: (json['user_id'] as String?) ?? '',
      workoutName: (json['workout_name'] as String?) ?? 'Treino',
      sessionDate: DateTime.parse(json['session_date'] as String),
      durationMinutes: (json['duration_minutes'] as int?) ?? 0,
      caloriesBurned:
          ((json['calories_burned'] ?? 0) as num).toDouble(),
      intensity: (json['intensity'] as String?) ?? 'moderada',
      exercises: exerciseList,
      notes: (json['notes'] ?? json['general_notes']) as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDay =
        DateTime(sessionDate.year, sessionDate.month, sessionDate.day);

    if (sessionDay == today) return 'Hoje';
    if (sessionDay == yesterday) return 'Ontem';
    return '${sessionDate.day}/${sessionDate.month}/${sessionDate.year}';
  }

  Color get intensityColor {
    switch (intensity.toLowerCase()) {
      case 'leve':
        return const Color(0xFF2ecc71);
      case 'moderada':
        return const Color(0xFFf39c12);
      case 'intensa':
        return const Color(0xFFe74c3c);
      default:
        return const Color(0xFF95a5a6);
    }
  }
}

/// DTO para criar/atualizar uma sessão de logbook
class CreateLogbookDTO {
  final String workoutName;
  final DateTime sessionDate;
  final int durationMinutes;
  final double caloriesBurned;
  final String intensity;
  final List<Map<String, dynamic>> exercises;
  final String? notes;

  CreateLogbookDTO({
    required this.workoutName,
    required this.sessionDate,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.intensity,
    required this.exercises,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'workout_name': workoutName,
        'session_date': sessionDate.toIso8601String(),
        'duration_minutes': durationMinutes,
        'calories_burned': caloriesBurned,
        'intensity': intensity,
        if (notes != null) 'notes': notes,
      };
}

/// Serviço de logbook (histórico de treinos)
///
/// Endpoints do backend:
///   GET    /api/v1/logbook/sessions           → Listar sessões (paginado)
///   POST   /api/v1/logbook/sessions           → Criar sessão
///   GET    /api/v1/logbook/sessions/{id}      → Buscar sessão
///   PUT    /api/v1/logbook/sessions/{id}      → Atualizar sessão
///   DELETE /api/v1/logbook/sessions/{id}      → Deletar sessão
class LogbookService {
  final ApiClient _apiClient;

  LogbookService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Lista sessões do logbook do usuário (retorna a lista do campo `data`)
  Future<List<LogbookResponse>> getLogbookSessions({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'page': page,
        'limit': limit,
      };

      final response = await _apiClient.get<List<LogbookResponse>>(
        '/logbook/sessions',
        queryParameters: queryParameters,
        fromJson: (data) {
          List<dynamic> items;
          if (data is Map && data.containsKey('data')) {
            items = data['data'] as List<dynamic>;
          } else if (data is List) {
            items = data;
          } else {
            return [];
          }
          return items
              .whereType<Map<String, dynamic>>()
              .map((item) => LogbookResponse.fromJson(item))
              .toList();
        },
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Busca uma sessão específica do logbook
  Future<LogbookResponse> getLogbookSession(String sessionId) async {
    try {
      final response = await _apiClient.get<LogbookResponse>(
        '/logbook/sessions/$sessionId',
        fromJson: (data) =>
            LogbookResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Cria uma nova sessão no logbook
  Future<LogbookResponse> createLogbookSession(CreateLogbookDTO dto) async {
    try {
      final response = await _apiClient.post<LogbookResponse>(
        '/logbook/sessions',
        body: dto.toJson(),
        fromJson: (data) =>
            LogbookResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Atualiza uma sessão do logbook
  Future<LogbookResponse> updateLogbookSession(
    String sessionId,
    CreateLogbookDTO dto,
  ) async {
    try {
      final response = await _apiClient.put<LogbookResponse>(
        '/logbook/sessions/$sessionId',
        body: {
          'general_notes': dto.notes,
        },
        fromJson: (data) =>
            LogbookResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Deleta uma sessão do logbook
  Future<void> deleteLogbookSession(String sessionId) async {
    try {
      await _apiClient.delete<void>(
        '/logbook/sessions/$sessionId',
        fromJson: (_) {},
      );
    } catch (e) {
      rethrow;
    }
  }
}
