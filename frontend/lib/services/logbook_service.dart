import 'package:flutter/material.dart';
import 'package:omniconnect_fitness/services/api_client.dart';

/// Modelo de exercício no logbook
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
      id: json['id'] as String,
      exerciseName: json['exercise_name'] as String,
      sets: json['sets'] as int,
      reps: json['reps'] as int,
      weight: (json['weight'] as num).toDouble(),
      restTime: json['rest_time'] as int,
      notes: json['notes'] as String?,
    );
  }
}

/// Modelo de sessão de treino (logbook)
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
    return LogbookResponse(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      workoutName: json['workout_name'] as String,
      sessionDate: DateTime.parse(json['session_date'] as String),
      durationMinutes: json['duration_minutes'] as int,
      caloriesBurned: (json['calories_burned'] as num).toDouble(),
      intensity: json['intensity'] as String,
      exercises: (json['exercises'] as List<dynamic>?)
          ?.map((e) => ExerciseLogResponse.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final sessionDay = DateTime(sessionDate.year, sessionDate.month, sessionDate.day);

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

/// Modelo para criar/atualizar logbook
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
    'exercises': exercises,
    if (notes != null) 'notes': notes,
  };
}

/// Serviço de logbook (histórico de treinos)
class LogbookService {
  final ApiClient _apiClient;

  LogbookService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Lista todas as sessões do logbook do usuário
  Future<List<LogbookResponse>> getLogbookSessions({
    int limit = 10,
    int offset = 0,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'limit': limit,
        'offset': offset,
      };

      final response = await _apiClient.get<List<LogbookResponse>>(
        '/logbook',
        queryParameters: queryParameters,
        fromJson: (data) {
          if (data is List) {
            return data.map((item) => LogbookResponse.fromJson(item as Map<String, dynamic>)).toList();
          }
          return [];
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
        '/logbook/$sessionId',
        fromJson: (data) => LogbookResponse.fromJson(data as Map<String, dynamic>),
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
        '/logbook',
        body: dto.toJson(),
        fromJson: (data) => LogbookResponse.fromJson(data as Map<String, dynamic>),
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
        '/logbook/$sessionId',
        body: dto.toJson(),
        fromJson: (data) => LogbookResponse.fromJson(data as Map<String, dynamic>),
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
        '/logbook/$sessionId',
        fromJson: (_) {},
      );
    } catch (e) {
      rethrow;
    }
  }
}
