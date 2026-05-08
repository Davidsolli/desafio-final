import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/logbook_provider.dart';
import '../../services/logbook_service.dart';
import '../../shared/widgets/index.dart';

class LogbookScreen extends StatefulWidget {
  const LogbookScreen({super.key});

  @override
  State<LogbookScreen> createState() => _LogbookScreenState();
}

class _LogbookScreenState extends State<LogbookScreen> {
  String _selectedIntensity = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<LogbookProvider>().loadSessions().catchError((e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao carregar logbook: $e')),
            );
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildIntensityFilter(),
            Expanded(
              child: Consumer<LogbookProvider>(
                builder: (context, logbookProvider, _) {
                  if (logbookProvider.isLoading) {
                    return const OmniLoader();
                  }

                  if (logbookProvider.error != null) {
                    return OmniErrorState(
                      message: logbookProvider.error ?? 'Erro ao carregar',
                      onRetry: logbookProvider.loadSessions,
                    );
                  }

                  final filteredSessions = _filterSessions(logbookProvider.sessions);

                  if (!logbookProvider.hasSessions || filteredSessions.isEmpty) {
                    return OmniEmptyState(
                      icon: Icons.notes_outlined,
                      title: 'Nenhuma sessão registrada',
                      actionLabel: 'Registrar Sessão',
                      onAction: () => _showCreateSessionDialog(context),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filteredSessions.length,
                    itemBuilder: (context, index) {
                      final session = filteredSessions[index];
                      return _buildSessionCard(context, session, index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateSessionDialog(context),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInDown(
            duration: const Duration(milliseconds: 300),
            child: Text(
              'Meu Logbook',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          const SizedBox(height: 8),
          FadeInUp(
            duration: const Duration(milliseconds: 300),
            delay: const Duration(milliseconds: 100),
            child: Text(
              'Histórico de suas sessões de treino',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: context.colors.textSecondary,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityFilter() {
    final filters = [
      ('all', '📋 Todas'),
      ('leve', '💚 Leve'),
      ('moderada', '🟡 Moderada'),
      ('intensa', '❤️ Intensa'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = _selectedIntensity == filter.$1;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(filter.$2),
                selected: isSelected,
                backgroundColor: context.colors.surface,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : context.colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _selectedIntensity = filter.$1);
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, LogbookResponse session, int index) {
    return FadeInUp(
      duration: const Duration(milliseconds: 300),
      delay: Duration(milliseconds: index * 100),
      child: GestureDetector(
        onTap: () => _showSessionDetails(context, session),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.colors.surface,
            border: Border.all(color: context.colors.border, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.workoutName,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 14,
                              color: context.colors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              session.formattedDate,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: context.colors.textMuted,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Text('Editar'),
                        onTap: () => _showEditSessionDialog(context, session),
                      ),
                      PopupMenuItem(
                        child: const Text('Deletar', style: TextStyle(color: AppColors.accentError)),
                        onTap: () => _confirmDelete(context, session),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem(
                    '⏱️',
                    '${session.durationMinutes}',
                    'min',
                    context,
                  ),
                  _buildStatItem(
                    '🔥',
                    '${session.caloriesBurned.toStringAsFixed(0)}',
                    'kcal',
                    context,
                  ),
                  _buildIntensityBadge(session.intensity),
                  Expanded(
                    child: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: session.intensityColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${session.exercises.length} exercícios',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: session.intensityColor,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String icon, String value, String label, BuildContext context) {
    return Column(
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.colors.textMuted,
                fontSize: 10,
              ),
        ),
      ],
    );
  }

  Widget _buildIntensityBadge(String intensity) {
    return OmniStatusBadge(
      label: _getIntensityLabel(intensity),
      color: _getIntensityColor(intensity),
    );
  }

  List<LogbookResponse> _filterSessions(List<LogbookResponse> sessions) {
    if (_selectedIntensity == 'all') {
      return sessions;
    }
    return sessions.where((s) => s.intensity.toLowerCase() == _selectedIntensity).toList();
  }

  void _showSessionDetails(BuildContext context, LogbookResponse session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(session.workoutName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Data', session.formattedDate),
              _buildDetailRow('Duração', '${session.durationMinutes} minutos'),
              _buildDetailRow('Calorias', '${session.caloriesBurned.toStringAsFixed(0)} kcal'),
              _buildDetailRow('Intensidade', _getIntensityLabel(session.intensity)),
              if (session.notes != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow('Notas', session.notes ?? ''),
              ],
              const SizedBox(height: 16),
              Text(
                'Exercícios (${session.exercises.length})',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              ...session.exercises.map((exercise) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.colors.background,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.exerciseName,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${exercise.sets}x${exercise.reps} × ${exercise.weight}kg',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: context.colors.textMuted,
                                  ),
                            ),
                            Text(
                              '${exercise.restTime}s',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.primary,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.colors.textMuted,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  void _showCreateSessionDialog(BuildContext context) {
    final nameController = TextEditingController();
    final durationController = TextEditingController();
    final caloriesController = TextEditingController();
    final notesController = TextEditingController();
    String selectedIntensity = 'moderada';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar Sessão'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome do treino',
                  hintText: 'Ex: Peito e Costas',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duração (minutos)',
                  hintText: 'Ex: 60',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calorias queimadas',
                  hintText: 'Ex: 300',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedIntensity,
                decoration: const InputDecoration(labelText: 'Intensidade'),
                items: const [
                  DropdownMenuItem(value: 'leve', child: Text('Leve')),
                  DropdownMenuItem(value: 'moderada', child: Text('Moderada')),
                  DropdownMenuItem(value: 'intensa', child: Text('Intensa')),
                ],
                onChanged: (value) {
                  selectedIntensity = value ?? 'moderada';
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  hintText: 'Ex: Senti forte no dia',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final dto = CreateLogbookDTO(
                workoutName: nameController.text,
                sessionDate: DateTime.now(),
                durationMinutes: int.tryParse(durationController.text) ?? 0,
                caloriesBurned: double.tryParse(caloriesController.text) ?? 0,
                intensity: selectedIntensity,
                exercises: [],
                notes: notesController.text.isEmpty ? null : notesController.text,
              );

              final provider = context.read<LogbookProvider>();
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              try {
                await provider.createSession(dto);
                if (mounted) {
                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Sessão registrada com sucesso!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Erro: $e')),
                  );
                }
              }
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  void _showEditSessionDialog(BuildContext context, LogbookResponse session) {
    final nameController = TextEditingController(text: session.workoutName);
    final durationController = TextEditingController(text: session.durationMinutes.toString());
    final caloriesController = TextEditingController(text: session.caloriesBurned.toString());
    final notesController = TextEditingController(text: session.notes ?? '');
    String selectedIntensity = session.intensity;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Sessão'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nome do treino'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Duração (minutos)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calorias queimadas'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedIntensity,
                decoration: const InputDecoration(labelText: 'Intensidade'),
                items: const [
                  DropdownMenuItem(value: 'leve', child: Text('Leve')),
                  DropdownMenuItem(value: 'moderada', child: Text('Moderada')),
                  DropdownMenuItem(value: 'intensa', child: Text('Intensa')),
                ],
                onChanged: (value) {
                  selectedIntensity = value ?? 'moderada';
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notas (opcional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final dto = CreateLogbookDTO(
                workoutName: nameController.text,
                sessionDate: session.sessionDate,
                durationMinutes: int.tryParse(durationController.text) ?? session.durationMinutes,
                caloriesBurned: double.tryParse(caloriesController.text) ?? session.caloriesBurned,
                intensity: selectedIntensity,
                exercises: session.exercises.map((e) => {
                  'exercise_name': e.exerciseName,
                  'sets': e.sets,
                  'reps': e.reps,
                  'weight': e.weight,
                  'rest_time': e.restTime,
                  'notes': e.notes,
                }).toList(),
                notes: notesController.text.isEmpty ? null : notesController.text,
              );

              final provider = context.read<LogbookProvider>();
              final nav = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              try {
                await provider.updateSession(session.id, dto);
                if (mounted) {
                  nav.pop();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Sessão atualizada!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Erro: $e')),
                  );
                }
              }
            },
            child: const Text('Atualizar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, LogbookResponse session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deletar Sessão'),
        content: Text('Tem certeza que deseja deletar "${session.workoutName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<LogbookProvider>().deleteSession(session.id).then((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sessão deletada!')),
                );
              }).catchError((e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erro: $e')),
                );
              });
            },
            child: const Text('Deletar', style: TextStyle(color: AppColors.accentError)),
          ),
        ],
      ),
    );
  }

  Color _getIntensityColor(String intensity) {
    switch (intensity.toLowerCase()) {
      case 'leve':
        return const Color(0xFF2ecc71);
      case 'moderada':
        return const Color(0xFFf39c12);
      case 'intensa':
        return const Color(0xFFe74c3c);
      default:
        return context.colors.textMuted;
    }
  }

  String _getIntensityLabel(String intensity) {
    switch (intensity.toLowerCase()) {
      case 'leve':
        return 'Leve';
      case 'moderada':
        return 'Moderada';
      case 'intensa':
        return 'Intensa';
      default:
        return 'Desconhecida';
    }
  }
}
