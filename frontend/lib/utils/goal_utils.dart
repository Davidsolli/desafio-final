import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

abstract class GoalUtils {
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.primary;
      case 'completed':
        return Colors.green;
      case 'failed':
        return AppColors.accentError;
      case 'paused':
        return Colors.orange;
      default:
        return AppColors.textMuted;
    }
  }

  static String getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Ativa';
      case 'completed':
        return 'Concluída';
      case 'failed':
        return 'Expirada';
      case 'paused':
        return 'Pausada';
      default:
        return status;
    }
  }

  static String getCategoryLabel(String category) {
    switch (category.toLowerCase()) {
      case 'strength':
        return '🏋️ Força';
      case 'endurance':
        return '🏃 Resistência';
      case 'composition':
        return '⚖️ Composição';
      case 'frequency':
        return '📅 Frequência';
      case 'general':
        return '🎯 Geral';
      default:
        return category.isNotEmpty ? category : 'N/D';
    }
  }
}
