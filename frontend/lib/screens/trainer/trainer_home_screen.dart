import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../services/dashboard_service.dart';
import '../../services/api_client.dart';
import '../../shared/widgets/index.dart';

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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Bom dia,';
    if (hour < 18) return 'Boa tarde,';
    return 'Boa noite,';
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
        backgroundColor: context.colors.background,
        body: SafeArea(
          child: Consumer<DashboardProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const OmniLoader();
              }

              if (provider.error != null) {
                return OmniErrorState(
                  message: provider.error ?? 'Erro ao carregar',
                  onRetry: _initDashboard,
                );
              }

              return CustomScrollView(
                slivers: [
                  // ── Header ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greeting(),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: context.colors.textSecondary),
                              ),
                              Row(
                                children: [
                                  Text(
                                    provider.trainerName,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text('🏋️', style: TextStyle(fontSize: 20)),
                                ],
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => context.push(AppRoutes.generateInvite),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.person_add_outlined,
                                  color: AppColors.primary, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Stats 2×2 ───────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _StatsCard(
                                  icon: Icons.people_outlined,
                                  title: '${provider.totalStudents}',
                                  subtitle: 'Alunos Ativos',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatsCard(
                                  icon: Icons.fitness_center_outlined,
                                  title: '${provider.workoutsThisWeek}',
                                  subtitle: 'Treinos esta\nSemana',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatsCard(
                                  icon: Icons.mail_outline,
                                  title: '${provider.pendingInvites}',
                                  subtitle: 'Convites\nPendentes',
                                  onTap: () => context.push(AppRoutes.generateInvite),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _StatsCard(
                                  icon: Icons.trending_up_outlined,
                                  title: '${provider.averageAdherence.toStringAsFixed(0)}%',
                                  subtitle: 'Adesão Média',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Ações Rápidas ────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ações Rápidas',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.person_add_outlined,
                                  label: 'Convidar\nAluno',
                                  color: AppColors.primary,
                                  onTap: () => context.push(AppRoutes.generateInvite),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.assignment_outlined,
                                  label: 'Criar\nFicha',
                                  color: AppColors.accentInfo,
                                  onTap: () => context.go(AppRoutes.trainerSheets),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _QuickActionButton(
                                  icon: Icons.people_outlined,
                                  label: 'Ver\nAlunos',
                                  color: AppColors.accentWarning,
                                  onTap: () => context.go(AppRoutes.trainerStudents),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Alertas: alunos inativos ─────────────────────────────
                  if (provider.studentsNeedingAttention.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFffc84d), size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Precisam de atenção',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(
                                        color: const Color(0xFFffc84d),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...provider.studentsNeedingAttention.map(
                              (s) => _StudentCard(student: s, needsAttention: true),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Lista de Alunos ──────────────────────────────────────
                  if (provider.students.isEmpty)
                    SliverFillRemaining(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: OmniEmptyState(
                          icon: Icons.people_outline,
                          title: 'Nenhum aluno vinculado ainda',
                          subtitle: 'Convide alunos para começar',
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Meus Alunos',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            ...provider.studentsSortedByAdherence.map(
                              (s) => _StudentCard(student: s),
                            ),
                          ],
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

/// Alias local para manter compatibilidade com o código de chamada
class _StatsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _StatsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OmniStatCard(
      icon: icon,
      value: title,
      label: subtitle,
      onTap: onTap,
    );
  }
}

/// Botão de ação rápida
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card individual do aluno
class _StudentCard extends StatelessWidget {
  final StudentDashboardData student;
  final bool needsAttention;

  const _StudentCard({required this.student, this.needsAttention = false});

  @override
  Widget build(BuildContext context) {
    final borderColor = needsAttention
        ? const Color(0xFFffc84d)
        : context.colors.border;

    return GestureDetector(
      onTap: () => context.push('/trainer/student/${student.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: needsAttention
              ? const Color(0xFFffc84d).withOpacity(0.06)
              : context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: needsAttention ? 1.5 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            OmniAvatar(name: student.name.isNotEmpty ? student.name : 'S', size: 48),
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
                          ?.copyWith(color: context.colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Último treino + aderência (direita)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (needsAttention)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFffc84d).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      student.lastWorkout == null
                          ? 'Nunca treinou'
                          : student.lastWorkoutDisplay,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFffc84d),
                          fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  Text(student.lastWorkoutDisplay,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: context.colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                SizedBox(
                  width: 100,
                  child: OmniProgressBar(
                    value: student.adherencePercent / 100,
                    trailingLabel:
                        '${student.adherencePercent.toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
