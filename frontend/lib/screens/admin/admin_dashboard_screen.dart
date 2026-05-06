import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/admin_provider.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _searchController = TextEditingController();
  String _filterStatus = 'all'; // all, active, inactive

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminProvider>().loadTrainers();
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<AdminProvider>(
          builder: (context, provider, _) {
            final filteredTrainers = _getFilteredTrainers(provider.trainers);
            final activeCount = provider.trainers.where((t) => t.isActive).length;
            final inactiveCount = provider.trainers.where((t) => !t.isActive).length;

            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.error != null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Erro: ${provider.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => provider.loadTrainers(),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gerenciar',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                      Text('Trainers',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStatsRow(context, provider.trainers.length, activeCount, inactiveCount),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Buscar trainer...',
                            hintStyle: const TextStyle(color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                            filled: true,
                            fillColor: AppColors.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => context.push('/admin/add-trainer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 16),
                Expanded(
                  child: filteredTrainers.isEmpty
                      ? Center(
                          child: Text('Nenhum trainer encontrado',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredTrainers.length,
                          itemBuilder: (context, index) {
                            final trainer = filteredTrainers[index];
                            return FadeInUp(
                              delay: Duration(milliseconds: index * 100),
                              child: _buildTrainerCard(
                                context,
                                trainerId: trainer.id,
                                name: trainer.name,
                                email: trainer.email,
                                phone: trainer.phoneWhatsapp ?? '',
                                isActive: trainer.isActive,
                                provider: provider,
                              ),
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

  List<dynamic> _getFilteredTrainers(List<dynamic> trainers) {
    var filtered = trainers;

    // Filtrar por status
    if (_filterStatus == 'active') {
      filtered = filtered.where((t) => t.isActive).toList();
    } else if (_filterStatus == 'inactive') {
      filtered = filtered.where((t) => !t.isActive).toList();
    }

    // Filtrar por busca
    final searchTerm = _searchController.text.toLowerCase();
    if (searchTerm.isNotEmpty) {
      filtered = filtered
          .where((t) => t.name.toLowerCase().contains(searchTerm) || t.email.toLowerCase().contains(searchTerm))
          .toList();
    }

    return filtered;
  }

  Widget _buildStatsRow(BuildContext context, int total, int active, int inactive) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _filterStatus = 'all'),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _filterStatus == 'all' ? AppColors.primary.withAlpha(20) : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _filterStatus == 'all' ? AppColors.primary : AppColors.border,
                  width: _filterStatus == 'all' ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text('$total',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _filterStatus = 'active'),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _filterStatus == 'active' ? Colors.green.withAlpha(20) : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _filterStatus == 'active' ? Colors.green : AppColors.border,
                  width: _filterStatus == 'active' ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ativos',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.green)),
                  const SizedBox(height: 4),
                  Text('$active',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _filterStatus = 'inactive'),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _filterStatus == 'inactive' ? Colors.red.withAlpha(20) : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _filterStatus == 'inactive' ? Colors.red : AppColors.border,
                  width: _filterStatus == 'inactive' ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Inativos',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red)),
                  const SizedBox(height: 4),
                  Text('$inactive',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrainerCard(
    BuildContext context, {
    required String trainerId,
    required String name,
    required String email,
    required String phone,
    required bool isActive,
    required AdminProvider provider,
  }) {
    return GestureDetector(
      onTap: () => context.push('/admin/trainer-students', extra: {'trainerId': trainerId, 'trainerName': name}),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withAlpha(30),
                  child: Text(
                    name[0],
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
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
                            child: Text(
                              name,
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.withAlpha(20) : Colors.red.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isActive ? 'Ativo' : 'Inativo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isActive ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text('Editar'),
                        ],
                      ),
                      onTap: () => context.push('/admin/edit-trainer', extra: {'trainerId': trainerId, 'trainerName': name, 'trainerEmail': email, 'trainerPhone': phone}),
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.block : Icons.check_circle,
                            size: 18,
                            color: isActive ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(isActive ? 'Desativar' : 'Ativar'),
                        ],
                      ),
                      onTap: () => _showStatusDialog(context, trainerId, name, isActive, provider),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.people,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ver alunos',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusDialog(
    BuildContext context,
    String trainerId,
    String name,
    bool isActive,
    AdminProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isActive ? 'Desativar Trainer' : 'Ativar Trainer'),
        content: Text(
          isActive
              ? 'Tem certeza que deseja desativar $name?'
              : 'Tem certeza que deseja ativar $name?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await provider.toggleUserStatus(trainerId, isActive);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isActive ? '$name desativado com sucesso!' : '$name ativado com sucesso!',
                      ),
                      backgroundColor: isActive ? Colors.orange : Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Erro ao atualizar status')),
                  );
                }
              }
            },
            child: Text(
              isActive ? 'Desativar' : 'Ativar',
              style: TextStyle(
                color: isActive ? Colors.orange : Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
