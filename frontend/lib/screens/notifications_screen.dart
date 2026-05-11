import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/theme_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = context.read<NotificationService>();
      final history = await service.getHistory();
      if (!mounted) return;
      setState(() {
        _items = history;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar notificações';
        _loading = false;
      });
    }
  }

  Future<void> _onTapItem(Map<String, dynamic> item) async {
    if (item['read_at'] != null) return;
    final id = item['id']?.toString();
    if (id == null) return;
    final service = context.read<NotificationService>();
    final ok = await service.markAsRead(id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        item['read_at'] = DateTime.now().toUtc().toIso8601String();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.notifications, color: AppColors.primary, size: 24),
            const SizedBox(width: 8),
            Text('Notificações', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: context.colors.textMuted),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _loadHistory,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.notifications_off_outlined,
                  size: 48, color: context.colors.textMuted),
              const SizedBox(height: 12),
              Text(
                'Nenhuma notificação por aqui ainda.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: context.colors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          final unread = item['read_at'] == null;
          final title = (item['title'] ?? '').toString();
          final body = (item['body'] ?? '').toString();
          final type = (item['notification_type'] ?? '').toString();
          final emoji = _emojiForType(type);
          final timeLabel = _formatCreatedAt(item['created_at']);

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _onTapItem(item),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.surface,
                border: Border.all(
                  color: unread ? AppColors.primary : context.colors.border,
                  width: unread ? 1.5 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight:
                                          unread ? FontWeight.bold : FontWeight.w500,
                                      color: context.colors.textPrimary,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unread)
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          body,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: context.colors.textSecondary,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (timeLabel.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            timeLabel,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: context.colors.textMuted,
                                ),
                          ),
                        ],
                      ],
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

  String _emojiForType(String type) {
    switch (type) {
      case 'workout_reminder':
        return '🏋️';
      case 'meal_reminder':
        return '🥗';
      case 'new_workout_sheet':
        return '📋';
      case 'achievement':
        return '🏆';
      case 'performance_report':
        return '📈';
      case 'student_inactivity':
        return '⚠️';
      default:
        return '🔔';
    }
  }

  String _formatCreatedAt(dynamic iso) {
    if (iso == null) return '';
    final raw = iso.toString();
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final dt = parsed.toLocal();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    if (diff.inDays == 1) return 'ontem';
    if (diff.inDays < 7) return '${diff.inDays}d atrás';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }
}
