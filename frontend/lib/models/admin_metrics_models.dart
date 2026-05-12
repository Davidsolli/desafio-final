/// DTOs para os endpoints de métricas administrativas.
/// Mapeia exatamente o schema retornado por /api/v1/admin/metrics/*

class StudentMetricsItemDTO {
  final String userId;
  final String userName;
  final String? trainerId;
  final String? trainerName;
  final double adherenceRate;
  final String adherenceCategory; // "high" | "medium" | "low"
  final int sessionsCompleted;
  final int sessionsTotal;
  final int dietLogsCount;
  final String riskLevel; // "critical" | "high" | "medium" | "low"
  final int riskScore;
  final int daysInactive;
  final DateTime? lastActivity;
  final double? goalProgress;

  const StudentMetricsItemDTO({
    required this.userId,
    required this.userName,
    this.trainerId,
    this.trainerName,
    required this.adherenceRate,
    required this.adherenceCategory,
    required this.sessionsCompleted,
    required this.sessionsTotal,
    required this.dietLogsCount,
    required this.riskLevel,
    required this.riskScore,
    required this.daysInactive,
    this.lastActivity,
    this.goalProgress,
  });

  factory StudentMetricsItemDTO.fromJson(Map<String, dynamic> json) {
    return StudentMetricsItemDTO(
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      trainerId: json['trainer_id'] as String?,
      trainerName: json['trainer_name'] as String?,
      adherenceRate: (json['adherence_rate'] as num).toDouble(),
      adherenceCategory: json['adherence_category'] as String,
      sessionsCompleted: json['sessions_completed'] as int,
      sessionsTotal: json['sessions_total'] as int,
      dietLogsCount: json['diet_logs_count'] as int,
      riskLevel: json['risk_level'] as String,
      riskScore: json['risk_score'] as int,
      daysInactive: json['days_inactive'] as int,
      lastActivity: json['last_activity'] != null
          ? DateTime.tryParse(json['last_activity'] as String)
          : null,
      goalProgress: json['goal_progress'] != null
          ? (json['goal_progress'] as num).toDouble()
          : null,
    );
  }
}

class StudentMetricsSummaryDTO {
  final int totalStudents;
  final int highAdherenceCount;
  final int mediumAdherenceCount;
  final int lowAdherenceCount;
  final double avgAdherenceRate;
  final int atRiskCritical;
  final int atRiskHigh;
  final int atRiskMedium;
  final int atRiskLow;

  const StudentMetricsSummaryDTO({
    required this.totalStudents,
    required this.highAdherenceCount,
    required this.mediumAdherenceCount,
    required this.lowAdherenceCount,
    required this.avgAdherenceRate,
    required this.atRiskCritical,
    required this.atRiskHigh,
    required this.atRiskMedium,
    required this.atRiskLow,
  });

  factory StudentMetricsSummaryDTO.fromJson(Map<String, dynamic> json) {
    return StudentMetricsSummaryDTO(
      totalStudents: json['total_students'] as int,
      highAdherenceCount: json['high_adherence_count'] as int,
      mediumAdherenceCount: json['medium_adherence_count'] as int,
      lowAdherenceCount: json['low_adherence_count'] as int,
      avgAdherenceRate: (json['avg_adherence_rate'] as num).toDouble(),
      atRiskCritical: json['at_risk_critical'] as int,
      atRiskHigh: json['at_risk_high'] as int,
      atRiskMedium: json['at_risk_medium'] as int,
      atRiskLow: json['at_risk_low'] as int,
    );
  }

  int get totalAtRisk => atRiskCritical + atRiskHigh + atRiskMedium;
}

class PaginatedStudentMetricsDTO {
  final int total;
  final int page;
  final int limit;
  final List<StudentMetricsItemDTO> data;
  final StudentMetricsSummaryDTO summary;

  const PaginatedStudentMetricsDTO({
    required this.total,
    required this.page,
    required this.limit,
    required this.data,
    required this.summary,
  });

  factory PaginatedStudentMetricsDTO.fromJson(Map<String, dynamic> json) {
    return PaginatedStudentMetricsDTO(
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      data: (json['data'] as List)
          .map((e) => StudentMetricsItemDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: StudentMetricsSummaryDTO.fromJson(
        json['summary'] as Map<String, dynamic>,
      ),
    );
  }
}

class TrainerMetricsItemDTO {
  final String trainerId;
  final String trainerName;
  final int totalStudents;
  final int activeStudents;
  final int atRiskStudents;
  final double portfolioHealth;
  final double avgStudentAdherence;
  final int invitesGenerated;
  final int invitesUsed;
  final double conversionRate;

  const TrainerMetricsItemDTO({
    required this.trainerId,
    required this.trainerName,
    required this.totalStudents,
    required this.activeStudents,
    required this.atRiskStudents,
    required this.portfolioHealth,
    required this.avgStudentAdherence,
    required this.invitesGenerated,
    required this.invitesUsed,
    required this.conversionRate,
  });

  factory TrainerMetricsItemDTO.fromJson(Map<String, dynamic> json) {
    return TrainerMetricsItemDTO(
      trainerId: json['trainer_id'] as String,
      trainerName: json['trainer_name'] as String,
      totalStudents: json['total_students'] as int,
      activeStudents: json['active_students'] as int,
      atRiskStudents: json['at_risk_students'] as int,
      portfolioHealth: (json['portfolio_health'] as num).toDouble(),
      avgStudentAdherence: (json['avg_student_adherence'] as num).toDouble(),
      invitesGenerated: json['invites_generated'] as int,
      invitesUsed: json['invites_used'] as int,
      conversionRate: (json['conversion_rate'] as num).toDouble(),
    );
  }
}

class PaginatedTrainerMetricsDTO {
  final int total;
  final int page;
  final int limit;
  final List<TrainerMetricsItemDTO> data;

  const PaginatedTrainerMetricsDTO({
    required this.total,
    required this.page,
    required this.limit,
    required this.data,
  });

  factory PaginatedTrainerMetricsDTO.fromJson(Map<String, dynamic> json) {
    return PaginatedTrainerMetricsDTO(
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      data: (json['data'] as List)
          .map((e) => TrainerMetricsItemDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SystemMetricsDTO {
  final int periodDays;
  final int totalUsers;
  final int activeUsers;
  final int newUsersInPeriod;
  final int totalTrainers;
  final int totalStudents;
  final int dau;
  final int mau;
  final double dauMauRatio;
  final int totalWorkoutsCompleted;
  final int totalDietLogs;
  final double chatbotAdoptionRate;
  final double chatbotQualityScore;

  const SystemMetricsDTO({
    required this.periodDays,
    required this.totalUsers,
    required this.activeUsers,
    required this.newUsersInPeriod,
    required this.totalTrainers,
    required this.totalStudents,
    required this.dau,
    required this.mau,
    required this.dauMauRatio,
    required this.totalWorkoutsCompleted,
    required this.totalDietLogs,
    required this.chatbotAdoptionRate,
    required this.chatbotQualityScore,
  });

  factory SystemMetricsDTO.fromJson(Map<String, dynamic> json) {
    return SystemMetricsDTO(
      periodDays: json['period_days'] as int,
      totalUsers: json['total_users'] as int,
      activeUsers: json['active_users'] as int,
      newUsersInPeriod: json['new_users_in_period'] as int,
      totalTrainers: json['total_trainers'] as int,
      totalStudents: json['total_students'] as int,
      dau: json['dau'] as int,
      mau: json['mau'] as int,
      dauMauRatio: (json['dau_mau_ratio'] as num).toDouble(),
      totalWorkoutsCompleted: json['total_workouts_completed'] as int,
      totalDietLogs: json['total_diet_logs'] as int,
      chatbotAdoptionRate: (json['chatbot_adoption_rate'] as num).toDouble(),
      chatbotQualityScore: (json['chatbot_quality_score'] as num).toDouble(),
    );
  }
}

class AIModelStatsDTO {
  final String model;
  final int messagesCount;
  final int totalTokens;
  final double avgLatencyMs;
  final double percentOfTotal;

  const AIModelStatsDTO({
    required this.model,
    required this.messagesCount,
    required this.totalTokens,
    required this.avgLatencyMs,
    required this.percentOfTotal,
  });

  factory AIModelStatsDTO.fromJson(Map<String, dynamic> json) {
    return AIModelStatsDTO(
      model: json['model'] as String,
      messagesCount: json['messages_count'] as int,
      totalTokens: json['total_tokens'] as int,
      avgLatencyMs: (json['avg_latency_ms'] as num).toDouble(),
      percentOfTotal: (json['percent_of_total'] as num).toDouble(),
    );
  }
}

class AIAnalyticsDTO {
  final int periodDays;
  final int totalMessages;
  final int totalTokens;
  final double avgTokensPerMessage;
  final double avgLatencyMs;
  final double qualityScore;
  final List<AIModelStatsDTO> byModel;

  const AIAnalyticsDTO({
    required this.periodDays,
    required this.totalMessages,
    required this.totalTokens,
    required this.avgTokensPerMessage,
    required this.avgLatencyMs,
    required this.qualityScore,
    required this.byModel,
  });

  factory AIAnalyticsDTO.fromJson(Map<String, dynamic> json) {
    return AIAnalyticsDTO(
      periodDays: json['period_days'] as int,
      totalMessages: json['total_messages'] as int,
      totalTokens: json['total_tokens'] as int,
      avgTokensPerMessage: (json['avg_tokens_per_message'] as num).toDouble(),
      avgLatencyMs: (json['avg_latency_ms'] as num).toDouble(),
      qualityScore: (json['quality_score'] as num).toDouble(),
      byModel: (json['by_model'] as List)
          .map((e) => AIModelStatsDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
