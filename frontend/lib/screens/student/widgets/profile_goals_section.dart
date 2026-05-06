import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../theme/app_colors.dart';
import '../../../../providers/goal_provider.dart';
import '../../../../providers/user_provider.dart';
import '../../../../services/goal_service.dart';
import '../../../../utils/goal_utils.dart';

class ProfileGoalsSection extends StatefulWidget {
  const ProfileGoalsSection({super.key});

  @override
  State<ProfileGoalsSection> createState() => _ProfileGoalsSectionState();
}

class _ProfileGoalsSectionState extends State<ProfileGoalsSection> {
  @override
  void initState() {
    super.initState();
    // #6: só carrega se ainda não há dados e não está carregando
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final p = context.read<GoalProvider>();
      if (p.goals.isEmpty && !p.isLoading) p.loadGoals();
    });
  }

  void _showCreateDialog(String userId) {
    String title = '';
    String description = '';
    String category = 'general';
    String currentValueStr = '0';
    String targetValueStr = '';
    String unit = 'kg';
    DateTime? targetDate;
    bool isSubmitting = false;

    // #3: ctx externo renomeado para dialogCtx — evita shadowing pelo StatefulBuilder
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nova Meta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  onChanged: (v) => title = v,
                  decoration: InputDecoration(
                    labelText: 'Título *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    hintText: 'Ex: Supino 100kg',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  onChanged: (v) => description = v,
                  decoration: InputDecoration(
                    labelText: 'Descrição (opcional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: category,
                  onChanged: (v) => setDialogState(() => category = v ?? 'general'),
                  decoration: InputDecoration(
                    labelText: 'Categoria',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'strength', child: Text('🏋️ Força')),
                    DropdownMenuItem(value: 'endurance', child: Text('🏃 Resistência')),
                    DropdownMenuItem(value: 'composition', child: Text('⚖️ Composição')),
                    DropdownMenuItem(value: 'frequency', child: Text('📅 Frequência')),
                    DropdownMenuItem(value: 'general', child: Text('🎯 Geral')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        onChanged: (v) => targetValueStr = v,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Meta *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: '0',
                        onChanged: (v) => currentValueStr = v,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Atual',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: unit,
                        onChanged: (v) => setDialogState(() => unit = v ?? 'kg'),
                        decoration: InputDecoration(
                          labelText: 'Unidade',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: ['kg', 'km', '%', 'min', 'rep', 'dias']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                    );
                    if (picked != null) setDialogState(() => targetDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: AppColors.textMuted),
                        const SizedBox(width: 8),
                        Text(
                          targetDate != null
                              ? '${targetDate!.day.toString().padLeft(2, '0')}/${targetDate!.month.toString().padLeft(2, '0')}/${targetDate!.year}'
                              : 'Prazo *',
                          style: TextStyle(
                            color: targetDate != null ? null : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              // #7: dialog fica aberto durante a chamada à API
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final target = double.tryParse(targetValueStr);
                      if (title.trim().isEmpty || target == null || targetDate == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Preencha título, meta e prazo')),
                        );
                        return;
                      }
                      setDialogState(() => isSubmitting = true);
                      try {
                        await context.read<GoalProvider>().createGoal(
                              CreateGoalDTO(
                                userId: userId,
                                title: title.trim(),
                                description: description.trim().isEmpty ? null : description.trim(),
                                category: category,
                                currentValue: double.tryParse(currentValueStr) ?? 0,
                                targetValue: target,
                                unit: unit,
                                targetDate: targetDate!,
                              ),
                            );
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        // #2: loga o erro para facilitar depuração
                        debugPrint('[ProfileGoalsSection] erro ao criar meta: $e');
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Erro ao criar meta')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salvar Meta'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(GoalResponse goal) {
    double currentValue = goal.currentValue;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Atualizar Progresso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(goal.title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                'Meta: ${goal.targetValue.toStringAsFixed(1)} ${goal.unit}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: currentValue.toStringAsFixed(1),
                keyboardType: TextInputType.number,
                onChanged: (v) => currentValue = double.tryParse(v) ?? currentValue,
                decoration: InputDecoration(
                  labelText: 'Valor atual (${goal.unit})',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              // #7: dialog fica aberto durante a chamada à API
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        await context.read<GoalProvider>().updateGoalProgress(goal.id, currentValue);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        // #2: loga o erro para facilitar depuração
                        debugPrint('[ProfileGoalsSection] erro ao atualizar progresso: $e');
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Erro ao atualizar progresso')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(String goalId) {
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Excluir Meta'),
          content: const Text('Tem certeza que deseja excluir esta meta?'),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              // #7: dialog fica aberto durante a chamada à API
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDialogState(() => isDeleting = true);
                      try {
                        await context.read<GoalProvider>().deleteGoal(goalId);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        // #2: loga o erro para facilitar depuração
                        debugPrint('[ProfileGoalsSection] erro ao excluir meta: $e');
                        setDialogState(() => isDeleting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Erro ao excluir meta')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentError),
              child: isDeleting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Excluir'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // #1: context.watch garante rebuild quando o usuário mudar
    final userId = context.watch<UserProvider>().user?.id;

    return Consumer<GoalProvider>(
      builder: (context, provider, _) {
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
                  // #1 + #5: botão desabilitado quando userId é nulo
                  TextButton.icon(
                    onPressed: userId == null ? null : () => _showCreateDialog(userId),
                    icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                    label: const Text('Nova', style: TextStyle(color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (provider.isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (provider.error != null)
                _ErrorWidget(
                  message: provider.error!,
                  onRetry: () => provider.loadGoals(),
                )
              else if (provider.goals.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Nenhuma meta cadastrada',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                )
              else
                ...provider.goals.map((goal) {
                  final progress = (goal.progressPercentage / 100).clamp(0.0, 1.0);
                  final isCompleted = goal.isCompleted;

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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      goal.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      GoalUtils.getCategoryLabel(goal.category),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  if (!isCompleted)
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 16, color: AppColors.textMuted),
                                      onPressed: () => _showEditDialog(goal),
                                      tooltip: 'Atualizar progresso',
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 16, color: AppColors.accentError),
                                    onPressed: () => _confirmDelete(goal.id),
                                    tooltip: 'Excluir',
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
                              backgroundColor: AppColors.surfaceLight,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                GoalUtils.getStatusColor(goal.status),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${goal.currentValue.toStringAsFixed(1)} / ${goal.targetValue.toStringAsFixed(1)} ${goal.unit}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: AppColors.textMuted),
                              ),
                              Text(
                                isCompleted
                                    ? '✅ Concluída'
                                    : goal.daysRemaining > 0
                                        ? '${goal.daysRemaining} dias restantes'
                                        : 'Prazo encerrado',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: isCompleted
                                          ? Colors.green
                                          : goal.daysRemaining <= 3
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

class _ErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorWidget({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
