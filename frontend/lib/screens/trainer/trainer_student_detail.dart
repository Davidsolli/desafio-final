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
import '../../services/dashboard_service.dart';
import '../../services/api_client.dart';
import '../../widgets/frequency_bar_chart.dart';
import '../../widgets/progression_line_chart.dart';
import '../../shared/widgets/index.dart';
import 'widgets/create_workout_sheet_dialog.dart';
import 'widgets/edit_workout_sheet_dialog.dart';
import '../student/widgets/create_custom_food_dialog.dart';

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
  WorkoutProgramResponse? _activeProgram;
  bool _sheetsLoading = true;
  String? _sheetsError;
  List<Diet> _studentDiets = [];
  bool _nutritionLoading = false;
  String? _nutritionError;

  // Estado local para a aba de Evolução
  bool _evolutionLoading = false;
  String? _evolutionError;
  List<Map<String, dynamic>> _frequencyData = [];
  String _frequencyPeriod = 'weekly';
  List<Map<String, dynamic>> _progressionData = [];
  String? _selectedExerciseId;
  String? _selectedExerciseName;
  List<Map<String, dynamic>> _muscleGroupData = [];
  List<ExerciseResponse> _studentExercises = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
    // Garante recarga quando a aba de Evolução for selecionada
    if (_tabController.index == 3 && !_evolutionLoading && _frequencyData.isEmpty) {
      _loadEvolutionData();
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
      await provider.loadPrograms(userId: widget.studentId);
      
      if (provider.programs.isNotEmpty) {
        final active = provider.programs.firstWhere((p) => p.isActive, orElse: () => provider.programs.first);
        await provider.loadSheets(workoutProgramId: active.id);
        
        final List<ExerciseResponse> exercises = [];
        final sheetService = provider.service;
        for (final s in provider.sheets) {
          try {
            final detailedSheet = await sheetService.getWorkoutSheet(s.id);
            exercises.addAll(detailedSheet.exercises);
          } catch (_) {}
        }
        
        final uniqueExercises = <String, ExerciseResponse>{};
        for (final ex in exercises) {
          uniqueExercises[ex.name] = ex;
        }

        if (mounted) {
          setState(() {
            _activeProgram = active;
            _studentSheets = provider.sheets;
            _studentExercises = uniqueExercises.values.toList();
            if (_studentExercises.isNotEmpty && _selectedExerciseId == null) {
              _selectedExerciseId = _studentExercises.first.id;
              _selectedExerciseName = _studentExercises.first.name;
            }
            _sheetsLoading = false;
          });
          _loadEvolutionData();
        }
      } else {
        if (mounted) {
          setState(() {
            _activeProgram = null;
            _studentSheets = [];
            _studentExercises = [];
            _sheetsLoading = false;
          });
          _loadEvolutionData();
        }
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

  Future<void> _loadEvolutionData() async {
    setState(() {
      _evolutionLoading = true;
      _evolutionError = null;
    });

    try {
      final apiClient = context.read<ApiClient>();
      final dashboardService = DashboardService(apiClient);

      // 1. Carrega frequência de treino
      final freqRes = await dashboardService.getFrequency(
        period: _frequencyPeriod,
        userId: widget.studentId,
      );
      final List<dynamic> freqDataList = freqRes != null && freqRes['data'] != null 
          ? freqRes['data'] as List<dynamic> 
          : [];

      // 2. Carrega foco muscular nos últimos 30 dias
      final muscleRes = await dashboardService.getMuscleGroupDistribution(
        days: 30,
        userId: widget.studentId,
      );
      final List<dynamic> muscleDataList = muscleRes != null && muscleRes['data'] != null 
          ? muscleRes['data'] as List<dynamic> 
          : [];

      // 3. Carrega progressão de carga do exercício selecionado se houver
      List<dynamic> progressionDataList = [];
      if (_selectedExerciseId != null) {
        final progRes = await dashboardService.getExerciseProgression(
          exerciseId: _selectedExerciseId!,
          userId: widget.studentId,
        );
        progressionDataList = progRes != null && progRes['data'] != null 
            ? progRes['data'] as List<dynamic> 
            : [];
      }

      if (mounted) {
        setState(() {
          _frequencyData = freqDataList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _muscleGroupData = muscleDataList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _progressionData = progressionDataList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _evolutionLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _evolutionError = 'Erro ao carregar dados de evolução';
          _evolutionLoading = false;
        });
      }
    }
  }

  Widget _buildEvolutionTab() {
    if (_sheetsLoading || (_evolutionLoading && _frequencyData.isEmpty)) {
      return const OmniLoader();
    }

    if (_evolutionError != null) {
      return OmniErrorState(
        message: _evolutionError!,
        onRetry: _loadEvolutionData,
      );
    }

    final totalExercisesCount = _muscleGroupData.fold<int>(0, (sum, item) => sum + ((item['count'] as num?)?.toInt() ?? 0));

    int currentWeekWorkoutsCount = 0;
    if (_frequencyData.isNotEmpty) {
      currentWeekWorkoutsCount = (_frequencyData.last['count'] as num?)?.toInt() ?? 0;
    }

    Color badgeColor;
    String badgeText;
    IconData badgeIcon;
    String badgeDesc;

    if (currentWeekWorkoutsCount >= 3) {
      badgeColor = AppColors.accentSuccess;
      badgeText = 'Foco Total 🔥';
      badgeIcon = Icons.local_fire_department_rounded;
      badgeDesc = 'O aluno está super active e consistente esta semana!';
    } else if (currentWeekWorkoutsCount > 0) {
      badgeColor = AppColors.accentWarning;
      badgeText = 'Consistente 💪';
      badgeIcon = Icons.trending_up_rounded;
      badgeDesc = 'Bom ritmo! Falta pouco para atingir a meta semanal ideal.';
    } else {
      badgeColor = AppColors.accentError;
      badgeText = 'Alerta de Inatividade ⚠️';
      badgeIcon = Icons.warning_amber_rounded;
      badgeDesc = 'O aluno não registrou treinos nos últimos 7 dias.';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    badgeColor.withOpacity(0.12),
                    badgeColor.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: badgeColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(badgeIcon, color: badgeColor, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badgeText,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          badgeDesc,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Treinos finalizados esta semana: $currentWeekWorkoutsCount',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: context.colors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Frequência de Treinos',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.colors.border),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_frequencyPeriod != 'weekly') {
                                setState(() {
                                  _frequencyPeriod = 'weekly';
                                });
                                _loadEvolutionData();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: _frequencyPeriod == 'weekly'
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Semanal',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _frequencyPeriod == 'weekly'
                                          ? Colors.white
                                          : context.colors.textMuted,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (_frequencyPeriod != 'monthly') {
                                setState(() {
                                  _frequencyPeriod = 'monthly';
                                });
                                _loadEvolutionData();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: _frequencyPeriod == 'monthly'
                                    ? AppColors.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Mensal',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: _frequencyPeriod == 'monthly'
                                          ? Colors.white
                                          : context.colors.textMuted,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.colors.border),
                  ),
                  child: FrequencyBarChart(
                    dataPoints: _frequencyData,
                    period: _frequencyPeriod,
                    isLoading: _evolutionLoading,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Progressão de Carga',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                if (_studentExercises.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.fitness_center, color: Colors.grey, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'Sem exercícios cadastrados',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedExerciseId,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                        dropdownColor: context.colors.surface,
                        items: _studentExercises.map((ex) {
                          return DropdownMenuItem<String>(
                            value: ex.id,
                            child: Text(
                              ex.name,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final selected = _studentExercises.firstWhere((e) => e.id == val);
                            setState(() {
                              _selectedExerciseId = val;
                              _selectedExerciseName = selected.name;
                            });
                            _loadEvolutionData();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 240,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: ProgressionLineChart(
                      dataPoints: _progressionData,
                      isLoading: _evolutionLoading,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Foco Muscular (Últimos 30 dias)',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                if (_muscleGroupData.isEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.pie_chart_outline_rounded, color: Colors.grey, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'Ainda sem treinos finalizados neste período',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.colors.border),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _muscleGroupData.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = _muscleGroupData[index];
                        final muscleName = item['muscle_group'] as String? ?? 'Outros';
                        final count = (item['count'] as num?)?.toInt() ?? 0;
                        final percent = totalExercisesCount > 0 ? count / totalExercisesCount : 0.0;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  muscleName.toUpperCase(),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: context.colors.textSecondary,
                                        letterSpacing: 1.1,
                                      ),
                                ),
                                Text(
                                  '$count séries (${(percent * 100).toStringAsFixed(0)}%)',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percent,
                                backgroundColor: context.colors.border.withOpacity(0.5),
                                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
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
                  Tab(icon: Icon(Icons.trending_up), text: 'Evolução'),
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
                  _buildEvolutionTab(),
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
      return const OmniLoader();
    }

    if (_studentError != null) {
      return OmniErrorState(
        message: _studentError!,
        onRetry: _loadStudentData,
      );
    }

    if (_student == null) {
      return const OmniEmptyState(
        icon: Icons.person_off,
        title: 'Aluno não encontrado',
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
              OmniAvatar(name: _student!.name, size: 60, useGradient: true),
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
                child: OmniStatCard(
                  icon: Icons.scale,
                  value: _student!.weight.toStringAsFixed(1),
                  label: 'Peso',
                  unit: 'kg',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OmniStatCard(
                  icon: Icons.height,
                  value: _student!.height.toStringAsFixed(1),
                  label: 'Altura',
                  unit: 'cm',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OmniStatCard(
                  icon: Icons.cake,
                  value: '${_student!.age}',
                  label: 'Idade',
                  unit: 'anos',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OmniStatCard(
                  icon: Icons.trending_up,
                  value: imc.toStringAsFixed(1),
                  label: 'IMC',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          OmniSectionHeader(title: 'Informações do Aluno'),
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

          if (_sheetsLoading)
            const OmniLoader()
          else if (_sheetsError != null)
            OmniErrorState(
              message: _sheetsError!,
              onRetry: _loadStudentSheets,
            )
          else if (_studentSheets.isEmpty)
            const OmniEmptyState(
              icon: Icons.fitness_center_outlined,
              title: 'Nenhuma ficha atribuída',
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
        workoutProgramId: _activeProgram!.id,
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
      return const OmniLoader();
    }

    if (_nutritionError != null) {
      return OmniErrorState(
        message: _nutritionError!,
        onRetry: _loadStudentNutrition,
      );
    }

    if (_studentDiets.isEmpty) {
      return const OmniEmptyState(
        icon: Icons.restaurant_outlined,
        title: 'Nenhum plano nutricional',
        subtitle: 'Nenhum plano nutricional cadastrado para este aluno.',
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
          _buildWaterTargetPrescriberCard(activeDiet),
          const SizedBox(height: 16),
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

  Widget _buildWaterTargetPrescriberCard(Diet activeDiet) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16C1F3).withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF16C1F3).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF16C1F3).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_drink_rounded,
                  color: Color(0xFF26C6DA),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Meta de Hidratação',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Prescrita individualmente para o aluno',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.white.withOpacity(0.7),
                          ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showEditWaterTargetDialog(activeDiet),
                icon: const Icon(Icons.edit, size: 14, color: Colors.white),
                label: const Text('Prescrever'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16C1F3).withOpacity(0.4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: const Color(0xFF16C1F3).withOpacity(0.5)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Meta Atual',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withOpacity(0.6),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${activeDiet.waterTargetMl}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'ml',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.7),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withOpacity(0.2),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fórmula Padrão',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withOpacity(0.6),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _student != null && _student!.weight > 0
                            ? '${(_student!.weight * 35).toInt()}'
                            : '2500',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'ml',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.7),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withOpacity(0.2),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Equivale a',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withOpacity(0.6),
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${(activeDiet.waterTargetMl / 250).toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: const Color(0xFF26C6DA),
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'copos',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withOpacity(0.7),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditWaterTargetDialog(Diet activeDiet) async {
    final controller = TextEditingController(text: '${activeDiet.waterTargetMl}');
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: context.colors.background,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Prescrever Meta de Água',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Defina uma meta diária personalizada de hidratação em mililitros (ml) para o aluno. Caso queira reverter para a fórmula automática de 35ml por kg de peso, defina como zero ou limpe o campo.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.colors.textMuted,
                        ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Meta Diária de Água (ml)',
                      hintText: 'Ex: 3000',
                      suffixText: 'ml',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.local_drink_rounded),
                    ),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final val = int.tryParse(value);
                        if (val == null || val < 0) {
                          return 'Digite um valor inteiro válido';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            // Define o valor calculado padrão baseado na fórmula
                            if (_student != null && _student!.weight > 0) {
                              controller.text = '${(_student!.weight * 35).toInt()}';
                            } else {
                              controller.text = '2500';
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Calcular Fórmula (35ml/kg)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;
                            
                            final targetValStr = controller.text.trim();
                            // Se estiver em branco ou for 0, mandamos 0 para reverter para o padrão do backend
                            final targetVal = targetValStr.isEmpty ? 0 : int.parse(targetValStr);

                            Navigator.pop(context); // fecha bottom sheet
                            
                            setState(() {
                              _nutritionLoading = true;
                            });

                            try {
                              final nutritionService = context.read<NutritionService>();
                              
                              // Para atualizar a dieta ativa mantendo todas as suas refeições originais,
                              // mapeamos as refeições para o formato de input esperado pelo DTO do backend.
                              final mealsPayload = activeDiet.meals.map((m) {
                                return {
                                  'name': m.name,
                                  'time': m.time,
                                  'order': m.order,
                                  'items': m.items.map((it) {
                                    return {
                                      'food_id': it.foodId,
                                      'quantity_g': it.quantityG,
                                      'observations': it.observations,
                                    };
                                  }).toList(),
                                };
                              }).toList();

                              await nutritionService.updateDiet(
                                dietId: activeDiet.id,
                                meals: mealsPayload,
                                waterTargetMl: targetVal,
                              );

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Meta de hidratação atualizada com sucesso!'),
                                  backgroundColor: AppColors.accentSuccess,
                                ),
                              );

                              // Recarrega
                              _loadStudentNutrition();
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Erro ao atualizar meta: ${e.toString()}'),
                                  backgroundColor: AppColors.accentError,
                                ),
                              );
                              setState(() {
                                _nutritionLoading = false;
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('Salvar Prescrição'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    if (_activeProgram == null) {
      // Cria um programa padrão automaticamente se não existir
      try {
        final provider = context.read<WorkoutSheetProvider>();
        final newProgram = await provider.createProgram(CreateWorkoutProgramDTO(
          userId: widget.studentId,
          name: 'Programa Padrão',
          goal: 'Geral',
        ));
        setState(() => _activeProgram = newProgram);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao criar programa inicial.'), backgroundColor: AppColors.accentError),
          );
        }
        return;
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CreateWorkoutSheetDialog(
        workoutProgramId: _activeProgram!.id,
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: TextButton.icon(
                        icon: const Icon(Icons.add_circle_outline, size: 14, color: AppColors.primary),
                        label: const Text(
                          'Criar Alimento Personalizado',
                          style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final newFood = await showDialog<CustomFood?>(
                            context: context,
                            builder: (ctx) => const CreateCustomFoodDialog(),
                          );
                          if (newFood != null) {
                            setModalState(() {
                              editableItems.add(
                                _EditableDietItem(
                                  foodId: null,
                                  customFoodId: newFood.id,
                                  foodName: newFood.name,
                                  quantityG: 100,
                                ),
                              );
                            });
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
                              foodId: food.source == 'taco' ? int.tryParse(food.id) : null,
                              customFoodId: food.source == 'custom' ? food.id : null,
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
