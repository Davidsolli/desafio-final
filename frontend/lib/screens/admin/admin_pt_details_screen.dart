import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/admin_provider.dart';
import '../../shared/widgets/index.dart';

class AdminPTDetailsScreen extends StatefulWidget {
  final String trainerId;
  final String trainerName;

  const AdminPTDetailsScreen({
    Key? key,
    required this.trainerId,
    required this.trainerName,
  }) : super(key: key);

  @override
  State<AdminPTDetailsScreen> createState() => _AdminPTDetailsScreenState();
}

class _AdminPTDetailsScreenState extends State<AdminPTDetailsScreen> {
  final _searchController = TextEditingController();
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadStudentsOfTrainer(widget.trainerId);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Consumer<AdminProvider>(
          builder: (context, provider, _) {
            final filtered = _getFiltered(provider.studentsOfTrainer);
            final activeCount = provider.studentsOfTrainer.where((s) => s.isActive).length;
            final inactiveCount = provider.studentsOfTrainer.where((s) => !s.isActive).length;

            if (provider.isLoading) {
              return const Center(child: OmniLoader());
            }

            if (provider.error != null) {
              return OmniErrorState(
                message: 'Erro: ${provider.error}',
                onRetry: () => provider.loadStudentsOfTrainer(widget.trainerId),
              );
            }

            return Column(
              children: [
                // ── Header ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: context.colors.border),
                          ),
                          child: const Icon(Icons.arrow_back, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Alunos de',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: context.colors.textSecondary)),
                            Text(widget.trainerName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Stats ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStatsRow(
                      context, provider.studentsOfTrainer.length, activeCount, inactiveCount),
                ),

                // ── Busca ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: OmniTextField(
                    controller: _searchController,
                    labelText: 'Buscar aluno...',
                    hintText: 'Nome ou email',
                    prefixIcon: Icons.search,
                  ),
                ),

                const SizedBox(height: 12),

                // ── Lista ────────────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? const OmniEmptyState(
                          icon: Icons.person_search,
                          title: 'Nenhum aluno encontrado',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final student = filtered[index];
                            return FadeInUp(
                              delay: Duration(milliseconds: index * 80),
                              child: _buildStudentCard(context, student, provider),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<dynamic> _getFiltered(List<dynamic> students) {
    var list = students;
    if (_filterStatus == 'active') list = list.where((s) => s.isActive).toList();
    if (_filterStatus == 'inactive') list = list.where((s) => !s.isActive).toList();
    final q = _searchController.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((s) => s.name.toLowerCase().contains(q) || s.email.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  Widget _buildStatsRow(BuildContext context, int total, int active, int inactive) {
    return Row(
      children: [
        Expanded(
          child: OmniStatCard(
            value: '$total',
            label: 'Total',
            onTap: () => setState(() => _filterStatus = 'all'),
            isSelected: _filterStatus == 'all',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OmniStatCard(
            value: '$active',
            label: 'Ativos',
            valueColor: Colors.green,
            onTap: () => setState(() => _filterStatus = 'active'),
            isSelected: _filterStatus == 'active',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OmniStatCard(
            value: '$inactive',
            label: 'Inativos',
            valueColor: Colors.red,
            onTap: () => setState(() => _filterStatus = 'inactive'),
            isSelected: _filterStatus == 'inactive',
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(BuildContext context, dynamic student, AdminProvider provider) {
    return GestureDetector(
      onTap: () => context.push('/admin/edit-student', extra: {
        'studentId': student.id,
        'studentName': student.name,
        'studentEmail': student.email,
        'studentPhone': student.phoneWhatsapp,
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.border),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmniAvatar(name: student.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(student.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      OmniStatusBadge(
                        label: student.isActive ? 'Ativo' : 'Inativo',
                        color: student.isActive ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(student.email,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: context.colors.textSecondary)),
                  if (student.phoneWhatsapp != null && student.phoneWhatsapp!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(student.phoneWhatsapp!,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: context.colors.textMuted)),
                  ],
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  context.push('/admin/edit-student', extra: {
                    'studentId': student.id,
                    'studentName': student.name,
                    'studentEmail': student.email,
                    'studentPhone': student.phoneWhatsapp,
                  });
                } else if (value == 'toggle') {
                  _showStatusDialog(context, student.id, student.name, student.isActive, provider);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Text('Editar'),
                  ]),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(
                      student.isActive ? Icons.block : Icons.check_circle,
                      size: 18,
                      color: student.isActive ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(student.isActive ? 'Desativar' : 'Ativar'),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDialog(
    BuildContext context,
    String studentId,
    String name,
    bool isActive,
    AdminProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isActive ? 'Desativar Aluno' : 'Ativar Aluno'),
        content: Text(isActive
            ? 'Tem certeza que deseja desativar $name?'
            : 'Tem certeza que deseja ativar $name?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.toggleUserStatus(studentId, isActive);
                await provider.loadStudentsOfTrainer(widget.trainerId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(isActive
                        ? '$name desativado com sucesso!'
                        : '$name ativado com sucesso!'),
                    backgroundColor: isActive ? Colors.orange : Colors.green,
                  ));
                }
              } catch (_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erro ao atualizar status')),
                  );
                }
              }
            },
            child: Text(isActive ? 'Desativar' : 'Ativar',
                style: TextStyle(color: isActive ? Colors.orange : Colors.green)),
          ),
        ],
      ),
    );
  }
}
