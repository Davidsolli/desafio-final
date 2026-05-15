import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../utils/available_timezones.dart';
import 'widgets/notification_toggle_tile.dart';

class NotificationsSettingsClientScreen extends StatefulWidget {
  const NotificationsSettingsClientScreen({super.key});

  @override
  State<NotificationsSettingsClientScreen> createState() =>
      _NotificationsSettingsClientScreenState();
}

class _NotificationsSettingsClientScreenState
    extends State<NotificationsSettingsClientScreen> {
  bool isLoading = true;
  bool notificationsEnabled = true;
  bool workoutReminderEnabled = true;
  bool mealReminderEnabled = false;
  bool newWorkoutSheetEnabled = true;
  String selectedTimezone = 'America/Sao_Paulo';

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
        final tzFromPrefs = prefs['timezone'];
        if (tzFromPrefs is String && tzFromPrefs.isNotEmpty) {
          selectedTimezone = tzFromPrefs;
        }
      });
    }
    setState(() {
      isLoading = false;
    });
  }

  Future<void> _onTimezoneChanged(String? tz) async {
    if (tz == null || tz == selectedTimezone) return;
    final previous = selectedTimezone;
    setState(() => selectedTimezone = tz);

    final service = context.read<NotificationService>();
    final ok = await service.updateTimezone(tz);
    if (!mounted) return;
    if (!ok) {
      setState(() => selectedTimezone = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao atualizar fuso horário')),
      );
    }
  }

  Future<void> _updatePreference(String key, dynamic value) async {
    final service = context.read<NotificationService>();

    setState(() {
      if (key == 'notifications_enabled') notificationsEnabled = value;
      if (key == 'workout_reminder_enabled') workoutReminderEnabled = value;
      if (key == 'meal_reminder_enabled') mealReminderEnabled = value;
      if (key == 'new_workout_sheet_enabled') newWorkoutSheetEnabled = value;
    });

    final success = await service.updatePreferences({key: value});
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Falha ao atualizar preferência',
            style: TextStyle(color: Colors.white),
          ),
        ),
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
        title: const Text(
          'Notificações',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildMasterSwitch(),
          const SizedBox(height: 20),
          _buildTimezoneSelector(),
          const SizedBox(height: 20),
          if (notificationsEnabled) ...[
            Text(
              'Lembretes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            NotificationToggleTile(
              title: 'Lembrete de Treino',
              subtitle: 'Avisar quando for a hora de treinar',
              icon: Icons.fitness_center,
              value: workoutReminderEnabled,
              onChanged: (val) =>
                  _updatePreference('workout_reminder_enabled', val),
            ),
            NotificationToggleTile(
              title: 'Lembrete de Refeição',
              subtitle: 'Avisar nos horários da dieta',
              icon: Icons.restaurant,
              value: mealReminderEnabled,
              onChanged: (val) =>
                  _updatePreference('meal_reminder_enabled', val),
            ),
            NotificationToggleTile(
              title: 'Novas Fichas',
              subtitle: 'Avisar quando o Personal enviar um novo treino',
              icon: Icons.assignment,
              value: newWorkoutSheetEnabled,
              onChanged: (val) =>
                  _updatePreference('new_workout_sheet_enabled', val),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
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

  Widget _buildTimezoneSelector() {
    final values = availableTimezones.map((o) => o.value).toList();
    if (!values.contains(selectedTimezone)) {
      values.insert(0, selectedTimezone);
    }
    String labelOf(String value) {
      final option = availableTimezones
          .where((o) => o.value == value)
          .cast<TimezoneOption?>()
          .firstWhere((_) => true, orElse: () => null);
      return option?.label ?? value;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.public, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text('Fuso horário', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: selectedTimezone,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
            ),
            isExpanded: true,
            items: values
                .map((v) => DropdownMenuItem<String>(value: v, child: Text(labelOf(v), overflow: TextOverflow.ellipsis)))
                .toList(),
            onChanged: _onTimezoneChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildMasterSwitch() {
    return Container(
      decoration: BoxDecoration(
        color: notificationsEnabled
            ? AppColors.primary.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notificationsEnabled
              ? AppColors.primary.withValues(alpha: 0.5)
              : Colors.transparent,
        ),
      ),
      child: SwitchListTile(
        title: const Text(
          'Ativar Notificações',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: const Text('Controla todas as notificações do app'),
        value: notificationsEnabled,
        activeThumbColor: AppColors.primary,
        onChanged: (val) => _updatePreference('notifications_enabled', val),
      ),
    );
  }
}
