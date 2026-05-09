import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../routes/app_routes.dart';
import '../../services/chat_api_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';

/// Tela de histórico de conversas com o chatbot (Card 18.10).
///
/// Lista as conversas anteriores via `GET /api/v1/chat/conversations`
/// ordenadas pela mais recente. Toque em um item abre a conversa.
class ChatHistoryScreen extends StatefulWidget {
  /// Permite injetar o serviço em testes; em produção usa o Provider.
  final ChatApiService? apiService;

  const ChatHistoryScreen({super.key, this.apiService});

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  late Future<ConversationListResponse> _future;
  late ChatApiService _service;

  @override
  void initState() {
    super.initState();
    _service = widget.apiService ?? context.read<ChatApiService>();
    _future = _service.getConversations();
  }

  void _reload() {
    setState(() {
      _future = _service.getConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Histórico de conversas'),
      ),
      body: FutureBuilder<ConversationListResponse>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(onRetry: _reload);
          }
          final conversations =
              List<Conversation>.from(snapshot.data?.conversations ?? const [])
                ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

          if (conversations.isEmpty) {
            return const _EmptyHistoryState();
          }

          return ListView.separated(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final conv = conversations[index];
              return _ConversationTile(conversation: conv);
            },
          );
        },
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;

  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colors.border, width: 1),
      ),
      child: ListTile(
        key: ValueKey<String>(conversation.id),
        leading: const CircleAvatar(
          backgroundColor: AppColors.primary,
          child: Icon(Icons.chat_bubble_outline,
              color: Colors.white, size: 20),
        ),
        title: Text(
          _formatStartedAt(conversation.startedAt),
          style: TextStyle(
            color: context.colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${_statusLabel(conversation)} • '
          '${conversation.messageCount} mensagens',
          style: TextStyle(
            color: context.colors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: Icon(Icons.chevron_right, color: context.colors.textMuted),
        onTap: () => context.push(
          AppRoutes.chat,
          extra: {'conversationId': conversation.id},
        ),
      ),
    );
  }

  String _statusLabel(Conversation c) {
    if (c.escalated) return 'Escalada';
    switch (c.status.toLowerCase()) {
      case 'fechada':
      case 'closed':
        return 'Fechada';
      case 'ativa':
      case 'active':
      case 'open':
        return 'Ativa';
      default:
        return c.status;
    }
  }

  String _formatStartedAt(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final isToday = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final isYesterday = local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day;

    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');

    if (isToday) return 'Hoje $hh:$mm';
    if (isYesterday) return 'Ontem $hh:$mm';

    final dd = local.day.toString().padLeft(2, '0');
    final mo = local.month.toString().padLeft(2, '0');
    return '$dd/$mo $hh:$mm';
  }
}

class _EmptyHistoryState extends StatelessWidget {
  const _EmptyHistoryState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 56, color: context.colors.textMuted),
            const SizedBox(height: 12),
            Text(
              'Você ainda não tem conversas. Comece perguntando algo!',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.chat),
              child: const Text('Conversar agora'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 56, color: AppColors.accentError),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar o histórico.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
