import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/nutrition_provider.dart';
import '../../models/diet_models.dart';
import 'widgets/food_search_modal.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<NutritionProvider>().loadTodayData().catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao carregar dados: $e')),
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.background,
          elevation: 0,
          title: Text(
            'Nutrição',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: context.colors.textPrimary,
                ),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: context.colors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(icon: Icon(Icons.menu_book), text: 'Diário Alimentar'),
              Tab(icon: Icon(Icons.assignment), text: 'Plano Alimentar'),
            ],
          ),
        ),
        body: Consumer<NutritionProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && provider.currentLogbook == null && provider.activeDiet == null) {
              return const Center(child: CircularProgressIndicator());
            }

            return TabBarView(
              children: [
                _buildLogbookTab(provider),
                _buildDietTab(provider),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Aba 1: Diário Alimentar (Logbook)
  // ---------------------------------------------------------------------------

  Widget _buildLogbookTab(NutritionProvider provider) {
    final logbook = provider.currentLogbook;
    final targets = provider.dailyTargets;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => provider.changeDate(provider.currentDate.subtract(const Duration(days: 1))),
              ),
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: provider.currentDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                    locale: const Locale('pt', 'BR'),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.light(
                            primary: AppColors.primary,
                            onPrimary: Colors.white,
                            surface: context.colors.surface,
                            onSurface: context.colors.textPrimary,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (date != null) {
                    provider.changeDate(date);
                  }
                },
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(provider.currentDate),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () {
                  if (provider.currentDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))) {
                     provider.changeDate(provider.currentDate.add(const Duration(days: 1)));
                  } else {
                     provider.changeDate(DateTime.now());
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWeeklyConsistencyGrid(provider),
          const SizedBox(height: 12),
          _buildCalorieCard(
            logbook?.totalKcal ?? 0.0,
            targets['calories'] ?? 2000.0,
            logbook?.totalProtein ?? 0.0,
            logbook?.totalCarbs ?? 0.0,
            logbook?.totalFats ?? 0.0,
          ),
          const SizedBox(height: 16),
          _buildAICoachCard(provider),
          const SizedBox(height: 4),
          _buildWaterTrackerCard(provider),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Refeições do Dia',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
                onPressed: () => _showAddFoodFlow(context, provider),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (logbook == null || logbook.entries.isEmpty)
            _buildEmptyState('Nenhum alimento registrado hoje.\nClique no + para adicionar.')
          else
            ...provider.entriesByMeal.entries.map((entry) {
              return _buildMealGroup(entry.key, entry.value);
            }).toList(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Componentes de Nutrição Avançada (Consistência, IA e Água)
  // ---------------------------------------------------------------------------

  Widget _buildWeeklyConsistencyGrid(NutritionProvider provider) {
    final now = provider.currentDate;
    final calorieTarget = provider.dailyTargets['calories'] ?? 2000.0;

    return Container(
      padding: const EdgeInsets.all(12),
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
              const Icon(Icons.insights, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Consistência Semanal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = now.subtract(Duration(days: 6 - index));
              final calories = provider.last7DaysCalories[index];
              final isLogged = provider.last7DaysLogged[index];
              
              final isWithinRange = isLogged && (calories >= calorieTarget * 0.85 && calories <= calorieTarget * 1.15);
              
              Color badgeColor = context.colors.surfaceLight;
              Widget icon = Text(
                '${date.day}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: context.colors.textSecondary),
              );

              if (isLogged) {
                if (isWithinRange) {
                  badgeColor = const Color(0xFF059669);
                  icon = const Icon(Icons.check, size: 12, color: Colors.white);
                } else {
                  badgeColor = Colors.amber[700]!;
                  icon = const Icon(Icons.star_half, size: 12, color: Colors.white);
                }
              }

              final isTodaySelected = date.year == now.year && date.month == now.month && date.day == now.day;

              return Column(
                children: [
                  Text(
                    _getAbbreviatedWeekday(date.weekday),
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: isTodaySelected ? FontWeight.bold : FontWeight.normal,
                      color: isTodaySelected ? AppColors.primary : context.colors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                      border: isTodaySelected 
                          ? Border.all(color: AppColors.primary, width: 2) 
                          : Border.all(color: Colors.transparent),
                      boxShadow: isTodaySelected ? [
                        BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 4, spreadRadius: 1)
                      ] : null,
                    ),
                    child: Center(child: icon),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  String _getAbbreviatedWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday: return 'Seg';
      case DateTime.tuesday: return 'Ter';
      case DateTime.wednesday: return 'Qua';
      case DateTime.thursday: return 'Qui';
      case DateTime.friday: return 'Sex';
      case DateTime.saturday: return 'Sáb';
      case DateTime.sunday: return 'Dom';
      default: return '';
    }
  }

  Widget _buildAICoachCard(NutritionProvider provider) {
    final feedback = provider.getAICoachFeedback();
    final title = feedback['title'] ?? 'Dica do OmniAI Coach 💡';
    final advice = feedback['advice'] ?? '';
    final type = feedback['type'] ?? 'info';

    Color cardBorderColor = context.colors.border;
    Color iconBgColor = AppColors.primary.withOpacity(0.1);
    Color iconColor = AppColors.primary;
    IconData icon = Icons.psychology_outlined;

    if (type == 'warning') {
      cardBorderColor = Colors.amber.withOpacity(0.4);
      iconBgColor = Colors.amber.withOpacity(0.12);
      iconColor = Colors.amber[800]!;
      icon = Icons.warning_amber_rounded;
    } else if (type == 'alert') {
      cardBorderColor = Colors.red.withOpacity(0.4);
      iconBgColor = Colors.red.withOpacity(0.12);
      iconColor = Colors.red[800]!;
      icon = Icons.error_outline_rounded;
    } else if (type == 'success') {
      cardBorderColor = const Color(0xFF10B981).withOpacity(0.4);
      iconBgColor = const Color(0xFF10B981).withOpacity(0.12);
      iconColor = const Color(0xFF059669);
      icon = Icons.emoji_events_outlined;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorderColor, width: 1.2),
        gradient: LinearGradient(
          colors: [
            context.colors.surface,
            iconBgColor.withOpacity(0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.colors.textPrimary),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8A2387), Color(0xFFE94057)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'OMNIAI',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      advice,
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomWaterDialog(BuildContext context, NutritionProvider provider) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: context.colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.water_drop, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Text(
                'Inserir Hidratação',
                style: TextStyle(color: context.colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Insira o volume personalizado em ml ou use os atalhos rápidos:',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _presetWaterChip(context, controller, 300),
                  _presetWaterChip(context, controller, 600),
                  _presetWaterChip(context, controller, 1000),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Ex: 400',
                  suffixText: 'ml',
                  suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  filled: true,
                  fillColor: context.colors.surfaceLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: context.colors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text;
                if (text.isNotEmpty) {
                  final val = int.tryParse(text);
                  if (val != null && val > 0) {
                    provider.addWater(val);
                  }
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
  }

  Widget _presetWaterChip(BuildContext context, TextEditingController controller, int amount) {
    return ActionChip(
      label: Text('+$amount ml'),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
      backgroundColor: Colors.blue.withOpacity(0.08),
      side: const BorderSide(color: Colors.blue, width: 0.8),
      onPressed: () {
        controller.text = '$amount';
      },
    );
  }

  Widget _buildWaterTrackerCard(NutritionProvider provider) {
    final water = provider.waterToday;
    final goal = provider.waterGoal;
    final percent = goal > 0 ? (water / goal).clamp(0.0, 1.0) : 0.0;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.water_drop, color: Colors.blue, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Registro de Hidratação',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: context.colors.textPrimary),
                  ),
                ],
              ),
              if (water > 0)
                GestureDetector(
                  onTap: () => provider.resetWater(),
                  child: Text(
                    'Zerar',
                    style: TextStyle(color: context.colors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${water} ml',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue),
                        ),
                        Text(
                          'Meta: ${goal} ml',
                          style: TextStyle(color: context.colors.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 10,
                        backgroundColor: context.colors.surfaceLight,
                        valueColor: const AlwaysStoppedAnimation(Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => provider.addWater(250),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('+250 ml', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => provider.addWater(500),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('+500 ml', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showCustomWaterDialog(context, provider),
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Outro', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealGroup(String mealName, List<DietLogbookEntry> entries) {
    final mealKcal = entries.fold<double>(0, (sum, e) => sum + e.kcal);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.colors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  mealName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  '${mealKcal.toStringAsFixed(0)} kcal',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ...entries.map((entry) => ListTile(
                title: Text(entry.foodName, style: const TextStyle(fontSize: 14)),
                subtitle: Text('${entry.quantityG}g • ${entry.kcal.toStringAsFixed(0)} kcal', style: const TextStyle(fontSize: 12)),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: context.colors.textMuted),
                  onPressed: () => _deleteLogbookEntry(context, entry.id),
                ),
              )),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Aba 2: Plano Alimentar (Dieta Prescrita)
  // ---------------------------------------------------------------------------

  Widget _buildDietTab(NutritionProvider provider) {
    final diet = provider.activeDiet;

    if (diet == null) {
      return _buildEmptyState('Nenhum plano alimentar ativo.\nPeça ao seu personal para prescrever uma dieta.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            diet.name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            'Objetivo: ${diet.goal ?? "Não definido"}',
            style: TextStyle(color: context.colors.textSecondary),
          ),
          const SizedBox(height: 16),
          _buildCalorieCard(
            diet.totalKcal,
            diet.totalKcal, // A meta é ela mesma no card de plano
            diet.totalProtein,
            diet.totalCarbs,
            diet.totalFats,
            isDietTab: true,
          ),
          const Text('Refeições Prescritas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...(() {
            final sortedMeals = List<DietMeal>.from(diet.meals)..sort((a, b) {
              if (a.time == null && b.time == null) return 0;
              if (a.time == null) return 1;
              if (b.time == null) return -1;
              return a.time!.compareTo(b.time!);
            });
            return sortedMeals.map((meal) => _buildDietMealCard(meal));
          })(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDietMealCard(DietMeal meal) {
    final nameParts = meal.name.split(' || ');
    final displayName = nameParts.first;
    final displayDesc = nameParts.length > 1 ? nameParts[1] : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: context.colors.border)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: context.colors.textMuted),
                      const SizedBox(width: 6),
                      Text(meal.time ?? '--:--', style: TextStyle(color: context.colors.textMuted)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (displayDesc.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  displayDesc,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.colors.textMuted,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${meal.subtotalKcal.toStringAsFixed(0)} kcal',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ...meal.items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(item.foodName, style: const TextStyle(fontWeight: FontWeight.w500))),
                    Text('${item.quantityG}g', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                if (item.observations != null && item.observations!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Obs: ${item.observations}', style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
                  ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widgets Compartilhados
  // ---------------------------------------------------------------------------

  Widget _buildCalorieCard(double current, double target, double p, double c, double f, {bool isDietTab = false}) {
    final percentRaw = target > 0 ? ((current / target) * 100) : 0.0;
    final percent = percentRaw.clamp(0.0, 100.0);
    final isOver = percentRaw > 100.0;

    final titleLabel = isDietTab ? 'Total Diário' : '${current.toStringAsFixed(0)} kcal';
    final subtitleLabel = isDietTab ? '${current.toStringAsFixed(0)} kcal prescritas' : 'de ${target.toStringAsFixed(0)} kcal (${percentRaw.toStringAsFixed(0)}% da meta diária)';
    
    final highlightColor = isOver && !isDietTab ? Colors.red : AppColors.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOver && !isDietTab ? Colors.red.withOpacity(0.1) : context.colors.surface,
        border: Border.all(
          color: isOver && !isDietTab ? Colors.red : context.colors.border, 
          width: isOver && !isDietTab ? 1.5 : 1
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleLabel,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleLabel,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
              if (!isDietTab)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: context.colors.surfaceLight),
                  child: Center(
                    child: Text(
                      '${percentRaw.toStringAsFixed(0)}%',
                      style: TextStyle(fontWeight: FontWeight.bold, color: highlightColor),
                    ),
                  ),
                ),
            ],
          ),
          if (!isDietTab) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0, 1),
                minHeight: 8,
                backgroundColor: context.colors.surfaceLight,
                valueColor: AlwaysStoppedAnimation(highlightColor),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroItem('Proteína', '${p.toStringAsFixed(0)}g', const Color(0xFF3dba5e)),
              _buildMacroItem('Carbs', '${c.toStringAsFixed(0)}g', const Color(0xFF4db8ff)),
              _buildMacroItem('Gordura', '${f.toStringAsFixed(0)}g', const Color(0xFFffc84d)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, color: context.colors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: context.colors.surfaceLight),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Ações
  // ---------------------------------------------------------------------------

  void _showAddFoodFlow(BuildContext context, NutritionProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FoodSearchModal(),
    );
  }

  void _deleteLogbookEntry(BuildContext context, String entryId) {
    final provider = context.read<NutritionProvider>();
    final date = provider.currentDate;
    provider.deleteLogbookEntry(entryId, date).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Hoje';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && date.month == yesterday.month && date.day == yesterday.day) {
      return 'Ontem';
    }
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
