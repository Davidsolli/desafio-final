import 'package:flutter/foundation.dart';

/// Modelo de notificação do app
class AppNotificationModel {
  final String id;
  final String title;
  final String message;
  final String emoji;
  final String type; // 'goal', 'workout', 'diet', 'system'
  final DateTime createdAt;
  bool unread;

  AppNotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.emoji,
    required this.type,
    required this.createdAt,
    this.unread = true,
  });

  String get formattedTime {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }
}

/// Provider para gerenciar notificações do app.
///
/// No MVP, as notificações são geradas localmente com base em eventos
/// (meta concluída, treino finalizado, etc.) e persistidas em memória.
/// Futuramente, serão integradas com FCM (RF-37 a RF-42).
class NotificationProvider extends ChangeNotifier {
  final List<AppNotificationModel> _notifications = [];
  bool _isLoading = false;

  // Getters
  List<AppNotificationModel> get notifications =>
      List.unmodifiable(_notifications);
  int get unreadCount =>
      _notifications.where((n) => n.unread).length;
  bool get hasNotifications => _notifications.isNotEmpty;
  bool get isLoading => _isLoading;

  /// Adiciona uma notificação ao topo da lista
  void addNotification(AppNotificationModel notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  /// Adiciona notificação de meta concluída
  void notifyGoalCompleted(String goalTitle) {
    addNotification(AppNotificationModel(
      id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Meta concluída! 🎯',
      message: 'Parabéns! Você concluiu a meta: $goalTitle',
      emoji: '🏆',
      type: 'goal',
      createdAt: DateTime.now(),
    ));
  }

  /// Adiciona notificação de treino finalizado
  void notifyWorkoutCompleted(String workoutName) {
    addNotification(AppNotificationModel(
      id: 'workout_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Treino finalizado! 💪',
      message: 'Você concluiu o treino: $workoutName',
      emoji: '💪',
      type: 'workout',
      createdAt: DateTime.now(),
    ));
  }

  /// Adiciona notificação de nova ficha de treino atribuída
  void notifyNewWorkoutSheet(String sheetName) {
    addNotification(AppNotificationModel(
      id: 'sheet_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Nova ficha de treino',
      message: 'Seu personal atribuiu uma nova ficha: $sheetName',
      emoji: '📋',
      type: 'workout',
      createdAt: DateTime.now(),
    ));
  }

  /// Marca uma notificação como lida
  void markAsRead(String notificationId) {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      _notifications[idx].unread = false;
      notifyListeners();
    }
  }

  /// Marca todas como lidas
  void markAllAsRead() {
    for (final n in _notifications) {
      n.unread = false;
    }
    notifyListeners();
  }

  /// Remove uma notificação
  void remove(String notificationId) {
    _notifications.removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  /// Limpa todas as notificações
  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }
}
