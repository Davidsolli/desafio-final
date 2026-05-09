import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/invitation_provider.dart';
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
            onPressed: () =>
                context.read<InvitationProvider>().loadWhatsAppPending(),
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
          final item = items[index];
          return _buildCard(context, provider, item.phone, item.name,
              item.email, item.createdAt);
        },
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    InvitationProvider provider,
    String phone,
    String? name,
    String? email,
    DateTime createdAt,
  ) {
    final timeAgo = _formatTimeAgo(createdAt);

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
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_chat_unread_outlined, color: Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? 'Sem nome',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Text(
                      email ?? 'Sem email',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              OmniStatusBadge(label: 'Pendente', color: Colors.orange),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.phone, size: 14, color: context.colors.textMuted),
              const SizedBox(width: 4),
              Text(
                phone,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: context.colors.textMuted),
              ),
              const Spacer(),
              Icon(Icons.access_time, size: 14, color: context.colors.textMuted),
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OmniButton(
              text: 'Aprovar e enviar código',
              onPressed: () => _confirmApprove(context, provider, phone, name),
              height: 40,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmApprove(
    BuildContext context,
    InvitationProvider provider,
    String phone,
    String? name,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprovar cadastro'),
        content: Text(
          'Aprovar o cadastro de ${name ?? phone}?\n\nUm código de acesso será enviado automaticamente via WhatsApp.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await provider.approveWhatsApp(phone);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok
                      ? '✅ Código enviado para ${name ?? phone}!'
                      : '❌ Erro ao aprovar. Tente novamente.'),
                  backgroundColor: ok ? Colors.green : Colors.red,
                ),
              );
            },
            child: const Text(
              'Aprovar',
              style: TextStyle(color: Colors.green),
            ),
          ),
        ],
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
