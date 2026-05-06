import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/user_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/logbook_provider.dart';

class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  String _selectedPeriod = 'week';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<UserProvider>().loadUser().catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao carregar métricas: $e')),
            );
          }
        });
        context.read<LogbookProvider>().loadSessions().catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao carregar sessões: $e')),
            );
          }
        });
        context.read<GoalProvider>().loadGoals().catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao carregar metas: $e')),
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildPeriodSelector(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Consumer<UserProvider>(
                  builder: (context, userProvider, _) {
                    if (userProvider.isLoading) {
                      return const SizedBox(
                        height: 300,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    final user = userProvider.user;
                    if (user == null) {
                      return const SizedBox(height: 300);
                    }

                    return Column(
                      children: [
                        _buildBodyMetrics(user),
                        const SizedBox(height: 16),
                        _buildWorkoutMetrics(),
                        const SizedBox(height: 16),
                        _buildGoalsMetrics(),
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 300),
            child: Text(
              'Meu Dashboard',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          FadeInUp(
            duration: const Duration(milliseconds: 300),
            delay: const Duration(milliseconds: 100),
            child: Text(
              'Acompanhe seu progresso e desempenho',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    final periods = [
      ('week', '📅 Semana'),
      ('month', '📊 Mês'),
      ('all', '📈 Todos'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: periods.map((period) {
            final isSelected = _selectedPeriod == period.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(period.$2),
                selected: isSelected,
                backgroundColor: context.colors.surface,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedPeriod = period.$1);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBodyMetrics(dynamic user) {
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      delay: const Duration(milliseconds: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💪 Métricas Corporais',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colors.surface,
              border: Border.all(color: context.colors.border, width: 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricCard('IMC', user.imc.toStringAsFixed(1), user.imcLabel, Icons.trending_up),
                    _buildMetricCard('TMB', user.tmb.toString(), 'kcal/dia', Icons.local_fire_department),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricCard('Peso', '${user.weight.toStringAsFixed(1)}', 'kg', Icons.scale),
                    _buildMetricCard('Altura', '${user.height.toStringAsFixed(0)}', 'cm', Icons.height),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, String unit, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted),
            ),
            Text(
              unit,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkoutMetrics() {
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      delay: const Duration(milliseconds: 200),
      child: Consumer<LogbookProvider>(
        builder: (context, logbookProvider, _) {
          final sessions = _filterSessionsByPeriod(logbookProvider.sessions);
          final totalDuration = sessions.fold<int>(0, (sum, s) => sum + (s.durationMinutes as int));
          final totalCalories = sessions.fold<double>(0.0, (sum, s) => sum + (s.caloriesBurned as double));
          final avgIntensity = sessions.isEmpty ? 'N/A' : _getAverageIntensity(sessions);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🏋️ Treinos',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border.all(color: context.colors.border, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCard('Sessões', sessions.length.toString(), 'treinos', Icons.fitness_center),
                        _buildMetricCard('Duração', totalDuration.toString(), 'min', Icons.schedule),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCard('Calorias', totalCalories.toStringAsFixed(0), 'kcal', Icons.local_fire_department),
                        _buildMetricCard('Intensidade', avgIntensity, 'média', Icons.show_chart),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGoalsMetrics() {
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      delay: const Duration(milliseconds: 300),
      child: Consumer<GoalProvider>(
        builder: (context, goalProvider, _) {
          final allGoals = goalProvider.goals;
          final completedGoals = allGoals.where((g) => g.isCompleted).length;
          final activeGoals = allGoals.where((g) => g.status.toLowerCase() == 'active').length;
          final avgProgress = allGoals.isEmpty
              ? 0.0
              : allGoals.fold<double>(0, (sum, g) => sum + g.progressPercentage) / allGoals.length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '🎯 Metas',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  border: Border.all(color: context.colors.border, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCard('Total', allGoals.length.toString(), 'metas', Icons.flag),
                        _buildMetricCard('Ativas', activeGoals.toString(), 'em progresso', Icons.check_circle_outline),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMetricCard('Concluídas', completedGoals.toString(), 'finalizadas', Icons.done_all),
                        _buildMetricCard('Progresso', avgProgress.toStringAsFixed(0), '%', Icons.trending_up),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<dynamic> _filterSessionsByPeriod(List<dynamic> sessions) {
    if (sessions.isEmpty) return [];

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));

    switch (_selectedPeriod) {
      case 'week':
        return sessions.where((s) => s.sessionDate.isAfter(weekAgo)).toList();
      case 'month':
        return sessions.where((s) => s.sessionDate.isAfter(monthAgo)).toList();
      default:
        return sessions;
    }
  }

  String _getAverageIntensity(List<dynamic> sessions) {
    if (sessions.isEmpty) return 'N/A';

    int leve = 0, moderada = 0, intensa = 0;
    for (var session in sessions) {
      switch (session.intensity.toLowerCase()) {
        case 'leve':
          leve++;
          break;
        case 'moderada':
          moderada++;
          break;
        case 'intensa':
          intensa++;
          break;
      }
    }

    if (intensa > moderada && intensa > leve) return 'Intensa';
    if (moderada >= leve) return 'Moderada';
    return 'Leve';
  }
}
