import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/admin_provider.dart';
import '../../models/admin_models.dart';
import '../../shared/widgets/index.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchController = TextEditingController();
  String _filterType = 'all';   // 'all' | 'professionals' | 'students'
  String _filterStatus = 'all'; // 'all' | 'active' | 'inactive'

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadAllUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isProfessional(AdminUserDTO u) => u.role != 'client' && u.role != 'admin';

  List<AdminUserDTO> _baseList(AdminProvider provider) {
    switch (_filterType) {
      case 'professionals':
        return provider.trainers;
      case 'students':
        return provider.allStudents;
      default:
        return [...provider.trainers, ...provider.allStudents];
    }
  }

  List<AdminUserDTO> _filteredList(AdminProvider provider) {
    var list = _baseList(provider);

    if (_filterStatus == 'active') {
      list = list.where((u) => u.isActive).toList();
    } else if (_filterStatus == 'inactive') {
      list = list.where((u) => !u.isActive).toList();
    }

    final q = _searchController.text.toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((u) => u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q))
          .toList();
    }

    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Consumer<AdminProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: OmniLoader());
            }

            if (provider.error != null) {
              return OmniErrorState(
                message: 'Erro: ${provider.error}',
                onRetry: provider.loadAllUsers,
              );
            }

            final base = _baseList(provider);
            final filtered = _filteredList(provider);
            final activeCount = base.where((u) => u.isActive).length;
            final inactiveCount = base.where((u) => !u.isActive).length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gerenciar',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.colors.textSecondary)),
                          Text('Usuários',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      _AddButton(),
                    ],
                  ),
                ),

                // ── Stats ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _buildStatsRow(context, base.length, activeCount, inactiveCount),
                ),

                // ── Busca ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: OmniTextField(
                    controller: _searchController,
                    labelText: 'Buscar usuário...',
                    hintText: 'Nome ou email',
                    prefixIcon: Icons.search,
                  ),
                ),

                // ── Chips de tipo ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _TypeChip(label: 'Todos', value: 'all', selected: _filterType, onTap: (v) => setState(() => _filterType = v)),
                        const SizedBox(width: 8),
                        _TypeChip(label: 'Profissionais', value: 'professionals', selected: _filterType, onTap: (v) => setState(() => _filterType = v)),
                        const SizedBox(width: 8),
                        _TypeChip(label: 'Alunos', value: 'students', selected: _filterType, onTap: (v) => setState(() => _filterType = v)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Lista ────────────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? const OmniEmptyState(
                          icon: Icons.person_search,
                          title: 'Nenhum usuário encontrado',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final user = filtered[index];
                            return FadeInUp(
                              delay: Duration(milliseconds: index * 60),
                              child: _buildUserCard(context, user, provider),
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

  Widget _buildUserCard(BuildContext context, AdminUserDTO user, AdminProvider provider) {
    final isProfessional = _isProfessional(user);

    // Nome do profissional vinculado (para alunos)
    String? linkedProfessionalName;
    if (!isProfessional && user.trainerId != null) {
      try {
        final prof = provider.trainers.firstWhere((t) => t.id == user.trainerId);
        linkedProfessionalName = prof.name;
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () {
        if (isProfessional) {
          context.push('/admin/trainer-students',
              extra: {'trainerId': user.id, 'trainerName': user.name});
        } else {
          context.push('/admin/edit-student', extra: {
            'studentId': user.id,
            'studentName': user.name,
            'studentEmail': user.email,
            'studentPhone': user.phoneWhatsapp,
          });
        }
      },
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
            OmniAvatar(name: user.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nome + status
                  Row(
                    children: [
                      Expanded(
                        child: Text(user.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      OmniStatusBadge(
                        label: user.isActive ? 'Ativo' : 'Inativo',
                        color: user.isActive ? Colors.green : Colors.red,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(user.email,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: context.colors.textSecondary)),
                  const SizedBox(height: 3),
                  // Badge de tipo
                  if (isProfessional)
                    Text(user.specialtyLabel,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.primary, fontWeight: FontWeight.w500))
                  else
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentWarning.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Aluno',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.accentWarning, fontWeight: FontWeight.w600)),
                        ),
                        if (linkedProfessionalName != null) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('• $linkedProfessionalName',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: context.colors.textMuted),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                  if (user.phoneWhatsapp != null && user.phoneWhatsapp!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(user.phoneWhatsapp!,
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
                  if (isProfessional) {
                    context.push('/admin/edit-trainer', extra: {
                      'trainerId': user.id,
                      'trainerName': user.name,
                      'trainerEmail': user.email,
                      'trainerPhone': user.phoneWhatsapp,
                      'trainerRole': user.role,
                    });
                  } else {
                    context.push('/admin/edit-student', extra: {
                      'studentId': user.id,
                      'studentName': user.name,
                      'studentEmail': user.email,
                      'studentPhone': user.phoneWhatsapp,
                    });
                  }
                } else if (value == 'transfer') {
                  _showTransferDialog(context, user, provider);
                } else if (value == 'toggle') {
                  _showStatusDialog(context, user, provider);
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
                if (!isProfessional)
                  PopupMenuItem(
                    value: 'transfer',
                    child: Row(children: [
                      Icon(Icons.swap_horiz, size: 18, color: AppColors.accentInfo),
                      const SizedBox(width: 8),
                      const Text('Transferir'),
                    ]),
                  ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(children: [
                    Icon(
                      user.isActive ? Icons.block : Icons.check_circle,
                      size: 18,
                      color: user.isActive ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(user.isActive ? 'Desativar' : 'Ativar'),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTransferDialog(BuildContext context, AdminUserDTO student, AdminProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransferStudentSheet(
        student: student,
        professionals: provider.trainers,
        onTransfer: (newTrainerId) async {
          try {
            await provider.transferStudent(student.id, newTrainerId);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${student.name} transferido com sucesso!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Erro ao transferir: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _showStatusDialog(BuildContext context, AdminUserDTO user, AdminProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(user.isActive ? 'Desativar usuário' : 'Ativar usuário'),
        content: Text(
          user.isActive
              ? 'Tem certeza que deseja desativar ${user.name}?'
              : 'Tem certeza que deseja ativar ${user.name}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await provider.toggleUserStatus(user.id, user.isActive);
                // Recarrega a lista correta
                if (user.role == 'client') {
                  await provider.loadAllStudents();
                } else {
                  await provider.loadTrainers();
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(user.isActive
                        ? '${user.name} desativado com sucesso!'
                        : '${user.name} ativado com sucesso!'),
                    backgroundColor: user.isActive ? Colors.orange : Colors.green,
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
            child: Text(
              user.isActive ? 'Desativar' : 'Ativar',
              style: TextStyle(color: user.isActive ? Colors.orange : Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Modal de transferência de aluno ────────────────────────────────────────

class _TransferStudentSheet extends StatefulWidget {
  final AdminUserDTO student;
  final List<AdminUserDTO> professionals;
  final Future<void> Function(String newTrainerId) onTransfer;

  const _TransferStudentSheet({
    required this.student,
    required this.professionals,
    required this.onTransfer,
  });

  @override
  State<_TransferStudentSheet> createState() => _TransferStudentSheetState();
}

class _TransferStudentSheetState extends State<_TransferStudentSheet> {
  String? _selectedId;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final currentTrainerId = widget.student.trainerId;
    final professionals = widget.professionals.where((p) => p.isActive).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.accentInfo.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.swap_horiz, color: AppColors.accentInfo, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Transferir Aluno',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text(widget.student.name,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: colors.textMuted,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Subtítulo
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Selecione o profissional destino:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
            ),
            // Lista de profissionais
            Expanded(
              child: professionals.isEmpty
                  ? Center(
                      child: Text('Nenhum profissional ativo disponível',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textMuted)),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: professionals.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final prof = professionals[i];
                        final isCurrent = prof.id == currentTrainerId;
                        final isSelected = _selectedId == prof.id;

                        return GestureDetector(
                          onTap: isCurrent ? null : () => setState(() => _selectedId = prof.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withOpacity(0.08)
                                  : isCurrent
                                      ? colors.surface.withOpacity(0.5)
                                      : colors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : isCurrent
                                        ? AppColors.accentWarning.withOpacity(0.5)
                                        : colors.border,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Avatar
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.primary.withOpacity(0.15),
                                  child: Text(
                                    prof.name[0].toUpperCase(),
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(prof.name,
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                    fontWeight: FontWeight.w600,
                                                    color: isCurrent ? colors.textMuted : null)),
                                          ),
                                          if (isCurrent)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.accentWarning.withOpacity(0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text('Atual',
                                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                      color: AppColors.accentWarning, fontWeight: FontWeight.w600)),
                                            ),
                                        ],
                                      ),
                                      Text(prof.specialtyLabel,
                                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: isCurrent ? colors.textMuted : AppColors.primary)),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            // Botão confirmar
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_selectedId == null || _loading)
                      ? null
                      : () async {
                          setState(() => _loading = true);
                          try {
                            await widget.onTransfer(_selectedId!);
                            if (mounted) Navigator.of(context).pop();
                          } finally {
                            if (mounted) setState(() => _loading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : const Text('Confirmar Transferência',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip de filtro de tipo ──────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  const _TypeChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.colors.border,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isSelected ? Colors.white : context.colors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
        ),
      ),
    );
  }
}

// ── Botão de adicionar com menu ─────────────────────────────────────────────

class _AddButton extends StatelessWidget {
  const _AddButton();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'professional') {
          context.push('/admin/add-trainer');
        }
        // 'student' — alunos precisam de convite, funcionalidade futura
      },
      offset: const Offset(0, 44),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 18),
            const SizedBox(width: 4),
            Text('Adicionar',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'professional',
          child: Row(children: [
            const Icon(Icons.fitness_center, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            const Text('Novo Profissional'),
          ]),
        ),
        PopupMenuItem(
          enabled: false,
          value: 'student',
          child: Row(children: [
            Icon(Icons.school_outlined, size: 18, color: Colors.grey.shade400),
            const SizedBox(width: 10),
            Text('Novo Aluno (via convite)',
                style: TextStyle(color: Colors.grey.shade400)),
          ]),
        ),
      ],
    );
  }
}
