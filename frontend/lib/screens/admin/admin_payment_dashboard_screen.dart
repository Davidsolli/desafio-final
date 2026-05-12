import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/payment_provider.dart';
import '../../services/payment_service.dart';
import '../../shared/widgets/index.dart';

class AdminPaymentDashboardScreen extends StatefulWidget {
  const AdminPaymentDashboardScreen({super.key});

  @override
  State<AdminPaymentDashboardScreen> createState() => _AdminPaymentDashboardScreenState();
}

class _AdminPaymentDashboardScreenState extends State<AdminPaymentDashboardScreen> {
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Consumer<PaymentProvider>(
          builder: (context, provider, _) {
            return RefreshIndicator(
              onRefresh: () => provider.loadDashboard(statusFilter: _statusFilter),
              color: AppColors.primary,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(context)),
                  if (provider.isLoadingDashboard && provider.summary == null)
                    const SliverFillRemaining(child: OmniLoader())
                  else if (provider.error != null && provider.summary == null)
                    SliverFillRemaining(
                      child: OmniErrorState(
                        message: provider.error!,
                        onRetry: () => provider.loadDashboard(),
                      ),
                    )
                  else ...[
                    if (provider.summary != null)
                      SliverToBoxAdapter(
                        child: _buildSummaryCards(context, provider.summary!),
                      ),
                    SliverToBoxAdapter(
                      child: _buildFilterBar(context, provider),
                    ),
                    if (provider.dashboardSubscriptions.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('Nenhuma assinatura encontrada'),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildSubscriptionCard(
                            context,
                            provider.dashboardSubscriptions[index],
                            provider,
                          ),
                          childCount: provider.dashboardSubscriptions.length,
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pagamentos',
            style: TextStyle(
              color: context.colors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Receita e assinaturas dos alunos',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context, SubscriptionSummary summary) {
    final revenueGrowth = summary.revenueLastMonth > 0
        ? ((summary.revenueThisMonth - summary.revenueLastMonth) / summary.revenueLastMonth * 100)
        : 0.0;
    final isPositive = revenueGrowth >= 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Receita do mês — card grande
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Receita deste mês',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatCurrency(summary.revenueThisMonth),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isPositive ? Icons.trending_up : Icons.trending_down,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${revenueGrowth.toStringAsFixed(1)}% vs mês anterior (${_formatCurrency(summary.revenueLastMonth)})',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Grid de status
          Row(
            children: [
              Expanded(child: _buildStatusCard(context, 'Ativas', summary.totalActive, AppColors.accentSuccess, Icons.check_circle_outline)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatusCard(context, 'Pendentes', summary.totalPending, AppColors.accentWarning, Icons.schedule_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatusCard(context, 'Canceladas', summary.totalCanceled, AppColors.accentError, Icons.cancel_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _buildStatusCard(context, 'Expiradas', summary.totalExpired, context.colors.textSecondary, Icons.timer_off_outlined)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.surfaceLight),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            '$count',
            style: TextStyle(color: context.colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(label, style: TextStyle(color: context.colors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, PaymentProvider provider) {
    final filters = [
      (null, 'Todos'),
      ('active', 'Ativas'),
      ('pending', 'Pendentes'),
      ('canceled', 'Canceladas'),
      ('expired', 'Expiradas'),
    ];

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (value, label) = filters[index];
          final isSelected = _statusFilter == value;
          return GestureDetector(
            onTap: () {
              setState(() => _statusFilter = value);
              provider.loadDashboard(statusFilter: value);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : context.colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : context.colors.surfaceLight,
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : context.colors.textSecondary,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    AdminSubscriptionItem item,
    PaymentProvider provider,
  ) {
    final statusColor = _statusColor(item.status);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.studentName,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      item.studentEmail,
                      style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  item.statusLabel,
                  style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.card_membership_outlined, color: context.colors.textSecondary, size: 14),
              const SizedBox(width: 6),
              Text(
                item.planName,
                style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
              ),
              const Spacer(),
              Text(
                _formatCurrency(item.planPrice),
                style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (item.expiresAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, color: context.colors.textSecondary, size: 14),
                const SizedBox(width: 6),
                Text(
                  item.isActive
                      ? 'Expira em ${_formatDate(item.expiresAt!)}'
                      : 'Expirou em ${_formatDate(item.expiresAt!)}',
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ],
          // Ações
          if (item.isPending || !item.isActive) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (!item.isActive)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmAction(
                        context,
                        title: 'Ativar assinatura?',
                        message: 'Ativar manualmente a assinatura de ${item.studentName}?',
                        confirmLabel: 'Ativar',
                        confirmColor: AppColors.accentSuccess,
                        onConfirm: () => provider.manualActivate(item.id),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Ativar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accentSuccess,
                        side: const BorderSide(color: AppColors.accentSuccess),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                if (!item.isActive && item.isPending) const SizedBox(width: 8),
                if (item.isActive || item.isPending)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmAction(
                        context,
                        title: 'Cancelar assinatura?',
                        message: 'Cancelar a assinatura de ${item.studentName}?',
                        confirmLabel: 'Cancelar',
                        confirmColor: AppColors.accentError,
                        onConfirm: () => provider.manualCancel(item.id),
                      ),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accentError,
                        side: const BorderSide(color: AppColors.accentError),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required Future<bool> Function() onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.surface,
        title: Text(title, style: TextStyle(color: context.colors.textPrimary)),
        content: Text(message, style: TextStyle(color: context.colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Voltar', style: TextStyle(color: context.colors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final success = await onConfirm();
              if (!mounted) return;
              messenger.showSnackBar(SnackBar(
                content: Text(success ? 'Operação realizada com sucesso' : 'Erro ao realizar operação'),
                backgroundColor: success ? AppColors.accentSuccess : AppColors.accentError,
              ));
            },
            child: Text(confirmLabel, style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active': return AppColors.accentSuccess;
      case 'pending': return AppColors.accentWarning;
      case 'canceled':
      case 'canceled_pending': return AppColors.accentError;
      default: return Colors.grey;
    }
  }

  String _formatCurrency(double value) =>
      'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}
