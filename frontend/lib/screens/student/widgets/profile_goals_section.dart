import 'package:flutter/material.dart';
import '../../../../theme/app_colors.dart';
import '../../../../models/mock_data.dart';

class ProfileGoalsSection extends StatefulWidget {
  const ProfileGoalsSection({super.key});

  @override
  State<ProfileGoalsSection> createState() => _ProfileGoalsSectionState();
}

class _ProfileGoalsSectionState extends State<ProfileGoalsSection> {
  List<GoalItem> userGoals = [...goals];

  void _showGoalDialog({GoalItem? editingGoal}) {
    String title = editingGoal?.title ?? '';
    String target = editingGoal?.target.toString() ?? '';
    String current = editingGoal?.current.toString() ?? '0';
    String unit = editingGoal?.unit ?? 'kg';
    String deadline = editingGoal?.deadline ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(editingGoal == null ? 'Nova Meta' : 'Editar Meta'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                onChanged: (v) => title = v,
                initialValue: title,
                decoration: InputDecoration(
                  labelText: 'Título',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: 'Ex: Supino 100kg',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      onChanged: (v) => target = v,
                      initialValue: target,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Meta',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: unit,
                      onChanged: (v) => unit = v ?? 'kg',
                      items: ['kg', 'dias', '%', 'min']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      decoration: InputDecoration(
                        labelText: 'Unidade',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                onChanged: (v) => deadline = v,
                initialValue: deadline,
                decoration: InputDecoration(
                  labelText: 'Prazo (DD/MM/YYYY)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
          ElevatedButton(
            onPressed: () {
              final newGoal = GoalItem(
                id: editingGoal?.id ?? 'g${DateTime.now().millisecondsSinceEpoch}',
                title: title,
                target: double.tryParse(target) ?? 0,
                current: double.tryParse(current) ?? 0,
                unit: unit,
                deadline: deadline,
                completed:
                    (double.tryParse(current) ?? 0) >= (double.tryParse(target) ?? 0),
              );

              setState(() {
                if (editingGoal != null) {
                  final index = userGoals.indexWhere((g) => g.id == editingGoal.id);
                  if (index != -1) userGoals[index] = newGoal;
                } else {
                  userGoals.add(newGoal);
                }
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Salvar Meta'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  const Icon(Icons.track_changes, color: AppColors.primary, size: 18),
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
                onPressed: () => _showGoalDialog(),
                icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                label: const Text('Nova', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...userGoals.map((goal) {
            final progress = (goal.current / goal.target).clamp(0.0, 1.0);
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 16, color: AppColors.textMuted),
                              onPressed: () => _showGoalDialog(editingGoal: goal),
                              tooltip: 'Editar',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 16, color: AppColors.accentError),
                              onPressed: () => setState(() {
                                userGoals.removeWhere((g) => g.id == goal.id);
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
                        value: progress,
                        minHeight: 6,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          goal.completed ? Colors.green : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${goal.current.toStringAsFixed(1)}/${goal.target.toStringAsFixed(1)} ${goal.unit}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                        ),
                        Text(
                          goal.completed ? '✅ Concluída' : 'até ${goal.deadline}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.textMuted,
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
  }
}
