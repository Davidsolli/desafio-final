import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/invitation_provider.dart';

class GenerateInviteScreen extends StatefulWidget {
  const GenerateInviteScreen({super.key});

  @override
  State<GenerateInviteScreen> createState() => _GenerateInviteScreenState();
}

class _GenerateInviteScreenState extends State<GenerateInviteScreen> {
  @override
  void initState() {
    super.initState();
    // Carrega lista de convites ao abrir
    Future.microtask(() {
      context.read<InvitationProvider>().loadMyInvitations();
    });
  }

  void _handleGenerateCode() async {
    final invitationProvider = context.read<InvitationProvider>();
    final success = await invitationProvider.generateNewCode();

    if (mounted) {
      if (success) {
        _showSuccess('Código gerado com sucesso!');
        // Recarrega a lista
        invitationProvider.loadMyInvitations();
      } else {
        _showError(invitationProvider.generationError ?? 'Erro ao gerar código');
      }
    }
  }

  void _copyToClipboard(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Código copiado!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Gerar Códigos de Acesso'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<InvitationProvider>(
        builder: (context, invitationProvider, _) {
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Card de geração de novo código
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gerar Novo Código',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Crie um novo código único para seus alunos se cadastrarem',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: context.colors.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 16),
                          // Código gerado
                          if (invitationProvider.generatedInvitation != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Código Gerado',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: context.colors.textSecondary,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          invitationProvider
                                              .generatedInvitation!.code,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.content_copy),
                                    onPressed: () => _copyToClipboard(
                                      invitationProvider
                                          .generatedInvitation!.code,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: invitationProvider.isGeneratingCode
                                    ? null
                                    : _handleGenerateCode,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  backgroundColor: AppColors.primary,
                                ),
                                child: invitationProvider.isGeneratingCode
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Gerar Novo Código',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Estatísticas
                  if (invitationProvider.myInvitations != null)
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            'Total',
                            invitationProvider.myInvitations!.total
                                .toString(),
                            Icons.card_giftcard,
                            AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Pendentes',
                            invitationProvider.myInvitations!.pending
                                .toString(),
                            Icons.schedule_outlined,
                            Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            'Usados',
                            invitationProvider.myInvitations!.used
                                .toString(),
                            Icons.check_circle_outlined,
                            Colors.green,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  // Lista de convites
                  if (invitationProvider.myInvitations != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Histórico de Códigos',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        if (invitationProvider.myInvitations!.invitations
                            .isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 48,
                                    color: context.colors.textSecondary,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Nenhum código gerado ainda',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: context.colors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: invitationProvider
                                .myInvitations!.invitations.length,
                            itemBuilder: (context, index) {
                              final invitation = invitationProvider
                                  .myInvitations!.invitations[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: invitation.used
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.orange.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      invitation.used
                                          ? Icons.check_circle
                                          : Icons.schedule,
                                      color: invitation.used
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                  title: Text(
                                    invitation.code,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  subtitle: Text(
                                    invitation.used
                                        ? 'Usado em ${invitation.usedAt?.toLocal().toString().split('.')[0] ?? 'desconhecido'}'
                                        : 'Pendente',
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.content_copy,
                                        size: 20),
                                    onPressed: () =>
                                        _copyToClipboard(invitation.code),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    )
                  else if (invitationProvider.isLoadingInvitations)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    )
                  else if (invitationProvider.loadingError != null)
                    Card(
                      color: Colors.red.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          invitationProvider.loadingError ??
                              'Erro ao carregar convites',
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
