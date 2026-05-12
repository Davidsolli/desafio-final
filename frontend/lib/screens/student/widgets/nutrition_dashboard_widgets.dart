/// Widgets de visualização avançada de nutrição para o Aluno.
///
/// Contém três componentes visuais isolados e performáticos:
///   - [MacroNutrientWheel]: Roda dinâmica de macronutrientes (PieChart)
///   - [WeeklyAdherenceChart]: Gráfico de barras de consistência semanal
///   - [NutritionStreakHeatmap]: Heatmap estilo GitHub dos últimos 28 dias
library nutrition_dashboard_widgets;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';

// ---------------------------------------------------------------------------
// MacroNutrientWheel — Roda Dinâmica de Macronutrientes
// ---------------------------------------------------------------------------

/// Renderiza um gráfico circular (PieChart) com a distribuição de macros do dia
/// em relação às metas. No centro exibe o déficit/superávit calórico.
class MacroNutrientWheel extends StatefulWidget {
  /// Calorias consumidas no dia.
  final double consumedKcal;

  /// Meta calórica diária.
  final double targetKcal;

  /// Proteína consumida (g).
  final double consumedProtein;

  /// Meta de proteína (g).
  final double targetProtein;

  /// Carboidratos consumidos (g).
  final double consumedCarbs;

  /// Meta de carboidratos (g).
  final double targetCarbs;

  /// Gordura consumida (g).
  final double consumedFat;

  /// Meta de gordura (g).
  final double targetFat;

  const MacroNutrientWheel({
    super.key,
    required this.consumedKcal,
    required this.targetKcal,
    required this.consumedProtein,
    required this.targetProtein,
    required this.consumedCarbs,
    required this.targetCarbs,
    required this.consumedFat,
    required this.targetFat,
  });

  @override
  State<MacroNutrientWheel> createState() => _MacroNutrientWheelState();
}

class _MacroNutrientWheelState extends State<MacroNutrientWheel>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _radiusAnimation;

  static const Color _proteinColor = Color(0xFF3dba5e);
  static const Color _carbsColor = Color(0xFF4db8ff);
  static const Color _fatColor = Color(0xFFffc84d);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _radiusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<PieChartSectionData> _buildSections() {
    final sections = <PieChartSectionData>[];

    // Calcula progresso de cada macro (0.0 a 1.0)
    double pRatio = widget.targetProtein > 0
        ? (widget.consumedProtein / widget.targetProtein).clamp(0.0, 1.0)
        : 0.0;
    double cRatio = widget.targetCarbs > 0
        ? (widget.consumedCarbs / widget.targetCarbs).clamp(0.0, 1.0)
        : 0.0;
    double fRatio = widget.targetFat > 0
        ? (widget.consumedFat / widget.targetFat).clamp(0.0, 1.0)
        : 0.0;

    // Valor mínimo para visualização mesmo quando zero
    const double minVal = 0.5;

    sections.addAll([
      PieChartSectionData(
        value: math.max(pRatio * 120, minVal),
        color: _proteinColor,
        radius: 22 * _radiusAnimation.value,
        showTitle: false,
      ),
      PieChartSectionData(
        value: math.max((1 - pRatio) * 120, minVal),
        color: _proteinColor.withOpacity(0.12),
        radius: 22 * _radiusAnimation.value,
        showTitle: false,
      ),
      PieChartSectionData(
        value: math.max(cRatio * 120, minVal),
        color: _carbsColor,
        radius: 16 * _radiusAnimation.value,
        showTitle: false,
      ),
      PieChartSectionData(
        value: math.max((1 - cRatio) * 120, minVal),
        color: _carbsColor.withOpacity(0.12),
        radius: 16 * _radiusAnimation.value,
        showTitle: false,
      ),
      PieChartSectionData(
        value: math.max(fRatio * 120, minVal),
        color: _fatColor,
        radius: 11 * _radiusAnimation.value,
        showTitle: false,
      ),
      PieChartSectionData(
        value: math.max((1 - fRatio) * 120, minVal),
        color: _fatColor.withOpacity(0.12),
        radius: 11 * _radiusAnimation.value,
        showTitle: false,
      ),
    ]);

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.consumedKcal - widget.targetKcal;
    final isOver = balance > 0;
    final balanceColor = isOver ? Colors.red[600]! : const Color(0xFF059669);
    final balanceLabel = isOver
        ? '+${balance.toStringAsFixed(0)} kcal'
        : '${balance.toStringAsFixed(0)} kcal';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pie_chart_outline, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Roda de Macronutrientes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Gráfico circular concêntrico
              SizedBox(
                width: 120,
                height: 120,
                child: AnimatedBuilder(
                  animation: _radiusAnimation,
                  builder: (_, __) {
                    return PieChart(
                      PieChartData(
                        sections: _buildSections(),
                        centerSpaceRadius: 34,
                        sectionsSpace: 2,
                        startDegreeOffset: -90,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              // Centro: balanço calórico + legenda
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Balanço calórico
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: balanceColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: balanceColor.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isOver ? 'Superávit' : 'Déficit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: balanceColor,
                            ),
                          ),
                          Text(
                            balanceLabel,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: balanceColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Legenda dos macros
                    _MacroLegendRow(
                      color: _proteinColor,
                      label: 'Proteína',
                      consumed: widget.consumedProtein,
                      target: widget.targetProtein,
                      unit: 'g',
                    ),
                    const SizedBox(height: 6),
                    _MacroLegendRow(
                      color: _carbsColor,
                      label: 'Carbs',
                      consumed: widget.consumedCarbs,
                      target: widget.targetCarbs,
                      unit: 'g',
                    ),
                    const SizedBox(height: 6),
                    _MacroLegendRow(
                      color: _fatColor,
                      label: 'Gordura',
                      consumed: widget.consumedFat,
                      target: widget.targetFat,
                      unit: 'g',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MacroLegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final double consumed;
  final double target;
  final String unit;

  const _MacroLegendRow({
    required this.color,
    required this.label,
    required this.consumed,
    required this.target,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 11, color: context.colors.textSecondary),
          ),
        ),
        Text(
          '${consumed.toStringAsFixed(0)}/${target.toStringAsFixed(0)}$unit',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: context.colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// WeeklyAdherenceChart — Gráfico de Consistência Semanal
// ---------------------------------------------------------------------------

/// Renderiza um gráfico de barras dos últimos 7 dias com faixa de aderência.
/// Barras verdes = dentro da meta (±100 kcal); amarelas = fora.
class WeeklyAdherenceChart extends StatelessWidget {
  /// Calorias consumidas nos últimos 7 dias (índice 0 = mais antigo).
  final List<double> last7DaysCalories;

  /// Indicadores de log nos últimos 7 dias.
  final List<bool> last7DaysLogged;

  /// Meta calórica diária.
  final double targetKcal;

  /// Data de referência (normalmente hoje).
  final DateTime referenceDate;

  const WeeklyAdherenceChart({
    super.key,
    required this.last7DaysCalories,
    required this.last7DaysLogged,
    required this.targetKcal,
    required this.referenceDate,
  });

  static const double _adherenceMargin = 100.0; // ±100 kcal

  String _weekdayLabel(int daysAgo) {
    final d = referenceDate.subtract(Duration(days: 6 - daysAgo));
    const labels = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    return labels[d.weekday % 7];
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = ([...last7DaysCalories, targetKcal + _adherenceMargin + 300]).reduce(math.max);
    final normalizedMax = maxVal == 0 ? 2500.0 : maxVal * 1.15;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Aderência Semanal',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: context.colors.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '±100 kcal da meta',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: normalizedMax,
                minY: 0,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipPadding: const EdgeInsets.all(6),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      if (!last7DaysLogged[groupIndex]) return null;
                      return BarTooltipItem(
                        '${last7DaysCalories[groupIndex].toStringAsFixed(0)} kcal',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 20,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= 7) return const SizedBox.shrink();
                        return Text(
                          _weekdayLabel(idx),
                          style: TextStyle(
                            fontSize: 10,
                            color: context.colors.textMuted,
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: normalizedMax / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: context.colors.border.withOpacity(0.5),
                    strokeWidth: 0.8,
                  ),
                ),
                borderData: FlBorderData(show: false),
                // Faixa de aderência sombreada (targetKcal ± 100)
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: targetKcal + _adherenceMargin,
                      color: const Color(0xFF059669).withOpacity(0.3),
                      strokeWidth: 1,
                      dashArray: [4, 3],
                      label: HorizontalLineLabel(
                        show: false,
                      ),
                    ),
                    HorizontalLine(
                      y: math.max(targetKcal - _adherenceMargin, 0),
                      color: const Color(0xFF059669).withOpacity(0.3),
                      strokeWidth: 1,
                      dashArray: [4, 3],
                    ),
                    HorizontalLine(
                      y: targetKcal,
                      color: AppColors.primary.withOpacity(0.4),
                      strokeWidth: 1.5,
                    ),
                  ],
                ),
                barGroups: List.generate(7, (idx) {
                  final kcal = last7DaysCalories[idx];
                  final isLogged = last7DaysLogged[idx];

                  Color barColor;
                  if (!isLogged) {
                    barColor = context.colors.surfaceLight;
                  } else if ((kcal - targetKcal).abs() <= _adherenceMargin) {
                    barColor = const Color(0xFF059669); // dentro da zona
                  } else {
                    barColor = Colors.amber[700]!; // fora da zona
                  }

                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: isLogged ? math.max(kcal, 1) : 0,
                        color: barColor,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
              swapAnimationDuration: const Duration(milliseconds: 600),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NutritionStreakHeatmap — Heatmap de Frequência de Registro (GitHub-style)
// ---------------------------------------------------------------------------

/// Grid de 4 linhas × 7 colunas representando os últimos 28 dias de registro.
/// A intensidade da cor indica o nível de adesão calórica (estilo GitHub commits).
class NutritionStreakHeatmap extends StatelessWidget {
  /// Calorias consumidas por dia (lista de 28 dias — índice 0 = mais antigo).
  final List<double> last28DaysCalories;

  /// Flags de registro por dia (lista de 28 dias).
  final List<bool> last28DaysLogged;

  /// Meta calórica diária (usada para calcular intensidade).
  final double targetKcal;

  /// Data de referência (normalmente hoje).
  final DateTime referenceDate;

  const NutritionStreakHeatmap({
    super.key,
    required this.last28DaysCalories,
    required this.last28DaysLogged,
    required this.targetKcal,
    required this.referenceDate,
  });

  Color _cellColor(BuildContext context, int index) {
    if (!last28DaysLogged[index]) {
      return context.colors.surfaceLight;
    }
    final kcal = last28DaysCalories[index];
    if (targetKcal <= 0) return const Color(0xFF0e4429);
    final ratio = kcal / targetKcal;
    if (ratio >= 0.9 && ratio <= 1.15) return const Color(0xFF26a641); // perfeito
    if (ratio >= 0.7) return const Color(0xFF39d353); // bom
    if (ratio >= 0.4) return const Color(0xFF0e4429); // parcial
    return const Color(0xFF003d1a); // muito baixo (registrou mas pouquíssimo)
  }

  @override
  Widget build(BuildContext context) {
    const weeks = 4;
    const daysPerWeek = 7;
    final days = weeks * daysPerWeek;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grid_on_rounded, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Calendário de Consistência (28 dias)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Verde = dentro da meta calórica',
            style: TextStyle(fontSize: 10, color: context.colors.textMuted),
          ),
          const SizedBox(height: 12),
          // Cabeçalho com dias da semana
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
                .map((d) => SizedBox(
                      width: 28,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 9, color: context.colors.textMuted),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 4),
          // Grid 4 × 7
          Column(
            children: List.generate(weeks, (week) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(daysPerWeek, (dayOfWeek) {
                    final index = week * daysPerWeek + dayOfWeek;
                    if (index >= days) return const SizedBox(width: 28, height: 28);
                    // Garante que não ultrapassa os dados disponíveis
                    final safeIndex = index.clamp(0, last28DaysCalories.length - 1);
                    final cellDate = referenceDate.subtract(Duration(days: days - 1 - index));
                    final isToday = cellDate.year == referenceDate.year &&
                        cellDate.month == referenceDate.month &&
                        cellDate.day == referenceDate.day;

                    return Tooltip(
                      message: last28DaysLogged[safeIndex]
                          ? '${cellDate.day}/${cellDate.month}: ${last28DaysCalories[safeIndex].toStringAsFixed(0)} kcal'
                          : '${cellDate.day}/${cellDate.month}: Sem registro',
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: _cellColor(context, safeIndex),
                          borderRadius: BorderRadius.circular(4),
                          border: isToday
                              ? Border.all(color: AppColors.primary, width: 1.5)
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Legenda de cores
          Row(
            children: [
              Text(
                'Menos',
                style: TextStyle(fontSize: 9, color: context.colors.textMuted),
              ),
              const SizedBox(width: 4),
              ...[
                context.colors.surfaceLight,
                const Color(0xFF003d1a),
                const Color(0xFF0e4429),
                const Color(0xFF39d353),
                const Color(0xFF26a641),
              ].map((c) => Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )),
              Text(
                'Mais',
                style: TextStyle(fontSize: 9, color: context.colors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
