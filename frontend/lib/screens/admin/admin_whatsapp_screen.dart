import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/invitation_provider.dart';
import '../../providers/admin_provider.dart';
import '../../services/invitation_service.dart';
import '../../shared/widgets/index.dart';

class AdminWhatsAppScreen extends StatefulWidget {
  const AdminWhatsAppScreen({Key? key}) : super(key: key);

  @override
  State<AdminWhatsAppScreen> createState() => _AdminWhatsAppScreenState();
}

class _AdminWhatsAppScreenState extends State<AdminWhatsAppScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InvitationProvider>().loadWhatsAppPending();
      context.read<AdminProvider>().loadTrainers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Consumer<InvitationProvider>(
          builder: (context, provider, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, provider),
                const SizedBox(height: 8),
                Expanded(child: _buildBody(context, provider)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, InvitationProvider provider) {
    final total = provider.whatsappPending?.total ?? 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solicitações',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: context.colors.textSecondary),
                ),
                Row(
                  children: [
                    Text(
                      'WhatsApp',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (total > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$total',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: context.colors.textSecondary),
            onPressed: () {
              context.read<InvitationProvider>().loadWhatsAppPending();
              context.read<AdminProvider>().loadTrainers();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, InvitationProvider provider) {
    if (provider.isLoadingWhatsapp) {
      return const Center(child: OmniLoader());
    }

    if (provider.whatsappError != null) {
      return OmniErrorState(
        message: 'Erro ao carregar solicitações',
        onRetry: provider.loadWhatsAppPending,
      );
    }

    final items = provider.whatsappPending?.items ?? [];

    if (items.isEmpty) {
      return const OmniEmptyState(
        icon: Icons.mark_chat_unread_outlined,
        title: 'Nenhuma solicitação pendente',
      );
    }

    return RefreshIndicator(
      onRefresh: provider.loadWhatsAppPending,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildCard(context, provider, items[index]);
        },
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    InvitationProvider provider,
    WhatsAppPendingItem item,
  ) {
    final timeAgo = _formatTimeAgo(item.createdAt);
    final isAwaitingPayment = item.awaitingPayment;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha de avatar + nome + badge de estado
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_chat_unread_outlined,
                    color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name ?? 'Sem nome',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      item.email ?? 'Sem email',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              _buildStateBadge(item),
            ],
          ),

          // Linha de telefone + tempo
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.phone, size: 14, color: context.colors.textMuted),
              const SizedBox(width: 4),
              Text(
                item.phone,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.colors.textMuted),
              ),
              const Spacer(),
              Icon(Icons.access_time,
                  size: 14, color: context.colors.textMuted),
              const SizedBox(width: 4),
              Text(
                timeAgo,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.colors.textMuted),
              ),
            ],
          ),

          // Botão de ação
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: isAwaitingPayment
                ? _buildAwaitingPaymentButton(context)
                : OmniButton(
                    text: 'Aprovar e enviar código',
                    onPressed: () =>
                        _confirmApprove(context, provider, item),
                    height: 40,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateBadge(WhatsAppPendingItem item) {
    if (item.awaitingPayment) {
      return OmniStatusBadge(label: 'Aguard. pagamento', color: Colors.blue);
    }
    if (item.paymentStatus == 'confirmed') {
      return OmniStatusBadge(label: 'Pago ✓', color: Colors.green);
    }
    return OmniStatusBadge(label: 'Pendente', color: Colors.orange);
  }

  Widget _buildAwaitingPaymentButton(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.hourglass_top_rounded,
              size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 6),
          Text(
            'Aguardando confirmação do pagamento',
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmApprove(
    BuildContext context,
    InvitationProvider provider,
    WhatsAppPendingItem item,
  ) {
    // Garante que a lista de trainers está carregada antes de abrir o dialog
    context.read<AdminProvider>().loadTrainers();

    String? selectedTrainerId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Consumer<AdminProvider>(
            builder: (ctx, adminProvider, _) {
              final trainers = adminProvider.trainers
                  .where((t) => t.isActive)
                  .toList();

              return AlertDialog(
                title: const Text('Aprovar cadastro'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aprovar o cadastro de ${item.name ?? item.phone}?\n\n'
                      'Um código de acesso será enviado automaticamente via WhatsApp.',
                    ),
                    const SizedBox(height: 20),
                    // Dropdown de personal trainer
                    adminProvider.isLoading && trainers.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            value: selectedTrainerId,
                            hint: const Text('Selecionar personal trainer'),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Personal Trainer *',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                            items: trainers
                                .map(
                                  (t) => DropdownMenuItem<String>(
                                    value: t.id,
                                    child: Text(
                                      t.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setDialogState(() => selectedTrainerId = val),
                          ),
                    if (trainers.isEmpty && !adminProvider.isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Nenhum personal trainer ativo encontrado.',
                          style: TextStyle(
                              color: Colors.red.shade400, fontSize: 12),
                        ),
                      ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar'),
                  ),
                  TextButton(
                    onPressed: selectedTrainerId == null
                        ? null
                        : () async {
                            final trainerId = selectedTrainerId!;
                            Navigator.pop(ctx);
                            final ok = await provider.approveWhatsApp(
                              item.phone,
                              trainerId: trainerId,
                            );
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? '✅ Código enviado para ${item.name ?? item.phone}!'
                                    : '❌ Erro ao aprovar. Tente novamente.'),
                                backgroundColor:
                                    ok ? Colors.green : Colors.red,
                              ),
                            );
                          },
                    child: Text(
                      'Aprovar',
                      style: TextStyle(
                        color: selectedTrainerId == null
                            ? Colors.grey
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return 'há ${diff.inDays}d';
  }
}
