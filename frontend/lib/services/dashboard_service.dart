/// Serviço de Dashboard do Personal Trainer.
///
/// Centraliza chamadas de API para montar o painel profissional com:
/// - Lista de alunos do personal
/// - Métricas: adesão, último treino, frequência

import 'api_client.dart';

class StudentDashboardData {
  final String id;
  final String name;
  final String? goalType;
  final int weeklyFrequency;
  final DateTime? lastWorkout;
  final double adherencePercent;

  StudentDashboardData({
    required this.id,
    required this.name,
    this.goalType,
    required this.weeklyFrequency,
    this.lastWorkout,
    required this.adherencePercent,
  });

  /// Retorna uma string amigável para o último treino
  /// "Hoje", "Ontem", "X dias atrás", ou "-" se nunca treinou
  String get lastWorkoutDisplay {
    if (lastWorkout == null) return '-';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final workoutDate = DateTime(lastWorkout!.year, lastWorkout!.month, lastWorkout!.day);
    final difference = today.difference(workoutDate).inDays;

    if (difference == 0) return 'Hoje';
    if (difference == 1) return 'Ontem';
    return '$difference dias atrás';
  }

  /// Retorna a frequência semanal formatada, ex: "4x/sem"
  String get frequencyDisplay => '${weeklyFrequency}x/sem';

  /// Label de objetivo, ex: "Ganhar Massa"
  String get goalLabel {
    switch (goalType) {
      case 'gain_mass':
        return 'Ganhar Massa';
      case 'lose_weight':
        return 'Perder Peso';
      case 'endurance':
        return 'Resistência';
      case 'maintain':
        return 'Manter';
      default:
        return goalType ?? '-';
    }
  }
}

class DashboardService {
  final ApiClient _apiClient;

  DashboardService(this._apiClient);

  /// Retorna lista de alunos do personal logado (fichas criadas por ele)
  Future<List<Map<String, dynamic>>> getMyStudents({
    int limit = 100,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/workout-sheets',
        queryParameters: {'limit': limit.toString()},
        fromJson: (data) => data as Map<String, dynamic>,
      );

      final dataRaw = response['data'];
      final List<dynamic> workoutSheets = dataRaw is List<dynamic> ? dataRaw : [];
      final uniqueUserIds = <String>{};

      for (final sheet in workoutSheets) {
        if (sheet is Map<String, dynamic>) {
          final userId = sheet['user_id'];
          if (userId != null) {
            uniqueUserIds.add(userId.toString());
          }
        }
      }

      return uniqueUserIds.map((id) => {'user_id': id}).toList();
    } catch (e) {
      return [];
    }
  }

  /// Retorna informações do usuário (nome, goal_type, etc)
  Future<Map<String, dynamic>> getStudentInfo(String studentId) async {
    try {
      return await _apiClient.get<Map<String, dynamic>>(
        '/users/$studentId',
        fromJson: (data) => data as Map<String, dynamic>,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Retorna a última sessão completada do aluno
  Future<Map<String, dynamic>?> getLastSession(String studentId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/logbook/sessions',
        queryParameters: {
          'user_id': studentId,
          'status': 'completed',
          'limit': '1',
        },
        fromJson: (data) => data as Map<String, dynamic>,
      );

      final sessions = response['data'] as List<dynamic>? ?? [];
      if (sessions.isEmpty) return null;

      return sessions.first as Map<String, dynamic>;
    } catch (e) {
      // Se não houver sessões, retorna null em vez de erro
      return null;
    }
  }

  /// Calcula adesão do mês atual (completed / total planejado)
  Future<double> getMonthAdherence(String studentId) async {
    try {
      final now = DateTime.now();
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/logbook/calendar',
        queryParameters: {
          'user_id': studentId,
          'year': now.year.toString(),
          'month': now.month.toString(),
        },
        fromJson: (data) => data as Map<String, dynamic>,
      );

      final summary = response['summary'] as Map<String, dynamic>? ?? {};
      final completed = (summary['completed'] as num?)?.toInt() ?? 0;
      final planned = (summary['planned'] as num?)?.toInt() ?? 1; // Evita divisão por zero

      if (planned == 0) return 0.0;

      final adherence = (completed / planned) * 100;
      return adherence.clamp(0, 100);
    } catch (e) {
      return 0.0;
    }
  }

  /// Retorna frequência semanal (qtd fichas ativas do aluno)
  Future<int> getWeeklyFrequency(String studentId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/workout-sheets',
        queryParameters: {
          'user_id': studentId,
          'limit': '100',
        },
        fromJson: (data) => data as Map<String, dynamic>,
      );

      final total = (response['total'] as num?)?.toInt() ?? 0;
      return total;
    } catch (e) {
      return 0;
    }
  }

  /// Retorna frequência de treinos agrupados por período (weekly/monthly)
  Future<Map<String, dynamic>?> getFrequency({
    required String period,
    int? limit,
  }) async {
    try {
      final queryParams = {'period': period};
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/logbook/frequency',
        queryParameters: queryParams,
        fromJson: (data) => data as Map<String, dynamic>,
      );

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Retorna progressão de exercício com agrupamento opcional
  Future<Map<String, dynamic>?> getExerciseProgression({
    required String exerciseId,
    String? groupBy,
    int? weeks,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (groupBy != null) {
        queryParams['group_by'] = groupBy;
      }
      if (weeks != null) {
        queryParams['weeks'] = weeks.toString();
      }

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/logbook/progression/$exerciseId',
        queryParameters: queryParams,
        fromJson: (data) => data as Map<String, dynamic>,
      );

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Retorna lista completa de `StudentDashboardData` para todos os alunos
  Future<List<StudentDashboardData>> loadDashboard() async {
    try {
      // 1. Pegar alunos do personal
      final studentRefs = await getMyStudents();

      if (studentRefs.isEmpty) {
        return [];
      }

      // 2. Para cada aluno, agregar seus dados em paralelo
      final futuresList = <Future<StudentDashboardData>>[];

      for (final ref in studentRefs) {
        final studentId = ref['user_id'] as String;

        futuresList.add(
          Future(() async {
            final infoFuture = getStudentInfo(studentId);
            final lastSessionFuture = getLastSession(studentId);
            final frequencyFuture = getWeeklyFrequency(studentId);
            final adherenceFuture = getMonthAdherence(studentId);

            final results = await Future.wait([
              infoFuture,
              lastSessionFuture.then((v) => v ?? {}),
              frequencyFuture,
              adherenceFuture,
            ]);

            final info = results[0] as Map<String, dynamic>;
            final lastSession = results[1] as Map<String, dynamic>;
            final frequency = results[2] as int;
            final adherence = results[3] as double;

            return StudentDashboardData(
              id: studentId,
              name: info['name'] as String? ?? 'Sem nome',
              goalType: info['goal_type'] as String?,
              weeklyFrequency: frequency,
              lastWorkout: lastSession['session_date'] != null
                  ? DateTime.parse(lastSession['session_date'].toString())
                  : null,
              adherencePercent: adherence,
            );
          }),
        );
      }

      final students = await Future.wait(futuresList);
      return students;
    } catch (e) {
      rethrow;
    }
  }
}
