import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../models/workout_sheet_model.dart';
import '../../providers/workout_sheet_provider.dart';
import '../../services/workout_sheet_service.dart';
import 'widgets/create_workout_sheet_dialog.dart';

class TrainerSheets extends StatefulWidget {
  const TrainerSheets({super.key});

  @override
  State<TrainerSheets> createState() => _TrainerSheetsState();
}

class _TrainerSheetsState extends State<TrainerSheets> {
  @override
  void initState() {
    super.initState();
    // Carrega fichas do backend na inicialização
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSheets();
    });
  }

  Future<void> _loadSheets() async {
    try {
      await context.read<WorkoutSheetProvider>().loadSheets();
    } catch (_) {
      // Erro já tratado pelo provider
    }
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const CreateWorkoutSheetDialog(),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Ficha criada com sucesso!'),
          backgroundColor: AppColors.accentSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.fitness_center, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text('Fichas de Treino',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  GestureDetector(
                    onTap: _openCreateDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.add, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text('Nova',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<WorkoutSheetProvider>(
                builder: (context, provider, child) {
                  // Estado de carregamento
                  if (provider.isLoading && provider.sheets.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }

                  // Estado de erro
                  if (provider.error != null && provider.sheets.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.accentError, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            provider.error!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _loadSheets,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Tentar novamente'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Estado vazio
                  if (provider.sheets.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.fitness_center_outlined, color: AppColors.textMuted, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Nenhuma ficha de treino',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Crie a primeira ficha para começar',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    );
                  }

                  // Lista de fichas
                  return RefreshIndicator(
                    onRefresh: _loadSheets,
                    color: AppColors.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: provider.sheets.length,
                      itemBuilder: (context, index) {
                        final sheet = provider.sheets[index];
                        return _buildSheetCard(sheet, index);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildSheetCard(WorkoutSheetListItem sheet, int index) {
    return FadeInUp(
      delay: Duration(milliseconds: index * 100),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
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
                  child: Row(
                    children: [
                      Text(sheet.emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sheet.name,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text('${sheet.dayOfWeekLabel} • ${sheet.exerciseCount} exercícios',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _duplicateSheet(sheet),
                      child: const Icon(Icons.copy, color: AppColors.textMuted, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.edit, color: AppColors.textMuted, size: 20),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _duplicateSheet(WorkoutSheetListItem sheet) async {
    try {
      final dto = DuplicateWorkoutSheetDTO(
        name: '${sheet.name} (Cópia)',
      );
      await context.read<WorkoutSheetProvider>().duplicateSheet(sheet.id, dto);
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
            content: Text('Erro: aluno já possui ficha ativa para este dia da semana.'),
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

  Widget _buildBottomNav() {
    final trainerNavItems = [
      {'icon': Icons.dashboard_outlined, 'label': 'Dashboard'},
      {'icon': Icons.people_outlined, 'label': 'Alunos'},
      {'icon': Icons.fitness_center_outlined, 'label': 'Fichas'},
      {'icon': Icons.person_outline, 'label': 'Perfil'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: 2,
        onTap: (index) {
          final routes = [
            '/trainer/dashboard',
            '/trainer/students',
            '/trainer/sheets',
            '/trainer/profile',
          ];
          context.go(routes[index]);
        },
        backgroundColor: AppColors.surface,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
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
