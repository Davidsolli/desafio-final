// Models DTO para o módulo de contador de passos.

class StepLog {
  final String id;
  final String userId;
  final DateTime date;
  final int steps;
  final double distanceMeters;
  final double caloriesBurned;
  final bool isAllTimeRecord;
  final int? handicapLevel;
  final DateTime createdAt;
  final DateTime updatedAt;

  StepLog({
    required this.id,
    required this.userId,
    required this.date,
    required this.steps,
    required this.distanceMeters,
    required this.caloriesBurned,
    required this.isAllTimeRecord,
    this.handicapLevel,
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
      caloriesBurned: (json['calories_burned'] as num? ?? 0).toDouble(),
      isAllTimeRecord: json['is_all_time_record'] as bool? ?? false,
      handicapLevel: json['handicap_level'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  double get distanceKm => distanceMeters / 1000.0;
}

class StepHistory {
  final List<StepLog> logs;
  final int allTimeRecord;
  final int currentWeekTotal;
  final int currentStreak;
  final int dailyGoal;
  final double totalCaloriesToday;

  StepHistory({
    required this.logs,
    required this.allTimeRecord,
    required this.currentWeekTotal,
    required this.currentStreak,
    required this.dailyGoal,
    required this.totalCaloriesToday,
  });

  factory StepHistory.fromJson(Map<String, dynamic> json) {
    final rawLogs = (json['logs'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(StepLog.fromJson)
        .toList();
    return StepHistory(
      logs: rawLogs,
      allTimeRecord: (json['all_time_record'] as num?)?.toInt() ?? 0,
      currentWeekTotal: (json['current_week_total'] as num?)?.toInt() ?? 0,
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      dailyGoal: (json['daily_step_goal'] as num?)?.toInt() ?? 1000,
      totalCaloriesToday:
          (json['total_calories_today'] as num? ?? 0).toDouble(),
    );
  }

  factory StepHistory.empty() => StepHistory(
        logs: [],
        allTimeRecord: 0,
        currentWeekTotal: 0,
        currentStreak: 0,
        dailyGoal: 1000,
        totalCaloriesToday: 0.0,
      );
}
