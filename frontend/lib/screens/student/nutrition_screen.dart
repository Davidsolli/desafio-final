import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/nutrition_provider.dart';
import '../../services/nutrition_service.dart';

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
        context.read<NutritionProvider>().loadMeals().catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao carregar refeições: $e')),
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Consumer<NutritionProvider>(
                  builder: (context, nutritionProvider, _) {
                    final totals = nutritionProvider.dailyTotals;
                    return Column(
                      children: [
                        _buildCalorieCard(totals),
                        const SizedBox(height: 20),
                        _buildMealsSection(nutritionProvider),
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
              'Nutrição',
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
              'Acompanhe sua ingestão calórica diária',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieCard(Map<String, double> totals) {
    final caloriesTarget = 2000.0;
    final currentCalories = totals['calories'] ?? 0;
    final percent = ((currentCalories / caloriesTarget) * 100).clamp(0, 100);

    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      delay: const Duration(milliseconds: 100),
      child: Container(
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${currentCalories.toStringAsFixed(0)} kcal',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${percent.toStringAsFixed(0)}% da meta diária',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surfaceLight,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${percent.toStringAsFixed(0)}%',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        Text(
                          'de 2000',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (percent / 100).clamp(0, 1),
                minHeight: 8,
                backgroundColor: AppColors.surfaceLight,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMacroItem('Proteína', '${totals['protein']?.toStringAsFixed(0) ?? '0'}g', const Color(0xFF3dba5e)),
                _buildMacroItem('Carbs', '${totals['carbs']?.toStringAsFixed(0) ?? '0'}g', const Color(0xFF4db8ff)),
                _buildMacroItem('Gordura', '${totals['fat']?.toStringAsFixed(0) ?? '0'}g', const Color(0xFFffc84d)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroItem(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildMealsSection(NutritionProvider provider) {
    final mealTypes = [
      {'type': 'breakfast', 'label': '🌅 Café da Manhã'},
      {'type': 'lunch', 'label': '🍽️ Almoço'},
      {'type': 'snack', 'label': '🍎 Lanche'},
      {'type': 'dinner', 'label': '🌙 Janta'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Refeições do Dia',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ...mealTypes.asMap().entries.map((entry) {
          final index = entry.key;
          final mealType = entry.value['type'] as String;
          final label = entry.value['label'] as String;

          final mealItems = provider.meals.where((m) => m.mealType == mealType).toList();
          final totalCalories = mealItems.fold<double>(0, (sum, m) => sum + m.calories);
          final totalProtein = mealItems.fold<double>(0, (sum, m) => sum + m.protein);
          final totalCarbs = mealItems.fold<double>(0, (sum, m) => sum + m.carbs);
          final totalFat = mealItems.fold<double>(0, (sum, m) => sum + m.fat);

          return FadeInUp(
            duration: const Duration(milliseconds: 300),
            delay: Duration(milliseconds: 100 + (index * 100)),
            child: GestureDetector(
              onTap: () => _showMealDetail(context, mealType, label, mealItems),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border, width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+${mealItems.length} item${mealItems.length != 1 ? 's' : ''}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                'P: ${totalProtein.toStringAsFixed(0)}g',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'C: ${totalCarbs.toStringAsFixed(0)}g',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'G: ${totalFat.toStringAsFixed(0)}g',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${totalCalories.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                        ),
                        Text(
                          'kcal',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  void _showMealDetail(BuildContext context, String mealType, String mealLabel, List<MealResponse> mealItems) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    mealLabel,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (mealItems.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const Icon(Icons.restaurant_outlined, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhum item registrado',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: mealItems.length,
                    itemBuilder: (context, index) {
                      final meal = mealItems[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          meal.foods.isNotEmpty ? meal.foods[0].name : meal.mealType,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${meal.calories.toStringAsFixed(0)} kcal',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                                        onPressed: () => _showEditMealDialog(context, meal),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18, color: AppColors.accentError),
                                        onPressed: () => _showDeleteConfirmation(context, meal),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _showAddFoodDialog(context, mealType);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar Item'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddFoodDialog(BuildContext context, String mealType) {
    final foodNameController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adicionar Alimento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: foodNameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do alimento',
                  hintText: 'Ex: Frango grelhado',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calorias (kcal)',
                  hintText: 'Ex: 165',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Proteína (g)',
                        hintText: '31',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Carbs (g)',
                        hintText: '0',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Gordura (g)',
                        hintText: '3.6',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final foodName = foodNameController.text;
              final calories = double.tryParse(caloriesController.text) ?? 0;
              final protein = double.tryParse(proteinController.text) ?? 0;
              final carbs = double.tryParse(carbsController.text) ?? 0;
              final fat = double.tryParse(fatController.text) ?? 0;

              if (foodName.isEmpty || calories == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Preencha nome e calorias')),
                );
                return;
              }

              final dto = CreateMealDTO(
                mealType: mealType,
                mealDate: DateTime.now(),
                foods: [
                  {
                    'name': foodName,
                    'calories': calories,
                    'protein': protein,
                    'carbs': carbs,
                    'fat': fat,
                  }
                ],
              );

              final provider = context.read<NutritionProvider>();
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              provider.createMeal(dto).then((_) {
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Alimento adicionado!')),
                );
              }).catchError((e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Erro: $e')),
                );
              });
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _showEditMealDialog(BuildContext context, MealResponse meal) {
    final foodNameController = TextEditingController(
      text: meal.foods.isNotEmpty ? meal.foods[0].name : '',
    );
    final caloriesController = TextEditingController(text: meal.calories.toStringAsFixed(0));
    final proteinController = TextEditingController(text: meal.protein.toStringAsFixed(0));
    final carbsController = TextEditingController(text: meal.carbs.toStringAsFixed(0));
    final fatController = TextEditingController(text: meal.fat.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Alimento'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: foodNameController,
                decoration: const InputDecoration(labelText: 'Nome do alimento'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calorias (kcal)'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: proteinController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Proteína (g)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: carbsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Carbs (g)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: fatController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Gordura (g)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final foodName = foodNameController.text;
              final calories = double.tryParse(caloriesController.text) ?? 0;
              final protein = double.tryParse(proteinController.text) ?? 0;
              final carbs = double.tryParse(carbsController.text) ?? 0;
              final fat = double.tryParse(fatController.text) ?? 0;

              final dto = CreateMealDTO(
                mealType: meal.mealType,
                mealDate: meal.mealDate,
                foods: [
                  {
                    'name': foodName,
                    'calories': calories,
                    'protein': protein,
                    'carbs': carbs,
                    'fat': fat,
                  }
                ],
              );

              final provider = context.read<NutritionProvider>();
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              provider.updateMeal(meal.id, dto).then((_) {
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Alimento atualizado!')),
                );
              }).catchError((e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Erro: $e')),
                );
              });
            },
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, MealResponse meal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar Alimento'),
        content: Text('Tem certeza que deseja deletar "${meal.foods.isNotEmpty ? meal.foods[0].name : 'este alimento'}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final provider = context.read<NutritionProvider>();
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              provider.deleteMeal(meal.id).then((_) {
                nav.pop();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Alimento deletado!')),
                );
              }).catchError((e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Erro: $e')),
                );
              });
            },
            child: const Text('Deletar', style: TextStyle(color: AppColors.accentError)),
          ),
        ],
      ),
    );
  }
}
