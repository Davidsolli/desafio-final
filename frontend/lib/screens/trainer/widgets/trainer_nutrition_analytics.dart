/// Widgets analíticos de nutrição para a visão do Personal Trainer.
///
/// Contém dois componentes de diagnóstico:
///   - [WeightCalorieCorrelationChart]: Correlação Peso × Calorias (linha + barras)
///   - [MealDistributionGauge]: Distribuição calórica por refeição (barras horizontais)
library trainer_nutrition_analytics;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/diet_models.dart';
import '../../../services/nutrition_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';

import 'package:flutter/gestures.dart';
import '../../student/widgets/nutrition_dashboard_widgets.dart';

// ---------------------------------------------------------------------------
// WeightCalorieCorrelationChart — Correlação Peso vs. Calorias
// ---------------------------------------------------------------------------


/// Gráfico interativo que sobrepõe:
///   - Linha contínua: peso do aluno ao longo do tempo (referência estática)
///   - Barras translúcidas: média calórica diária real
///
/// Permite selecionar o período via chips (30 / 60 / 90 dias).
class WeightCalorieCorrelationChart extends StatefulWidget {
  /// ID do aluno (usado para buscar os dados de analytics).
  final String studentId;

  /// Serviço de nutrição para buscar dados via API.
  final NutritionService nutritionService;

  /// Peso atual do aluno em kg (referência estática).
  final double? weightKg;

  const WeightCalorieCorrelationChart({
    super.key,
    required this.studentId,
    required this.nutritionService,
    this.weightKg,
  });

  @override
  State<WeightCalorieCorrelationChart> createState() =>
      _WeightCalorieCorrelationChartState();
}

class _WeightCalorieCorrelationChartState
    extends State<WeightCalorieCorrelationChart> {
  int _selectedDays = 30;
  NutritionAnalyticsSummary? _analytics;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final end = DateTime.now();
      final start = end.subtract(Duration(days: _selectedDays - 1));
      final data = await widget.nutritionService.getAnalyticsSummary(
        startDate: start,
        endDate: end,
        studentId: widget.studentId,
      );
      if (mounted) {
        setState(() {
          _analytics = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erro ao carregar histórico: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          // Cabeçalho
          Row(
            children: [
              const Icon(Icons.auto_graph, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Correlação Peso × Calorias',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Barras = consumo calórico diário • Linha = peso de referência',
            style: TextStyle(fontSize: 10, color: context.colors.textMuted),
          ),
          const SizedBox(height: 10),
          // Seletor de período
          Wrap(
            spacing: 6,
            children: [30, 60, 90].map((days) {
              final selected = _selectedDays == days;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDays = days);
                  _loadAnalytics();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.primary : context.colors.border,
                    ),
                  ),
                  child: Text(
                    '$days dias',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: selected ? Colors.white : context.colors.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          // Gráfico
          if (_loading)
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SizedBox(
              height: 160,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, color: context.colors.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      'Não foi possível carregar os dados',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
                      ),
                    ),
                    TextButton(
                      onPressed: _loadAnalytics,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          else
            _buildChart(context),
        ],
      ),
    );
  }

  Widget _buildChart(BuildContext context) {
    final days = _analytics?.days ?? [];
    if (days.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant_menu_outlined, size: 36, color: context.colors.textMuted),
              const SizedBox(height: 8),
              Text(
                'Sem registros alimentares no período',
                style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    // Agrega em grupos mensais para visualização limpa
    final monthlyData = _buildMonthlyAggregates(days);
    final maxKcal = monthlyData.isEmpty
        ? 3000.0
        : monthlyData.map((d) => d.avgKcal).reduce(math.max) * 1.2;
    final weightRef = widget.weightKg ?? days.firstWhere(
      (d) => d.weightKg != null,
      orElse: () => NutritionAnalyticsDay(
        date: DateTime.now(),
        totalKcal: 0,
        totalProtein: 0,
        totalCarbs: 0,
        totalFats: 0,
        waterMl: 0,
        isFullyLogged: false,
        mealDistribution: [],
      ),
    ).weightKg;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: math.max(maxKcal, 3000),
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                if (groupIndex >= monthlyData.length) return null;
                final d = monthlyData[groupIndex];
                return BarTooltipItem(
                  '${d.label}\n${d.avgKcal.toStringAsFixed(0)} kcal/dia\n${d.loggedDays}/${d.totalDays} dias',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= monthlyData.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    monthlyData[idx].label,
                    style: TextStyle(fontSize: 9, color: context.colors.textMuted),
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
            horizontalInterval: math.max(maxKcal, 3000) / 4,
            getDrawingHorizontalLine: (v) => FlLine(
              color: context.colors.border.withOpacity(0.4),
              strokeWidth: 0.8,
            ),
          ),
          borderData: FlBorderData(show: false),
          // Linha de referência de peso (convertido para escala kcal via proporção)
          extraLinesData: weightRef != null
              ? ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: weightRef * 25.0, // proporção visual aproximada
                      color: Colors.red.withOpacity(0.5),
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        padding: const EdgeInsets.only(right: 4, bottom: 2),
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.red[600],
                          fontWeight: FontWeight.bold,
                        ),
                        labelResolver: (_) => '${weightRef.toStringAsFixed(1)} kg',
                      ),
                    ),
                  ],
                )
              : null,
          barGroups: List.generate(monthlyData.length, (idx) {
            final d = monthlyData[idx];
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: d.avgKcal,
                  color: AppColors.primary.withOpacity(0.7),
                  width: 28,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  List<_MonthAggregate> _buildMonthlyAggregates(List<NutritionAnalyticsDay> days) {
    final Map<String, _MonthAggregate> map = {};
    for (final day in days) {
      final key =
          '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}';
      final label = _monthLabel(day.date.month, day.date.year);
      if (!map.containsKey(key)) {
        map[key] = _MonthAggregate(label: label);
      }
      map[key]!.totalDays++;
      if (day.isFullyLogged) {
        map[key]!.totalKcal += day.totalKcal;
        map[key]!.loggedDays++;
      }
    }
    final result = map.values.toList();
    for (final m in result) {
      m.avgKcal = m.loggedDays > 0 ? m.totalKcal / m.loggedDays : 0;
    }
    return result;
  }

  String _monthLabel(int month, int year) {
    const months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return months[(month - 1).clamp(0, 11)];
  }
}

class _MonthAggregate {
  final String label;
  int totalDays = 0;
  int loggedDays = 0;
  double totalKcal = 0;
  double avgKcal = 0;

  _MonthAggregate({required this.label});
}

// ---------------------------------------------------------------------------
// MealDistributionGauge — Distribuição Calórica por Refeição
// ---------------------------------------------------------------------------

/// Barras horizontais empilhadas mostrando a concentração calórica por refeição.
/// Útil para detectar padrões como compulsão noturna ou refeições muito pesadas.
class MealDistributionGauge extends StatelessWidget {
  /// Distribuição de calorias por refeição do aluno.
  final List<MealKcalData> mealDistribution;

  /// Total calórico do dia para calcular percentuais.
  final double totalKcal;

  const MealDistributionGauge({
    super.key,
    required this.mealDistribution,
    required this.totalKcal,
  });

  static const List<Color> _mealColors = [
    Color(0xFF3dba5e),
    Color(0xFF4db8ff),
    Color(0xFFffc84d),
    Color(0xFFff6b6b),
    Color(0xFFa78bfa),
    Color(0xFFfb923c),
    Color(0xFF34d399),
  ];

  @override
  Widget build(BuildContext context) {
    if (mealDistribution.isEmpty) {
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
                const Icon(Icons.donut_small, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'Distribuição por Refeição',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: context.colors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Nenhum dado de refeição disponível para hoje.',
                style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
    }

    // Ordena por maior concentração calórica
    final sorted = List<MealKcalData>.from(mealDistribution)
      ..sort((a, b) => b.kcal.compareTo(a.kcal));

    final effectiveTotal = totalKcal > 0
        ? totalKcal
        : sorted.fold(0.0, (sum, m) => sum + m.kcal);

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
              const Icon(Icons.donut_small, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Distribuição por Refeição',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: context.colors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${effectiveTotal.toStringAsFixed(0)} kcal',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Refeições ordenadas por maior aporte calórico',
            style: TextStyle(fontSize: 10, color: context.colors.textMuted),
          ),
          const SizedBox(height: 14),
          // Barra total empilhada
          if (sorted.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: sorted.asMap().entries.map((e) {
                  final pct = effectiveTotal > 0 ? e.value.kcal / effectiveTotal : 0.0;
                  return Flexible(
                    flex: math.max((pct * 1000).toInt(), 1),
                    child: Container(
                      height: 12,
                      color: _mealColors[e.key % _mealColors.length],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],
          // Lista de refeições com barras individuais
          ...sorted.asMap().entries.map((e) {
            final idx = e.key;
            final meal = e.value;
            final pct = effectiveTotal > 0
                ? (meal.kcal / effectiveTotal).clamp(0.0, 1.0)
                : 0.0;
            final color = _mealColors[idx % _mealColors.length];

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          meal.mealName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: context.colors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${meal.kcal.toStringAsFixed(0)} kcal',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${(pct * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: color.withOpacity(0.12),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// TrainerNutritionAnalyticsTab — Aba Completa de Estatísticas (Personal)
// ---------------------------------------------------------------------------

/// Widget de alto nível que agrega os gráficos analíticos em uma aba
/// scrollável dentro do painel do Personal Trainer.
class TrainerNutritionAnalyticsTab extends StatefulWidget {
  final String studentId;
  final NutritionService nutritionService;
  final double? studentWeightKg;
  final Diet? activeDiet;

  const TrainerNutritionAnalyticsTab({
    super.key,
    required this.studentId,
    required this.nutritionService,
    this.studentWeightKg,
    this.activeDiet,
  });

  @override
  State<TrainerNutritionAnalyticsTab> createState() =>
      _TrainerNutritionAnalyticsTabState();
}

class _TrainerNutritionAnalyticsTabState
    extends State<TrainerNutritionAnalyticsTab> {
  NutritionAnalyticsSummary? _analytics;
  bool _loading = false;
  final PageController _chartPageController = PageController();
  int _currentChartPage = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  @override
  void dispose() {
    _chartPageController.dispose();
    super.dispose();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _loading = true);
    try {
      final today = DateTime.now();
      final start = today.subtract(const Duration(days: 27));
      final data = await widget.nutritionService.getAnalyticsSummary(
        startDate: start,
        endDate: today,
        studentId: widget.studentId,
      );
      if (mounted) {
        setState(() {
          _analytics = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = {
      'calories': widget.activeDiet?.totalKcal ?? 2000.0,
      'protein': widget.activeDiet?.totalProtein ?? 120.0,
      'carbs': widget.activeDiet?.totalCarbs ?? 250.0,
      'fat': widget.activeDiet?.totalFats ?? 55.0,
    };

    final now = DateTime.now();
    NutritionAnalyticsDay? todayDay;
    if (_analytics != null && _analytics!.days.isNotEmpty) {
      try {
        todayDay = _analytics!.days.firstWhere(
          (d) => d.date.year == now.year && d.date.month == now.month && d.date.day == now.day,
        );
      } catch (_) {
        todayDay = _analytics!.days.first;
      }
    }

    final consumedKcal = todayDay?.totalKcal ?? 0.0;
    final consumedProtein = todayDay?.totalProtein ?? 0.0;
    final consumedCarbs = todayDay?.totalCarbs ?? 0.0;
    final consumedFat = todayDay?.totalFats ?? 0.0;

    // Constrói as listas para aderência semanal (últimos 7 dias)
    final last7DaysCalories = List.filled(7, 0.0);
    final last7DaysLogged = List.filled(7, false);

    if (_analytics != null && _analytics!.days.isNotEmpty) {
      for (int i = 0; i < 7; i++) {
        final d = now.subtract(Duration(days: 6 - i));
        try {
          final dayData = _analytics!.days.firstWhere(
            (x) => x.date.year == d.year && x.date.month == d.month && x.date.day == d.day,
          );
          last7DaysCalories[i] = dayData.totalKcal;
          last7DaysLogged[i] = dayData.isFullyLogged;
        } catch (_) {}
      }
    }

    // Constrói as listas para heatmap (últimos 28 dias)
    final last28DaysCalories = List.filled(28, 0.0);
    final last28DaysLogged = List.filled(28, false);

    if (_analytics != null && _analytics!.days.isNotEmpty) {
      for (int i = 0; i < 28; i++) {
        final d = now.subtract(Duration(days: 27 - i));
        try {
          final dayData = _analytics!.days.firstWhere(
            (x) => x.date.year == d.year && x.date.month == d.month && x.date.day == d.day,
          );
          last28DaysCalories[i] = dayData.totalKcal;
          last28DaysLogged[i] = dayData.isFullyLogged;
        } catch (_) {}
      }
    }

    final charts = <Widget>[
      // Página 1: Roda de Macronutrientes
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: MacroNutrientWheel(
          consumedKcal: consumedKcal,
          targetKcal: targets['calories']!,
          consumedProtein: consumedProtein,
          targetProtein: targets['protein']!,
          consumedCarbs: consumedCarbs,
          targetCarbs: targets['carbs']!,
          consumedFat: consumedFat,
          targetFat: targets['fat']!,
        ),
      ),
      // Página 2: Gráfico de Aderência Semanal
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: WeeklyAdherenceChart(
          last7DaysCalories: last7DaysCalories,
          last7DaysLogged: last7DaysLogged,
          targetKcal: targets['calories']!,
          referenceDate: now,
        ),
      ),
      // Página 3: Heatmap de Consistência (28 dias)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: NutritionStreakHeatmap(
          last28DaysCalories: last28DaysCalories,
          last28DaysLogged: last28DaysLogged,
          targetKcal: targets['calories']!,
          referenceDate: now,
        ),
      ),
    ];

    return RefreshIndicator(
      onRefresh: _loadAnalytics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título da aba
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.analytics_outlined,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Análise Avançada',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      'Histórico e padrões alimentares do aluno',
                      style: TextStyle(
                          fontSize: 11, color: context.colors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Carrossel Premium de Gráficos
            if (_loading)
              Container(
                height: 260,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: const Center(child: CircularProgressIndicator()),
              )
            else
              Column(
                children: [
                  SizedBox(
                    height: 260,
                    child: PageView(
                      controller: _chartPageController,
                      scrollBehavior: ScrollConfiguration.of(context).copyWith(
                        dragDevices: {
                          PointerDeviceKind.touch,
                          PointerDeviceKind.mouse,
                          PointerDeviceKind.trackpad,
                        },
                      ),
                      onPageChanged: (page) => setState(() => _currentChartPage = page),
                      children: charts,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Indicadores de página (dots)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(charts.length, (idx) {
                      return GestureDetector(
                        onTap: () {
                          _chartPageController.animateToPage(
                            idx,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentChartPage == idx ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentChartPage == idx
                                ? AppColors.primary
                                : context.colors.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Distribuição por refeição (dados de hoje)
            if (_loading)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: const Center(child: CircularProgressIndicator()),
              )
            else
              MealDistributionGauge(
                mealDistribution: todayDay?.mealDistribution ?? [],
                totalKcal: todayDay?.totalKcal ?? 0,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
