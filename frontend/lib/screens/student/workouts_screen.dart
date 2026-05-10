import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';

import 'package:omniconnect_fitness/theme/app_colors.dart';
import 'package:omniconnect_fitness/theme/theme_colors.dart';
import 'package:omniconnect_fitness/models/workout_sheet_model.dart';
import 'package:omniconnect_fitness/providers/auth_provider.dart';
import 'package:omniconnect_fitness/providers/workout_sheet_provider.dart';
import 'package:omniconnect_fitness/providers/logbook_provider.dart';
import 'package:omniconnect_fitness/services/api_client.dart';
import 'package:omniconnect_fitness/shared/widgets/index.dart';
import 'package:omniconnect_fitness/widgets/frequency_bar_chart.dart';
import 'package:omniconnect_fitness/widgets/progression_line_chart.dart';

class WorkoutsScreen extends StatefulWidget {
  const WorkoutsScreen({super.key});

  @override
  State<WorkoutsScreen> createState() => _WorkoutsScreenState();
}

class _WorkoutsScreenState extends State<WorkoutsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Controle de Sessão de Treino Ativo (Hevy Style)
  String? _activeSessionId;
  WorkoutSheetResponse? _activeSheet;
  Timer? _chronometerTimer;
  int _elapsedSeconds = 0;
  
  // Mapas para salvar dados digitados em tempo real na sessão de treino
  // exerciseId -> List de flags de conclusão de séries
  final Map<String, List<bool>> _setsChecked = {};
  // exerciseId -> List de cargas reais para cada série
  final Map<String, List<double>> _setsLoads = {};
  // exerciseId -> List de repetições reais para cada série
  final Map<String, List<int>> _setsReps = {};

  // Rest Timer State
  int? _restTimerSeconds;
  Timer? _restTimer;

  // Filtros / Seleções para Aba Progresso
  String _selectedPeriod = 'weekly';
  String? _progressionExerciseId;

  // Estado para Confetes / Tela de Sucesso
  bool _showSuccessOverlay = false;
  int _lastWorkoutDuration = 0;
  double _lastWorkoutTotalLoad = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _handleTabSelection() {
    if (_tabController.index == 1) {
      _loadProgressData();
    }
  }

  Future<void> _loadInitialData() async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;
    if (userId == null) return;

    try {
      final sheetProvider = context.read<WorkoutSheetProvider>();
      await sheetProvider.loadPrograms(userId: userId);
      
      if (sheetProvider.programs.isNotEmpty) {
        // Seleciona o programa ativo como padrão
        final activeProg = sheetProvider.programs.firstWhere(
          (p) => p.isActive, 
          orElse: () => sheetProvider.programs.first,
        );
        sheetProvider.selectProgram(activeProg);
        await sheetProvider.loadSheets(workoutProgramId: activeProg.id);
      }
    } catch (_) {}
  }

  Future<void> _loadProgressData() async {
    try {
      final logbookProvider = context.read<LogbookProvider>();
      await logbookProvider.loadFrequency(_selectedPeriod, limit: 12);
      await logbookProvider.loadMuscleGroupDistribution(days: 30);
      
      // Se tivermos exercícios nos treinos do usuário, seleciona o primeiro para progressão por padrão
      final sheetProvider = context.read<WorkoutSheetProvider>();
      if (sheetProvider.sheets.isNotEmpty && _progressionExerciseId == null) {
        // Carrega os detalhes do primeiro treino para extrair um exercício válido
        final firstSheet = sheetProvider.sheets.first;
        await sheetProvider.loadSheetDetail(firstSheet.id);
        if (sheetProvider.selectedSheet != null && sheetProvider.selectedSheet!.exercises.isNotEmpty) {
          final exercise = sheetProvider.selectedSheet!.exercises.first;
          setState(() {
            _progressionExerciseId = exercise.id;
          });
          await logbookProvider.loadExerciseProgression(exercise.id, weeks: 8);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    _chronometerTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  // --- CRONÔMETRO ---
  void _startChronometer() {
    _chronometerTimer?.cancel();
    _elapsedSeconds = 0;
    _chronometerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // --- TIMER DE DESCANSO ---
  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    setState(() => _restTimerSeconds = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_restTimerSeconds! > 0) {
            _restTimerSeconds = _restTimerSeconds! - 1;
          } else {
            _restTimer?.cancel();
            _restTimerSeconds = null;
            // Alerta sonoro / visual de conclusão de descanso
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🕒 Descanso concluído! Volte para a próxima série! 🔥'),
                duration: Duration(seconds: 3),
                backgroundColor: AppColors.primary,
              ),
            );
          }
        });
      }
    });
  }

  // --- GERENCIAMENTO DE EXERCÍCIOS ATIVOS ---
  void _initializeActiveSheetData(WorkoutSheetResponse sheet) {
    _setsChecked.clear();
    _setsLoads.clear();
    _setsReps.clear();

    for (var exercise in sheet.exercises) {
      _setsChecked[exercise.id] = List.generate(exercise.series, (_) => false);
      _setsLoads[exercise.id] = List.generate(exercise.series, (_) => exercise.loadKg);
      _setsReps[exercise.id] = List.generate(exercise.series, (_) => exercise.repetitions);
    }
  }

  // Iniciar sessão de treino na API
  Future<void> _startWorkoutSession(WorkoutSheetResponse sheet) async {
    final logbookProvider = context.read<LogbookProvider>();
    try {
      final sessionData = await logbookProvider.startActiveSession(sheet.id);
      setState(() {
        _activeSessionId = sessionData['id'] as String;
        _activeSheet = sheet;
        _initializeActiveSheetData(sheet);
        _startChronometer();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🔥 Treino "${sheet.name}" iniciado! Siga a sequência.'),
          backgroundColor: AppColors.accentSuccess,
        ),
      );
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        // Sessão já em andamento! Oferece para recuperar ou sobrescrever.
        _showRecoveryDialog(sheet);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao iniciar treino: ${e.message}'), backgroundColor: AppColors.accentError),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao conectar ao servidor: $e'), backgroundColor: AppColors.accentError),
      );
    }
  }

  void _showRecoveryDialog(WorkoutSheetResponse sheet) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Treino em Andamento ⚠️'),
        content: const Text(
          'Você já possui uma sessão de treino ativa em progresso. Deseja substituí-la por esta nova sessão?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.accentError),
            onPressed: () async {
              Navigator.pop(ctx);
              // Força o encerramento da sessão em progresso para iniciar uma nova
              // Para simplificar, excluímos ou finalizamos a anterior de forma silenciosa e iniciamos
              final logbookProvider = context.read<LogbookProvider>();
              await logbookProvider.loadSessions(limit: 1);
              if (logbookProvider.sessions.isNotEmpty) {
                final lastSess = logbookProvider.sessions.first;
                if (lastSess.status == 'in_progress' || lastSess.exercises.isEmpty) {
                  await logbookProvider.deleteSession(lastSess.id);
                }
              }
              _startWorkoutSession(sheet);
            },
            child: const Text('Substituir'),
          ),
        ],
      ),
    );
  }

  // Alterna o status do set/série
  void _toggleSetCheck(String exerciseId, int setIndex, int restSeconds) {
    final currentStatus = _setsChecked[exerciseId]![setIndex];
    setState(() {
      _setsChecked[exerciseId]![setIndex] = !currentStatus;
    });

    if (!currentStatus) {
      // Ativou o set, dispara cronômetro de descanso
      _startRestTimer(restSeconds);
    }
  }

  // Salva alteração de carga em tempo real
  void _onLoadChanged(String exerciseId, int setIndex, String value) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      _setsLoads[exerciseId]![setIndex] = parsed;
    }
  }

  // Salva alteração de repetição em tempo real
  void _onRepsChanged(String exerciseId, int setIndex, String value) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      _setsReps[exerciseId]![setIndex] = parsed;
    }
  }

  // Finaliza a sessão salvando todos os dados reais
  Future<void> _finishWorkout() async {
    if (_activeSheet == null || _activeSessionId == null) return;

    // Calcula volume total levantado para as estatísticas premium
    double totalLoad = 0;
    int completedSetsCount = 0;

    for (var exercise in _activeSheet!.exercises) {
      final checked = _setsChecked[exercise.id] ?? [];
      final loads = _setsLoads[exercise.id] ?? [];
      final reps = _setsReps[exercise.id] ?? [];

      for (int i = 0; i < checked.length; i++) {
        if (checked[i]) {
          totalLoad += loads[i] * reps[i];
          completedSetsCount++;
        }
      }
    }

    if (completedSetsCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Por favor, conclua pelo menos uma série antes de finalizar o treino!'),
          backgroundColor: AppColors.accentWarning,
        ),
      );
      return;
    }

    // Mostra Dialog com RPE slider, Mood picker e notas
    _showFinishSummaryDialog(totalLoad);
  }

  void _showFinishSummaryDialog(double totalLoad) {
    double rpeValue = 7.0;
    String selectedMood = '🙂';
    final notesController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Color rpeColor = Colors.green;
            String rpeLabel = 'Leve';
            if (rpeValue >= 4 && rpeValue <= 7) {
              rpeColor = Colors.orange;
              rpeLabel = 'Firme / Desafiador';
            } else if (rpeValue > 7) {
              rpeColor = Colors.red;
              rpeLabel = 'Extremo / Limite';
            }

            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 30,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '🏆 Finalizar Sessão de Treino',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Parabéns! Defina os detalhes finais de evolução de sua sessão.',
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                  ),
                  const Divider(height: 24),

                  // Seletor de Esforço RPE
                  Text(
                    'Esforço Percebido (RPE): ${rpeValue.toInt()}/10',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: rpeValue,
                          min: 1,
                          max: 10,
                          divisions: 9,
                          activeColor: rpeColor,
                          inactiveColor: rpeColor.withOpacity(0.2),
                          onChanged: (val) {
                            setModalState(() {
                              rpeValue = val;
                            });
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: rpeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          rpeLabel,
                          style: TextStyle(color: rpeColor, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Seletor de Humor / Mood
                  const Text(
                    'Como se sentiu hoje?',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMoodIcon(setModalState, '😢', 'Fraco', selectedMood, (m) => selectedMood = m),
                      _buildMoodIcon(setModalState, '😐', 'Ok', selectedMood, (m) => selectedMood = m),
                      _buildMoodIcon(setModalState, '🙂', 'Forte', selectedMood, (m) => selectedMood = m),
                      _buildMoodIcon(setModalState, '🔥', 'Monstro', selectedMood, (m) => selectedMood = m),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Campo de notas
                  const Text(
                    'Anotações do Treino',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Escreva observações sobre dores, superações de carga ou cansaço...',
                      hintStyle: TextStyle(color: context.colors.textMuted, fontSize: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botão Confirmar
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx); // fecha modal
                        _saveAndCompleteWorkout(rpeValue.toInt(), selectedMood, notesController.text, totalLoad);
                      },
                      child: const Text('Salvar e Registrar Treino', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMoodIcon(StateSetter setModalState, String emoji, String label, String currentSelected, Function(String) onSelect) {
    final isSelected = currentSelected == emoji;
    return GestureDetector(
      onTap: () {
        setModalState(() {
          onSelect(emoji);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.15) : Colors.transparent,
          border: Border.all(color: isSelected ? AppColors.primary : Colors.grey[300]!, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10, 
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? AppColors.primary : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveAndCompleteWorkout(int rpe, String mood, String notes, double totalLoad) async {
    final logbookProvider = context.read<LogbookProvider>();

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // 1. Logar cada um dos exercícios concluídos com suas respectivas séries
      for (var exercise in _activeSheet!.exercises) {
        final checked = _setsChecked[exercise.id] ?? [];
        final loads = _setsLoads[exercise.id] ?? [];
        final reps = _setsReps[exercise.id] ?? [];

        // Verifica se completou pelo menos uma série
        int checkedCount = checked.where((c) => c).length;
        if (checkedCount == 0) continue;

        // Constrói array de detalhes das séries para o histórico profundo
        final List<Map<String, dynamic>> seriesDetails = [];
        for (int i = 0; i < checked.length; i++) {
          seriesDetails.add({
            'set_number': i + 1,
            'load_kg': loads[i],
            'repetitions': reps[i],
            'completed': checked[i],
          });
        }

        // Encontra a primeira série completada para fins de carga principal do exercício
        final firstCompletedIndex = checked.indexOf(true);
        final finalLoad = loads[firstCompletedIndex];
        final finalReps = reps[firstCompletedIndex];

        await logbookProvider.logSessionExercise(
          sessionId: _activeSessionId!,
          exerciseId: exercise.id,
          actualSeries: checkedCount,
          actualRepetitions: finalReps,
          actualLoadKg: finalLoad,
          seriesDetails: seriesDetails,
          exerciseNotes: 'Séries completadas com sucesso.',
        );
      }

      // 2. Finalizar e salvar os metadados da sessão (RPE, mood, etc)
      await logbookProvider.completeActiveSession(
        sessionId: _activeSessionId!,
        notes: notes,
        difficultyLevel: rpe,
        mood: mood,
      );

      // Fecha o loader de progresso
      if (mounted) Navigator.pop(context);

      // Configura o overlay de sucesso premium!
      setState(() {
        _lastWorkoutDuration = _elapsedSeconds ~/ 60;
        if (_lastWorkoutDuration == 0) _lastWorkoutDuration = 1;
        _lastWorkoutTotalLoad = totalLoad;
        _showSuccessOverlay = true;
        _activeSheet = null;
        _activeSessionId = null;
        _chronometerTimer?.cancel();
        _restTimer?.cancel();
        _restTimerSeconds = null;
      });

      // Recarrega todos os programas e sheets para atualizar os contadores de treinos efetuados
      _loadInitialData();

    } catch (e) {
      if (mounted) Navigator.pop(context); // fecha loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar treino: $e'), backgroundColor: AppColors.accentError),
      );
    }
  }

  // --- CRIADOR DE ROTINA / FICHA CUSTOMIZADA ---
  void _openCustomRoutineBuilder() {
    final programNameController = TextEditingController(text: 'Minha Rotina Personalizada');
    final sheetNameController = TextEditingController(text: 'Ficha Customizada');
    int selectedDay = 0; // Segunda-feira
    
    // Lista local de exercícios adicionados na ficha customizada
    final List<Map<String, dynamic>> addedExercises = [];

    // Busca inicial do catálogo para preencher
    final sheetProvider = context.read<WorkoutSheetProvider>();
    sheetProvider.searchCatalog(search: '', limit: 15);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateBuilder) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '➕ Criar Rotina Customizada',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nome do Programa
                          const Text('Nome da Rotina / Foco', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: programNameController,
                            decoration: InputDecoration(
                              hintText: 'Ex: Hipertrofia Pernas, Meu Treino em Casa...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Nome da Ficha
                          const Text('Nome do Treino (Ficha)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: sheetNameController,
                            decoration: InputDecoration(
                              hintText: 'Ex: Treino A - Superior, Força...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Dia de agendamento
                          const Text('Agendar para Dia da Semana', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: List.generate(7, (i) {
                                final isSel = selectedDay == i;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: ChoiceChip(
                                    label: Text(dayOfWeekLabels[i]!),
                                    selected: isSel,
                                    selectedColor: AppColors.primary,
                                    backgroundColor: context.colors.surface,
                                    labelStyle: TextStyle(color: isSel ? Colors.white : context.colors.textPrimary, fontSize: 11),
                                    onSelected: (val) {
                                      if (val) {
                                        setStateBuilder(() => selectedDay = i);
                                      }
                                    },
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Exercícios Adicionados
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Exercícios (${addedExercises.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              TextButton.icon(
                                icon: const Icon(Icons.search, size: 16),
                                label: const Text('Buscar e Adicionar', style: TextStyle(fontSize: 12)),
                                onPressed: () {
                                  _showExerciseSearchCatalogDialog(setStateBuilder, addedExercises);
                                },
                              ),
                            ],
                          ),
                          
                          if (addedExercises.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              alignment: Alignment.center,
                              child: Text(
                                'Nenhum exercício adicionado. Toque em buscar acima para incluir! 🏋️',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: context.colors.textMuted, fontSize: 12),
                              ),
                            )
                          else
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: addedExercises.length,
                              itemBuilder: (context, index) {
                                final ex = addedExercises[index];
                                final name = ex['name'] as String;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    dense: true,
                                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Row(
                                      children: [
                                        Text('Séries: ${ex['series']} | Reps: ${ex['repetitions']} | Carga: ${ex['load_kg']}kg'),
                                      ],
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.accentError, size: 18),
                                      onPressed: () {
                                        setStateBuilder(() {
                                          addedExercises.removeAt(index);
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: addedExercises.isEmpty ? null : () async {
                        Navigator.pop(ctx);
                        _saveCustomProgram(
                          programNameController.text,
                          sheetNameController.text,
                          selectedDay,
                          addedExercises,
                        );
                      },
                      child: const Text('Criar Minha Rotina', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveCustomProgram(
    String programName,
    String sheetName,
    int selectedDay,
    List<Map<String, dynamic>> addedExercises,
  ) async {
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuário não autenticado.'), backgroundColor: AppColors.accentError),
      );
      return;
    }

    final sheetProvider = context.read<WorkoutSheetProvider>();

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      // Mapeia os exercícios locais para DTOs
      final List<ExerciseCreateDTO> exercises = addedExercises.map((ex) {
        return ExerciseCreateDTO(
          name: ex['name'] as String,
          muscleGroup: ex['muscle_group'] as String,
          series: ex['series'] as int,
          repetitions: ex['repetitions'] as int,
          loadKg: ex['load_kg'] as double,
          restSeconds: ex['rest_seconds'] as int,
          gifUrl: ex['gif_url'] as String?,
          imageUrl: ex['image_url'] as String?,
          order: ex['order'] as int,
        );
      }).toList();

      // Cria a Ficha dentro do Programa
      final sheetDTO = CreateWorkoutSheetDTO(
        workoutProgramId: '', // O backend associa automaticamente no fluxo de criação de programa
        name: sheetName,
        dayOfWeek: selectedDay,
        order: 1,
        exercises: exercises,
      );

      final programDTO = CreateWorkoutProgramDTO(
        userId: userId,
        name: programName,
        description: 'Ficha personalizada criada pelo usuário.',
        goal: 'Hipertrofia',
        workoutSheets: [sheetDTO],
      );

      final newProgram = await sheetProvider.createProgram(programDTO);
      sheetProvider.selectProgram(newProgram);
      await sheetProvider.loadSheets(workoutProgramId: newProgram.id);

      if (mounted) {
        Navigator.pop(context); // Fecha o loader
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Rotina criada e ativada com sucesso! 🚀'),
              ],
            ),
            backgroundColor: AppColors.accentSuccess,
          ),
        );
      }
    } on NetworkException catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro de conexão: ${e.message}'), backgroundColor: AppColors.accentError),
      );
    } on ApiException catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro na API: ${e.message}'), backgroundColor: AppColors.accentError),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao criar rotina: $e'), backgroundColor: AppColors.accentError),
      );
    }
  }

  void _showExerciseSearchCatalogDialog(StateSetter parentSetState, List<Map<String, dynamic>> addedExercises) {
    final searchController = TextEditingController();
    Timer? debounce;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final sheetProvider = context.watch<WorkoutSheetProvider>();

            void triggerSearch(String query) {
              if (debounce?.isActive ?? false) debounce!.cancel();
              debounce = Timer(const Duration(milliseconds: 500), () {
                sheetProvider.searchCatalog(search: query, limit: 15);
              });
            }

            return AlertDialog(
              title: const Text('Selecionar Exercício'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Digite o nome do exercício...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: triggerSearch,
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: sheetProvider.isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : sheetProvider.catalogItems.isEmpty
                              ? const Center(child: Text('Nenhum exercício encontrado.'))
                              : ListView.builder(
                                  itemCount: sheetProvider.catalogItems.length,
                                  itemBuilder: (context, index) {
                                    final item = sheetProvider.catalogItems[index];
                                    return ListTile(
                                      dense: true,
                                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      subtitle: Text(item.muscleGroupMapped ?? 'Geral', style: const TextStyle(fontSize: 11)),
                                      trailing: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        _showSetsAndLoadSetupDialog(parentSetState, addedExercises, item);
                                      },
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Fechar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSetsAndLoadSetupDialog(StateSetter parentSetState, List<Map<String, dynamic>> addedExercises, ExerciseCatalogItem item) {
    final seriesController = TextEditingController(text: '4');
    final repsController = TextEditingController(text: '10');
    final loadController = TextEditingController(text: '15');
    final restController = TextEditingController(text: '60');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Ajustes: ${item.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: seriesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Séries (Séries totais)'),
                ),
                TextField(
                  controller: repsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Repetições por série'),
                ),
                TextField(
                  controller: loadController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Carga Alvo (kg)'),
                ),
                TextField(
                  controller: restController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tempo de Descanso (segundos)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                final series = int.tryParse(seriesController.text) ?? 4;
                final reps = int.tryParse(repsController.text) ?? 10;
                final load = double.tryParse(loadController.text) ?? 10.0;
                final rest = int.tryParse(restController.text) ?? 60;

                parentSetState(() {
                  addedExercises.add({
                    'name': item.name,
                    'muscle_group': item.muscleGroupMapped ?? 'peito',
                    'series': series,
                    'repetitions': reps,
                    'load_kg': load,
                    'rest_seconds': rest,
                    'gif_url': item.gifUrl,
                    'image_url': item.imageUrl,
                    'order': addedExercises.length + 1,
                  });
                });
                Navigator.pop(ctx);
              },
              child: const Text('Adicionar'),
            ),
          ],
        );
      },
    );
  }

  // --- RENDERS DE ABAS ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(
        children: [
          SafeArea(
            child: _activeSheet != null ? _buildActiveSessionView() : _buildMainLayout(),
          ),
          if (_showSuccessOverlay) _buildPremiumSuccessOverlay(),
        ],
      ),
    );
  }

  Widget _buildMainLayout() {
    return Column(
      children: [
        _buildSuperHeader(),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMyWorkoutsTab(),
              _buildProgressTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuperHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Foco & Evolução 🚀',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
              ),
              Text(
                'Acompanhe e personalize sua rotina de força',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
            onPressed: _openCustomRoutineBuilder,
            tooltip: 'Criar Rotina Customizada',
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: AppColors.primary,
      unselectedLabelColor: context.colors.textMuted,
      indicatorColor: AppColors.primary,
      indicatorSize: TabBarIndicatorSize.tab,
      tabs: const [
        Tab(text: 'Meus Treinos', icon: Icon(Icons.fitness_center)),
        Tab(text: 'Meu Progresso', icon: Icon(Icons.analytics_outlined)),
      ],
    );
  }

  // ==========================================
  // ABA "MEUS TREINOS"
  // ==========================================
  Widget _buildMyWorkoutsTab() {
    return Consumer<WorkoutSheetProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.programs.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null && provider.programs.isEmpty) {
          return OmniErrorState(
            message: 'Erro: ${provider.error}',
            onRetry: _loadInitialData,
          );
        }

        if (provider.programs.isEmpty) {
          return OmniEmptyState(
            icon: Icons.fitness_center_outlined,
            title: 'Nenhuma rotina disponível',
            subtitle: 'Crie uma rotina customizada no botão + ou aguarde seu personal prescrever.',
            actionLabel: 'Criar Rotina Personalizada',
            onAction: _openCustomRoutineBuilder,
          );
        }

        final activeProgram = provider.selectedProgram ?? provider.programs.first;
        
        // Verifica sugestão de treino para hoje
        WorkoutSheetListItem? todaySuggestedSheet;
        final todayWeekday = DateTime.now().weekday - 1; // 0 = Segunda, 6 = Domingo
        for (var sheet in provider.sheets) {
          if (sheet.dayOfWeek == todayWeekday) {
            todaySuggestedSheet = sheet;
            break;
          }
        }

        return RefreshIndicator(
          onRefresh: _loadInitialData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Ativo Program Selector
              _buildActiveProgramSelector(provider),
              const SizedBox(height: 16),

              // 2. Pulse Sugestão de Hoje
              if (todaySuggestedSheet != null) ...[
                Pulse(
                  infinite: true,
                  duration: const Duration(seconds: 4),
                  child: _buildTodaySuggestionCard(todaySuggestedSheet),
                ),
                const SizedBox(height: 16),
              ],

              // 3. Cabeçalho de Fichas do Programa Selecionado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Fichas de Treino (${provider.sheets.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  if (activeProgram.personalTrainerId == null) // Permite deletar programas criados pelo próprio aluno
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AppColors.accentError, size: 20),
                      onPressed: () => _confirmDeleteProgram(activeProgram.id),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // 4. Lista de Fichas / Sheets
              if (provider.sheets.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  alignment: Alignment.center,
                  child: Text(
                    'Nenhuma ficha atribuída a este programa.',
                    style: TextStyle(color: context.colors.textMuted),
                  ),
                )
              else
                ...provider.sheets.map((sheet) => _buildSheetCard(sheet)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveProgramSelector(WorkoutSheetProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Programa Ativo',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: provider.programs.map((prog) {
              final isSelected = provider.selectedProgram?.id == prog.id;
              final isOfficial = prog.personalTrainerId != null;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Row(
                    children: [
                      Text(prog.name, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOfficial ? Colors.amber[800] : Colors.blue[800],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isOfficial ? 'Oficial 🛡️' : 'Personalizado 👤',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  backgroundColor: context.colors.surface,
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : context.colors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                  onSelected: (selected) async {
                    if (selected) {
                      provider.selectProgram(prog);
                      await provider.loadSheets(workoutProgramId: prog.id);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTodaySuggestionCard(WorkoutSheetListItem sheet) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
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
              const Text(
                '🔥 SUGESTÃO PARA HOJE',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.1),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                child: Text(
                  dayOfWeekLabels[DateTime.now().weekday - 1]!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Treino ${sheet.name}',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          Text(
            'Foco do dia: ${sheet.exerciseCount} exercícios catalogados prontos para evolução!',
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              onPressed: () async {
                // Carrega exercícios do treino sugerido para iniciar sessão ativa
                final provider = context.read<WorkoutSheetProvider>();
                await provider.loadSheetDetail(sheet.id);
                if (provider.selectedSheet != null) {
                  _startWorkoutSession(provider.selectedSheet!);
                }
              },
              child: const Text('🚀 Iniciar Treino Ativo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetCard(WorkoutSheetListItem sheet) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(sheet.emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sheet.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(sheet.dayOfWeekLabel, style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                const SizedBox(height: 2),
                Text('${sheet.exerciseCount} exercícios', style: TextStyle(color: context.colors.textMuted, fontSize: 11)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withOpacity(0.12),
              foregroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: () async {
              // Carrega exercícios do treino sugerido para iniciar sessão ativa
              final provider = context.read<WorkoutSheetProvider>();
              await provider.loadSheetDetail(sheet.id);
              if (provider.selectedSheet != null) {
                _startWorkoutSession(provider.selectedSheet!);
              }
            },
            child: const Text('Iniciar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProgram(String programId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deletar Programa Customizado'),
        content: const Text('Tem certeza de que deseja deletar este programa personalizado e todas as suas fichas?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.accentError),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<WorkoutSheetProvider>().deleteProgram(programId);
              _loadInitialData();
            },
            child: const Text('Deletar'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW DO TREINO ATIVO (HEVY STYLE LIVE WORKOUT)
  // ==========================================
  Widget _buildActiveSessionView() {
    if (_activeSheet == null) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Icon(Icons.circle, color: AppColors.accentError, size: 10),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_activeSheet!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Text(
                    'Duração: ${_formatDuration(_elapsedSeconds)}', 
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.accentError, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: _finishWorkout,
              child: const Text('Finalizar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Progresso Real das Séries do Treino
          _buildActiveWorkoutProgressBar(),

          // Countdown do Rest Timer se ativo
          if (_restTimerSeconds != null && _restTimerSeconds! > 0)
            _buildActiveRestTimerIndicator(),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _activeSheet!.exercises.length,
              itemBuilder: (context, index) {
                final ex = _activeSheet!.exercises[index];
                return _buildActiveExerciseCard(ex);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveWorkoutProgressBar() {
    // Calcula o percentual total de séries marcadas
    int totalSets = 0;
    int completedSets = 0;

    _setsChecked.forEach((_, list) {
      totalSets += list.length;
      completedSets += list.where((c) => c).length;
    });

    final pct = totalSets > 0 ? completedSets / totalSets : 0.0;

    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progresso da Sessão', 
                style: TextStyle(fontSize: 11, color: context.colors.textSecondary, fontWeight: FontWeight.w600),
              ),
              Text(
                '$completedSets/$totalSets séries concluídas (${(pct * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              color: AppColors.primary,
              backgroundColor: context.colors.surfaceLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRestTimerIndicator() {
    return SlideInDown(
      duration: const Duration(milliseconds: 300),
      child: Container(
        color: AppColors.primary.withOpacity(0.12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.alarm, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Tempo de Descanso: ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                ),
                Text(
                  '${_restTimerSeconds! ~/ 60}:${(_restTimerSeconds! % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                ),
              ],
            ),
            InkWell(
              onTap: () {
                setState(() => _restTimerSeconds = null);
                _restTimer?.cancel();
              },
              child: const Icon(Icons.close, color: AppColors.primary, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveExerciseCard(ExerciseResponse ex) {
    final checkedList = _setsChecked[ex.id] ?? [];
    final loadsList = _setsLoads[ex.id] ?? [];
    final repsList = _setsReps[ex.id] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Exercício Super Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ex.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(ex.muscleGroup.toUpperCase(), style: TextStyle(color: context.colors.textMuted, fontSize: 10, letterSpacing: 1.1)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: context.colors.surfaceLight, borderRadius: BorderRadius.circular(4)),
                  child: Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Text('${ex.restSeconds}s', style: const TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Table of sets
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const SizedBox(width: 35, child: Text('SÉRIE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey))),
                const Expanded(child: Center(child: Text('PESO (KG)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)))),
                const Expanded(child: Center(child: Text('REPS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)))),
                const SizedBox(width: 45, child: Center(child: Text('STATUS', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)))),
              ],
            ),
          ),
          const Divider(height: 1),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: ex.series,
            itemBuilder: (ctx, setIdx) {
              final isChecked = checkedList.isNotEmpty ? checkedList[setIdx] : false;
              final loadVal = loadsList.isNotEmpty ? loadsList[setIdx] : ex.loadKg;
              final repsVal = repsList.isNotEmpty ? repsList[setIdx] : ex.repetitions;

              return Container(
                color: isChecked ? Colors.green.withOpacity(0.08) : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    // Set Index
                    SizedBox(
                      width: 35,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: isChecked ? Colors.green : context.colors.border,
                        child: Text(
                          '${setIdx + 1}',
                          style: TextStyle(fontSize: 10, color: isChecked ? Colors.white : context.colors.textPrimary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    
                    // Load Input
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: 65,
                          height: 32,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.all(4),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            controller: TextEditingController(text: loadVal.toStringAsFixed(1))
                              ..selection = TextSelection.collapsed(offset: loadVal.toStringAsFixed(1).length),
                            onChanged: (val) => _onLoadChanged(ex.id, setIdx, val),
                          ),
                        ),
                      ),
                    ),

                    // Reps Input
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: 65,
                          height: 32,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.all(4),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            controller: TextEditingController(text: repsVal.toString())
                              ..selection = TextSelection.collapsed(offset: repsVal.toString().length),
                            onChanged: (val) => _onRepsChanged(ex.id, setIdx, val),
                          ),
                        ),
                      ),
                    ),

                    // Checkbox/Check Button
                    SizedBox(
                      width: 45,
                      child: Center(
                        child: InkWell(
                          onTap: () => _toggleSetCheck(ex.id, setIdx, ex.restSeconds),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: isChecked ? Colors.green : Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isChecked ? Icons.check : Icons.add_task,
                              size: 16,
                              color: isChecked ? Colors.white : Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ==========================================
  // ABA "MEU PROGRESSO" (ESTATÍSTICAS & GRAFICOS)
  // ==========================================
  Widget _buildProgressTab() {
    return Consumer<LogbookProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.frequencyResponse == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: _loadProgressData,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Gráfico de Frequência
              _buildFrequencySection(provider),
              const SizedBox(height: 16),

              // 2. Gráfico Donut de Foco Muscular (Premium)
              _buildMuscleFocusSection(provider),
              const SizedBox(height: 16),

              // 3. Gráfico de Progressão Individual de Exercício
              _buildExerciseProgressionSection(provider),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFrequencySection(LogbookProvider provider) {
    // Mapeia para compatibilidade com o widget que espera List<Map<String, dynamic>>
    final mappedData = provider.frequencyResponse?.dataPoints.map((dp) => {
      'period_start': dp.periodStart.toIso8601String(),
      'period_end': dp.periodEnd.toIso8601String(),
      'count': dp.count,
    }).toList() ?? [];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: context.colors.border)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Consistência de Treinos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                // Seleção de Período
                DropdownButton<String>(
                  value: _selectedPeriod,
                  underline: const SizedBox(),
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                  items: const [
                    DropdownMenuItem(value: 'weekly', child: Text('Últimas 12 Semanas')),
                    DropdownMenuItem(value: 'monthly', child: Text('Últimos 6 Meses')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedPeriod = val);
                      provider.loadFrequency(val, limit: 12);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 200,
              child: FrequencyBarChart(
                dataPoints: mappedData,
                period: _selectedPeriod,
                isLoading: provider.isLoading && mappedData.isEmpty,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuscleFocusSection(LogbookProvider provider) {
    final dist = provider.distributionResponse?.distribution ?? [];
    
    // Lista de Cores tailormade para o gráfico donut
    final List<Color> donutColors = [
      Colors.blue,
      Colors.orange,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.teal,
      Colors.amber,
      Colors.indigo,
      Colors.brown,
      Colors.pink,
    ];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: context.colors.border)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Foco Muscular', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Distribuição de séries completadas por grupo muscular (Últimos 30 dias)', style: TextStyle(color: context.colors.textMuted, fontSize: 10)),
            const SizedBox(height: 20),

            if (dist.isEmpty)
              Container(
                height: 150,
                alignment: Alignment.center,
                child: Text('Ainda sem histórico suficiente para focar os músculos.', style: TextStyle(color: context.colors.textMuted, fontSize: 12)),
              )
            else
              Row(
                children: [
                  // Pie / Donut Chart
                  Expanded(
                    flex: 4,
                    child: SizedBox(
                      height: 140,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 35,
                          sections: List.generate(dist.length, (idx) {
                            final item = dist[idx];
                            final color = donutColors[idx % donutColors.length];
                            return PieChartSectionData(
                              color: color,
                              value: item.count.toDouble(),
                              title: '${item.count}',
                              radius: 18,
                              titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Legend
                  Expanded(
                    flex: 5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(dist.length, (idx) {
                        final item = dist[idx];
                        final color = donutColors[idx % donutColors.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.muscleGroup.toUpperCase(), 
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseProgressionSection(LogbookProvider provider) {
    // Monta lista de todos os exercícios das fichas para o dropdown de evolução
    final List<Map<String, String>> availableExercises = [];
    final Set<String> addedIds = {};

    // 1. Coleta exercícios de todas as fichas carregadas do aluno
    final sheetProvider = context.read<WorkoutSheetProvider>();
    for (var sheet in sheetProvider.sheets) {
      for (var ex in sheet.exercises) {
        if (!addedIds.contains(ex.id)) {
          addedIds.add(ex.id);
          availableExercises.add({'id': ex.id, 'name': ex.name});
        }
      }
    }

    // 2. Coleta exercícios de sessões anteriores gravadas no logbook histórico
    for (var sess in provider.sessions) {
      for (var ex in sess.exercises) {
        final exId = ex.exerciseId.isNotEmpty ? ex.exerciseId : ex.id;
        if (exId.isNotEmpty && !addedIds.contains(exId)) {
          addedIds.add(exId);
          availableExercises.add({'id': exId, 'name': ex.exerciseName});
        }
      }
    }

    // Se a lista continuar vazia, preenchemos com alguns padrões da base de dados
    if (availableExercises.isEmpty) {
      availableExercises.addAll([
        {'id': 'e3c0490b-19b8-4c91-9540-cc5b6e206001', 'name': 'Supino Reto'},
        {'id': 'e3c0490b-19b8-4c91-9540-cc5b6e206002', 'name': 'Agachamento Livre'},
        {'id': 'e3c0490b-19b8-4c91-9540-cc5b6e206003', 'name': 'Levantamento Terra'},
        {'id': 'e3c0490b-19b8-4c91-9540-cc5b6e206004', 'name': 'Puxada Pulley'},
      ]);
    }

    // Garante que o ID selecionado esteja contido na lista para evitar falhas do Dropdown
    final hasSelected = availableExercises.any((ex) => ex['id'] == _progressionExerciseId);
    if (!hasSelected && availableExercises.isNotEmpty) {
      _progressionExerciseId = availableExercises.first['id'];
      provider.loadExerciseProgression(_progressionExerciseId!, weeks: 8);
    } else if (availableExercises.isEmpty) {
      _progressionExerciseId = null;
    }

    // Mapeamento para o ProgressionLineChart
    final mappedPoints = provider.progressionResponse?.dataPoints.map((dp) => {
      'session_date': dp.sessionDate.toIso8601String(),
      'actual_load_kg': dp.actualLoadKg,
    }).toList() ?? [];

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: context.colors.border)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Evolução de Cargas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                // Dropdown de Exercícios
                DropdownButton<String>(
                  value: _progressionExerciseId,
                  underline: const SizedBox(),
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11),
                  items: availableExercises.map((ex) {
                    return DropdownMenuItem<String>(
                      value: ex['id'],
                      child: Text(ex['name']!),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _progressionExerciseId = val;
                      });
                      provider.loadExerciseProgression(val, weeks: 8);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            SizedBox(
              height: 380,
              child: ProgressionLineChart(
                dataPoints: mappedPoints,
                isLoading: provider.isLoading && mappedPoints.isEmpty,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // OVERLAY PREMIUM DE SUCESSO (CONFETES E CONQUISTAS)
  // ==========================================
  Widget _buildPremiumSuccessOverlay() {
    return Positioned.fill(
      child: FadeIn(
        duration: const Duration(milliseconds: 400),
        child: Container(
          color: Colors.black.withOpacity(0.92),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElasticIn(
                duration: const Duration(milliseconds: 1200),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: AppColors.accentSuccess,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.emoji_events, size: 50, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              
              FadeInDown(
                delay: const Duration(milliseconds: 400),
                child: const Text(
                  'TREINO CONCLUÍDO!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 26, letterSpacing: 1.5),
                ),
              ),
              const SizedBox(height: 6),
              FadeInUp(
                delay: const Duration(milliseconds: 500),
                child: Text(
                  'Mais um passo gigante na sua evolução consistente.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ),
              const SizedBox(height: 32),

              // Card de Conquistas da Sessão
              FadeInUp(
                delay: const Duration(milliseconds: 700),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    border: Border.all(color: Colors.grey[800]!),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('🕒 Duração', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text('$_lastWorkoutDuration min', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      Container(width: 1, height: 35, color: Colors.grey[800]),
                      Column(
                        children: [
                          const Text('🏋️ Volume Total', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text('${_lastWorkoutTotalLoad.toStringAsFixed(0)} kg', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              FadeInUp(
                delay: const Duration(milliseconds: 1000),
                child: SizedBox(
                  width: 200,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      setState(() {
                        _showSuccessOverlay = false;
                      });
                    },
                    child: const Text('Excelente!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
