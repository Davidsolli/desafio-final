import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../providers/admin_provider.dart';

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
    _searchController.addListener(() {
      setState(() {});
    });
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<AdminProvider>(
          builder: (context, provider, _) {
            final filteredStudents = _getFilteredStudents(provider.studentsOfTrainer);
            final activeCount = provider.studentsOfTrainer.where((s) => s.isActive).length;
            final inactiveCount = provider.studentsOfTrainer.where((s) => !s.isActive).length;

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
                      onPressed: () => provider.loadStudentsOfTrainer(widget.trainerId),
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
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
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
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
                            Text(widget.trainerName,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildStatsRow(context, provider.studentsOfTrainer.length, activeCount, inactiveCount),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar aluno...',
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
                const SizedBox(height: 16),
                Expanded(
                  child: filteredStudents.isEmpty
                      ? Center(
                          child: Text('Nenhum aluno encontrado',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredStudents.length,
                          itemBuilder: (context, index) {
                            final student = filteredStudents[index];
                            return FadeInUp(
                              delay: Duration(milliseconds: index * 100),
                              child: _buildStudentCard(
                                context,
                                studentId: student.id,
                                name: student.name,
                                email: student.email,
                                phone: student.phoneWhatsapp ?? '',
                                isActive: student.isActive,
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

  List<dynamic> _getFilteredStudents(List<dynamic> students) {
    var filtered = students;

    // Filtrar por status
    if (_filterStatus == 'active') {
      filtered = filtered.where((s) => s.isActive).toList();
    } else if (_filterStatus == 'inactive') {
      filtered = filtered.where((s) => !s.isActive).toList();
    }

    // Filtrar por busca
    final searchTerm = _searchController.text.toLowerCase();
    if (searchTerm.isNotEmpty) {
      filtered = filtered
          .where((s) => s.name.toLowerCase().contains(searchTerm) || s.email.toLowerCase().contains(searchTerm))
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
                border: Border.all(color: AppColors.border),
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
                border: Border.all(color: AppColors.border),
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
                border: Border.all(color: AppColors.border),
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

  Widget _buildStudentCard(
    BuildContext context, {
    required String studentId,
    required String name,
    required String email,
    required String phone,
    required bool isActive,
    required AdminProvider provider,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                name[0],
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(isActive ? 'Ativo' : 'Inativo'),
                        backgroundColor: isActive ? Colors.green.withAlpha(30) : Colors.red.withAlpha(30),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          color: isActive ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
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
                  onTap: () => context.push('/admin/edit-student', extra: {'studentId': studentId, 'studentName': name, 'studentEmail': email, 'studentPhone': phone}),
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
                  onTap: () => _showStatusDialog(context, studentId, name, isActive, provider),
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
      builder: (context) => AlertDialog(
        title: Text(isActive ? 'Desativar Aluno' : 'Ativar Aluno'),
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
                await provider.toggleUserStatus(studentId, isActive);
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
