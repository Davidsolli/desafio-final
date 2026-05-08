import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../services/user_service.dart';
import '../../shared/widgets/index.dart';

class TrainerStudentsScreen extends StatefulWidget {
  const TrainerStudentsScreen({super.key});

  @override
  State<TrainerStudentsScreen> createState() => _TrainerStudentsScreenState();
}

class _TrainerStudentsScreenState extends State<TrainerStudentsScreen> {
  late List<UserResponse> _allStudents = [];
  late List<UserResponse> _filteredStudents = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterStudents);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStudents();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userService = context.read<UserService>();
      final students = await userService.getStudents();
      setState(() {
        _allStudents = students;
        _filteredStudents = List.from(students);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar alunos';
        _isLoading = false;
      });
    }
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents
          .where((s) => s.name.toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meus',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary)),
                  Text('Alunos 👥',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildStatsRow(),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OmniTextField(
                controller: _searchController,
                labelText: 'Buscar aluno...',
                hintText: 'Digite o nome do aluno',
                prefixIcon: Icons.search,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const OmniLoader()
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.accentError, size: 40),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textMuted)),
                              const SizedBox(height: 16),
                              OmniButton(
                                text: '🔄 Tentar novamente',
                                onPressed: _loadStudents,
                                isOutlined: true,
                              ),
                            ],
                          ),
                        )
                      : _filteredStudents.isEmpty
                          ? Center(
                              child: Text('Nenhum aluno encontrado',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textMuted)),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _filteredStudents.length,
                              itemBuilder: (context, index) {
                                final student = _filteredStudents[index];
                                return FadeInUp(
                                  delay: Duration(milliseconds: index * 100),
                                  child: GestureDetector(
                                    onTap: () => context.push('/trainer/student/${student.id}'),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: context.colors.surface,
                                        border: Border.all(color: context.colors.border, width: 1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [AppColors.primary, AppColors.primaryLight],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Center(
                                              child: Text(student.name[0],
                                                  style: const TextStyle(
                                                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(student.name,
                                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                                Text(_mapGoalTypeToPt(student.goalType),
                                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Icon(Icons.chevron_right, color: context.colors.textMuted, size: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: FadeInLeft(
            delay: const Duration(milliseconds: 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border.all(color: context.colors.border, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.people, color: AppColors.primary, size: 20),
                  const SizedBox(height: 6),
                  Text('${_allStudents.length}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Alunos Ativos',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FadeInRight(
            delay: const Duration(milliseconds: 100),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border.all(color: context.colors.border, width: 1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.accentInfo, size: 20),
                  const SizedBox(height: 6),
                  Text('${_allStudents.length}x', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Acompanhando',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ],
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
      default:
        return goalType == null || goalType.isEmpty ? 'Sem objetivo' : goalType;
    }
  }
}
