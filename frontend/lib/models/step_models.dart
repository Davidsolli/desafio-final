/// Models DTO para o módulo de contador de passos.

class StepLog {
  final String id;
  final String userId;
  final DateTime date;
  final int steps;
  final double distanceMeters;
  final bool isWeekRecord;
  final DateTime createdAt;
  final DateTime updatedAt;

  StepLog({
    required this.id,
    required this.userId,
    required this.date,
    required this.steps,
    required this.distanceMeters,
    required this.isWeekRecord,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StepLog.fromJson(Map<String, dynamic> json) {
    return StepLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      steps: (json['steps'] as num).toInt(),
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      isWeekRecord: json['is_week_record'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  double get distanceKm => distanceMeters / 1000.0;
}

class StepHistory {
  final List<StepLog> logs;
  final int weeklyBest;
  final int currentWeekTotal;
  final bool isNewWeekRecord;

  StepHistory({
    required this.logs,
    required this.weeklyBest,
    required this.currentWeekTotal,
    required this.isNewWeekRecord,
  });

  factory StepHistory.fromJson(Map<String, dynamic> json) {
    final rawLogs = (json['logs'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(StepLog.fromJson)
        .toList();
    return StepHistory(
      logs: rawLogs,
      weeklyBest: (json['weekly_best'] as num?)?.toInt() ?? 0,
      currentWeekTotal: (json['current_week_total'] as num?)?.toInt() ?? 0,
      isNewWeekRecord: json['is_new_week_record'] as bool? ?? false,
    );
  }

  factory StepHistory.empty() => StepHistory(
        logs: [],
        weeklyBest: 0,
        currentWeekTotal: 0,
        isNewWeekRecord: false,
      );
}
