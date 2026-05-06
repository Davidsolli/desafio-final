import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/goal_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/goal_service.dart';
import '../../utils/goal_utils.dart';
import 'goal_detail_screen.dart';

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
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterTabs(),
            Expanded(
              child: Consumer<GoalProvider>(
                builder: (context, goalProvider, _) {
                  if (goalProvider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
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
                          Icon(Icons.flag_outlined, size: 48, color: context.colors.textMuted),
                          const SizedBox(height: 16),
                          Text(
                            'Nenhuma meta ${_selectedFilter == 'active' ? 'ativa' : _selectedFilter == 'completed' ? 'concluída' : 'expirada'}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: context.colors.textSecondary,
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
                    itemCount: goalProvider.goals.length + (goalProvider.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == goalProvider.goals.length) {
                        return _buildLoadMore(context, goalProvider);
                      }
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

  Widget _buildLoadMore(BuildContext context, GoalProvider goalProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: goalProvider.isLoadingMore
            ? const CircularProgressIndicator()
            : OutlinedButton.icon(
                onPressed: () => goalProvider.loadMoreGoals(),
                icon: const Icon(Icons.expand_more),
                label: const Text('Carregar mais'),
              ),
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
                    color: context.colors.textSecondary,
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
      ('failed', '⏰ Expiradas'),
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
                backgroundColor: context.colors.surface,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : context.colors.textPrimary,
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
      delay: Duration(milliseconds: (index * 60).clamp(0, 300)),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GoalDetailScreen(goalId: goal.id, initialGoal: goal),
          ),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border.all(color: context.colors.border, width: 1),
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
                        if (goal.description != null && goal.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            goal.description!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        Future.microtask(() => _showUpdateGoalDialog(context, goal));
                      } else if (value == 'delete') {
                        Future.microtask(() => _confirmDelete(context, goal));
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Editar'),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Deletar', style: TextStyle(color: AppColors.accentError)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${goal.currentValue.toStringAsFixed(1)} / ${goal.targetValue.toStringAsFixed(1)} ${goal.unit}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: context.colors.textMuted,
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
                  value: (goal.progressPercentage / 100).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: context.colors.surfaceLight,
                  valueColor: AlwaysStoppedAnimation(
                    goal.isCompleted ? Colors.green : AppColors.primary,
                  ),
                ),
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
                        color: goal.isExpired ? AppColors.accentError : context.colors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTargetDate(goal.targetDate),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: goal.isExpired ? AppColors.accentError : context.colors.textMuted,
                            ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        GoalUtils.getCategoryLabel(goal.category),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: context.colors.textMuted,
                            ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: GoalUtils.getStatusColor(goal.status).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      GoalUtils.getStatusLabel(goal.status),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: GoalUtils.getStatusColor(goal.status),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateGoalDialog(BuildContext context) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final currentValueController = TextEditingController();
    final targetValueController = TextEditingController();
    final unitController = TextEditingController(text: 'kg');
    String? selectedCategory;
    DateTime? selectedDate;
    bool isSaving = false;

    final categories = [
      ('strength', 'Força'),
      ('endurance', 'Resistência'),
      ('composition', 'Composição'),
      ('frequency', 'Frequência'),
    ];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nova Meta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título *',
                    hintText: 'Ex: Emagrecer 5kg',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Descrição (opcional)',
                    hintText: 'Ex: Objetivo para o mês',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Categoria *'),
                  value: selectedCategory,
                  items: categories
                      .map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2)))
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedCategory = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: currentValueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor inicial *',
                    hintText: 'Ex: 80',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetValueController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Valor alvo *',
                    hintText: 'Ex: 75',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unidade *',
                    hintText: 'Ex: kg, cm, vezes',
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now().add(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) {
                      setDialogState(() => selectedDate = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    selectedDate == null
                        ? 'Selecionar data alvo *'
                        : '${selectedDate!.day.toString().padLeft(2, '0')}/${selectedDate!.month.toString().padLeft(2, '0')}/${selectedDate!.year}',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: isSaving
                  ? null
                  : () {
                      final title = titleController.text.trim();
                      final unit = unitController.text.trim();
                      final currentValue = double.tryParse(currentValueController.text.trim());
                      final targetValue = double.tryParse(targetValueController.text.trim());

                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Título é obrigatório')),
                        );
                        return;
                      }
                      if (selectedCategory == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Selecione uma categoria')),
                        );
                        return;
                      }
                      if (currentValue == null || currentValue < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Informe um valor inicial válido (≥ 0)')),
                        );
                        return;
                      }
                      if (targetValue == null || targetValue < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Informe um valor alvo válido (≥ 0)')),
                        );
                        return;
                      }
                      if (currentValue == targetValue) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Valor alvo deve ser diferente do valor inicial')),
                        );
                        return;
                      }
                      if (unit.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Informe a unidade')),
                        );
                        return;
                      }
                      if (selectedDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Selecione a data alvo')),
                        );
                        return;
                      }

                      final userId = context.read<AuthProvider>().user?.id;
                      if (userId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Usuário não autenticado')),
                        );
                        return;
                      }

                      final dto = CreateGoalDTO(
                        userId: userId,
                        title: title,
                        description: descriptionController.text.trim().isEmpty
                            ? null
                            : descriptionController.text.trim(),
                        category: selectedCategory!,
                        currentValue: currentValue,
                        targetValue: targetValue,
                        unit: unit,
                        targetDate: selectedDate!,
                      );

                      setDialogState(() => isSaving = true);
                      context.read<GoalProvider>().createGoal(dto).then((_) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Meta criada com sucesso!')),
                        );
                      }).catchError((e) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro: $e')),
                        );
                      });
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Criar'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateGoalDialog(BuildContext context, GoalResponse goal) {
    final currentValueController = TextEditingController(
      text: goal.currentValue.toStringAsFixed(1),
    );
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Atualizar Progresso'),
          content: TextField(
            controller: currentValueController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Valor atual (${goal.unit})',
              hintText: goal.currentValue.toStringAsFixed(1),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: isSaving
                  ? null
                  : () {
                      final newValue = double.tryParse(currentValueController.text);
                      if (newValue == null || newValue < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Informe um valor válido (≥ 0)')),
                        );
                        return;
                      }
                      setDialogState(() => isSaving = true);
                      context.read<GoalProvider>().updateGoalProgress(goal.id, newValue).then((_) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Progresso atualizado!')),
                        );
                      }).catchError((e) {
                        setDialogState(() => isSaving = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erro: $e')),
                        );
                      });
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Atualizar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, GoalResponse goal) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deletar Meta'),
        content: Text('Tem certeza que deseja deletar "${goal.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
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

  String _formatTargetDate(DateTime targetDate) {
    final now = DateTime.now();
    final difference = targetDate.difference(now).inDays;
    if (difference < 0) return 'Expirado';
    if (difference == 0) return 'Hoje';
    if (difference == 1) return 'Amanhã';
    return 'Em $difference dias';
  }

}
