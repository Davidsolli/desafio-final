import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:omniconnect_fitness/providers/logbook_provider.dart';
import 'package:omniconnect_fitness/services/logbook_service.dart';
import 'package:omniconnect_fitness/theme/app_colors.dart';
import 'package:omniconnect_fitness/shared/utils/muscle_group_helper.dart';

/// Extensão helper para cores do tema
extension _ThemeX on BuildContext {
  ColorScheme get cs => Theme.of(this).colorScheme;
}

// ────────────────────────────────────────────────────────────────
// 1. HEATMAP DE ATIVIDADE (12 semanas estilo GitHub)
// ────────────────────────────────────────────────────────────────
class ActivityHeatmap extends StatelessWidget {
  final String? studentId;
  const ActivityHeatmap({super.key, this.studentId});

  @override
  Widget build(BuildContext context) {
    return Consumer<LogbookProvider>(
      builder: (context, provider, _) {
        final freqRes = studentId == null
            ? provider.frequencyResponse
            : provider.getStudentFrequency(studentId!);
        final dataPoints = freqRes?.dataPoints ?? [];

        // Monta mapa de semana -> count
        final Map<String, int> weekMap = {};
        for (final dp in dataPoints) {
          final key = _weekKey(dp.periodStart);
          weekMap[key] = dp.count;
        }

        final now = DateTime.now();
        final weeks = <DateTime>[];
        // 12 semanas para trás, segunda-feira de cada
        for (int i = 11; i >= 0; i--) {
          final monday = now.subtract(Duration(days: now.weekday - 1 + i * 7));
          weeks.add(DateTime(monday.year, monday.month, monday.day));
        }

        final maxCount = weekMap.values.fold(0, math.max);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.cs.outline.withOpacity(0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Atividade — Últimas 12 Semanas',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${dataPoints.where((d) => d.count > 0).length} sem. ativas',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Grid de blocos
                SizedBox(
                  height: 42,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: weeks.map((wk) {
                      final key = _weekKey(wk);
                      final count = weekMap[key] ?? 0;
                      final intensity = maxCount > 0 ? count / maxCount : 0.0;
                      final color = _heatColor(intensity, context);
                      final isCurrentWeek =
                          _weekKey(now.subtract(Duration(days: now.weekday - 1))) == key;
                      return Tooltip(
                        message: count == 0
                            ? 'Sem. ${_shortDate(wk)}: sem treinos'
                            : 'Sem. ${_shortDate(wk)}: $count treino${count > 1 ? 's' : ''}',
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                                border: isCurrentWeek
                                    ? Border.all(color: AppColors.primary, width: 1.5)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${wk.day}/${wk.month}',
                              style: const TextStyle(fontSize: 7, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),
                // Legenda
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text('Menos', style: TextStyle(fontSize: 9, color: Colors.grey)),
                    const SizedBox(width: 4),
                    ...List.generate(5, (i) {
                      return Container(
                        margin: const EdgeInsets.only(left: 3),
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _heatColor(i / 4.0, context),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                    const SizedBox(width: 4),
                    const Text('Mais', style: TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _weekKey(DateTime dt) {
    final mon = dt.subtract(Duration(days: dt.weekday - 1));
    return '${mon.year}-${mon.month.toString().padLeft(2, '0')}-${mon.day.toString().padLeft(2, '0')}';
  }

  String _shortDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';

  Color _heatColor(double intensity, BuildContext context) {
    if (intensity <= 0) {
      return Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF1E2530)
          : const Color(0xFFEBEDF0);
    }
    return Color.lerp(
      AppColors.primary.withOpacity(0.25),
      AppColors.primary,
      intensity,
    )!;
  }
}

// ────────────────────────────────────────────────────────────────
// 2. CARD DE RECORDES PESSOAIS (PRs)
// ────────────────────────────────────────────────────────────────
class PersonalRecordsCard extends StatelessWidget {
  final String? studentId;
  const PersonalRecordsCard({super.key, this.studentId});

  @override
  Widget build(BuildContext context) {
    return Consumer<LogbookProvider>(
      builder: (context, provider, _) {
        final prRes = studentId == null
            ? provider.personalRecordsResponse
            : provider.getStudentPersonalRecords(studentId!);
        final records = prRes?.records ?? [];

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.cs.outline.withOpacity(0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Recordes Pessoais',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    if (records.isNotEmpty)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${records.length} exercício${records.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '1RM estimado pela fórmula de Epley  (carga × (1 + reps/30))',
                  style: TextStyle(
                      color: context.cs.onSurface.withOpacity(0.5), fontSize: 10),
                ),
                const SizedBox(height: 12),
                if (provider.isLoading && records.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (records.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Complete treinos para ver seus recordes aqui.',
                        style: TextStyle(
                            color: context.cs.onSurface.withOpacity(0.5),
                            fontSize: 12),
                      ),
                    ),
                  )
                else
                  ...records.map((pr) => _PRRow(record: pr)).toList(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PRRow extends StatelessWidget {
  final PersonalRecord record;
  const _PRRow({required this.record});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerHighest.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Ícone grupamento
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                MuscleGroupHelper.getEmoji(record.muscleGroup),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Nome e grupamento
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.exerciseName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  record.displayName,
                  style: TextStyle(
                      color: context.cs.onSurface.withOpacity(0.5),
                      fontSize: 10),
                ),
              ],
            ),
          ),
          // Carga e 1RM
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${record.maxLoadKg.toStringAsFixed(1)} kg',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary),
              ),
              Text(
                '1RM ≈ ${record.estimated1rm.toStringAsFixed(1)} kg',
                style: const TextStyle(fontSize: 10, color: Colors.amber),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// 3. FOCO MUSCULAR — BARRAS HORIZONTAIS
// ────────────────────────────────────────────────────────────────
class MuscleFocusBars extends StatefulWidget {
  final String? studentId;
  const MuscleFocusBars({super.key, this.studentId});

  @override
  State<MuscleFocusBars> createState() => _MuscleFocusBarsState();
}

class _MuscleFocusBarsState extends State<MuscleFocusBars> {
  int _selectedDays = 30;

  @override
  Widget build(BuildContext context) {
    return Consumer<LogbookProvider>(
      builder: (context, provider, _) {
        final distRes = widget.studentId == null
            ? provider.distributionResponse
            : provider.getStudentDistribution(widget.studentId!);
        final dist = distRes?.distribution ?? [];
        final total = distRes?.totalSets ?? 0;
        final maxCount = dist.fold(0, (m, d) => math.max(m, d.count));

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.cs.outline.withOpacity(0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Foco Muscular',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const Spacer(),
                    DropdownButton<int>(
                      value: _selectedDays,
                      underline: const SizedBox(),
                      iconSize: 16,
                      style: TextStyle(
                          color: context.cs.onSurface.withOpacity(0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                      items: const [
                        DropdownMenuItem(value: 7, child: Text('Últ. 7 dias')),
                        DropdownMenuItem(value: 30, child: Text('Últ. 30 dias')),
                      ],
                      onChanged: (val) {
                        if (val == null) return;
                        setState(() => _selectedDays = val);
                        if (widget.studentId == null) {
                          provider.loadMuscleGroupDistribution(days: val);
                        } else {
                          provider.loadStudentMuscleGroupDistribution(widget.studentId!, days: val);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Total de séries: $total',
                  style: TextStyle(
                      color: context.cs.onSurface.withOpacity(0.45),
                      fontSize: 10),
                ),
                const SizedBox(height: 14),
                if (dist.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Complete treinos para ver a distribuição muscular.',
                        style: TextStyle(
                            color: context.cs.onSurface.withOpacity(0.5),
                            fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...dist.map((item) {
                    final frac = maxCount > 0 ? item.count / maxCount : 0.0;
                    final isActive = item.count > 0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 96,
                            child: Text(
                              item.displayName,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: isActive
                                    ? context.cs.onSurface
                                    : context.cs.onSurface.withOpacity(0.35),
                              ),
                            ),
                          ),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: frac,
                                minHeight: 8,
                                color: isActive
                                    ? AppColors.primary
                                    : context.cs.outline.withOpacity(0.2),
                                backgroundColor:
                                    context.cs.outline.withOpacity(0.08),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 55,
                            child: Text(
                              isActive
                                  ? '${item.count} (${item.percentage.toStringAsFixed(0)}%)'
                                  : '—',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isActive
                                    ? AppColors.primary
                                    : context.cs.onSurface.withOpacity(0.3),
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────
// 4. EVOLUÇÃO DE EXERCÍCIO — VOLUME LOAD + CARGA MÁX
// ────────────────────────────────────────────────────────────────
class ExerciseEvolutionCard extends StatefulWidget {
  final List<Map<String, String>> availableExercises;
  final String? initialExerciseId;
  final String? studentId;

  const ExerciseEvolutionCard({
    super.key,
    required this.availableExercises,
    this.initialExerciseId,
    this.studentId,
  });

  @override
  State<ExerciseEvolutionCard> createState() => _ExerciseEvolutionCardState();
}

class _ExerciseEvolutionCardState extends State<ExerciseEvolutionCard> {
  String? _selectedId;
  bool _showVolume = true; // toggle: Volume Load vs Carga Máx

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialExerciseId ??
        (widget.availableExercises.isNotEmpty
            ? widget.availableExercises.first['id']
            : null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    if (_selectedId == null) return;
    if (widget.studentId == null) {
      context.read<LogbookProvider>().loadVolumeLoad(_selectedId!, weeks: 8);
    } else {
      context.read<LogbookProvider>().loadStudentVolumeLoad(widget.studentId!, _selectedId!, weeks: 8);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LogbookProvider>(
      builder: (context, provider, _) {
        final vl = widget.studentId == null
            ? provider.volumeLoadResponse
            : provider.getStudentVolumeLoad(widget.studentId!, _selectedId ?? '');
        final points = vl?.dataPoints ?? [];
        final stats = vl?.statistics;

        final values = points
            .map((p) => _showVolume ? p.totalVolumeKg : p.maxLoadKg)
            .toList();
        final maxVal = values.fold(0.0, math.max);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.cs.outline.withOpacity(0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  runSpacing: 8,
                  children: [
                    const Text(
                      'Evolução de Exercício',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    if (widget.availableExercises.isNotEmpty)
                      DropdownButton<String>(
                        value: _selectedId,
                        underline: const SizedBox(),
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 11),
                        items: widget.availableExercises
                            .map((ex) => DropdownMenuItem(
                                  value: ex['id'],
                                  child: Text(ex['name']!),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() => _selectedId = val);
                          if (widget.studentId == null) {
                            provider.loadVolumeLoad(val, weeks: 8);
                          } else {
                            provider.loadStudentVolumeLoad(widget.studentId!, val, weeks: 8);
                          }
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Toggle Volume Load / Carga Máx
                Row(
                  children: [
                    _ToggleChip(
                      label: 'Volume Load',
                      active: _showVolume,
                      onTap: () => setState(() => _showVolume = true),
                    ),
                    const SizedBox(width: 8),
                    _ToggleChip(
                      label: 'Carga Máx',
                      active: !_showVolume,
                      onTap: () => setState(() => _showVolume = false),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Stats Pills
                if (stats != null && points.isNotEmpty) ...[
                  Row(
                    children: [
                      _StatPill(
                        label: _showVolume ? 'Média/Sem' : 'Média',
                        value: _showVolume
                            ? '${stats.avgVolumeKg.toStringAsFixed(0)} kg'
                            : '${stats.avgVolumeKg.toStringAsFixed(1)} kg',
                      ),
                      const SizedBox(width: 8),
                      _StatPill(
                        label: _showVolume ? 'Pico' : 'Pico',
                        value: _showVolume
                            ? '${stats.maxVolumeKg.toStringAsFixed(0)} kg'
                            : '${stats.maxVolumeKg.toStringAsFixed(1)} kg',
                      ),
                      const SizedBox(width: 8),
                      _StatPill(
                        label: 'Tendência',
                        value: _trendLabel(stats.trend),
                        valueColor: _trendColor(stats.trend),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],

                // Gráfico de barras simples
                if (provider.isLoading && points.isEmpty)
                  const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (points.isEmpty)
                  SizedBox(
                    height: 120,
                    child: Center(
                      child: Text(
                        'Nenhum dado para este exercício nas últimas 8 semanas.',
                        style: TextStyle(
                            color: context.cs.onSurface.withOpacity(0.4),
                            fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 130,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(points.length, (i) {
                        final val = values[i];
                        final frac = maxVal > 0 ? val / maxVal : 0.0;
                        final isLast = i == points.length - 1;
                        final wk = points[i].weekStart;
                        return Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (isLast && val > 0)
                                  Text(
                                    '${val.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                        fontSize: 8,
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold),
                                  ),
                                AnimatedContainer(
                                  duration: Duration(
                                      milliseconds: 300 + i * 40),
                                  height: math.max(frac * 100, val > 0 ? 4 : 2),
                                  decoration: BoxDecoration(
                                    color: isLast
                                        ? AppColors.primary
                                        : AppColors.primary.withOpacity(0.45),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${wk.day}/${wk.month}',
                                  style: const TextStyle(
                                      fontSize: 7, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _trendLabel(String t) {
    switch (t) {
      case 'increasing': return '📈 Subindo';
      case 'decreasing': return '📉 Caindo';
      default: return '➡️ Estável';
    }
  }

  Color _trendColor(String t) {
    switch (t) {
      case 'increasing': return Colors.green;
      case 'decreasing': return Colors.red;
      default: return Colors.orange;
    }
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _ToggleChip(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? AppColors.primary
              : context.cs.outline.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: active ? Colors.white : context.cs.onSurface.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatPill({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: context.cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 9,
                    color: context.cs.onSurface.withOpacity(0.5))),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────
// 5. HISTÓRICO DE TREINOS CONCLUÍDOS
// ────────────────────────────────────────────────────────────────
class WorkoutHistorySection extends StatefulWidget {
  final String? studentId;
  const WorkoutHistorySection({super.key, this.studentId});

  @override
  State<WorkoutHistorySection> createState() => _WorkoutHistorySectionState();
}

class _WorkoutHistorySectionState extends State<WorkoutHistorySection> {
  bool _showAll = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<LogbookProvider>(
      builder: (context, provider, _) {
        final sessions = widget.studentId == null
            ? provider.sessions
            : provider.getStudentSessions(widget.studentId!);
        if (sessions.isEmpty) {
          return const SizedBox.shrink();
        }

        final displaySessions = _showAll ? sessions : sessions.take(3).toList();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.cs.outline.withOpacity(0.15)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.history, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Histórico de Treinos',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    Text(
                      '${sessions.length} concluído(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.cs.onSurface.withOpacity(0.5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displaySessions.length,
                  separatorBuilder: (context, index) => Divider(
                    color: context.cs.outline.withOpacity(0.1),
                    height: 24,
                  ),
                  itemBuilder: (context, index) {
                    final session = displaySessions[index];
                    return _buildSessionItem(context, session);
                  },
                ),
                if (sessions.length > 3) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _showAll = !_showAll;
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      child: Text(
                        _showAll ? 'Mostrar menos' : 'Ver todo o histórico',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSessionItem(BuildContext context, LogbookResponse session) {
    return InkWell(
      onTap: () => _showSessionDetailsDialog(context, session),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    session.workoutName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  session.formattedDate,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.cs.onSurface.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildStatBadge(Icons.timer_outlined, '${session.durationMinutes} min', context),
                const SizedBox(width: 8),
                _buildStatBadge(Icons.local_fire_department_outlined, '${session.caloriesBurned.toStringAsFixed(0)} kcal', context),
                const SizedBox(width: 8),
                _buildIntensityBadge(session.intensity, context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.cs.onSurface.withOpacity(0.6)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: context.cs.onSurface.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityBadge(String intensity, BuildContext context) {
    Color color;
    switch (intensity.toLowerCase()) {
      case 'leve':
        color = const Color(0xFF2ecc71);
        break;
      case 'moderada':
        color = const Color(0xFFf39c12);
        break;
      case 'intensa':
        color = const Color(0xFFe74c3c);
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        intensity.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  void _showSessionDetailsDialog(BuildContext context, LogbookResponse session) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        session.workoutName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                Text(
                  session.formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.cs.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildModalStatTile('Tempo', '${session.durationMinutes}m', Icons.timer_outlined, context),
                    _buildModalStatTile('Calorias', '${session.caloriesBurned.toStringAsFixed(0)} kcal', Icons.local_fire_department_outlined, context),
                    _buildModalStatTile('Esforço', session.intensity, Icons.fitness_center_outlined, context),
                  ],
                ),
                if (session.notes != null && session.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.cs.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.cs.outline.withOpacity(0.1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Anotações:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.notes!,
                          style: TextStyle(fontSize: 12, color: context.cs.onSurface.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Exercícios Realizados',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: session.exercises.length,
                      separatorBuilder: (context, index) => Divider(color: context.cs.outline.withOpacity(0.08)),
                      itemBuilder: (context, index) {
                        final ex = session.exercises[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ex.exerciseName,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    '${ex.sets} séries × ${ex.reps} reps',
                                    style: TextStyle(fontSize: 11, color: context.cs.onSurface.withOpacity(0.6)),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${ex.weight} kg',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary),
                                  ),
                                ],
                              ),
                              if (ex.notes != null && ex.notes!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Obs: ${ex.notes}',
                                  style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: context.cs.onSurface.withOpacity(0.5)),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalStatTile(String label, String value, IconData icon, BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: context.cs.onSurface.withOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}
