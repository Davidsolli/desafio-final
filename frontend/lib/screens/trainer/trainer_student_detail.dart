import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../models/workout_sheet_model.dart';
import '../../models/diet_models.dart';
import '../../providers/workout_sheet_provider.dart';
import '../../services/nutrition_service.dart';
import '../../services/user_service.dart';
import '../../services/workout_sheet_service.dart';
import 'widgets/create_workout_sheet_dialog.dart';
import 'widgets/edit_workout_sheet_dialog.dart';

class TrainerStudentDetail extends StatefulWidget {
  final String studentId;

  const TrainerStudentDetail({super.key, required this.studentId});

  @override
  State<TrainerStudentDetail> createState() => _TrainerStudentDetailState();
}

class _TrainerStudentDetailState extends State<TrainerStudentDetail> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserResponse? _student;
  bool _studentLoading = true;
  String? _studentError;

  // Estado local para fichas do aluno (carregadas via API)
  List<WorkoutSheetListItem> _studentSheets = [];
  bool _sheetsLoading = false;
  String? _sheetsError;
  List<Diet> _studentDiets = [];
  bool _nutritionLoading = false;
  String? _nutritionError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);

    // Carrega dados do aluno e fichas via API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudentData();
      _loadStudentSheets();
      _loadStudentNutrition();
    });
  }

  void _handleTabChanged() {
    // Garante recarga quando a aba Nutrição for selecionada, inclusive após hot reload.
    if (_tabController.index == 2 && !_nutritionLoading && _studentDiets.isEmpty) {
      _loadStudentNutrition();
    }
  }

  Future<void> _loadStudentData() async {
    setState(() {
      _studentLoading = true;
      _studentError = null;
    });

    try {
      final userService = context.read<UserService>();
      final student = await userService.getUserById(widget.studentId);
      setState(() {
        _student = student;
        _studentLoading = false;
      });
    } catch (e) {
      setState(() {
        _studentError = 'Erro ao carregar aluno';
        _studentLoading = false;
      });
    }
  }

  Future<void> _loadStudentNutrition() async {
    setState(() {
      _nutritionLoading = true;
      _nutritionError = null;
    });
    try {
      final nutritionService = context.read<NutritionService>();
      final diets = await nutritionService.getDiets(
        userId: widget.studentId,
        limit: 20,
      );
      if (mounted) {
        setState(() {
          _studentDiets = diets.where((d) => d.isActive).toList();
          _nutritionLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _nutritionError = 'Erro ao carregar dados de nutrição: ${e.toString()}';
          _nutritionLoading = false;
        });
      }
    }
  }

  Future<void> _loadStudentSheets() async {
    setState(() {
      _sheetsLoading = true;
      _sheetsError = null;
    });
    try {
      final provider = context.read<WorkoutSheetProvider>();
      await provider.loadSheets(userId: widget.studentId);
      if (mounted) {
        setState(() {
          _studentSheets = provider.sheets;
          _sheetsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sheetsError = 'Erro ao carregar fichas';
          _sheetsLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _student?.name ?? 'Carregando...',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              _mapGoalTypeToPt(_student?.goalType),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: context.colors.surface,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.info_outline), text: 'Info'),
                  Tab(icon: Icon(Icons.fitness_center), text: 'Treinos'),
                  Tab(icon: Icon(Icons.restaurant_outlined), text: 'Nutrição'),
                ],
                labelColor: AppColors.primary,
                unselectedLabelColor: context.colors.textMuted,
                indicatorColor: AppColors.primary,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInfoTab(),
                  _buildWorkoutsTab(),
                  _buildNutritionTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildInfoTab() {
    if (_studentLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_studentError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.accentError, size: 40),
            const SizedBox(height: 12),
            Text(_studentError!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textMuted)),
          ],
        ),
      );
    }

    if (_student == null) {
      return Center(
        child: Text('Aluno não encontrado',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textMuted)),
      );
    }

    final imc = _student!.height > 0 ? _student!.weight / ((_student!.height / 100) * (_student!.height / 100)) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(_student!.name[0],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_student!.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text(_mapGoalTypeToPt(_student!.goalType), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary)),
                  Text('${_student!.age} anos', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FadeInLeft(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      border: Border.all(color: context.colors.border, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.scale, color: AppColors.primary, size: 20),
                        const SizedBox(height: 6),
                        Text('${_student!.weight.toStringAsFixed(1)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Peso', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FadeInRight(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      border: Border.all(color: context.colors.border, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.height, color: AppColors.primary, size: 20),
                        const SizedBox(height: 6),
                        Text('${_student!.height.toStringAsFixed(1)} cm', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Altura', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FadeInLeft(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      border: Border.all(color: context.colors.border, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.cake, color: AppColors.primary, size: 20),
                        const SizedBox(height: 6),
                        Text('${_student!.age} anos', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Idade', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FadeInRight(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      border: Border.all(color: context.colors.border, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.trending_up, color: AppColors.primary, size: 20),
                        const SizedBox(height: 6),
                        Text('${imc.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('IMC', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Informações do Aluno', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildQuestionRow('Objetivo', _mapGoalTypeToPt(_student!.goalType)),
          const SizedBox(height: 8),
          _buildQuestionRow('Gênero', _mapGenderToPt(_student!.gender)),
          const SizedBox(height: 8),
          _buildQuestionRow('Email', _student!.email),
        ],
      ),
    );
  }

  Widget _buildWorkoutsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Fichas Atribuídas', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: _showCreateWorkoutDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('Novo',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Estado de carregamento
          if (_sheetsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          // Estado de erro
          else if (_sheetsError != null)
            Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.accentError, size: 40),
                  const SizedBox(height: 8),
                  Text(_sheetsError!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textMuted)),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loadStudentSheets,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            )
          // Estado vazio
          else if (_studentSheets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.fitness_center_outlined, color: context.colors.textMuted, size: 40),
                    const SizedBox(height: 8),
                    Text('Nenhuma ficha atribuída',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textMuted)),
                  ],
                ),
              ),
            )
          // Lista de fichas reais da API
          else
            ..._studentSheets.map((sheet) {
              return FadeInUp(
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
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
                          Expanded(
                            child: Row(
                              children: [
                                Text(sheet.emoji, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(sheet.name,
                                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                      Text('${sheet.dayOfWeekLabel} • ${sheet.exerciseCount} exercícios',
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _duplicateSheetForStudent(sheet),
                                child: Icon(Icons.copy, color: context.colors.textMuted, size: 16),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showEditSheetDialog(sheet),
                                child: Icon(Icons.edit, color: context.colors.textMuted, size: 16),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _deleteSheet(sheet),
                                child: const Icon(Icons.delete, color: AppColors.accentError, size: 16),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _duplicateSheetForStudent(WorkoutSheetListItem sheet) async {
    try {
      final dto = DuplicateWorkoutSheetDTO(
        name: '${sheet.name} (Cópia)',
        userId: widget.studentId,
      );
      await context.read<WorkoutSheetProvider>().duplicateSheet(sheet.id, dto);
      await _loadStudentSheets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ficha duplicada com sucesso!'),
            backgroundColor: AppColors.accentSuccess,
          ),
        );
      }
    } on WorkoutSheetConflictException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro: aluno já possui ficha ativa para este dia da semana (RN-01).'),
            backgroundColor: AppColors.accentError,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao duplicar ficha.'),
            backgroundColor: AppColors.accentError,
          ),
        );
      }
    }
  }

  Future<void> _deleteSheet(WorkoutSheetListItem sheet) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Confirmar exclusão'),
        content: Text('Deseja realmente remover a ficha "${sheet.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Excluir', style: TextStyle(color: AppColors.accentError)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await context.read<WorkoutSheetProvider>().deleteSheet(sheet.id);
        await _loadStudentSheets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ficha removida com sucesso.'),
              backgroundColor: AppColors.accentSuccess,
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao remover ficha.'),
              backgroundColor: AppColors.accentError,
            ),
          );
        }
      }
    }
  }

  Widget _buildNutritionTab() {
    if (_nutritionLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_nutritionError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.accentError, size: 40),
            const SizedBox(height: 8),
            Text(
              _nutritionError!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textMuted),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadStudentNutrition,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_studentDiets.isEmpty) {
      return Center(
        child: Text(
          'Nenhum plano nutricional cadastrado para este aluno.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textMuted),
        ),
      );
    }

    final activeDiet = _studentDiets.first;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Plano Nutricional', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              Text(
                activeDiet.name,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.colors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...activeDiet.meals.map((m) {
            return FadeInUp(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
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
                            Text(m.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              '${m.time ?? "--:--"} • ${m.subtotalKcal.toStringAsFixed(0)} kcal',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => _showEditMealDialog(activeDiet, m),
                          child: Icon(Icons.edit, color: context.colors.textMuted, size: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('P: ${m.subtotalProtein.toStringAsFixed(1)}g', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted)),
                        Text('C: ${m.subtotalCarbs.toStringAsFixed(1)}g', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted)),
                        Text('G: ${m.subtotalFats.toStringAsFixed(1)}g', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Text(
            'Totais da dieta: ${activeDiet.totalKcal.toStringAsFixed(0)} kcal • '
            'P ${activeDiet.totalProtein.toStringAsFixed(1)}g • '
            'C ${activeDiet.totalCarbs.toStringAsFixed(1)}g • '
            'G ${activeDiet.totalFats.toStringAsFixed(1)}g',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionRow(String question, String answer) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(question, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textMuted)),
          Text(answer, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _mapGoalTypeToPt(String? goalType) {
    switch (goalType) {
      case 'gain_mass':
        return 'ganho de massa';
      case 'lose_weight':
        return 'perda de peso';
      case 'maintain':
      case 'maintenance':
        return 'manutenção';
      case 'endurance':
        return 'resistência';
      case 'bulking':
        return 'bulking';
      case 'cutting':
        return 'cutting';
      default:
        return goalType == null || goalType.isEmpty ? 'Não informado' : goalType;
    }
  }

  String _mapGenderToPt(String? gender) {
    switch (gender) {
      case 'male':
        return 'masculino';
      case 'female':
        return 'feminino';
      default:
        return gender == null || gender.isEmpty ? 'Não informado' : gender;
    }
  }

  Future<void> _showCreateWorkoutDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CreateWorkoutSheetDialog(
        targetUserId: widget.studentId,
      ),
    );
    if (result == true && mounted) {
      await _loadStudentSheets();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ficha criada com sucesso!'),
          backgroundColor: AppColors.accentSuccess,
        ),
      );
    }
  }

  Future<void> _showEditSheetDialog(WorkoutSheetListItem sheet) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditWorkoutSheetDialog(sheetId: sheet.id),
    );

    if (updated == true && mounted) {
      await _loadStudentSheets();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ficha atualizada com sucesso.'),
          backgroundColor: AppColors.accentSuccess,
        ),
      );
    }
  }

  Future<void> _showEditMealDialog(Diet activeDiet, DietMeal targetMeal) async {
    final nutritionService = context.read<NutritionService>();
    final mealNameController = TextEditingController(text: targetMeal.name);
    final mealTimeController = TextEditingController(text: targetMeal.time ?? '');
    final editableItems = targetMeal.items
        .map((item) => _EditableDietItem(
              foodId: item.foodId,
              customFoodId: item.customFoodId,
              foodName: item.foodName,
              quantityG: item.quantityG,
              observations: item.observations,
            ))
        .toList();

    List<FoodCatalogItem> searchResults = [];
    bool searching = false;
    final searchController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: context.colors.surface,
          title: Text('Editar ${targetMeal.name}'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: mealNameController,
                    decoration: const InputDecoration(labelText: 'Nome da refeição'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: mealTimeController,
                    decoration: const InputDecoration(labelText: 'Horário (HH:MM)'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Buscar alimento',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: () async {
                          final query = searchController.text.trim();
                          if (query.length < 2) return;
                          setModalState(() => searching = true);
                          try {
                            final result = await nutritionService.searchFoodCatalog(query);
                            setModalState(() => searchResults = result.items);
                          } finally {
                            setModalState(() => searching = false);
                          }
                        },
                      ),
                    ),
                  ),
                  if (searching)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  ...searchResults.take(5).map(
                    (food) => ListTile(
                      dense: true,
                      title: Text(food.name),
                      subtitle: Text('${food.energyKcal.toStringAsFixed(0)} kcal/100g'),
                      trailing: const Icon(Icons.add, size: 18),
                      onTap: () {
                        setModalState(() {
                          editableItems.add(
                            _EditableDietItem(
                              foodId: int.tryParse(food.id),
                              customFoodId: null,
                              foodName: food.name,
                              quantityG: 100,
                            ),
                          );
                        });
                      },
                    ),
                  ),
                  const Divider(),
                  ...editableItems.asMap().entries.map(
                    (entry) {
                      final index = entry.key;
                      final item = entry.value;
                      return Row(
                        children: [
                          Expanded(
                            child: Text(item.foodName, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 90,
                            child: TextFormField(
                              initialValue: item.quantityG.toStringAsFixed(0),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(suffixText: 'g'),
                              onChanged: (v) => item.quantityG = double.tryParse(v) ?? item.quantityG,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.accentError),
                            onPressed: () => setModalState(() => editableItems.removeAt(index)),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true) return;

    try {
      final updatedMeals = activeDiet.meals.map((meal) {
        if (meal.id != targetMeal.id) {
          return {
            'name': meal.name,
            'time': meal.time,
            'order': meal.order,
            'items': meal.items
                .map((i) => {
                      if (i.foodId != null) 'food_id': i.foodId,
                      if (i.customFoodId != null) 'custom_food_id': i.customFoodId,
                      'quantity_g': i.quantityG,
                      if (i.observations != null) 'observations': i.observations,
                    })
                .toList(),
          };
        }

        return {
          'name': mealNameController.text.trim().isEmpty ? targetMeal.name : mealNameController.text.trim(),
          'time': mealTimeController.text.trim().isEmpty ? null : mealTimeController.text.trim(),
          'order': targetMeal.order,
          'items': editableItems
              .map((i) => {
                    if (i.foodId != null) 'food_id': i.foodId,
                    if (i.customFoodId != null) 'custom_food_id': i.customFoodId,
                    'quantity_g': i.quantityG,
                    if (i.observations != null) 'observations': i.observations,
                  })
              .toList(),
        };
      }).toList();

      await nutritionService.updateDiet(
        dietId: activeDiet.id,
        name: activeDiet.name,
        goal: activeDiet.goal,
        meals: updatedMeals,
      );
      await _loadStudentNutrition();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refeição atualizada com sucesso.'),
            backgroundColor: AppColors.accentSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar refeição: ${e.toString()}'),
            backgroundColor: AppColors.accentError,
          ),
        );
      }
    }
  }

  Widget _buildBottomNav() {
    final trainerNavItems = [
      {'icon': Icons.dashboard_outlined, 'label': 'Dashboard'},
      {'icon': Icons.people_outlined, 'label': 'Alunos'},
      {'icon': Icons.fitness_center_outlined, 'label': 'Fichas'},
      {'icon': Icons.person_outline, 'label': 'Perfil'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.border, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: 1,
        onTap: (index) {
          final routes = [
            '/trainer/dashboard',
            '/trainer/students',
            '/trainer/sheets',
            '/trainer/profile',
          ];
          context.go(routes[index]);
        },
        backgroundColor: context.colors.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: context.colors.textMuted,
        items: trainerNavItems
            .map((item) => BottomNavigationBarItem(
                  icon: Icon(item['icon'] as IconData, size: 24),
                  label: item['label'] as String,
                ))
            .toList(),
      ),
    );
  }
}

class _EditableDietItem {
  int? foodId;
  String? customFoodId;
  String foodName;
  double quantityG;
  String? observations;

  _EditableDietItem({
    required this.foodId,
    required this.customFoodId,
    required this.foodName,
    required this.quantityG,
    this.observations,
  });
}
