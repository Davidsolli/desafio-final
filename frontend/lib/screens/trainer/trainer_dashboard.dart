import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../models/mock_data.dart';
import '../../routes/app_routes.dart';

class TrainerDashboard extends StatefulWidget {
  const TrainerDashboard({super.key});

  @override
  State<TrainerDashboard> createState() => _TrainerDashboardState();
}

class _TrainerDashboardState extends State<TrainerDashboard> {
  late List<Student> _filteredStudents;
  final TextEditingController _searchController = TextEditingController();
  int _selectedNavIndex = 1;

  @override
  void initState() {
    super.initState();
    _filteredStudents = List.from(students);
    _searchController.addListener(_filterStudents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = students
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Olá, Personal',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.textSecondary)),
                      Text('Painel Profissional 👨‍🏫',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.card_giftcard_outlined),
                    color: AppColors.primary,
                    onPressed: () => context.push(AppRoutes.generateInvite),
                    tooltip: 'Gerar Códigos',
                  ),
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
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar aluno...',
                  hintStyle: TextStyle(color: context.colors.textMuted),
                  prefixIcon: Icon(Icons.search, color: context.colors.textMuted),
                  filled: true,
                  fillColor: context.colors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.colors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: TextStyle(color: context.colors.textPrimary),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Alunos', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _filteredStudents.isEmpty
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
                                        Text('${student.goal} • ${student.lastSession}',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted)),
                                      ],
                                    ),
                                  ),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: SizedBox(
                                      width: 60,
                                      height: 24,
                                      child: LinearProgressIndicator(
                                        value: student.progress / 100,
                                        backgroundColor: context.colors.surfaceLight,
                                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('${student.progress.toInt()}%',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                          color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 11)),
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
      bottomNavigationBar: _buildBottomNav(),
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
                  Text('${students.length}', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                  Text('3x', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                  Text('Freq. Média',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.colors.textMuted), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ],
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
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.colors.border, width: 1)),
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedNavIndex,
        onTap: (index) {
          setState(() => _selectedNavIndex = index);
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
