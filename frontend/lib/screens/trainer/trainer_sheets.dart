import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../models/workout_sheet_model.dart';
import '../../providers/workout_sheet_provider.dart';
import '../../services/workout_sheet_service.dart';
import '../../services/user_service.dart';
import 'widgets/create_workout_sheet_dialog.dart';
import 'widgets/edit_workout_sheet_dialog.dart';
import 'widgets/create_workout_program_dialog.dart';

class TrainerSheets extends StatefulWidget {
  const TrainerSheets({super.key});

  @override
  State<TrainerSheets> createState() => _TrainerSheetsState();
}

class _TrainerSheetsState extends State<TrainerSheets> {
  List<UserResponse> _students = [];
  UserResponse? _selectedStudent;
  WorkoutProgramResponse? _selectedProgram;
  bool _studentsLoading = true;
  String? _studentsError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudents();
    });
  }

  Future<void> _loadStudents() async {
    setState(() {
      _studentsLoading = true;
      _studentsError = null;
    });

    try {
      final userService = context.read<UserService>();
      final students = await userService.getStudents();
      setState(() {
        _students = students;
        if (students.isNotEmpty) {
          _selectedStudent = students.first;
        }
        _studentsLoading = false;
      });

      if (_selectedStudent != null) {
        _loadStudentPrograms(_selectedStudent!.id);
      }
    } catch (e) {
      setState(() {
        _studentsError = 'Erro ao carregar alunos';
        _studentsLoading = false;
      });
    }
  }

  Future<void> _loadStudentPrograms(String userId) async {
    try {
      final provider = context.read<WorkoutSheetProvider>();
      await provider.loadPrograms(userId: userId);
      
      setState(() {
        if (provider.programs.isNotEmpty) {
          _selectedProgram = provider.programs.first;
        } else {
          _selectedProgram = null;
        }
      });

      if (_selectedProgram != null) {
        _loadSheets();
      }
    } catch (_) {
      // Erros já tratados pelo provider
    }
  }

  Future<void> _loadSheets() async {
    if (_selectedProgram == null) return;
    try {
      await context.read<WorkoutSheetProvider>().loadSheets(
        workoutProgramId: _selectedProgram!.id,
      );
    } catch (_) {
      // Erros já tratados pelo provider
    }
  }

  Future<void> _openCreateProgramDialog() async {
    if (_selectedStudent == null) return;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateWorkoutProgramDialog(userId: _selectedStudent!.id),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Programa criado com sucesso!'),
          backgroundColor: AppColors.accentSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _loadStudentPrograms(_selectedStudent!.id);
    }
  }

  Future<void> _openCreateDialog() async {
    if (_selectedProgram == null) return;

    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CreateWorkoutSheetDialog(
        workoutProgramId: _selectedProgram!.id,
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Ficha criada com sucesso!'),
          backgroundColor: AppColors.accentSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadSheets();
    }
  }

  Future<void> _openEditDialog(WorkoutSheetListItem sheet) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditWorkoutSheetDialog(sheetId: sheet.id),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Ficha atualizada com sucesso!'),
          backgroundColor: AppColors.accentSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadSheets();
    }
  }

  Future<void> _deleteSelectedProgram() async {
    if (_selectedProgram == null) return;
    final program = _selectedProgram!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
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
            child: const Text('Remover',
                style: TextStyle(color: AppColors.accentError)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await context.read<WorkoutSheetProvider>().deleteProgram(program.id);
      setState(() => _selectedProgram = null);
      if (_selectedStudent != null) {
        await _loadStudentPrograms(_selectedStudent!.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Programa removido com sucesso.'),
            backgroundColor: AppColors.accentSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao remover programa.'),
            backgroundColor: AppColors.accentError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workoutProvider = context.watch<WorkoutSheetProvider>();

    return SafeArea(
      child: Column(
        children: [
          // Seletor de Aluno e Programa
          _buildSelectorHeader(workoutProvider),

          // Área de Conteúdo Principal
          Expanded(
            child: _studentsLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _studentsError != null
                    ? _buildErrorWidget()
                    : _students.isEmpty
                        ? _buildEmptyStudentsWidget()
                        : _selectedProgram == null
                            ? _buildEmptyProgramsWidget()
                            : _buildSheetsList(workoutProvider),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorHeader(WorkoutSheetProvider workoutProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fitness_center, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Gestão de Fichas',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Dropdown de Aluno
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aluno',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<UserResponse>(
                      value: _selectedStudent,
                      dropdownColor: context.colors.surface,
                      isExpanded: true,
                      decoration: _dropdownDecoration(),
                      items: _students.map((student) {
                        return DropdownMenuItem(
                          value: student,
                          child: Text(
                            student.name,
                            style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (student) {
                        if (student != null) {
                          setState(() {
                            _selectedStudent = student;
                            _selectedProgram = null;
                          });
                          _loadStudentPrograms(student.id);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Dropdown de Programa
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Programa',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<WorkoutProgramResponse>(
                            value: _selectedProgram,
                            dropdownColor: context.colors.surface,
                            isExpanded: true,
                            decoration: _dropdownDecoration(),
                            hint: Text(
                              'Selecione...',
                              style: TextStyle(color: context.colors.textMuted, fontSize: 14),
                            ),
                            items: workoutProvider.programs.map((program) {
                              return DropdownMenuItem(
                                value: program,
                                child: Text(
                                  program.name,
                                  style: TextStyle(color: context.colors.textPrimary, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (program) {
                              if (program != null) {
                                setState(() {
                                  _selectedProgram = program;
                                });
                                _loadSheets();
                              }
                            },
                          ),
                        ),
                        if (_selectedStudent != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _openCreateProgramDialog,
                            child: Container(
                              height: 45,
                              width: 45,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add, color: AppColors.primary, size: 20),
                            ),
                          ),
                        ],
                        // Botão deletar programa — só aparece quando o programa foi
                        // criado pelo profissional (personalTrainerId != null)
                        if (_selectedProgram != null &&
                            _selectedProgram!.personalTrainerId != null) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _deleteSelectedProgram,
                            child: Container(
                              height: 45,
                              width: 45,
                              decoration: BoxDecoration(
                                color: AppColors.accentError.withValues(alpha: 0.08),
                                border: Border.all(color: AppColors.accentError.withValues(alpha: 0.3)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.delete_outline, color: AppColors.accentError, size: 20),
                            ),
                          ),
                        ],
                      ],
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

  Widget _buildSheetsList(WorkoutSheetProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Fichas de Treino',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: _openCreateDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Nova Ficha',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: provider.isLoading && provider.sheets.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : provider.error != null && provider.sheets.isEmpty
                  ? _buildSheetsErrorWidget(provider)
                  : provider.sheets.isEmpty
                      ? _buildEmptySheetsWidget()
                      : RefreshIndicator(
                          onRefresh: _loadSheets,
                          color: AppColors.primary,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: provider.sheets.length,
                            itemBuilder: (context, index) {
                              final sheet = provider.sheets[index];
                              return _buildSheetCard(sheet, index);
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildSheetCard(WorkoutSheetListItem sheet, int index) {
    return FadeInUp(
      delay: Duration(milliseconds: index * 50),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border.all(color: context.colors.border, width: 1),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(sheet.emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sheet.name,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${sheet.dayOfWeekLabel} • ${sheet.exerciseCount} exercícios',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: () => _duplicateSheet(sheet),
                  icon: Icon(Icons.copy, color: context.colors.textMuted, size: 18),
                  tooltip: 'Duplicar ficha',
                ),
                IconButton(
                  onPressed: () => _openEditDialog(sheet),
                  icon: const Icon(Icons.edit, color: AppColors.primary, size: 20),
                  tooltip: 'Editar ficha',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _duplicateSheet(WorkoutSheetListItem sheet) async {
    if (_selectedProgram == null) return;
    try {
      final dto = DuplicateWorkoutSheetDTO(
        name: '${sheet.name} (Cópia)',
        workoutProgramId: _selectedProgram!.id,
      );
      await context.read<WorkoutSheetProvider>().duplicateSheet(sheet.id, dto);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Ficha duplicada com sucesso!'),
            backgroundColor: AppColors.accentSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadSheets();
      }
    } on WorkoutSheetConflictException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Erro: aluno já possui ficha ativa para este dia da semana (RN-01).'),
            backgroundColor: AppColors.accentError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erro ao duplicar ficha.'),
            backgroundColor: AppColors.accentError,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.accentError, size: 48),
          const SizedBox(height: 12),
          Text(
            _studentsError!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadStudents,
            icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
            label: const Text('Tentar novamente', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetsErrorWidget(WorkoutSheetProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppColors.accentError, size: 48),
          const SizedBox(height: 12),
          Text(
            provider.error ?? 'Erro ao carregar fichas',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadSheets,
            icon: const Icon(Icons.refresh, size: 18, color: Colors.white),
            label: const Text('Tentar novamente', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyStudentsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, color: context.colors.textMuted, size: 56),
          const SizedBox(height: 12),
          Text(
            'Nenhum aluno cadastrado',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Você precisa de alunos vinculados para gerenciar fichas.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProgramsWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open_outlined, color: AppColors.primary, size: 48),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum Programa de Treino',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Este aluno não possui nenhum programa de treino cadastrado.\nCrie um programa (ex: Divisão ABC) para começar a adicionar fichas.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openCreateProgramDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Criar Primeiro Programa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySheetsWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center_outlined, color: context.colors.textMuted, size: 56),
            const SizedBox(height: 16),
            Text(
              'Nenhuma Ficha de Treino',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione fichas de treino para este programa (ex: Peito e Tríceps para Segunda-feira).',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _openCreateDialog,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Adicionar Ficha', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: context.colors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: context.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}
