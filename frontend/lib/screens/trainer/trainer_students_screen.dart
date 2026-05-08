import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
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
                      ? OmniErrorState(
                          message: _error!,
                          onRetry: _loadStudents,
                        )
                      : _filteredStudents.isEmpty
                          ? const OmniEmptyState(
                              icon: Icons.person_search,
                              title: 'Nenhum aluno encontrado',
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
                                          OmniAvatar(name: student.name, useGradient: true),
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
          child: OmniStatCard(
            icon: Icons.people,
            value: '${_allStudents.length}',
            label: 'Alunos Ativos',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OmniStatCard(
            icon: Icons.calendar_today,
            value: '${_allStudents.length}x',
            label: 'Acompanhando',
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
