import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import 'widgets/notification_toggle_tile.dart';

/// Tela de configurações de notificação do personal trainer.
///
/// Trainer não recebe `workout_reminder`, `meal_reminder`, `new_workout_sheet`
/// ou `achievement` — esses tipos são para clients. O único push direcionado
/// ao trainer é `student_inactivity` (aluno inativo há 7+ dias).
///
/// Por isso esta tela mostra apenas:
/// - master switch (`notifications_enabled`)
/// - dropdown de fuso horário
/// - toggle "Aluno Inativo" (`student_inactivity_enabled`)
class NotificationsSettingsTrainerScreen extends StatefulWidget {
  const NotificationsSettingsTrainerScreen({super.key});

  @override
  State<NotificationsSettingsTrainerScreen> createState() =>
      _NotificationsSettingsTrainerScreenState();
}

const _availableTimezones = <_TimezoneOption>[
  _TimezoneOption('America/Sao_Paulo', 'São Paulo (UTC-3)'),
  _TimezoneOption('America/Belem', 'Belém (UTC-3)'),
  _TimezoneOption('America/Recife', 'Recife (UTC-3)'),
  _TimezoneOption('America/Cuiaba', 'Cuiabá (UTC-4)'),
  _TimezoneOption('America/Manaus', 'Manaus (UTC-4)'),
  _TimezoneOption('America/Rio_Branco', 'Rio Branco (UTC-5)'),
  _TimezoneOption('America/Noronha', 'Fernando de Noronha (UTC-2)'),
];

class _TimezoneOption {
  final String value;
  final String label;
  const _TimezoneOption(this.value, this.label);
}

class _NotificationsSettingsTrainerScreenState
    extends State<NotificationsSettingsTrainerScreen> {
  bool isLoading = true;
  bool notificationsEnabled = true;
  bool studentInactivityEnabled = true;
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
        studentInactivityEnabled =
            prefs['student_inactivity_enabled'] ?? true;
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
      if (key == 'student_inactivity_enabled') {
        studentInactivityEnabled = value;
      }
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
              'Alertas de Alunos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 10),
            NotificationToggleTile(
              title: 'Aluno Inativo',
              subtitle: 'Avisar quando um aluno ficar 7+ dias sem treinar',
              icon: Icons.person_off,
              value: studentInactivityEnabled,
              onChanged: (val) =>
                  _updatePreference('student_inactivity_enabled', val),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Todas as notificações estão silenciadas. Você não receberá alertas dos seus alunos.',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildTimezoneSelector() {
    final values = _availableTimezones.map((o) => o.value).toList();
    if (!values.contains(selectedTimezone)) {
      values.insert(0, selectedTimezone);
    }
    String labelOf(String value) {
      final option = _availableTimezones
          .where((o) => o.value == value)
          .cast<_TimezoneOption?>()
          .firstWhere((_) => true, orElse: () => null);
      return option?.label ?? value;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.public, color: AppColors.primary),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Fuso horário',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          DropdownButton<String>(
            value: selectedTimezone,
            underline: const SizedBox.shrink(),
            items: values
                .map(
                  (v) => DropdownMenuItem<String>(
                    value: v,
                    child: Text(labelOf(v)),
                  ),
                )
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
