import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/payment_provider.dart';
import '../../routes/app_routes.dart';
import '../../shared/widgets/index.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().loadCurrentSubscription();
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
                  if (provider.isLoadingSubscription) return const OmniLoader();

                  final sub = provider.currentSubscription;

                  if (sub == null) return _buildNoSubscription(context);

                  if (sub.canRenew) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildStatusCard(context, sub.statusLabel, sub.isActive),
                          const SizedBox(height: 16),
                          if (sub.plan != null) _buildPlanCardFaded(context, sub),
                          const SizedBox(height: 24),
                          _buildRenewCard(context, sub),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildStatusCard(context, sub.statusLabel, sub.isActive),
                        const SizedBox(height: 16),
                        if (sub.plan != null) _buildPlanCard(context, sub),
                        const SizedBox(height: 16),
                        _buildDetailsCard(context, sub),
                        if (sub.isActive && sub.daysRemaining <= 7) ...[
                          const SizedBox(height: 16),
                          _buildRenewReminderCard(context),
                        ],
                        if (sub.isActive || sub.isCanceledPending) ...[
                          const SizedBox(height: 24),
                          _buildAccessCard(context),
                        ],
                        if (sub.isActive) ...[
                          const SizedBox(height: 16),
                          _buildActionButtons(context, sub),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Icon(Icons.arrow_back_ios, color: context.colors.textPrimary, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'Minha Assinatura',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSubscription(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.card_membership_outlined, color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'Sem Assinatura Ativa',
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contrate um plano para acessar treinos, dieta e IA.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push(AppRoutes.plans),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Ver Planos Disponíveis', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, String statusLabel, bool isActive) {
    final color = isActive ? AppColors.accentSuccess : AppColors.accentWarning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: Icon(
              isActive ? Icons.check_circle_outline : Icons.schedule_outlined,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Status da Assinatura',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
              ),
              Text(
                statusLabel,
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, sub) {
    final plan = sub.plan!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Plano Contratado',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  plan.durationLabel,
                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            plan.name,
            style: TextStyle(color: context.colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          if (plan.description != null) ...[
            const SizedBox(height: 4),
            Text(plan.description!, style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          Text(
            plan.priceFormatted,
            style: const TextStyle(color: AppColors.primary, fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.surfaceLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Detalhes',
            style: TextStyle(color: context.colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (sub.startedAt != null)
            _buildDetailRow(context, 'Início', _formatDate(sub.startedAt!)),
          if (sub.expiresAt != null) ...[
            _buildDetailRow(context, 'Expira em', _formatDate(sub.expiresAt!)),
            _buildDetailRow(
              context,
              'Dias restantes',
              '${sub.daysRemaining} dias',
              valueColor: sub.daysRemaining <= 7 ? AppColors.accentWarning : null,
            ),
          ],
          if (sub.paymentMethod != null)
            _buildDetailRow(
              context,
              'Pagamento',
              sub.paymentMethod == 'pix' ? 'PIX' : 'Cartão de Crédito',
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? context.colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acesso Completo Incluso',
            style: TextStyle(color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          for (final item in [
            (Icons.fitness_center, 'Treinos personalizados'),
            (Icons.restaurant_menu, 'Plano alimentar'),
            (Icons.smart_toy_outlined, 'Chat com IA'),
            (Icons.bar_chart, 'Logbook e métricas'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(item.$1, color: AppColors.primary, size: 16),
                  const SizedBox(width: 10),
                  Text(item.$2, style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRenewReminderCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentWarning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accentWarning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.accentWarning, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seu plano está acabando!',
                  style: TextStyle(color: AppColors.accentWarning, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Renove agora para não perder o acesso.',
                  style: TextStyle(color: AppColors.accentWarning.withValues(alpha: 0.85), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.push(AppRoutes.plans),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentWarning,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Renovar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCardFaded(BuildContext context, sub) {
    final plan = sub.plan!;
    return Opacity(
      opacity: 0.45,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.surfaceLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Último Plano', style: TextStyle(color: context.colors.textSecondary, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(plan.durationLabel,
                      style: TextStyle(color: context.colors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(plan.name,
                style: TextStyle(color: context.colors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            if (plan.description != null) ...[
              const SizedBox(height: 4),
              Text(plan.description!, style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Text(plan.priceFormatted,
                style: TextStyle(color: context.colors.textMuted, fontSize: 24, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildRenewCard(BuildContext context, sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.card_membership_outlined, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Assinatura encerrada',
                        style: TextStyle(color: context.colors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('Renove para continuar acessando treinos, dieta e IA.',
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push(AppRoutes.plans),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Renovar Plano', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, sub) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.plans),
            icon: const Icon(Icons.swap_horiz, size: 18),
            label: const Text('Trocar Plano'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _confirmCancel(context),
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Cancelar Assinatura'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentError,
              side: const BorderSide(color: AppColors.accentError),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text('Cancelar Assinatura', style: TextStyle(color: context.colors.textPrimary)),
        content: Text(
          'Tem certeza que deseja cancelar sua assinatura? Você perderá o acesso ao final do período pago.',
          style: TextStyle(color: context.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentError),
            child: const Text('Cancelar Assinatura'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success = await context.read<PaymentProvider>().cancelMySubscription();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Assinatura cancelada com sucesso.' : 'Erro ao cancelar assinatura.'),
            backgroundColor: success ? AppColors.accentSuccess : AppColors.accentError,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
