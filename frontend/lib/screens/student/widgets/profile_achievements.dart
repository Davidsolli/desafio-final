import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../providers/goal_provider.dart';
import '../../../../services/goal_service.dart';

/// Widget que exibe conquistas derivadas de metas concluídas.
///
/// Cada meta com status 'completed' vira um "badge" de conquista.
class ProfileAchievements extends StatelessWidget {
  const ProfileAchievements({super.key});

  String _goalEmoji(GoalResponse goal) {
    final unit = goal.unit.toLowerCase();
    if (unit == 'kg') return '🏋️';
    if (unit == '%') return '📊';
    if (unit == 'dias') return '📅';
    if (unit == 'min') return '⏱️';
    return '🏆';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GoalProvider>(
      builder: (context, goalProvider, _) {
        final completed =
            goalProvider.goals.where((g) => g.isCompleted).toList();
        final total = goalProvider.goals.length;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events,
                      color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Conquistas (${completed.length}/$total)',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (goalProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (completed.isEmpty)
                const Text(
                  'Complete metas para desbloquear conquistas!',
                  style: TextStyle(color: AppColors.textMuted),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: completed
                        .map((goal) => Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Column(
                                children: [
                                  Text(
                                    _goalEmoji(goal),
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 56,
                                    child: Text(
                                      goal.title,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: AppColors.textMuted,
                                          ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
