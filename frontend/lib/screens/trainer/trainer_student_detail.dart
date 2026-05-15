import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../models/workout_sheet_model.dart';
import '../../models/diet_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/workout_sheet_provider.dart';
import '../../models/admin_models.dart';
import '../../services/nutrition_service.dart';
import '../../services/user_service.dart';
import '../../services/workout_sheet_service.dart';
import '../../services/api_client.dart';
import '../../services/step_service.dart';
import '../../models/step_models.dart';
import '../../shared/widgets/index.dart';
import 'widgets/create_workout_program_dialog.dart';
import 'widgets/create_workout_sheet_dialog.dart';
import 'widgets/edit_workout_sheet_dialog.dart';
import '../student/widgets/food_search_modal.dart';
import '../../providers/logbook_provider.dart';
import '../../widgets/progress_widgets.dart';
import 'widgets/trainer_nutrition_analytics.dart';

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

  // Estado local para programas e fichas do aluno
  List<WorkoutProgramResponse> _allPrograms = [];
  List<WorkoutSheetListItem> _studentSheets = []; // fichas do programa ativo (para evolução)
  WorkoutProgramResponse? _activeProgram;
  bool _sheetsLoading = true;
  String? _sheetsError;
  String? _expandedProgramId;
  final Map<String, List<WorkoutSheetListItem>> _sheetsCache = {};
  final Map<String, bool> _sheetsLoadingCache = {};
  List<Diet> _studentDiets = [];
  bool _nutritionLoading = false;
  String? _nutritionError;

  // Estado local para a aba de Evolução
  bool _evolutionLoading = false;
  String? _evolutionError;
  List<ExerciseResponse> _studentExercises = [];

  // Estado local para o Diário do Aluno (Aba Nutrição Avançada)
  int _nutritionSubTabIndex = 0; // 0 para Diário do Aluno, 1 para Plano Alimentar
  DietLogbook? _studentLogbook;
  bool _studentLogbookLoading = false;
  DateTime _selectedLogbookDate = DateTime.now();
  List<double> _studentLast7DaysCalories = List.filled(7, 0.0);
  List<bool> _studentLast7DaysLogged = List.filled(7, false);
  int _studentWaterToday = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChanged);

    // Carrega dados do aluno e fichas via API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudentData();
      _loadStudentSheets();
      _loadStudentNutrition();
      _loadStudentLogbook();
    });
  }

  void _handleTabChanged() {
    // Garante recarga quando a aba Nutrição for selecionada, inclusive após hot reload.
    if (_tabController.index == 2) {
      if (!_nutritionLoading && _studentDiets.isEmpty) {
        _loadStudentNutrition();
      }
      _loadStudentLogbook();
    }
    // Garante recarga quando a aba de Evolução for selecionada
    if (_tabController.index == 3 && !_evolutionLoading) {
      final logbookProv = context.read<LogbookProvider>();
      if (logbookProv.getStudentSessions(widget.studentId).isEmpty) {
        _loadEvolutionData();
      }
    }
    // Aba de Passos
    if (_tabController.index == 4 && !_stepsLoading && _stepHistory == null) {
      _loadStepHistory();
    }
  }

  // ----- Estado da aba de Passos -----
  StepHistory? _stepHistory;
  bool _stepsLoading = false;
  String? _stepsError;

  Future<void> _loadStepHistory() async {
    setState(() {
      _stepsLoading = true;
      _stepsError = null;
    });
    try {
      final apiClient = context.read<ApiClient>();
      final stepService = StepService(apiClient: apiClient);
      final history = await stepService.getStudentHistory(widget.studentId);
      if (!mounted) return;
      setState(() {
        _stepHistory = history;
        _stepsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _stepsError = 'Erro ao carregar histórico de passos: $e';
        _stepsLoading = false;
      });
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

  Future<void> _loadStudentLogbook() async {
    if (_studentLogbookLoading) return;
    setState(() {
      _studentLogbookLoading = true;
    });
    try {
      final nutritionService = context.read<NutritionService>();
      final logbook = await nutritionService.getStudentLogbookByDate(
        userId: widget.studentId,
        date: _selectedLogbookDate,
      );

      // Carrega histórico dos últimos 7 dias para o Grid de Consistência
      final List<double> last7Calories = List.filled(7, 0.0);
      final List<bool> last7Logged = List.filled(7, false);
      
      for (int i = 0; i < 7; i++) {
        final targetDate = _selectedLogbookDate.subtract(Duration(days: 6 - i));
        try {
          final dailyLog = await nutritionService.getStudentLogbookByDate(
            userId: widget.studentId,
            date: targetDate,
          );
          last7Calories[i] = dailyLog.totalKcal;
          last7Logged[i] = dailyLog.entries.isNotEmpty;
        } catch (_) {
          // Trata falha silenciosamente
        }
      }

      // Carrega o diário de água do SharedPreferences local e isolado por estudante
      final prefs = await SharedPreferences.getInstance();
      final dateStr = _selectedLogbookDate.toIso8601String().split('T')[0];
      final savedWater = prefs.getInt('water_log_${widget.studentId}_$dateStr') ?? 0;

      if (mounted) {
        setState(() {
          _studentLogbook = logbook;
          _studentLast7DaysCalories = last7Calories;
          _studentLast7DaysLogged = last7Logged;
          _studentWaterToday = savedWater;
          _studentLogbookLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _studentLogbookLoading = false;
        });
      }
    }
  }

  Future<void> _updateStudentWater(int amountMl) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = _selectedLogbookDate.toIso8601String().split('T')[0];
    final current = prefs.getInt('water_log_${widget.studentId}_$dateStr') ?? 0;
    final updated = current + amountMl;
    await prefs.setInt('water_log_${widget.studentId}_$dateStr', updated);
    if (mounted) {
      setState(() {
        _studentWaterToday = updated;
      });
    }
  }

  Future<void> _resetStudentWater() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = _selectedLogbookDate.toIso8601String().split('T')[0];
    await prefs.remove('water_log_${widget.studentId}_$dateStr');
    if (mounted) {
      setState(() {
        _studentWaterToday = 0;
      });
    }
  }

  Future<void> _loadStudentSheets() async {
    setState(() {
      _sheetsLoading = true;
      _sheetsError = null;
    });
    try {
      final provider = context.read<WorkoutSheetProvider>();
      await provider.loadPrograms(userId: widget.studentId, limit: 50);

      if (provider.programs.isNotEmpty) {
        final active = provider.programs.firstWhere(
          (p) => p.isActive,
          orElse: () => provider.programs.first,
        );

        if (mounted) {
          setState(() {
            _allPrograms = provider.programs;
            _activeProgram = active;
            _expandedProgramId ??= active.id;
            _sheetsLoading = false;
          });
          // Carrega fichas do programa expandido para uso em Evolução
          await _loadSheetsForProgram(active.id, forEvolution: true);
          _loadEvolutionData();
        }
      } else {
        if (mounted) {
          setState(() {
            _allPrograms = [];
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
          _sheetsError = 'Erro ao carregar programas';
          _sheetsLoading = false;
        });
      }
    }
  }

  Future<void> _loadSheetsForProgram(String programId, {bool forEvolution = false}) async {
    if (_sheetsLoadingCache[programId] == true) return;
    setState(() => _sheetsLoadingCache[programId] = true);
    try {
      final provider = context.read<WorkoutSheetProvider>();
      await provider.loadSheets(workoutProgramId: programId);
      final sheets = List<WorkoutSheetListItem>.from(provider.sheets);

      if (!mounted) return;
      setState(() {
        _sheetsCache[programId] = sheets;
        _sheetsLoadingCache[programId] = false;
      });

      if (forEvolution) {
        _studentSheets = sheets;
        final List<ExerciseResponse> exercises = [];
        final sheetService = provider.service;
        for (final s in sheets) {
          try {
            final detail = await sheetService.getWorkoutSheet(s.id);
            exercises.addAll(detail.exercises);
          } catch (_) {}
        }
        final unique = <String, ExerciseResponse>{};
        for (final ex in exercises) {
          unique[ex.name] = ex;
        }
        if (mounted) setState(() => _studentExercises = unique.values.toList());
      }
    } catch (_) {
      if (mounted) setState(() => _sheetsLoadingCache[programId] = false);
    }
  }

  Future<void> _loadEvolutionData() async {
    setState(() {
      _evolutionLoading = true;
      _evolutionError = null;
    });

    try {
      final logbookProv = context.read<LogbookProvider>();
      await Future.wait([
        logbookProv.loadStudentSessions(widget.studentId),
        logbookProv.loadStudentFrequency(widget.studentId, 'weekly', limit: 12),
        logbookProv.loadStudentMuscleGroupDistribution(widget.studentId, days: 30),
        logbookProv.loadStudentPersonalRecords(widget.studentId),
      ]);

      if (mounted) {
        setState(() {
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
    if (_sheetsLoading || _evolutionLoading) {
      return const OmniLoader();
    }

    if (_evolutionError != null) {
      return OmniErrorState(
        message: _evolutionError!,
        onRetry: _loadEvolutionData,
      );
    }

    final logbookProv = context.read<LogbookProvider>();
    final studentSessions = logbookProv.getStudentSessions(widget.studentId);

    // Se não houver histórico, exibe um belo estado vazio
    if (studentSessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhum treino finalizado ainda',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Os dados de evolução aparecerão aqui assim que o aluno concluir e salvar seu primeiro treino no aplicativo.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Combina os exercícios das fichas e os finalizados para o dropdown
    final List<Map<String, String>> availableExercises = [];
    final addedIds = <String>{};

    for (var ex in _studentExercises) {
      if (ex.id.isNotEmpty && !addedIds.contains(ex.id)) {
        addedIds.add(ex.id);
        availableExercises.add({'id': ex.id, 'name': ex.name});
      }
    }

    for (var sess in studentSessions) {
      for (var ex in sess.exercises) {
        final exId = ex.exerciseId.isNotEmpty ? ex.exerciseId : ex.id;
        if (exId.isNotEmpty && !addedIds.contains(exId)) {
          addedIds.add(exId);
          availableExercises.add({'id': exId, 'name': ex.exerciseName});
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Heatmap de Atividade
          FadeInDown(
            duration: const Duration(milliseconds: 400),
            child: ActivityHeatmap(studentId: widget.studentId),
          ),
          const SizedBox(height: 16),

          // 2. Histórico de Treinos Concluídos
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: WorkoutHistorySection(studentId: widget.studentId),
          ),
          const SizedBox(height: 16),

          // 3. Recordes Pessoais (PRs)
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: PersonalRecordsCard(studentId: widget.studentId),
          ),
          const SizedBox(height: 16),

          // 4. Foco Muscular (Barras Horizontais)
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: MuscleFocusBars(studentId: widget.studentId),
          ),
          const SizedBox(height: 16),

          // 5. Evolução de Exercício
          FadeInUp(
            duration: const Duration(milliseconds: 400),
            child: ExerciseEvolutionCard(
              studentId: widget.studentId,
              availableExercises: availableExercises,
            ),
          ),
          const SizedBox(height: 24),
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
                isScrollable: false,
                tabAlignment: TabAlignment.fill,
                tabs: const [
                  Tab(icon: Icon(Icons.info_outline), text: 'Info'),
                  Tab(icon: Icon(Icons.fitness_center), text: 'Fichas'),
                  Tab(icon: Icon(Icons.restaurant_outlined), text: 'Nutrição'),
                  Tab(icon: Icon(Icons.trending_up), text: 'Evolução'),
                  Tab(icon: Icon(Icons.directions_walk), text: 'Passos'),
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
                  _buildStepsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
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
    final role = context.read<AuthProvider>().user?.role ?? 'personal_trainer';
    final canCreateProgram = hasRole(role, 'personal_trainer') || role == 'admin';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Programas de Treino',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              if (canCreateProgram)
                GestureDetector(
                  onTap: _showCreateProgramDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        const Icon(Icons.add, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text('Novo Programa',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
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
            OmniErrorState(message: _sheetsError!, onRetry: _loadStudentSheets)
          else if (_allPrograms.isEmpty)
            const OmniEmptyState(
              icon: Icons.fitness_center_outlined,
              title: 'Nenhum programa de treino',
              subtitle: 'Crie o primeiro programa para este aluno',
            )
          else
            ..._allPrograms.map((program) => _buildProgramCard(program, role)),
        ],
      ),
    );
  }

  Widget _buildProgramCard(WorkoutProgramResponse program, String role) {
    final isExpanded = _expandedProgramId == program.id;
    final isStudentOwned = program.personalTrainerId == null;
    final canEditSheets =
        (hasRole(role, 'personal_trainer') || role == 'admin') && !isStudentOwned;
    final sheets = _sheetsCache[program.id];
    final isLoadingSheets = _sheetsLoadingCache[program.id] == true;

    return FadeInUp(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border.all(
            color: isExpanded ? AppColors.primary.withOpacity(0.5) : context.colors.border,
            width: isExpanded ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // ── Cabeçalho do programa ───────────────────────────────
            GestureDetector(
              onTap: () async {
                final isClosing = _expandedProgramId == program.id;
                setState(() => _expandedProgramId = isClosing ? null : program.id);
                if (!isClosing && sheets == null) {
                  await _loadSheetsForProgram(program.id);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isStudentOwned
                            ? AppColors.accentWarning.withOpacity(0.15)
                            : AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isStudentOwned ? Icons.person_outline : Icons.fitness_center,
                        color: isStudentOwned ? AppColors.accentWarning : AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(program.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.bold)),
                              ),
                              if (program.isActive)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Ativo',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: Colors.green, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(children: [
                            if (program.goal != null)
                              Text(program.goal!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: context.colors.textMuted)),
                            if (isStudentOwned) ...[
                              if (program.goal != null) const Text(' · ', style: TextStyle(fontSize: 10)),
                              Text('Criado pelo aluno',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.accentWarning, fontWeight: FontWeight.w500)),
                            ],
                          ]),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canEditSheets)
                          GestureDetector(
                            onTap: () => _deleteProgram(program),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(Icons.delete_outline,
                                  color: AppColors.accentError, size: 18),
                            ),
                          ),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: context.colors.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Fichas (expansível) ─────────────────────────────────
            if (isExpanded) ...[
              Divider(height: 1, color: context.colors.border),
              if (isLoadingSheets)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (sheets == null || sheets.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.assignment_outlined, color: context.colors.textMuted, size: 18),
                      const SizedBox(width: 8),
                      Text('Nenhuma ficha neste programa',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: context.colors.textMuted)),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    children: sheets.map((sheet) => _buildSheetRow(sheet, canEditSheets)).toList(),
                  ),
                ),

              // Botão Nova Ficha (só para personal em programas do trainer)
              if (canEditSheets)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: GestureDetector(
                    onTap: () => _showCreateWorkoutDialog(programId: program.id),
                    child: DottedBorderContainer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add, color: AppColors.primary, size: 16),
                          const SizedBox(width: 6),
                          Text('Nova Ficha',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSheetRow(WorkoutSheetListItem sheet, bool canEdit) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Text(sheet.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sheet.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                Text('${sheet.dayOfWeekLabel} · ${sheet.exerciseCount} exercício${sheet.exerciseCount == 1 ? '' : 's'}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted)),
              ],
            ),
          ),
          // Ver exercícios — sempre visível
          GestureDetector(
            onTap: () => _showSheetDetailModal(sheet),
            child: const Icon(Icons.visibility_outlined, color: AppColors.primary, size: 18),
          ),
          if (canEdit) ...[
            const SizedBox(width: 8),
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
        ],
      ),
    );
  }

  Future<void> _showSheetDetailModal(WorkoutSheetListItem sheet) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SheetDetailModal(sheet: sheet),
    );
  }

  Future<void> _deleteProgram(WorkoutProgramResponse program) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Remover Programa'),
        content: Text(
          'Deseja remover o programa "${program.name}"?\n\n'
          'Todas as fichas e exercícios vinculados também serão removidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover', style: TextStyle(color: AppColors.accentError)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await context.read<WorkoutSheetProvider>().deleteProgram(program.id);
      _sheetsCache.remove(program.id);
      _sheetsLoadingCache.remove(program.id);
      if (_expandedProgramId == program.id) {
        setState(() => _expandedProgramId = null);
      }
      await _loadStudentSheets();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Programa removido com sucesso.'),
            backgroundColor: AppColors.accentSuccess,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao remover programa.'),
            backgroundColor: AppColors.accentError,
          ),
        );
      }
    }
  }

  Future<void> _duplicateSheetForStudent(WorkoutSheetListItem sheet) async {
    try {
      final dto = DuplicateWorkoutSheetDTO(
        name: '${sheet.name} (Cópia)',
        workoutProgramId: sheet.workoutProgramId,
      );
      await context.read<WorkoutSheetProvider>().duplicateSheet(sheet.id, dto);
      _sheetsCache.remove(sheet.workoutProgramId);
      await _loadSheetsForProgram(sheet.workoutProgramId);
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
        _sheetsCache.remove(sheet.workoutProgramId);
        await _loadSheetsForProgram(sheet.workoutProgramId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ficha removida com sucesso.'), backgroundColor: AppColors.accentSuccess),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro ao remover ficha.'), backgroundColor: AppColors.accentError),
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

    // Usa a dieta ativa se disponível; caso contrário, cria um objeto vazio
    // para não bloquear o acesso ao Diário e à aba de Análise.
    final activeDiet = _studentDiets.isNotEmpty ? _studentDiets.first : null;

    return Column(
      children: [
        // Premium Sub-tab Sliding Segment Switcher (3 abas)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          height: 44,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: context.colors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _nutritionSubTabIndex = 0;
                    });
                    _loadStudentLogbook();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _nutritionSubTabIndex == 0
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Diário',
                      style: TextStyle(
                        color: _nutritionSubTabIndex == 0
                            ? Colors.white
                            : context.colors.textMuted,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _nutritionSubTabIndex = 1;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _nutritionSubTabIndex == 1
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Plano',
                      style: TextStyle(
                        color: _nutritionSubTabIndex == 1
                            ? Colors.white
                            : context.colors.textMuted,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _nutritionSubTabIndex = 2;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _nutritionSubTabIndex == 2
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Análise',
                          style: TextStyle(
                            color: _nutritionSubTabIndex == 2
                                ? Colors.white
                                : context.colors.textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          Icons.analytics_outlined,
                          size: 12,
                          color: _nutritionSubTabIndex == 2
                              ? Colors.white
                              : context.colors.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Sub-tab content view
        Expanded(
          child: _nutritionSubTabIndex == 0
              ? _buildStudentLogbookView(activeDiet)
              : _nutritionSubTabIndex == 1
                  ? (activeDiet != null
                      ? _buildDietPrescriptionView(activeDiet)
                      : _buildEmptyDietView())
                  : _buildNutritionAnalyticsView(activeDiet),
        ),
      ],
    );
  }

  Widget _buildNutritionAnalyticsView(Diet? activeDiet) {
    final nutritionService = context.read<NutritionService>();
    return TrainerNutritionAnalyticsTab(
      studentId: widget.studentId,
      nutritionService: nutritionService,
      studentWeightKg: _student?.weight,
      activeDiet: activeDiet,
    );
  }


  Widget _buildDietPrescriptionView(Diet activeDiet) {
    final sortedMeals = List<DietMeal>.from(activeDiet.meals);
    sortedMeals.sort((a, b) {
      if (a.time == null && b.time == null) return 0;
      if (a.time == null) return 1;
      if (b.time == null) return -1;
      return a.time!.compareTo(b.time!);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          ...sortedMeals.map((m) {
            final nameParts = m.name.split(' || ');
            final displayName = nameParts.first;
            final displayDesc = nameParts.length > 1 ? nameParts[1] : '';

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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(displayName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                              if (displayDesc.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    displayDesc,
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: context.colors.textMuted,
                                          fontStyle: FontStyle.italic,
                                        ),
                                  ),
                                ),
                              Text(
                                '${m.time ?? "--:--"} • ${m.subtotalKcal.toStringAsFixed(0)} kcal',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted),
                              ),
                            ],
                          ),
                        ),
                        Builder(builder: (context) {
                          final role = context.read<AuthProvider>().user?.role ?? 'personal_trainer';
                          final canEditDiet = hasRole(role, 'nutritionist') || role == 'admin';
                          if (!canEditDiet) return const SizedBox.shrink();
                          return Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showEditMealDialog(activeDiet, m),
                                child: Icon(Icons.edit, color: context.colors.textMuted, size: 16),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => _deleteMeal(activeDiet, m),
                                child: const Icon(Icons.delete_outline, color: AppColors.accentError, size: 16),
                              ),
                            ],
                          );
                        }),
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
          const SizedBox(height: 8),
          Builder(builder: (context) {
            final role = context.read<AuthProvider>().user?.role ?? 'personal_trainer';
            final canEditDiet = hasRole(role, 'nutritionist') || role == 'admin';
            if (!canEditDiet) return const SizedBox.shrink();
            return SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showAddMealDialog(activeDiet),
                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: const Text('Adicionar Refeição', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
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

  Widget _buildStudentLogbookView(Diet? activeDiet) {
    if (_studentLogbookLoading && _studentLogbook == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalTargetKcal = activeDiet?.totalKcal ?? 2000.0;
    final totalTargetProtein = activeDiet?.totalProtein ?? 120.0;
    final totalTargetCarbs = activeDiet?.totalCarbs ?? 250.0;
    final totalTargetFats = activeDiet?.totalFats ?? 55.0;
    final waterTargetMl = activeDiet?.waterTargetMl ?? 2500;

    final currentKcal = _studentLogbook?.totalKcal ?? 0.0;
    final currentProtein = _studentLogbook?.totalProtein ?? 0.0;
    final currentCarbs = _studentLogbook?.totalCarbs ?? 0.0;
    final currentFats = _studentLogbook?.totalFats ?? 0.0;

    // Agrupar entradas por refeição ordenadas cronologicamente
    final Map<String, List<DietLogbookEntry>> tempGroupedEntries = {};
    if (_studentLogbook != null) {
      for (final entry in _studentLogbook!.entries) {
        tempGroupedEntries.putIfAbsent(entry.mealName, () => []).add(entry);
      }
    }

    const mealOrder = [
      'Café da Manhã',
      'Cafe da Manha',
      'Lanche da Manhã',
      'Almoço',
      'Almoco',
      'Lanche da Tarde',
      'Lanche',
      'Pré-Treino',
      'Pós-Treino',
      'Jantar',
      'Ceia',
    ];

    final sortedMealKeys = tempGroupedEntries.keys.toList()..sort((a, b) {
      int idxA = mealOrder.indexOf(a);
      int idxB = mealOrder.indexOf(b);
      if (idxA == -1) idxA = 999;
      if (idxB == -1) idxB = 999;
      if (idxA != idxB) return idxA.compareTo(idxB);
      return a.compareTo(b);
    });

    final Map<String, List<DietLogbookEntry>> groupedEntries = {};
    for (final key in sortedMealKeys) {
      groupedEntries[key] = tempGroupedEntries[key]!;
    }

    return RefreshIndicator(
      onRefresh: _loadStudentLogbook,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Navegador de Datas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: context.colors.textPrimary),
                  onPressed: () {
                    setState(() {
                      _selectedLogbookDate = _selectedLogbookDate.subtract(const Duration(days: 1));
                    });
                    _loadStudentLogbook();
                  },
                ),
                Text(
                  _getFormattedDateLabel(_selectedLogbookDate),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: context.colors.textPrimary),
                  onPressed: () {
                    setState(() {
                      _selectedLogbookDate = _selectedLogbookDate.add(const Duration(days: 1));
                    });
                    _loadStudentLogbook();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Grid de Consistência Semanal (Últimos 7 dias)
            _buildWeeklyConsistencyGrid(totalTargetKcal),
            const SizedBox(height: 20),

            // 3. Progresso Nutricional Diário (Macronutrientes)
            _buildMacronutrientsProgressCard(
              currentKcal: currentKcal,
              targetKcal: totalTargetKcal,
              currentProtein: currentProtein,
              targetProtein: totalTargetProtein,
              currentCarbs: currentCarbs,
              targetCarbs: totalTargetCarbs,
              currentFats: currentFats,
              targetFats: totalTargetFats,
            ),

            const SizedBox(height: 20),

            // 5. Card de Hidratação Interativo
            _buildHydrationInteractiveCard(waterTargetMl),
            const SizedBox(height: 20),

            // 6. Lista de Refeições Logadas
            Text(
              'Alimentos Consumidos',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            if (groupedEntries.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.restaurant_outlined, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(
                      'Nenhum alimento registrado hoje.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: context.colors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Os registros que o aluno realizar no aplicativo aparecerão aqui.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: context.colors.textMuted,
                          ),
                    ),
                  ],
                ),
              )
            else
              ...groupedEntries.entries.map((mealGroup) {
                final mealName = mealGroup.key;
                final entriesList = mealGroup.value;
                final mealKcal = entriesList.fold<double>(0, (sum, item) => sum + item.kcal);
                final mealProtein = entriesList.fold<double>(0, (sum, item) => sum + item.protein);
                final mealCarbs = entriesList.fold<double>(0, (sum, item) => sum + item.carbs);
                final mealFats = entriesList.fold<double>(0, (sum, item) => sum + item.fats);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
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
                          Text(
                            mealName,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            '${mealKcal.toStringAsFixed(0)} kcal',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('P: ${mealProtein.toStringAsFixed(1)}g', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textSecondary)),
                          Text('C: ${mealCarbs.toStringAsFixed(1)}g', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textSecondary)),
                          Text('G: ${mealFats.toStringAsFixed(1)}g', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textSecondary)),
                        ],
                      ),
                      const Divider(height: 16),
                      ...entriesList.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.foodName,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    Text(
                                      '${entry.quantityG.toStringAsFixed(0)}g • P:${entry.protein.toStringAsFixed(0)}g C:${entry.carbs.toStringAsFixed(0)}g G:${entry.fats.toStringAsFixed(0)}g',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: context.colors.textMuted,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${entry.kcal.toStringAsFixed(0)} kcal',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              }).toList(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _getFormattedDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Hoje 📅';
    if (diff == -1) return 'Ontem ⬅️';
    if (diff == 1) return 'Amanhã ➡️';

    final List<String> weekdays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];
    final List<String> months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    
    return '${weekdays[date.weekday % 7]}, ${date.day} de ${months[date.month - 1]}';
  }

  Widget _buildWeeklyConsistencyGrid(double targetKcal) {
    final weekdays = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
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
          Text(
            'Consistência Semanal (Calorias)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final date = _selectedLogbookDate.subtract(Duration(days: 6 - index));
              final weekdayName = weekdays[(date.weekday - 1) % 7];
              final kcal = _studentLast7DaysCalories[index];
              final logged = _studentLast7DaysLogged[index];

              Color circleColor = Colors.grey.withOpacity(0.3);
              Widget innerWidget = Text(
                weekdayName,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.colors.textSecondary,
                    ),
              );

              if (logged) {
                final diffRatio = (kcal - targetKcal).abs() / targetKcal;
                if (diffRatio <= 0.15) {
                  circleColor = AppColors.accentSuccess; // Perfeita consistência
                  innerWidget = const Icon(Icons.check, size: 14, color: Colors.white);
                } else {
                  circleColor = AppColors.accentWarning; // Logou mas variou
                  innerWidget = const Icon(Icons.local_fire_department, size: 14, color: Colors.white);
                }
              }

              final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;

              return Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: logged ? circleColor : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isToday ? AppColors.primary : circleColor,
                        width: isToday ? 2.5 : 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: innerWidget,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${date.day}/${date.month}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isToday ? AppColors.primary : context.colors.textMuted,
                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          fontSize: 9,
                        ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMacronutrientsProgressCard({
    required double currentKcal,
    required double targetKcal,
    required double currentProtein,
    required double targetProtein,
    required double currentCarbs,
    required double targetCarbs,
    required double currentFats,
    required double targetFats,
  }) {
    final kcalPercent = targetKcal > 0 ? (currentKcal / targetKcal) : 0.0;
    final proteinPercent = targetProtein > 0 ? (currentProtein / targetProtein) : 0.0;
    final carbsPercent = targetCarbs > 0 ? (currentCarbs / targetCarbs) : 0.0;
    final fatsPercent = targetFats > 0 ? (currentFats / targetFats) : 0.0;

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
              Text(
                'Macronutrientes Logados',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              Text(
                '${(kcalPercent * 100).toStringAsFixed(0)}% da meta',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: kcalPercent > 1.1 ? AppColors.accentWarning : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progresso de Calorias
          _buildMacProgressBar(
            label: 'Calorias',
            current: currentKcal,
            target: targetKcal,
            percent: kcalPercent,
            color: Colors.deepOrange,
            unit: 'kcal',
          ),
          const SizedBox(height: 12),

          // Proteínas
          _buildMacProgressBar(
            label: 'Proteínas',
            current: currentProtein,
            target: targetProtein,
            percent: proteinPercent,
            color: AppColors.macroProtein,
            unit: 'g',
          ),
          const SizedBox(height: 12),

          // Carboidratos
          _buildMacProgressBar(
            label: 'Carboidratos',
            current: currentCarbs,
            target: targetCarbs,
            percent: carbsPercent,
            color: AppColors.macroCarbs,
            unit: 'g',
          ),
          const SizedBox(height: 12),

          // Gorduras
          _buildMacProgressBar(
            label: 'Gorduras',
            current: currentFats,
            target: targetFats,
            percent: fatsPercent,
            color: AppColors.macroFat,
            unit: 'g',
          ),
        ],
      ),
    );
  }

  Widget _buildMacProgressBar({
    required String label,
    required double current,
    required double target,
    required double percent,
    required Color color,
    required String unit,
  }) {
    final limitedPercent = percent.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Text(
              '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: limitedPercent,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }



  void _showCustomWaterTrainerDialog(BuildContext context) {
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
                'Registrar Hidratação',
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
                  ActionChip(
                    label: const Text('+300 ml'),
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                    backgroundColor: Colors.blue.withOpacity(0.08),
                    side: const BorderSide(color: Colors.blue, width: 0.8),
                    onPressed: () {
                      controller.text = '300';
                    },
                  ),
                  ActionChip(
                    label: const Text('+600 ml'),
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                    backgroundColor: Colors.blue.withOpacity(0.08),
                    side: const BorderSide(color: Colors.blue, width: 0.8),
                    onPressed: () {
                      controller.text = '600';
                    },
                  ),
                  ActionChip(
                    label: const Text('+1000 ml'),
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue),
                    backgroundColor: Colors.blue.withOpacity(0.08),
                    side: const BorderSide(color: Colors.blue, width: 0.8),
                    onPressed: () {
                      controller.text = '1000';
                    },
                  ),
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
                    _updateStudentWater(val);
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

  Widget _buildHydrationInteractiveCard(int targetMl) {
    final percent = targetMl > 0 ? (_studentWaterToday / targetMl).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A5298).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.local_drink_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Controle de Hidratação',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              Text(
                '${(_studentWaterToday)} / $targetMl ml',
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4FC3F7)),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: _resetStudentWater,
                icon: const Icon(Icons.refresh, color: Colors.white70, size: 16),
                label: const Text(
                  'Zerar',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () => _updateStudentWater(250),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('+250ml', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _updateStudentWater(500),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('+500ml', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: () => _showCustomWaterTrainerDialog(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.35),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Outro', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
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
              Builder(builder: (context) {
                final role = context.read<AuthProvider>().user?.role ?? 'personal_trainer';
                final canEditDiet = hasRole(role, 'nutritionist') || role == 'admin';
                if (!canEditDiet) return const SizedBox.shrink();
                return ElevatedButton.icon(
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
                );
              }),
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

  Widget _buildEmptyDietView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const OmniEmptyState(
              icon: Icons.restaurant_outlined,
              title: 'Nenhum plano nutricional',
              subtitle: 'Este aluno ainda não possui uma dieta prescrita.',
            ),
            const SizedBox(height: 24),
            Builder(builder: (context) {
              final role = context.read<AuthProvider>().user?.role ?? 'personal_trainer';
              final canCreate = hasRole(role, 'nutritionist') || role == 'admin';
              if (!canCreate) return const SizedBox.shrink();
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _createInitialDiet,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Criar Plano Nutricional'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _createInitialDiet() async {
    setState(() => _nutritionLoading = true);
    try {
      final apiClient = context.read<ApiClient>();
      final response = await apiClient.post<Map<String, dynamic>>(
        '/diets',
        body: {
          'user_id': widget.studentId,
          'name': 'Plano Nutricional Inicial',
          'goal': 'maintenance',
          'meals': [
            {
              'name': 'Café da Manhã',
              'time': '08:00',
              'order': 1,
              'items': [],
            }
          ],
          'water_target_ml': 2500,
        },
        fromJson: (data) => data as Map<String, dynamic>,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Plano nutricional criado! Agora você pode adicionar as refeições.'),
            backgroundColor: AppColors.accentSuccess,
          ),
        );
        _loadStudentNutrition();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _nutritionError = 'Erro ao criar plano: ${e.toString()}';
          _nutritionLoading = false;
        });
      }
    }
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
        return 'Ganho de Massa';
      case 'lose_weight':
        return 'Perda de Peso';
      case 'maintain':
      case 'maintenance':
        return 'Manutenção';
      case 'endurance':
        return 'Resistência';
      case 'bulking':
        return 'Bulking';
      case 'cutting':
        return 'Cutting';
      default:
        return goalType == null || goalType.isEmpty ? 'Não informado' : goalType;
    }
  }

  String _mapGenderToPt(String? gender) {
    switch (gender) {
      case 'male':
        return 'Masculino';
      case 'female':
        return 'Feminino';
      default:
        return gender == null || gender.isEmpty ? 'Não informado' : gender;
    }
  }

  Future<void> _showCreateWorkoutDialog({String? programId}) async {
    final targetProgramId = programId ?? _activeProgram?.id;
    if (targetProgramId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione um programa para adicionar a ficha.')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CreateWorkoutSheetDialog(workoutProgramId: targetProgramId),
    );
    if (result == true && mounted) {
      // Invalida cache para recarregar fichas do programa
      _sheetsCache.remove(targetProgramId);
      await _loadSheetsForProgram(targetProgramId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ficha criada com sucesso!'), backgroundColor: AppColors.accentSuccess),
      );
    }
  }

  Future<void> _showCreateProgramDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => CreateWorkoutProgramDialog(userId: widget.studentId),
    );
    if (result == true && mounted) {
      setState(() {
        _sheetsCache.clear();
        _sheetsLoadingCache.clear();
      });
      await _loadStudentSheets();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Programa criado com sucesso!'), backgroundColor: AppColors.accentSuccess),
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
      _sheetsCache.remove(sheet.workoutProgramId);
      await _loadSheetsForProgram(sheet.workoutProgramId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ficha atualizada com sucesso.'), backgroundColor: AppColors.accentSuccess),
      );
    }
  }

  Future<void> _showEditMealDialog(Diet activeDiet, DietMeal targetMeal) async {
    final nutritionService = context.read<NutritionService>();
    final nameParts = targetMeal.name.split(' || ');
    final initialName = nameParts.first;
    final initialDesc = nameParts.length > 1 ? nameParts[1] : '';

    final mealNameController = TextEditingController(text: initialName);
    final mealTimeController = TextEditingController(text: targetMeal.time ?? '');
    final mealDescController = TextEditingController(text: initialDesc);

    final editableItems = targetMeal.items
        .map((item) => _EditableDietItem(
              foodId: item.foodId,
              customFoodId: item.customFoodId,
              foodName: item.foodName,
              quantityG: item.quantityG,
              observations: item.observations,
            ))
        .toList();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: context.colors.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Editar $initialName', style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: mealNameController,
                    decoration: const InputDecoration(labelText: 'Nome da refeição'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: mealDescController,
                    decoration: const InputDecoration(labelText: 'Descrição / Observações da refeição'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: mealTimeController,
                    decoration: const InputDecoration(labelText: 'Horário (HH:MM)'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => FractionallySizedBox(
                          heightFactor: 0.9,
                          child: FoodSearchModal(
                            isTrainer: true,
                            activeDiet: activeDiet,
                            onFoodSelected: (food, quantity, meal) {
                              setModalState(() {
                                editableItems.add(
                                  _EditableDietItem(
                                    foodId: food.source == 'taco' ? int.tryParse(food.id) : null,
                                    customFoodId: food.source == 'custom' ? food.id : null,
                                    foodName: food.name,
                                    quantityG: quantity,
                                  ),
                                );
                              });
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Buscar no Catálogo Completo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  if (editableItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'Nenhum alimento nesta refeição.',
                          style: TextStyle(color: context.colors.textMuted),
                        ),
                      ),
                    )
                  else
                    ...editableItems.asMap().entries.map(
                      (entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.foodName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 90,
                                    child: TextFormField(
                                      initialValue: item.quantityG.toStringAsFixed(0),
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(
                                        suffixText: 'g',
                                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        isDense: true,
                                      ),
                                      onChanged: (v) => item.quantityG = double.tryParse(v) ?? item.quantityG,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.accentError),
                                    onPressed: () => setModalState(() => editableItems.removeAt(index)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              TextFormField(
                                initialValue: item.observations ?? '',
                                decoration: const InputDecoration(
                                  hintText: 'Descrição/Obs do alimento (ex: grelhado, fatiado)',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  isDense: true,
                                ),
                                style: const TextStyle(fontSize: 12),
                                onChanged: (v) => item.observations = v.trim().isEmpty ? null : v.trim(),
                              ),
                              const SizedBox(height: 4),
                              const Divider(height: 1),
                            ],
                          ),
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
              child: Text('Cancelar', style: TextStyle(color: context.colors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                if (mealNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Por favor, informe o nome da refeição.')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (shouldSave != true) return;

    try {
      final finalMealName = mealDescController.text.trim().isEmpty
          ? mealNameController.text.trim()
          : '${mealNameController.text.trim()} || ${mealDescController.text.trim()}';

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
          'name': finalMealName,
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

  void _showAddMealDialog(Diet activeDiet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FoodSearchModal(
        isTrainer: true,
        activeDiet: activeDiet,
        onFoodSelected: (food, quantity, meal) async {
          try {
            final nutritionService = context.read<NutritionService>();
            
            final existingMealIdx = activeDiet.meals.indexWhere((m) {
              final nameOnly = m.name.split(' || ').first.trim();
              return nameOnly.toLowerCase() == meal.toLowerCase();
            });

            final updatedMeals = activeDiet.meals.map((m) {
              return {
                'name': m.name,
                'time': m.time,
                'order': m.order,
                'items': m.items.map((i) => {
                  if (i.foodId != null) 'food_id': i.foodId,
                  if (i.customFoodId != null) 'custom_food_id': i.customFoodId,
                  'quantity_g': i.quantityG,
                  if (i.observations != null) 'observations': i.observations,
                }).toList(),
              };
            }).toList();

            if (existingMealIdx != -1) {
              final itemsList = updatedMeals[existingMealIdx]['items'] as List<dynamic>;
              itemsList.add({
                if (food.source == 'taco') 'food_id': int.tryParse(food.id),
                if (food.source == 'custom') 'custom_food_id': food.id,
                'quantity_g': quantity,
              });
            } else {
              updatedMeals.add({
                'name': meal,
                'time': null,
                'order': activeDiet.meals.length + 1,
                'items': [
                  {
                    if (food.source == 'taco') 'food_id': int.tryParse(food.id),
                    if (food.source == 'custom') 'custom_food_id': food.id,
                    'quantity_g': quantity,
                  }
                ],
              });
            }

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
                  content: Text('Alimento adicionado à dieta com sucesso!'),
                  backgroundColor: AppColors.accentSuccess,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao atualizar dieta: $e'),
                  backgroundColor: AppColors.accentError,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Future<void> _deleteMeal(Diet activeDiet, DietMeal mealToDelete) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: const Text('Excluir Refeição'),
        content: Text('Tem certeza de que deseja excluir a refeição "${mealToDelete.name}" de forma permanente?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: context.colors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentError,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final nutritionService = context.read<NutritionService>();
    try {
      final updatedMeals = activeDiet.meals
          .where((m) => m.id != mealToDelete.id)
          .map((meal) {
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
          })
          .toList();

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
            content: Text('Refeição excluída com sucesso.'),
            backgroundColor: AppColors.accentSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir refeição: ${e.toString()}'),
            backgroundColor: AppColors.accentError,
          ),
        );
      }
    }
  }



  // ----- Aba de Passos -----

  static const _kHandicapColor = Color(0xFFF59E0B);

  Widget _buildStepsTab() {
    if (_stepsLoading) {
      return const OmniLoader();
    }
    if (_stepsError != null) {
      return OmniErrorState(
        message: _stepsError!,
        onRetry: _loadStepHistory,
      );
    }
    final history = _stepHistory;
    
    // Se estiver carregando e ainda não temos histórico (primeira carga), mostramos o loader
    // para evitar o flash de "Sem registros".
    if (_stepsLoading && history == null) {
      return const OmniLoader();
    }

    if (history == null || history.logs.isEmpty) {
      return const OmniEmptyState(
        icon: Icons.directions_walk,
        title: 'Sem registros de passos',
        subtitle: 'Este aluno ainda não sincronizou nenhum dia.',
      );
    }

    final weekCalories = history.logs.fold<double>(
        0.0, (s, l) => s + l.caloriesBurned);

    return RefreshIndicator(
      onRefresh: _loadStepHistory,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepsSummary(history, weekCalories),
            const SizedBox(height: 16),
            Text(
              'Série histórica (últimos 30 dias)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildStepsLineChart(history),
            const SizedBox(height: 24),
            Text(
              'Histórico',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ..._sortLogsDesc(history.logs).take(30).map(_buildStepRow),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsSummary(StepHistory history, double weekCalories) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCell(
                label: 'Semana atual',
                value: _formatThousands(history.currentWeekTotal),
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCell(
                label: 'Melhor dia',
                value: _formatThousands(history.allTimeRecord),
                color: context.colors.textPrimary,
                badge: '🏆',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCell(
                label: 'Sequência',
                value: '${history.currentStreak} ${history.currentStreak == 1 ? 'dia' : 'dias'} 🔥',
                color: history.currentStreak > 0
                    ? AppColors.primary
                    : context.colors.textSecondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCell(
                label: 'kcal (semana)',
                value: '${weekCalories.toStringAsFixed(0)} kcal',
                color: _kHandicapColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTrainerGoalEditor(history),
      ],
    );
  }

  Widget _buildTrainerGoalEditor(StepHistory history) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                  'Meta diária do aluno',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.textSecondary,
                      ),
                ),
                Text(
                  '${_formatThousands(history.dailyGoal)} passos/dia',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () => _showTrainerGoalDialog(history.dailyGoal),
            icon: const Icon(Icons.edit, size: 16),
            label: const Text('Editar'),
          ),
        ],
      ),
    );
  }

  void _showTrainerGoalDialog(int currentGoal) {
    final controller = TextEditingController(text: currentGoal.toString());
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Meta diária de passos'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
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
            onPressed: () async {
              final val = int.tryParse(controller.text);
              if (val != null && val >= 100) {
                Navigator.of(ctx).pop();
                try {
                  final apiClient = context.read<ApiClient>();
                  final stepService = StepService(apiClient: apiClient);
                  await stepService.updateStudentGoal(
                      widget.studentId, val);
                  await _loadStepHistory();
                } catch (_) {}
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Widget _summaryCell({
    required String label,
    required String value,
    required Color color,
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
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsLineChart(StepHistory history) {
    final logs = List<StepLog>.from(history.logs)
      ..sort((a, b) => a.date.compareTo(b.date));

    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }

    final spots = List<FlSpot>.generate(
      logs.length,
      (i) => FlSpot(i.toDouble(), logs[i].steps.toDouble()),
    );
    final maxY = logs.fold<int>(0, (m, l) => l.steps > m ? l.steps : m);
    final yMax = maxY > 0 ? maxY * 1.15 : 1000.0;

    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          maxY: yMax.toDouble(),
          minY: 0,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, __, idx) {
                  final isHandicap = logs[idx].handicapLevel != null;
                  return FlDotCirclePainter(
                    radius: 3,
                    color: isHandicap ? _kHandicapColor : AppColors.primary,
                    strokeWidth: 0,
                    strokeColor: Colors.transparent,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),
          ],
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: (logs.length / 6).ceilToDouble().clamp(1.0, 10.0),
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= logs.length) {
                    return const SizedBox.shrink();
                  }
                  final d = logs[idx].date;
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${d.day}/${d.month}',
                      style: const TextStyle(fontSize: 9),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const SizedBox.shrink();
                  final v = value.toInt();
                  return Text(
                    v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : '$v',
                    style: const TextStyle(fontSize: 9),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }

  Widget _buildStepRow(StepLog log) {
    final isHandicap = log.handicapLevel != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(
          color: isHandicap
              ? _kHandicapColor.withValues(alpha: 0.4)
              : context.colors.border,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
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
            _formatThousands(log.steps),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isHandicap ? _kHandicapColor : null,
                ),
          ),
          if (log.isAllTimeRecord) ...[
            const SizedBox(width: 6),
            const Text('🏆'),
          ],
        ],
      ),
    );
  }

  static List<StepLog> _sortLogsDesc(List<StepLog> logs) {
    final list = List<StepLog>.from(logs);
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  static String _formatThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }
}

// ---------------------------------------------------------------------------
// Widgets auxiliares
// ---------------------------------------------------------------------------

class DottedBorderContainer extends StatelessWidget {
  final Widget child;
  const DottedBorderContainer({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DottedBorderPainter(color: AppColors.primary.withOpacity(0.5)),
      child: Padding(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16), child: child),
    );
  }
}

class _DottedBorderPainter extends CustomPainter {
  final Color color;
  _DottedBorderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dashWidth = 5.0;
    const dashSpace = 4.0;
    final radius = Radius.circular(8);
    final rRect = RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), radius);
    final path = Path()..addRRect(rRect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dashWidth), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Modal de detalhes de ficha de treino (leitura — disponível para todos)
// ---------------------------------------------------------------------------

class _SheetDetailModal extends StatefulWidget {
  final WorkoutSheetListItem sheet;
  const _SheetDetailModal({required this.sheet});

  @override
  State<_SheetDetailModal> createState() => _SheetDetailModalState();
}

class _SheetDetailModalState extends State<_SheetDetailModal> {
  WorkoutSheetResponse? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final service = WorkoutSheetService(
        apiClient: context.read<ApiClient>(),
      );
      final detail = await service.getWorkoutSheet(widget.sheet.id);
      if (mounted) setState(() { _detail = detail; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sheet = widget.sheet;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(sheet.emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sheet.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${sheet.dayOfWeekLabel} • ${sheet.exerciseCount} exercício${sheet.exerciseCount == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: colors.textMuted,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Body
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.accentError, size: 32),
                              const SizedBox(height: 8),
                              Text('Erro ao carregar exercícios', style: Theme.of(context).textTheme.bodyMedium),
                              TextButton(onPressed: _load, child: const Text('Tentar novamente')),
                            ],
                          ),
                        )
                      : _detail == null || _detail!.exercises.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.fitness_center_outlined, color: colors.textMuted, size: 40),
                                  const SizedBox(height: 12),
                                  Text('Nenhum exercício nesta ficha', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textMuted)),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: controller,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              itemCount: _detail!.exercises.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final ex = _detail!.exercises[i];
                                return _ExerciseCard(exercise: ex);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final ExerciseResponse exercise;
  const _ExerciseCard({required this.exercise});

  String get _muscleLabel {
    const labels = {
      'peito': 'Peito',
      'costa': 'Costas',
      'ombro': 'Ombro',
      'bíceps': 'Bíceps',
      'tríceps': 'Tríceps',
      'antebraço': 'Antebraço',
      'core': 'Core / Abdômen',
      'perna_anterior': 'Perna (Quadríceps)',
      'perna_posterior': 'Perna (Posterior)',
      'panturrilha': 'Panturrilha',
    };
    return labels[exercise.muscleGroup] ?? exercise.muscleGroup;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagem do exercício
          if (exercise.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                exercise.imageUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 80,
                  color: colors.background,
                  child: Icon(Icons.fitness_center, color: colors.textMuted, size: 32),
                ),
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : Container(
                        height: 140,
                        color: colors.background,
                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _muscleLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Stats: séries × reps × carga × descanso
                Row(
                  children: [
                    _Stat(label: 'Séries', value: '${exercise.series}'),
                    const SizedBox(width: 16),
                    _Stat(label: 'Reps', value: '${exercise.repetitions}'),
                    const SizedBox(width: 16),
                    _Stat(label: 'Carga', value: exercise.loadKg > 0 ? '${exercise.loadKg.toStringAsFixed(exercise.loadKg % 1 == 0 ? 0 : 1)} kg' : 'Livre'),
                    const SizedBox(width: 16),
                    _Stat(label: 'Descanso', value: '${exercise.restSeconds}s'),
                  ],
                ),
                if (exercise.observations != null && exercise.observations!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    exercise.observations!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted)),
        const SizedBox(height: 2),
        Text(value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
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
