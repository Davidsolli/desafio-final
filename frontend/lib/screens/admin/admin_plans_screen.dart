import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/payment_provider.dart';
import '../../services/payment_service.dart';
import '../../shared/widgets/index.dart';

class AdminPlansScreen extends StatefulWidget {
  const AdminPlansScreen({super.key});

  @override
  State<AdminPlansScreen> createState() => _AdminPlansScreenState();
}

class _AdminPlansScreenState extends State<AdminPlansScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().loadAdminPlans();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Consumer<PaymentProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) return const OmniLoader();

                  if (provider.error != null) {
                    return OmniErrorState(
                      message: provider.error!,
                      onRetry: () => provider.loadAdminPlans(),
                    );
                  }

                  if (provider.plans.isEmpty) {
                    return OmniEmptyState(
                      icon: Icons.card_membership_outlined,
                      title: 'Nenhum plano criado',
                      subtitle: 'Crie seu primeiro plano de assinatura.',
                      actionLabel: '+ Criar Plano',
                      onAction: () => _showCreatePlanDialog(context),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: provider.plans.length,
                    itemBuilder: (context, index) =>
                        _buildPlanCard(context, provider.plans[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePlanDialog(context),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Novo Plano', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Meus Planos',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Gerencie os planos de assinatura',
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, PlanModel plan) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.colors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: plan.isActive
                      ? AppColors.accentSuccess.withValues(alpha: 0.15)
                      : AppColors.accentError.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  plan.isActive ? 'Ativo' : 'Inativo',
                  style: TextStyle(
                    color: plan.isActive ? AppColors.accentSuccess : AppColors.accentError,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showEditPlanDialog(context, plan),
                child: Icon(Icons.edit_outlined, color: context.colors.textSecondary, size: 20),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmDelete(context, plan),
                child: const Icon(Icons.delete_outline, color: AppColors.accentError, size: 20),
              ),
            ],
          ),
          if (plan.description != null) ...[
            const SizedBox(height: 4),
            Text(plan.description!, style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                plan.priceFormatted,
                style: const TextStyle(color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                '• ${plan.durationLabel}',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCreatePlanDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    int selectedDuration = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Criar Novo Plano',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                OmniTextField(
                  controller: nameCtrl,
                  labelText: 'Nome do plano',
                  hintText: 'Ex: Plano Premium',
                ),
                const SizedBox(height: 12),
                OmniTextField(
                  controller: descCtrl,
                  labelText: 'Descrição (opcional)',
                  hintText: 'Ex: Treino + Dieta + IA',
                ),
                const SizedBox(height: 12),
                OmniTextField(
                  controller: priceCtrl,
                  labelText: 'Valor (R\$)',
                  hintText: 'Ex: 150.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                Text(
                  'Duração',
                  style: TextStyle(color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [1, 3, 6, 12].map((months) {
                    final isSelected = selectedDuration == months;
                    final label = months == 12 ? '1 ano' : '$months ${months == 1 ? 'mês' : 'meses'}';
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedDuration = months),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : context.colors.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : context.colors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _doCreatePlan(
                      ctx,
                      nameCtrl.text,
                      descCtrl.text,
                      priceCtrl.text,
                      selectedDuration,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Criar Plano', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _doCreatePlan(
    BuildContext ctx,
    String name,
    String description,
    String priceStr,
    int durationMonths,
  ) async {
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome do plano é obrigatório'), backgroundColor: AppColors.accentError),
      );
      return;
    }

    final price = double.tryParse(priceStr.replaceAll(',', '.'));
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor válido'), backgroundColor: AppColors.accentError),
      );
      return;
    }

    Navigator.pop(ctx);

    final provider = context.read<PaymentProvider>();
    final success = await provider.createPlan(
      name: name.trim(),
      description: description.trim().isEmpty ? null : description.trim(),
      price: price,
      durationMonths: durationMonths,
      modality: null,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Plano criado com sucesso!' : provider.error ?? 'Erro ao criar plano'),
        backgroundColor: success ? AppColors.accentSuccess : AppColors.accentError,
      ),
    );
  }

  void _confirmDelete(BuildContext context, PlanModel plan) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Excluir plano?', style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          'O plano "${plan.name}" será desativado. Assinaturas existentes não serão afetadas.',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<PaymentProvider>();
              final messenger = ScaffoldMessenger.of(context);
              final success = await provider.deletePlan(plan.id);
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(success ? 'Plano excluído' : 'Erro ao excluir'),
                  backgroundColor: success ? AppColors.accentSuccess : AppColors.accentError,
                ),
              );
            },
            child: const Text('Excluir', style: TextStyle(color: AppColors.accentError)),
          ),
        ],
      ),
    );
  }

  void _showEditPlanDialog(BuildContext context, PlanModel plan) {
    final nameCtrl = TextEditingController(text: plan.name);
    final descCtrl = TextEditingController(text: plan.description ?? '');
    final priceCtrl = TextEditingController(text: plan.price.toStringAsFixed(2));
    int selectedDuration = plan.durationMonths;
    bool isActive = plan.isActive;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: context.colors.surfaceLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Editar Plano',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                OmniTextField(
                  controller: nameCtrl,
                  labelText: 'Nome do plano',
                  hintText: 'Ex: Plano Premium',
                ),
                const SizedBox(height: 12),
                OmniTextField(
                  controller: descCtrl,
                  labelText: 'Descrição (opcional)',
                  hintText: 'Ex: Treino + Dieta + IA',
                ),
                const SizedBox(height: 12),
                OmniTextField(
                  controller: priceCtrl,
                  labelText: 'Valor (R\$)',
                  hintText: 'Ex: 150.00',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                Text(
                  'Duração',
                  style: TextStyle(color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [1, 3, 6, 12].map((months) {
                    final isSelected = selectedDuration == months;
                    final label = months == 12 ? '1 ano' : '$months ${months == 1 ? 'mês' : 'meses'}';
                    return GestureDetector(
                      onTap: () => setModalState(() => selectedDuration = months),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : context.colors.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : context.colors.textSecondary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Plano Ativo',
                      style: TextStyle(color: context.colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Switch(
                      value: isActive,
                      activeColor: AppColors.primary,
                      onChanged: (val) => setModalState(() => isActive = val),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _doUpdatePlan(
                      ctx,
                      plan.id,
                      nameCtrl.text,
                      descCtrl.text,
                      priceCtrl.text,
                      selectedDuration,
                      isActive,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Salvar Alterações', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _doUpdatePlan(
    BuildContext ctx,
    String planId,
    String name,
    String description,
    String priceStr,
    int durationMonths,
    bool isActive,
  ) async {
    if (name.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome do plano é obrigatório'), backgroundColor: AppColors.accentError),
      );
      return;
    }

    final price = double.tryParse(priceStr.replaceAll(',', '.'));
    if (price == null || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um valor válido'), backgroundColor: AppColors.accentError),
      );
      return;
    }

    Navigator.pop(ctx);

    final provider = context.read<PaymentProvider>();
    final success = await provider.updatePlan(
      planId,
      name: name.trim(),
      description: description.trim().isEmpty ? null : description.trim(),
      price: price,
      durationMonths: durationMonths,
      isActive: isActive,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Plano atualizado com sucesso!' : provider.error ?? 'Erro ao atualizar plano'),
        backgroundColor: success ? AppColors.accentSuccess : AppColors.accentError,
      ),
    );
  }
}
