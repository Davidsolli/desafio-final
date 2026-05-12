import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../models/step_models.dart';
import '../../../providers/step_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';
import '../../../shared/widgets/index.dart';

const _kHandicapColor = Color(0xFFF59E0B);

enum _StepsFilter { week, currentMonth, lastMonth, record }

class StepsScreen extends StatefulWidget {
  const StepsScreen({super.key});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  _StepsFilter _filter = _StepsFilter.week;

  // ---------------------------------------------------------------------------
  // Build principal
  // ---------------------------------------------------------------------------

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
            return _buildPermissionDenied();
          }
          if (provider.state == StepProviderState.sensorUnavailable) {
            return _buildSensorUnavailable();
          }

          final filteredLogs = _applyFilter(provider);

          return RefreshIndicator(
            onRefresh: provider.refreshHistory,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTodayCard(provider),
                  const SizedBox(height: 12),
                  _buildHandicapSelector(provider),
                  const SizedBox(height: 12),
                  _buildStreakCard(provider),
                  const SizedBox(height: 16),
                  _buildStatsRow(provider.history),
                  const SizedBox(height: 20),
                  _buildFilterHeader(provider, filteredLogs),
                  const SizedBox(height: 12),
                  _buildChart(provider, filteredLogs),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text(
                        'Histórico',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${filteredLogs.where((l) => l.id.isNotEmpty).length} dias)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.colors.textMuted,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildHistoryList(filteredLogs),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Lógica de filtro
  // ---------------------------------------------------------------------------

  List<StepLog> _applyFilter(StepProvider provider) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_filter) {
      case _StepsFilter.week:
        return _getLast7Days(provider);

      case _StepsFilter.currentMonth:
        final logs = _logsOfMonth(provider.history.logs, now.year, now.month);
        return _mergeToday(logs, provider, today);

      case _StepsFilter.lastMonth:
        final last = DateTime(now.year, now.month - 1);
        return _logsOfMonth(
            provider.history.logs, last.year, last.month);

      case _StepsFilter.record:
        if (provider.history.allTimeRecord == 0) return [];
        return provider.history.logs
            .where((l) => l.isAllTimeRecord)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    }
  }

  List<StepLog> _logsOfMonth(
      List<StepLog> all, int year, int month) {
    return (all.where((l) => l.date.year == year && l.date.month == month)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date)));
  }

  List<StepLog> _mergeToday(
      List<StepLog> logs, StepProvider provider, DateTime today) {
    final idx =
        logs.indexWhere((l) => _isSameDay(l.date, today));
    if (idx >= 0 && provider.stepsToday > logs[idx].steps) {
      final updated = StepLog(
        id: logs[idx].id,
        userId: logs[idx].userId,
        date: today,
        steps: provider.stepsToday,
        distanceMeters: provider.distanceTodayMeters,
        caloriesBurned: provider.caloriesToday,
        isAllTimeRecord: logs[idx].isAllTimeRecord,
        handicapLevel: provider.selectedHandicapLevel,
        createdAt: logs[idx].createdAt,
        updatedAt: logs[idx].updatedAt,
      );
      final result = List<StepLog>.from(logs);
      result[idx] = updated;
      return result;
    }
    return logs;
  }

  // ---------------------------------------------------------------------------
  // Header: título do gráfico + chips de filtro
  // ---------------------------------------------------------------------------

  Widget _buildFilterHeader(StepProvider provider, List<StepLog> filtered) {
    final titles = {
      _StepsFilter.week: 'Últimos 7 dias',
      _StepsFilter.currentMonth: 'Mês atual',
      _StepsFilter.lastMonth: 'Último mês',
      _StepsFilter.record: 'Recorde pessoal',
    };

    final chipLabels = {
      _StepsFilter.week: '7 dias',
      _StepsFilter.currentMonth: 'Mês atual',
      _StepsFilter.lastMonth: 'Último mês',
      _StepsFilter.record: '🏆 Recorde',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titles[_filter]!,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _StepsFilter.values.map((f) {
              final selected = _filter == f;
              final isRecord = f == _StepsFilter.record;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: selected
                          ? (isRecord
                              ? const Color(0xFFF59E0B)
                              : AppColors.primary)
                          : context.colors.surface,
                      border: Border.all(
                        color: selected
                            ? (isRecord
                                ? const Color(0xFFF59E0B)
                                : AppColors.primary)
                            : context.colors.border,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      chipLabels[f]!,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? Colors.white
                            : context.colors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Gráfico — adapta ao filtro ativo
  // ---------------------------------------------------------------------------

  Widget _buildChart(StepProvider provider, List<StepLog> logs) {
    if (logs.isEmpty) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          'Sem dados para este período',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colors.textMuted,
              ),
        ),
      );
    }

    // Filtro recorde: exibe um único card em destaque
    if (_filter == _StepsFilter.record) {
      return _buildRecordHighlight(logs.first);
    }

    // Gráfico de barras para semana (7 dias fixos incluindo zeros)
    if (_filter == _StepsFilter.week) {
      return _buildBarChart(logs, labelFn: (l) => _weekdayLabel(l.date));
    }

    // Gráfico de barras para mês (apenas dias com dados)
    return _buildBarChart(
      logs,
      labelFn: (l) => '${l.date.day}',
      barWidth: logs.length > 15 ? 7.0 : 11.0,
      showEvery: logs.length > 20 ? 5 : (logs.length > 10 ? 3 : 1),
    );
  }

  Widget _buildBarChart(
    List<StepLog> logs, {
    required String Function(StepLog) labelFn,
    double barWidth = 14.0,
    int showEvery = 1,
  }) {
    final maxY =
        (logs.fold<int>(0, (m, p) => p.steps > m ? p.steps : m)).toDouble();

    return SizedBox(
      height: 220,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
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
                    if (idx < 0 || idx >= logs.length) {
                      return const SizedBox.shrink();
                    }
                    if (showEvery > 1 && idx % showEvery != 0) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(labelFn(logs[idx]),
                          style: const TextStyle(fontSize: 9)),
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
                    return Text(_abbreviateNumber(value.toInt()),
                        style: const TextStyle(fontSize: 9));
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            barGroups: List.generate(logs.length, (i) {
              final p = logs[i];
              final isToday = _isToday(p.date);
              final isHandicap = p.handicapLevel != null;
              final isRecord = p.isAllTimeRecord;

              Color barColor;
              if (isRecord) {
                barColor = const Color(0xFFF59E0B);
              } else if (isHandicap) {
                barColor = isToday
                    ? _kHandicapColor
                    : _kHandicapColor.withValues(alpha: 0.6);
              } else {
                barColor = isToday
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.5);
              }

              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: p.steps.toDouble(),
                    color: barColor,
                    width: barWidth,
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

  Widget _buildRecordHighlight(StepLog log) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 44)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Melhor dia de sempre',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatNumber(log.steps),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${log.distanceKm.toStringAsFixed(2)} km · ${log.caloriesBurned.toStringAsFixed(0)} kcal',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(log.date),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card principal: passos de hoje
  // ---------------------------------------------------------------------------

  Widget _buildTodayCard(StepProvider provider) {
    final goal = provider.dailyGoal;
    final progress = goal > 0 ? provider.stepsToday / goal : 0.0;
    final distance = provider.distanceTodayKm;
    final calories = provider.caloriesToday;

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
          Row(
            children: [
              const Icon(Icons.directions_walk, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'PASSOS HOJE',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showGoalDialog(provider),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Meta: ${_formatNumber(goal)}',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit, color: Colors.white, size: 12),
                    ],
                  ),
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
          Row(
            children: [
              Text(
                '${distance.toStringAsFixed(2)} km',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.local_fire_department,
                  color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(
                '${calories.toStringAsFixed(0)} kcal',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
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
                      strokeWidth: 2, color: Colors.white70),
                ),
                SizedBox(width: 8),
                Text('Sincronizando...',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Botão "Não estou bem hoje"
  // ---------------------------------------------------------------------------

  Widget _buildHandicapSelector(StepProvider provider) {
    final current = provider.selectedHandicapLevel;
    final isActive = current != null;

    return GestureDetector(
      onTap: () => _showHandicapModal(provider),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive
              ? _kHandicapColor.withValues(alpha: 0.1)
              : context.colors.surface,
          border: Border.all(
            color:
                isActive ? _kHandicapColor : context.colors.border,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive
                    ? _kHandicapColor.withValues(alpha: 0.15)
                    : context.colors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isActive
                    ? Icons.healing_outlined
                    : Icons.sentiment_dissatisfied_outlined,
                color: isActive
                    ? _kHandicapColor
                    : context.colors.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Não estou bem hoje',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isActive ? _kHandicapColor : null,
                        ),
                  ),
                  Text(
                    isActive
                        ? 'Nível $current ativo — meta reduzida para hoje'
                        : 'Toque para ajustar sua meta de hoje',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isActive
                              ? _kHandicapColor.withValues(alpha: 0.8)
                              : context.colors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isActive
                  ? _kHandicapColor
                  : context.colors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showHandicapModal(StepProvider provider) {
    final goal = provider.dailyGoal;
    final current = provider.selectedHandicapLevel;

    final levels = [
      (
        level: null as int?,
        label: 'Dia normal',
        description: 'Meta padrão completa',
        goalSteps: goal,
        icon: Icons.check_circle_outline,
        color: AppColors.primary,
      ),
      (
        level: 1 as int?,
        label: 'Nível 1 — Cansado',
        description: 'Pequena redução para dias mais pesados',
        goalSteps: (goal * 3 / 4).round(),
        icon: Icons.battery_3_bar,
        color: _kHandicapColor,
      ),
      (
        level: 2 as int?,
        label: 'Nível 2 — Mal-estar',
        description: 'Redução moderada para quando não se sente bem',
        goalSteps: (goal * 2 / 4).round(),
        icon: Icons.battery_2_bar,
        color: _kHandicapColor,
      ),
      (
        level: 3 as int?,
        label: 'Nível 3 — Muito mal',
        description: 'Mínimo para dias de recuperação',
        goalSteps: (goal * 1 / 4).round(),
        icon: Icons.battery_1_bar,
        color: _kHandicapColor,
      ),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: ctx.colors.background,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Text('😓', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text(
                  'Não estou bem hoje',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _kHandicapColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _kHandicapColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: _kHandicapColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'A alteração de meta ficará ativa apenas hoje. '
                      'Sua sequência não será quebrada se atingir a meta reduzida.',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: _kHandicapColor,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            ...levels.map((opt) {
              final isSelected = current == opt.level;
              return GestureDetector(
                onTap: () {
                  provider.setHandicapLevel(opt.level);
                  Navigator.of(ctx).pop();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? opt.color.withValues(alpha: 0.1)
                        : ctx.colors.surface,
                    border: Border.all(
                      color:
                          isSelected ? opt.color : ctx.colors.border,
                      width: isSelected ? 1.5 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(opt.icon, color: opt.color, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              opt.label,
                              style: Theme.of(ctx)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? opt.color : null,
                                  ),
                            ),
                            Text(
                              opt.description,
                              style: Theme.of(ctx)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: ctx.colors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _formatNumber(opt.goalSteps),
                            style: Theme.of(ctx)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: opt.color,
                                ),
                          ),
                          Text(
                            'passos',
                            style: Theme.of(ctx)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: ctx.colors.textSecondary,
                                  fontSize: 10,
                                ),
                          ),
                        ],
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.check_circle,
                            color: opt.color, size: 18),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Card de sequência
  // ---------------------------------------------------------------------------

  Widget _buildStreakCard(StepProvider provider) {
    final streak = provider.currentStreak;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: streak > 0
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$streak ${streak == 1 ? 'dia seguido' : 'dias seguidos'}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Continue assim! Meta batida $streak ${streak == 1 ? 'vez' : 'vezes'} consecutiva${streak == 1 ? '' : 's'}.',
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                      ),
                    ],
                  )
                : Text(
                    'Comece hoje a sua sequência!',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: context.colors.textSecondary),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Linha de estatísticas
  // ---------------------------------------------------------------------------

  Widget _buildStatsRow(StepHistory history) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCell(
            label: 'Semana atual',
            value: _formatNumber(history.currentWeekTotal),
            highlight: false,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCell(
            label: 'Melhor dia',
            value: _formatNumber(history.allTimeRecord),
            highlight: true,
            badge: '🏆',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCell({
    required String label,
    required String value,
    required bool highlight,
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.colors.textSecondary,
                    ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 4),
                Text(badge, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: highlight ? AppColors.primary : null,
                ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Lista de histórico filtrada
  // ---------------------------------------------------------------------------

  Widget _buildHistoryList(List<StepLog> logs) {
    final withData =
        logs.where((l) => l.id.isNotEmpty && l.steps > 0).toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    if (withData.isEmpty) {
      return OmniEmptyState(
        icon: Icons.directions_walk,
        title: 'Sem dados neste período',
      );
    }

    return Column(
      children: withData.map((log) => _buildHistoryRow(log)).toList(),
    );
  }

  Widget _buildHistoryRow(StepLog log) {
    final isHandicap = log.handicapLevel != null;
    final isRecord = log.isAllTimeRecord;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(
          color: isRecord
              ? _kHandicapColor.withValues(alpha: 0.5)
              : isHandicap
                  ? _kHandicapColor.withValues(alpha: 0.4)
                  : context.colors.border,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isRecord
                  ? _kHandicapColor.withValues(alpha: 0.15)
                  : isHandicap
                      ? _kHandicapColor.withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isRecord ? Icons.emoji_events : Icons.directions_walk,
              color: isRecord
                  ? _kHandicapColor
                  : isHandicap
                      ? _kHandicapColor
                      : AppColors.primary,
              size: 20,
            ),
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
                  '${log.distanceKm.toStringAsFixed(2)} km · ${log.caloriesBurned.toStringAsFixed(0)} kcal',
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
          if (isRecord) ...[
            const SizedBox(width: 6),
            const Text('🏆'),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Estados de erro
  // ---------------------------------------------------------------------------

  Widget _buildPermissionDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_walk,
                size: 64, color: context.colors.textMuted),
            const SizedBox(height: 16),
            Text('Permissão necessária',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
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

  Widget _buildSensorUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors_off,
                size: 64, color: context.colors.textMuted),
            const SizedBox(height: 16),
            Text('Sensor indisponível',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
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

  // ---------------------------------------------------------------------------
  // Diálogo de meta
  // ---------------------------------------------------------------------------

  void _showGoalDialog(StepProvider provider) {
    final controller =
        TextEditingController(text: provider.dailyGoal.toString());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Meta diária de passos'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Passos por dia',
            suffixText: 'passos',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val >= 100) {
                provider.setGoal(val);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

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
        if (_isToday(day) && provider.stepsToday > existing.steps) {
          result.add(StepLog(
            id: existing.id,
            userId: existing.userId,
            date: day,
            steps: provider.stepsToday,
            distanceMeters: provider.distanceTodayMeters,
            caloriesBurned: provider.caloriesToday,
            isAllTimeRecord: existing.isAllTimeRecord,
            handicapLevel: provider.selectedHandicapLevel,
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
          distanceMeters:
              _isToday(day) ? provider.distanceTodayMeters : 0,
          caloriesBurned:
              _isToday(day) ? provider.caloriesToday : 0,
          isAllTimeRecord: false,
          handicapLevel:
              _isToday(day) ? provider.selectedHandicapLevel : null,
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

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

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
