import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../providers/goal_provider.dart';
import '../../../../services/goal_service.dart';

class ProfileGoalsSection extends StatefulWidget {
  const ProfileGoalsSection({super.key});

  @override
  State<ProfileGoalsSection> createState() => _ProfileGoalsSectionState();
}

class _ProfileGoalsSectionState extends State<ProfileGoalsSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<GoalProvider>().loadGoals().catchError((_) {});
      }
    });
  }

  void _showCreateGoalDialog() {
    String title = '';
    String target = '';
    String current = '0';
    String unit = 'kg';
    DateTime? deadline;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nova Meta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  onChanged: (v) => title = v,
                  decoration: InputDecoration(
                    labelText: 'Título',
                    hintText: 'Ex: Supino 100kg',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        onChanged: (v) => target = v,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Meta',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        onChanged: (v) => current = v,
                        initialValue: current,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Atual',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        onChanged: (v) => unit = v ?? 'kg',
                        items: ['kg', 'dias', '%', 'min']
                            .map((e) =>
                                DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        decoration: InputDecoration(
                          labelText: 'Unidade',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) {
                      setDialogState(() => deadline = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(deadline == null
                      ? 'Selecionar prazo'
                      : '${deadline!.day}/${deadline!.month}/${deadline!.year}'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (title.isEmpty ||
                    target.isEmpty ||
                    deadline == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Preencha todos os campos obrigatórios')),
                  );
                  return;
                }
                final dto = CreateGoalDTO(
                  title: title,
                  description: title,
                  targetValue: double.tryParse(target) ?? 0,
                  unit: unit,
                  deadline: deadline!,
                );
                final provider = context.read<GoalProvider>();
                final nav = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await provider.createGoal(dto);
                  nav.pop();
                } catch (e) {
                  messenger.showSnackBar(
                      SnackBar(content: Text('Erro ao criar meta: $e')));
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: const Text('Salvar Meta'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUpdateProgressDialog(GoalResponse goal) {
    String current = goal.currentValue.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Atualizar: ${goal.title}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Meta: ${goal.targetValue.toStringAsFixed(1)} ${goal.unit}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextFormField(
              onChanged: (v) => current = v,
              initialValue: current,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Valor atual (${goal.unit})',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final provider = context.read<GoalProvider>();
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await provider.updateGoalProgress(
                    goal.id, double.tryParse(current) ?? goal.currentValue);
                nav.pop();
              } catch (e) {
                messenger.showSnackBar(
                    SnackBar(content: Text('Erro ao atualizar: $e')));
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GoalProvider>(
      builder: (context, goalProvider, _) {
        return Container(
          padding: const EdgeInsets.all(16),
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
                      const Icon(Icons.track_changes,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Minhas Metas',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: _showCreateGoalDialog,
                    icon: const Icon(Icons.add,
                        size: 16, color: AppColors.primary),
                    label: const Text('Nova',
                        style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (goalProvider.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (goalProvider.error != null)
                Text(
                  goalProvider.error!,
                  style: const TextStyle(color: AppColors.accentError),
                )
              else if (!goalProvider.hasGoals)
                const Text(
                  'Nenhuma meta cadastrada. Crie sua primeira meta!',
                  style: TextStyle(color: AppColors.textMuted),
                )
              else
                ...goalProvider.goals.map((goal) {
                  final progress = goal.progressPercentage / 100;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  goal.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w600),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit,
                                        size: 16,
                                        color: AppColors.textMuted),
                                    onPressed: () =>
                                        _showUpdateProgressDialog(goal),
                                    tooltip: 'Atualizar progresso',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        size: 16,
                                        color: AppColors.accentError),
                                    onPressed: () => goalProvider
                                        .deleteGoal(goal.id)
                                        .catchError((e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                              content: Text(
                                                  'Erro ao deletar: $e')));
                                    }),
                                    tooltip: 'Deletar',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: Colors.grey[300],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                goal.isCompleted
                                    ? Colors.green
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${goal.currentValue.toStringAsFixed(1)}/${goal.targetValue.toStringAsFixed(1)} ${goal.unit}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                              Text(
                                goal.isCompleted
                                    ? '✅ Concluída'
                                    : 'até ${goal.deadline.day}/${goal.deadline.month}/${goal.deadline.year}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: goal.isExpired && !goal.isCompleted
                                          ? AppColors.accentError
                                          : AppColors.textMuted,
                                    ),
                              ),
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
      },
    );
  }
}
