/// Serviço de Dashboard do Personal Trainer.
///
/// Centraliza chamadas de API para montar o painel profissional com:
/// - Lista de alunos do personal
/// - Métricas: adesão, último treino, frequência

import 'api_client.dart';

/// Converte qualquer Map para Map<String, dynamic> de forma segura.
/// Resolve o problema de LinkedMap<dynamic, dynamic> vindo do JSON decoder.
/// Converte qualquer Map para Map<String, dynamic> de forma segura.
/// Resolve o problema de LinkedMap<dynamic, dynamic> vindo do JSON decoder.
Map<String, dynamic> _m(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

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

  /// Retorna lista de alunos vinculados ao personal logado
  Future<List<Map<String, dynamic>>> getMyStudents({
    int limit = 100,
  }) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/users/students',
        queryParameters: {'page': '1', 'limit': limit.toString()},
        fromJson: (data) => _m(data),
      );

      final dataRaw = response['data'];
      final List<dynamic> students = dataRaw is List<dynamic> ? dataRaw : [];
      return students.map((s) => _m(s)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Retorna informações do usuário (nome, goal_type, etc)
  Future<Map<String, dynamic>> getStudentInfo(String studentId) async {
    try {
      return await _apiClient.get<Map<String, dynamic>>(
        '/users/$studentId',
        fromJson: (data) => _m(data),
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
        fromJson: (data) => _m(data),
      );

      final sessions = response['data'] as List<dynamic>? ?? [];
      if (sessions.isEmpty) return null;

      return _m(sessions.first);
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
        fromJson: (data) => _m(data),
      );

      final summary = _m(response['summary']);
      final completed = (summary['completed'] as num?)?.toInt() ?? 0;
      final planned = (summary['planned'] as num?)?.toInt() ?? 1;

      final adherence = (completed / planned) * 100;
      return adherence.clamp(0, 100);
    } catch (e) {
      return 0.0;
    }
  }

  /// Retorna frequência semanal (dias/semana únicos nas fichas do aluno)
  Future<int> getWeeklyFrequency(String studentId) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/workout-programs',
        queryParameters: {'user_id': studentId, 'limit': '10'},
        fromJson: (data) => _m(data),
      );

      final programs = response['data'] as List<dynamic>? ?? [];
      final days = <int>{};
      for (final prog in programs) {
        final progMap = _m(prog);
        final sheets = progMap['workout_sheets'] as List<dynamic>? ?? [];
        for (final sheet in sheets) {
          final sheetMap = _m(sheet);
          final day = sheetMap['day_of_week'];
          if (day != null) days.add((day as num).toInt());
        }
      }
      return days.length;
    } catch (e) {
      return 0;
    }
  }

  /// Retorna total de sessões completadas esta semana por todos os alunos
  Future<int> getStudentsWorkoutsThisWeek(List<String> studentIds) async {
    if (studentIds.isEmpty) return 0;
    try {
      final futures = studentIds.map((id) async {
        final r = await getFrequency(period: 'weekly', limit: 1, userId: id);
        if (r == null) return 0;
        final points = r['data_points'] as List<dynamic>? ?? [];
        if (points.isEmpty) return 0;
        final last = _m(points.last);
        return (last['count'] as num?)?.toInt() ?? 0;
      });
      final counts = await Future.wait(futures);
      return counts.fold<int>(0, (sum, c) => sum + c);
    } catch (_) {
      return 0;
    }
  }

  /// Retorna frequência de treinos agrupados por período (weekly/monthly)
  Future<Map<String, dynamic>?> getFrequency({
    required String period,
    int? limit,
    String? userId,
  }) async {
    try {
      final queryParams = {'period': period};
      if (limit != null) {
        queryParams['limit'] = limit.toString();
      }
      if (userId != null) {
        queryParams['user_id'] = userId;
      }

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/logbook/frequency',
        queryParameters: queryParams,
        fromJson: (data) => _m(data),
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
    String? userId,
  }) async {
    try {
      final queryParams = <String, String>{};
      if (groupBy != null) {
        queryParams['group_by'] = groupBy;
      }
      if (weeks != null) {
        queryParams['weeks'] = weeks.toString();
      }
      if (userId != null) {
        queryParams['user_id'] = userId;
      }

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/logbook/progression/$exerciseId',
        queryParameters: queryParams,
        fromJson: (data) => _m(data),
      );

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Retorna distribuição muscular dos exercícios completados pelo aluno
  Future<Map<String, dynamic>?> getMuscleGroupDistribution({
    int days = 30,
    String? userId,
  }) async {
    try {
      final queryParams = <String, String>{'days': days.toString()};
      if (userId != null) {
        queryParams['user_id'] = userId;
      }

      final response = await _apiClient.get<Map<String, dynamic>>(
        '/logbook/muscle-group-distribution',
        queryParameters: queryParams,
        fromJson: (data) => _m(data),
      );

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Retorna total de convites pendentes (não utilizados) do personal logado
  Future<int> getPendingInvites() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '/invitations',
        fromJson: (data) => _m(data),
      );
      return (response['pending'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Retorna lista completa de `StudentDashboardData` para todos os alunos
  Future<List<StudentDashboardData>> loadDashboard() async {
    try {
      // 1. Busca alunos via /users/students (já contém nome e goal_type)
      final studentRefs = await getMyStudents();

      if (studentRefs.isEmpty) {
        return [];
      }

      // 2. Para cada aluno, agrega dados em paralelo
      final futuresList = studentRefs.map((ref) async {
        final studentId = ref['id'] as String;
        final studentName = ref['name'] as String? ?? 'Sem nome';
        final goalType = ref['goal_type'] as String?;

        final results = await Future.wait([
          getLastSession(studentId).then((v) => v ?? <String, dynamic>{}),
          getWeeklyFrequency(studentId),
          getMonthAdherence(studentId),
        ]);

        final lastSession = _m(results[0]);
        final frequency = (results[1] as num?)?.toInt() ?? 0;
        final adherence = (results[2] as num?)?.toDouble() ?? 0.0;

        return StudentDashboardData(
          id: studentId,
          name: studentName,
          goalType: goalType,
          weeklyFrequency: frequency,
          lastWorkout: lastSession['session_date'] != null
              ? DateTime.tryParse(lastSession['session_date'].toString())
              : null,
          adherencePercent: adherence,
        );
      }).toList();

      return await Future.wait(futuresList);
    } catch (e) {
      rethrow;
    }
  }
}
