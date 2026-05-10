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

  /// Busca a frequência de treinos por período (weekly ou monthly)
  Future<FrequencyResponse> getWorkoutFrequency({
    required String period,
    int? limit,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'period': period,
        if (limit != null) 'limit': limit.toString(),
      };

      final response = await _apiClient.get<FrequencyResponse>(
        '/logbook/frequency',
        queryParameters: queryParameters,
        fromJson: (data) => FrequencyResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Busca a distribuição de volume de treinos por grupo muscular
  Future<MuscleGroupDistributionResponse> getMuscleGroupDistribution({
    int days = 30,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'days': days.toString(),
      };

      final response = await _apiClient.get<MuscleGroupDistributionResponse>(
        '/logbook/muscle-group-distribution',
        queryParameters: queryParameters,
        fromJson: (data) => MuscleGroupDistributionResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Busca a evolução histórica de cargas de um exercício específico
  Future<ProgressionResponse> getExerciseProgression(
    String exerciseId, {
    int weeks = 8,
  }) async {
    try {
      final queryParameters = <String, dynamic>{
        'weeks': weeks.toString(),
      };

      final response = await _apiClient.get<ProgressionResponse>(
        '/logbook/progression/$exerciseId',
        queryParameters: queryParameters,
        fromJson: (data) => ProgressionResponse.fromJson(data as Map<String, dynamic>),
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }
}

/// Ponto de dados de progressão de carga de um exercício
class ProgressionDataPoint {
  final DateTime sessionDate;
  final double actualLoadKg;
  final int actualSeries;
  final int actualRepetitions;
  final double volumeKg;

  ProgressionDataPoint({
    required this.sessionDate,
    required this.actualLoadKg,
    required this.actualSeries,
    required this.actualRepetitions,
    required this.volumeKg,
  });

  factory ProgressionDataPoint.fromJson(Map<String, dynamic> json) {
    return ProgressionDataPoint(
      sessionDate: DateTime.parse(json['session_date'] as String),
      actualLoadKg: (json['actual_load_kg'] as num).toDouble(),
      actualSeries: json['actual_series'] as int,
      actualRepetitions: json['actual_repetitions'] as int,
      volumeKg: (json['volume_kg'] as num).toDouble(),
    );
  }
}

/// Estatísticas calculadas de progressão
class ProgressionStatistics {
  final int totalSessions;
  final double avgLoadKg;
  final double maxLoadKg;
  final double minLoadKg;
  final double avgVolumeKg;
  final String trend;
  final double improvementPercentage;

  ProgressionStatistics({
    required this.totalSessions,
    required this.avgLoadKg,
    required this.maxLoadKg,
    required this.minLoadKg,
    required this.avgVolumeKg,
    required this.trend,
    required this.improvementPercentage,
  });

  factory ProgressionStatistics.fromJson(Map<String, dynamic> json) {
    return ProgressionStatistics(
      totalSessions: json['total_sessions'] as int,
      avgLoadKg: (json['avg_load_kg'] as num).toDouble(),
      maxLoadKg: (json['max_load_kg'] as num).toDouble(),
      minLoadKg: (json['min_load_kg'] as num).toDouble(),
      avgVolumeKg: (json['avg_volume_kg'] as num).toDouble(),
      trend: json['trend'] as String,
      improvementPercentage: (json['improvement_percentage'] as num).toDouble(),
    );
  }
}

/// Resposta completa de progressão de um exercício
class ProgressionResponse {
  final String exerciseId;
  final String userId;
  final List<ProgressionDataPoint> dataPoints;
  final ProgressionStatistics statistics;

  ProgressionResponse({
    required this.exerciseId,
    required this.userId,
    required this.dataPoints,
    required this.statistics,
  });

  factory ProgressionResponse.fromJson(Map<String, dynamic> json) {
    return ProgressionResponse(
      exerciseId: json['exercise_id'] as String,
      userId: json['user_id'] as String,
      dataPoints: (json['data_points'] as List<dynamic>?)
          ?.map((e) => ProgressionDataPoint.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      statistics: ProgressionStatistics.fromJson(json['statistics'] as Map<String, dynamic>),
    );
  }
}

/// Ponto de dados de frequência de treinos
class FrequencyDataPoint {
  final DateTime periodStart;
  final DateTime periodEnd;
  final int count;

  FrequencyDataPoint({
    required this.periodStart,
    required this.periodEnd,
    required this.count,
  });

  factory FrequencyDataPoint.fromJson(Map<String, dynamic> json) {
    return FrequencyDataPoint(
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      count: json['count'] as int,
    );
  }
}

/// Resposta de frequência de treinos agrupada
class FrequencyResponse {
  final String userId;
  final String period;
  final List<FrequencyDataPoint> dataPoints;

  FrequencyResponse({
    required this.userId,
    required this.period,
    required this.dataPoints,
  });

  factory FrequencyResponse.fromJson(Map<String, dynamic> json) {
    return FrequencyResponse(
      userId: json['user_id'] as String,
      period: json['period'] as String,
      dataPoints: (json['data_points'] as List<dynamic>?)
          ?.map((e) => FrequencyDataPoint.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}

/// Item de distribuição de treinos por grupo muscular
class MuscleGroupDistributionItem {
  final String muscleGroup;
  final int count;

  MuscleGroupDistributionItem({
    required this.muscleGroup,
    required this.count,
  });

  factory MuscleGroupDistributionItem.fromJson(Map<String, dynamic> json) {
    return MuscleGroupDistributionItem(
      muscleGroup: json['muscle_group'] as String,
      count: json['count'] as int,
    );
  }
}

/// Resposta de distribuição de treinos por grupo muscular
class MuscleGroupDistributionResponse {
  final String userId;
  final int days;
  final List<MuscleGroupDistributionItem> distribution;

  MuscleGroupDistributionResponse({
    required this.userId,
    required this.days,
    required this.distribution,
  });

  factory MuscleGroupDistributionResponse.fromJson(Map<String, dynamic> json) {
    return MuscleGroupDistributionResponse(
      userId: json['user_id'] as String,
      days: json['days'] as int,
      distribution: (json['distribution'] as List<dynamic>?)
          ?.map((e) => MuscleGroupDistributionItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }
}
