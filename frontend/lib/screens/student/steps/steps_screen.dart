import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../models/step_models.dart';
import '../../../providers/step_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';
import '../../../shared/widgets/index.dart';

class StepsScreen extends StatelessWidget {
  const StepsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        elevation: 0,
        title: const Text('Contador de passos'),
        centerTitle: true,
      ),
      body: Consumer<StepProvider>(
        builder: (context, provider, _) {
          if (provider.state == StepProviderState.loading) {
            return const OmniLoader();
          }

          if (provider.state == StepProviderState.permissionDenied) {
            return _buildPermissionDenied(context);
          }

          if (provider.state == StepProviderState.sensorUnavailable) {
            return _buildSensorUnavailable(context);
          }

          return RefreshIndicator(
            onRefresh: provider.refreshHistory,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTodayCard(context, provider),
                  const SizedBox(height: 16),
                  if (provider.history.isNewWeekRecord ||
                      provider.history.weeklyBest > 0)
                    _buildWeeklyStatsCard(context, provider.history),
                  const SizedBox(height: 16),
                  Text(
                    'Últimos 7 dias',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildWeeklyChart(context, provider),
                  const SizedBox(height: 24),
                  Text(
                    'Histórico',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  _buildHistoryList(context, provider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPermissionDenied(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_walk,
                size: 64, color: context.colors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Permissão necessária',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Para contar seus passos, precisamos da permissão de reconhecimento '
              'de atividade física. Habilite nas configurações do dispositivo.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorUnavailable(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors_off,
                size: 64, color: context.colors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Sensor indisponível',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Seu dispositivo não possui sensor de passos compatível.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard(BuildContext context, StepProvider provider) {
    final progress = provider.stepsToday / kDailyStepGoal;
    final distance = provider.distanceTodayKm;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_walk, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'PASSOS HOJE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatNumber(provider.stepsToday),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'de $kDailyStepGoal • ${distance.toStringAsFixed(2)} km',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          if (provider.isSyncing) ...[
            const SizedBox(height: 12),
            const Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Sincronizando...',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyStatsCard(BuildContext context, StepHistory history) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semana atual',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNumber(history.currentWeekTotal),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: context.colors.border,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Recorde',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                    ),
                    if (history.isNewWeekRecord) ...[
                      const SizedBox(width: 4),
                      const Text('🏆', style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNumber(history.weeklyBest),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: history.isNewWeekRecord
                            ? AppColors.primary
                            : null,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart(BuildContext context, StepProvider provider) {
    final last7 = _getLast7Days(provider);
    final maxY =
        (last7.fold<int>(0, (m, p) => p.steps > m ? p.steps : m)).toDouble();

    return SizedBox(
      height: 220,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: BarChart(
          BarChartData(
            maxY: maxY > 0 ? maxY * 1.2 : 1000,
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= last7.length) {
                      return const SizedBox.shrink();
                    }
                    final d = last7[idx].date;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _weekdayLabel(d),
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const SizedBox.shrink();
                    return Text(
                      _abbreviateNumber(value.toInt()),
                      style: const TextStyle(fontSize: 9),
                    );
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(last7.length, (i) {
              final p = last7[i];
              final isToday = _isToday(p.date);
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: p.steps.toDouble(),
                    color: isToday
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.5),
                    width: 14,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context, StepProvider provider) {
    final logs = List<StepLog>.from(provider.history.logs)
      ..sort((a, b) => b.date.compareTo(a.date));

    if (logs.isEmpty) {
      return OmniEmptyState(
        icon: Icons.directions_walk,
        title: 'Sem histórico ainda',
      );
    }

    return Column(
      children: logs.take(30).map((log) => _buildHistoryRow(context, log)).toList(),
    );
  }

  Widget _buildHistoryRow(BuildContext context, StepLog log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.directions_walk,
                color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(log.date),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${log.distanceKm.toStringAsFixed(2)} km',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Text(
            _formatNumber(log.steps),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          if (log.isWeekRecord) ...[
            const SizedBox(width: 6),
            const Text('🏆'),
          ],
        ],
      ),
    );
  }

  // ----- Helpers -----

  List<StepLog> _getLast7Days(StepProvider provider) {
    final logsByDate = {
      for (final l in provider.history.logs)
        DateTime(l.date.year, l.date.month, l.date.day): l,
    };
    final result = <StepLog>[];
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    for (var i = 6; i >= 0; i--) {
      final day = base.subtract(Duration(days: i));
      final existing = logsByDate[day];
      if (existing != null) {
        // Para o dia de hoje, usamos os passos atuais do sensor (mais recentes
        // que o último sync).
        if (_isToday(day) && provider.stepsToday > existing.steps) {
          result.add(StepLog(
            id: existing.id,
            userId: existing.userId,
            date: day,
            steps: provider.stepsToday,
            distanceMeters: provider.distanceTodayMeters,
            isWeekRecord: existing.isWeekRecord,
            createdAt: existing.createdAt,
            updatedAt: existing.updatedAt,
          ));
        } else {
          result.add(existing);
        }
      } else {
        result.add(StepLog(
          id: '',
          userId: '',
          date: day,
          steps: _isToday(day) ? provider.stepsToday : 0,
          distanceMeters: _isToday(day) ? provider.distanceTodayMeters : 0,
          isWeekRecord: false,
          createdAt: day,
          updatedAt: day,
        ));
      }
    }
    return result;
  }

  static bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  static String _weekdayLabel(DateTime d) {
    const labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return labels[d.weekday - 1];
  }

  static String _formatNumber(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _abbreviateNumber(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(n % 1000 == 0 ? 0 : 1)}k';
    }
    return n.toString();
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }
}
