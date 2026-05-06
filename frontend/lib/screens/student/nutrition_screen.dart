import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
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
          _buildCalorieCard(
            logbook?.totalKcal ?? 0.0,
            targets['calories'] ?? 2000.0,
            logbook?.totalProtein ?? 0.0,
            logbook?.totalCarbs ?? 0.0,
            logbook?.totalFats ?? 0.0,
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 24),
          const Text('Refeições Prescritas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...diet.meals.map((meal) => _buildDietMealCard(meal)).toList(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDietMealCard(DietMeal meal) {
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
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: context.colors.textMuted),
                    const SizedBox(width: 6),
                    Text(meal.time ?? '--:--', style: TextStyle(color: context.colors.textMuted)),
                    const SizedBox(width: 8),
                    Text(
                      meal.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
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
    final percent = target > 0 ? ((current / target) * 100).clamp(0, 100) : 0.0;
    final titleLabel = isDietTab ? 'Total Diário' : '${current.toStringAsFixed(0)} kcal';
    final subtitleLabel = isDietTab ? '${current.toStringAsFixed(0)} kcal prescritas' : '${percent.toStringAsFixed(0)}% da meta diária';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border, width: 1),
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
                      '${percent.toStringAsFixed(0)}%',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
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
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
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
    final date = context.read<NutritionProvider>().currentLogbook?.date ?? DateTime.now();
    context.read<NutritionProvider>().deleteLogbookEntry(entryId, date).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    });
  }
}
