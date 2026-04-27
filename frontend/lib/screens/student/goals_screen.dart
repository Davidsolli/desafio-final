import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_colors.dart';
import '../../routes/app_routes.dart';
import '../../providers/goal_provider.dart';
import '../../services/goal_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  String _selectedFilter = 'active';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GoalProvider>().loadGoals(status: _selectedFilter).catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao carregar metas: $e')),
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterTabs(),
            Expanded(
              child: Consumer<GoalProvider>(
                builder: (context, goalProvider, _) {
                  if (goalProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (goalProvider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppColors.accentError),
                          const SizedBox(height: 16),
                          Text(goalProvider.error ?? 'Erro ao carregar metas'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => goalProvider.loadGoals(status: _selectedFilter),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!goalProvider.hasGoals) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flag_outlined, size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma meta ${_selectedFilter == 'active' ? 'ativa' : _selectedFilter == 'completed' ? 'concluída' : 'expirada'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () => _showCreateGoalDialog(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Criar Meta'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: goalProvider.goals.length,
                    itemBuilder: (context, index) {
                      final goal = goalProvider.goals[index];
                      return _buildGoalCard(context, goal, index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateGoalDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 300),
            child: Text(
              'Minhas Metas',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          FadeInUp(
            duration: const Duration(milliseconds: 300),
            delay: const Duration(milliseconds: 100),
            child: Text(
              'Acompanhe seu progresso e alcance seus objetivos',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      ('active', '🔥 Ativas'),
      ('completed', '✅ Concluídas'),
      ('expired', '⏰ Expiradas'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedFilter == filter.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filter.$2),
                selected: isSelected,
                backgroundColor: AppColors.surface,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedFilter = filter.$1);
                    context.read<GoalProvider>().loadGoals(status: filter.$1);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, GoalResponse goal, int index) {
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      delay: Duration(milliseconds: index * 100),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        goal.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Text('Editar'),
                      onTap: () => _showUpdateGoalDialog(context, goal),
                    ),
                    PopupMenuItem(
                      child: const Text('Deletar', style: TextStyle(color: AppColors.accentError)),
                      onTap: () => _confirmDelete(context, goal),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${goal.currentValue.toStringAsFixed(1)} / ${goal.targetValue.toStringAsFixed(1)} ${goal.unit}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.textMuted,
                                ),
                          ),
                          Text(
                            '${goal.progressPercentage.toStringAsFixed(0)}%',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: goal.progressPercentage / 100,
                          minHeight: 6,
                          backgroundColor: AppColors.surfaceLight,
                          valueColor: AlwaysStoppedAnimation(
                            goal.isCompleted ? Colors.green : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: goal.isExpired ? AppColors.accentError : AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDeadline(goal.deadline),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: goal.isExpired ? AppColors.accentError : AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(goal.status).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _getStatusLabel(goal.status),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _getStatusColor(goal.status),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateGoalDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final targetController = TextEditingController();
    final unitController = TextEditingController(text: 'kg');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nova Meta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ex: Emagrecer 5kg',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descrição',
                  hintText: 'Ex: Objetivo mensal',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Valor alvo',
                  hintText: 'Ex: 75',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: unitController,
                decoration: const InputDecoration(
                  labelText: 'Unidade',
                  hintText: 'Ex: kg, cm, vezes',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final dto = CreateGoalDTO(
                title: titleController.text,
                description: descriptionController.text,
                targetValue: double.tryParse(targetController.text) ?? 0,
                unit: unitController.text,
                deadline: DateTime.now().add(const Duration(days: 30)),
              );

              context.read<GoalProvider>().createGoal(dto).then((_) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Meta criada com sucesso!')),
                );
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro: $e')),
                );
              });
            },
            child: const Text('Criar'),
          ),
        ],
      ),
    );
  }

  void _showUpdateGoalDialog(BuildContext context, GoalResponse goal) {
    final currentValueController = TextEditingController(
      text: goal.currentValue.toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Atualizar Progresso'),
        content: TextField(
          controller: currentValueController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Valor atual (${goal.unit})',
            hintText: goal.currentValue.toStringAsFixed(1),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final newValue = double.tryParse(currentValueController.text) ?? goal.currentValue;
              context.read<GoalProvider>().updateGoalProgress(goal.id, newValue).then((_) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Progresso atualizado!')),
                );
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro: $e')),
                );
              });
            },
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, GoalResponse goal) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar Meta'),
        content: Text('Tem certeza que deseja deletar "${goal.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<GoalProvider>().deleteGoal(goal.id).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Meta deletada!')),
                );
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro: $e')),
                );
              });
            },
            child: const Text('Deletar', style: TextStyle(color: AppColors.accentError)),
          ),
        ],
      ),
    );
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now).inDays;

    if (difference < 0) {
      return 'Expirado';
    } else if (difference == 0) {
      return 'Hoje';
    } else if (difference == 1) {
      return 'Amanhã';
    } else {
      return 'Em $difference dias';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return AppColors.primary;
      case 'completed':
        return Colors.green;
      case 'failed':
        return AppColors.accentError;
      default:
        return AppColors.textMuted;
    }
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return 'Ativa';
      case 'completed':
        return 'Concluída';
      case 'failed':
        return 'Expirada';
      default:
        return 'Desconhecido';
    }
  }
}
