import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../models/workout_sheet_model.dart';
import '../../providers/workout_sheet_provider.dart';
import '../../providers/trainer_provider.dart';
import '../../services/user_service.dart';
import '../../services/workout_sheet_service.dart';

class TrainerStudentDetail extends StatefulWidget {
  final String studentId;

  const TrainerStudentDetail({super.key, required this.studentId});

  @override
  State<TrainerStudentDetail> createState() => _TrainerStudentDetailState();
}

class _TrainerStudentDetailState extends State<TrainerStudentDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  UserResponse? _student;
  List<WorkoutSheetListItem> _studentSheets = [];
  bool _sheetsLoading = false;
  String? _sheetsError;
  bool _studentLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudentData();
      _loadStudentSheets();
    });
  }

  Future<void> _loadStudentData() async {
    setState(() => _studentLoading = true);

    // Tenta buscar o aluno na lista já carregada do TrainerProvider
    final trainerProvider = context.read<TrainerProvider>();
    final cached = trainerProvider.students
        .where((s) => s.id == widget.studentId)
        .firstOrNull;

    if (cached != null) {
      setState(() {
        _student = cached;
        _studentLoading = false;
      });
      return;
    }

    // Se a lista ainda não foi carregada, carrega e tenta novamente
    try {
      await trainerProvider.loadStudents();
      final found = trainerProvider.students
          .where((s) => s.id == widget.studentId)
          .firstOrNull;
      if (mounted) {
        setState(() {
          _student = found;
          _studentLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _studentLoading = false);
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
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _student?.name ?? 'Carregando...';

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
            Text(name,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text('Aluno',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
      body: SafeArea(
        child: _studentLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Container(
                    color: AppColors.surface,
                    child: TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(icon: Icon(Icons.info_outline), text: 'Info'),
                        Tab(
                            icon: Icon(Icons.fitness_center),
                            text: 'Treinos'),
                        Tab(
                            icon: Icon(Icons.restaurant_outlined),
                            text: 'Nutrição'),
                        Tab(
                            icon: Icon(Icons.emoji_events),
                            text: 'Conquistas'),
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
    final s = _student;
    if (s == null) {
      return const Center(
          child: Text('Aluno não encontrado',
              style: TextStyle(color: AppColors.textMuted)));
    }
    final imcStr = s.imc.toStringAsFixed(1);
    final tmbStr = '${s.tmb}';
    final weightStr = '${s.weight.toStringAsFixed(1)} kg';
    final heightStr = '${s.height.toStringAsFixed(0)} cm';
    final ageStr = '${s.age} anos';

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
                  child: Text(
                    s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(s.email,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary)),
                  Text('${s.imcLabel}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: FadeInLeft(
                  child: _statCard(
                      Icons.scale, AppColors.primary, weightStr, 'Peso'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FadeInRight(
                  child: _statCard(
                      Icons.height, AppColors.primary, heightStr, 'Altura'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FadeInLeft(
                  child:
                      _statCard(Icons.cake, AppColors.primary, ageStr, 'Idade'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FadeInRight(
                  child: _statCard(Icons.trending_up, AppColors.primary,
                      imcStr, 'IMC'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FadeInLeft(
                  child: _statCard(Icons.local_fire_department,
                      AppColors.primary, tmbStr, 'TMB'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FadeInRight(
                  child: _statCard(Icons.bolt, AppColors.accentInfo,
                      '${s.tdee}', 'TDEE'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Informações de Contato',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _buildQuestionRow('Email', s.email),
          const SizedBox(height: 8),
          if (s.phoneWhatsapp != null && s.phoneWhatsapp!.isNotEmpty) ...[
            _buildQuestionRow('WhatsApp', s.phoneWhatsapp!),
            const SizedBox(height: 8),
          ],
          _buildQuestionRow('IMC', '${imcStr} — ${s.imcLabel}'),
        ],
      ),
    );
  }

  Widget _statCard(
      IconData icon, Color color, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.textMuted)),
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
              Text('Fichas Atribuídas',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('Novo',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_sheetsLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_sheetsError != null)
            Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.accentError, size: 40),
                  const SizedBox(height: 8),
                  Text(_sheetsError!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textMuted)),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loadStudentSheets,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            )
          else if (_studentSheets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.fitness_center_outlined,
                        color: AppColors.textMuted, size: 40),
                    const SizedBox(height: 8),
                    Text('Nenhuma ficha atribuída',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
            )
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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(sheet.emoji,
                                style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sheet.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                  Text(
                                      '${sheet.dayOfWeekLabel} • ${sheet.exerciseCount} exercícios',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                              color: AppColors.textMuted)),
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
                            child: const Icon(Icons.copy,
                                color: AppColors.textMuted, size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit,
                              color: AppColors.textMuted, size: 16),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () => _deleteSheet(sheet),
                            child: const Icon(Icons.delete,
                                color: AppColors.accentError, size: 16),
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
            content: Text(
                'Erro: aluno já possui ficha ativa para este dia da semana (RN-01).'),
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
            child: const Text('Excluir',
                style: TextStyle(color: AppColors.accentError)),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu_outlined,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Plano Nutricional',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Visualização do diário alimentar do aluno em breve. '
              'O módulo de nutrição está disponível para o próprio aluno.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events_outlined,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              'Conquistas',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'As conquistas do aluno são derivadas de suas metas completadas. '
              'Em breve você poderá acompanhar o progresso aqui.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
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
          Text(question,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted)),
          Flexible(
            child: Text(answer,
                textAlign: TextAlign.end,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
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
