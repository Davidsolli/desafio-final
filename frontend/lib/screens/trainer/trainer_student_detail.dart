import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../models/mock_data.dart';
import '../../models/workout_sheet_model.dart';
import '../../providers/workout_sheet_provider.dart';
import '../../services/workout_sheet_service.dart';
import 'widgets/create_workout_sheet_dialog.dart';

class TrainerStudentDetail extends StatefulWidget {
  final String studentId;

  const TrainerStudentDetail({super.key, required this.studentId});

  @override
  State<TrainerStudentDetail> createState() => _TrainerStudentDetailState();
}

class _TrainerStudentDetailState extends State<TrainerStudentDetail> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Student _student;

  // Estado local para fichas do aluno (carregadas via API)
  List<WorkoutSheetListItem> _studentSheets = [];
  bool _sheetsLoading = false;
  String? _sheetsError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _student = students.firstWhere((s) => s.id == widget.studentId, orElse: () => students[0]);

    // Carrega fichas do aluno via API
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudentSheets();
    });
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_student.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
            Text(_student.goal, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: AppColors.surface,
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.info_outline), text: 'Info'),
                  Tab(icon: Icon(Icons.fitness_center), text: 'Treinos'),
                  Tab(icon: Icon(Icons.restaurant_outlined), text: 'Nutrição'),
                  Tab(icon: Icon(Icons.emoji_events), text: 'Conquistas'),
                ],
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textMuted,
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
                  _buildBadgesTab(),
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
                  child: Text(_student.name[0],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_student.name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text(_student.goal, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  Text('4x/semana', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
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
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.scale, color: AppColors.primary, size: 20),
                        const SizedBox(height: 6),
                        const Text('78 kg', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Peso', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
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
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.height, color: AppColors.primary, size: 20),
                        const SizedBox(height: 6),
                        const Text('175 cm', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Altura', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
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
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.cake, color: AppColors.primary, size: 20),
                        const SizedBox(height: 6),
                        const Text('27 anos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Idade', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
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
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.percent, color: AppColors.primary, size: 20),
                        const SizedBox(height: 6),
                        const Text('16%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('Gordura', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
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
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.trending_up, color: AppColors.primary, size: 20),
                        const SizedBox(height: 6),
                        const Text('25.5', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('IMC', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
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
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.local_fire_department, color: AppColors.primary, size: 20),
                        const SizedBox(height: 6),
                        const Text('1820', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('TMB', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Respostas do Questionário', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildQuestionRow('Objetivo', 'Ganhar massa muscular'),
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
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
                    const Icon(Icons.fitness_center_outlined, color: AppColors.textMuted, size: 40),
                    const SizedBox(height: 8),
                    Text('Nenhuma ficha atribuída',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
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
                                Text(sheet.emoji, style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 8),
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
                                onTap: () => _duplicateSheetForStudent(sheet),
                                child: const Icon(Icons.copy, color: AppColors.textMuted, size: 16),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.edit, color: AppColors.textMuted, size: 16),
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
        backgroundColor: AppColors.surface,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Plano Nutricional', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text('Nova',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...meals.map((m) {
            return FadeInUp(
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                            Text('${m.time} • ${m.calories} kcal',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.edit, color: AppColors.textMuted, size: 16),
                            const SizedBox(width: 8),
                            Icon(Icons.delete, color: AppColors.accentError, size: 16),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('P: ${m.protein}g', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
                        Text('C: ${m.carbs}g', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
                        Text('G: ${m.fat}g', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
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

  Widget _buildBadgesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ativo/desative conquistas para este aluno:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: badges.length,
            itemBuilder: (context, index) {
              final badge = badges[index];
              return FadeInUp(
                delay: Duration(milliseconds: index * 50),
                child: Container(
                  decoration: BoxDecoration(
                    color: badge.unlocked ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
                    border: Border.all(
                      color: badge.unlocked ? AppColors.primary : AppColors.border,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(badge.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(height: 8),
                      Text(badge.title,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: badge.unlocked ? AppColors.primary : AppColors.textMuted,
                              fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionRow(String question, String answer) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(question, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
          Text(answer, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
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
