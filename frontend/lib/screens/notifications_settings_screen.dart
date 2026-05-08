import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  bool isLoading = true;
  bool notificationsEnabled = true;
  bool workoutReminderEnabled = true;
  bool mealReminderEnabled = false;
  bool newWorkoutSheetEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final service = context.read<NotificationService>();
    final prefs = await service.getPreferences();
    
    if (prefs.isNotEmpty) {
      setState(() {
        notificationsEnabled = prefs['notifications_enabled'] ?? true;
        workoutReminderEnabled = prefs['workout_reminder_enabled'] ?? true;
        mealReminderEnabled = prefs['meal_reminder_enabled'] ?? false;
        newWorkoutSheetEnabled = prefs['new_workout_sheet_enabled'] ?? true;
      });
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _updatePreference(String key, dynamic value) async {
    final service = context.read<NotificationService>();
    
    // Atualiza local para resposta rápida (Optimistic UI)
    setState(() {
      if (key == 'notifications_enabled') notificationsEnabled = value;
      if (key == 'workout_reminder_enabled') workoutReminderEnabled = value;
      if (key == 'meal_reminder_enabled') mealReminderEnabled = value;
      if (key == 'new_workout_sheet_enabled') newWorkoutSheetEnabled = value;
    });

    final success = await service.updatePreferences({key: value});
    if (!success && mounted) {
      // Reverte em caso de erro
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao atualizar preferência', style: TextStyle(color: Colors.white))),
      );
      _loadPreferences();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildMasterSwitch(),
          const SizedBox(height: 20),
          if (notificationsEnabled) ...[
            const Text(
              'Lembretes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 10),
            _buildSwitchItem(
              title: 'Lembrete de Treino',
              subtitle: 'Avisar quando for a hora de treinar',
              icon: Icons.fitness_center,
              value: workoutReminderEnabled,
              onChanged: (val) => _updatePreference('workout_reminder_enabled', val),
            ),
            _buildSwitchItem(
              title: 'Lembrete de Refeição',
              subtitle: 'Avisar nos horários da dieta',
              icon: Icons.restaurant,
              value: mealReminderEnabled,
              onChanged: (val) => _updatePreference('meal_reminder_enabled', val),
            ),
            _buildSwitchItem(
              title: 'Novas Fichas',
              subtitle: 'Avisar quando o Personal enviar um novo treino',
              icon: Icons.assignment,
              value: newWorkoutSheetEnabled,
              onChanged: (val) => _updatePreference('new_workout_sheet_enabled', val),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Todas as notificações estão silenciadas. Você não receberá lembretes de treinos nem avisos de metas.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            )
          ]
        ],
      ),
    );
  }

  Widget _buildMasterSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: notificationsEnabled ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notificationsEnabled ? AppTheme.primaryColor.withOpacity(0.5) : Colors.transparent,
        ),
      ),
      child: SwitchListTile(
        title: const Text(
          'Ativar Notificações',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: const Text('Controla todas as notificações do app'),
        value: notificationsEnabled,
        activeColor: AppTheme.primaryColor,
        onChanged: (val) => _updatePreference('notifications_enabled', val),
      ),
    );
  }

  Widget _buildSwitchItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.grey.withOpacity(0.05),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        activeColor: AppTheme.primaryColor,
        onChanged: onChanged,
      ),
    );
  }
}
