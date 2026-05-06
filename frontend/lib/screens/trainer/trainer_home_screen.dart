import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/dashboard_service.dart';
import '../../services/api_client.dart';

class TrainerHomeScreen extends StatefulWidget {
  const TrainerHomeScreen({super.key});

  @override
  State<TrainerHomeScreen> createState() => _TrainerHomeScreenState();
}

class _TrainerHomeScreenState extends State<TrainerHomeScreen> {
  late DashboardProvider _dashboardProvider;

  @override
  void initState() {
    super.initState();
    _initDashboard();
  }

  void _initDashboard() {
    final apiClient = context.read<ApiClient>();
    final service = DashboardService(apiClient);
    _dashboardProvider = DashboardProvider(service);

    final authProvider = context.read<AuthProvider>();
    final trainerName = authProvider.user?.name ?? 'Personal';

    _dashboardProvider.loadDashboard(trainerName: trainerName);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _dashboardProvider,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Consumer<DashboardProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }

              if (provider.error != null) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text(provider.error ?? 'Erro ao carregar',
                          style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => _initDashboard(),
                        child: const Text('Tentar Novamente'),
                      ),
                    ],
                  ),
                );
              }

              return CustomScrollView(
                slivers: [
                  // Header
                  SliverAppBar(
                    backgroundColor: AppColors.background,
                    elevation: 0,
                    pinned: false,
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Olá, ${provider.trainerName}',
                                      style: Theme.of(context).textTheme.bodySmall
                                          ?.copyWith(color: AppColors.textSecondary)),
                                  Text('Painel Profissional 👨‍🏫',
                                      style: Theme.of(context).textTheme.headlineSmall
                                          ?.copyWith(fontWeight: FontWeight.bold)),
                                ],
                              ),
                              IconButton(
                                icon: const Icon(Icons.card_giftcard_outlined),
                                color: AppColors.primary,
                                onPressed: () => context.push(AppRoutes.generateInvite),
                                tooltip: 'Gerar Convite',
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Stats
                          Row(
                            children: [
                              // Total Alunos
                              Expanded(
                                child: _StatsCard(
                                  icon: Icons.people_outlined,
                                  title: '${provider.totalStudents}',
                                  subtitle: 'Alunos Ativos',
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Freq Média
                              Expanded(
                                child: _StatsCard(
                                  icon: Icons.calendar_today_outlined,
                                  title: '${provider.averageFrequency.toStringAsFixed(1)}x',
                                  subtitle: 'Freq. Média',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Lista de Alunos
                  if (provider.students.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline,
                                size: 48, color: AppColors.textMuted),
                            const SizedBox(height: 16),
                            Text('Nenhum aluno vinculado ainda',
                                style: Theme.of(context).textTheme.bodyLarge),
                            const SizedBox(height: 8),
                            Text('Crie uma ficha de treino para começar',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final student = provider.studentsSortedByAdherence[index];
                            return _StudentCard(student: student);
                          },
                          childCount: provider.students.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Card com estatísticas
class _StatsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StatsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// Card individual do aluno
class _StudentCard extends StatelessWidget {
  final StudentDashboardData student;

  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/trainer/student/${student.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary,
              child: Text(
                student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('${student.goalLabel} • ${student.frequencyDisplay}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Último treino (direita)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(student.lastWorkoutDisplay,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                // Barra de progresso + %
                Row(
                  children: [
                    SizedBox(
                      width: 60,
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: student.adherencePercent / 100,
                          backgroundColor: AppColors.textMuted.withOpacity(0.2),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${student.adherencePercent.toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
