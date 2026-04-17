import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_colors.dart';
import '../../models/mock_data.dart';

class TrainerStudentDetail extends StatefulWidget {
  final String studentId;

  const TrainerStudentDetail({super.key, required this.studentId});

  @override
  State<TrainerStudentDetail> createState() => _TrainerStudentDetailState();
}

class _TrainerStudentDetailState extends State<TrainerStudentDetail> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Student _student;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _student = students.firstWhere((s) => s.id == widget.studentId, orElse: () => students[0]);
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
                    Text('Novo',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...workouts.map((w) {
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
                        Row(
                          children: [
                            Text(w.emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${w.name} — ${w.label}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                                Text('${w.dayOfWeek} • ${w.exercises.length} exercícios',
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted)),
                              ],
                            ),
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
                    Wrap(
                      spacing: 6,
                      children: w.exercises.map((ex) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(ex.name,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
                        );
                      }).toList(),
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
