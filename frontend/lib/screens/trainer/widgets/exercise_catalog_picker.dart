import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';
import '../../../models/workout_sheet_model.dart';
import '../../../providers/workout_sheet_provider.dart';

/// Bottom sheet para buscar e selecionar exercícios do catálogo da API.
///
/// Retorna um [ExerciseCatalogItem] ao caller quando o usuário seleciona,
/// ou null se fechar sem selecionar.
///
/// Uso:
/// ```dart
/// final item = await showExerciseCatalogPicker(context);
/// if (item != null) { /* usar item.name, item.muscleGroupMapped, etc. */ }
/// ```
Future<ExerciseCatalogItem?> showExerciseCatalogPicker(BuildContext context) {
  return showModalBottomSheet<ExerciseCatalogItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ExerciseCatalogPickerSheet(),
  );
}

class _ExerciseCatalogPickerSheet extends StatefulWidget {
  const _ExerciseCatalogPickerSheet();

  @override
  State<_ExerciseCatalogPickerSheet> createState() =>
      _ExerciseCatalogPickerSheetState();
}

class _ExerciseCatalogPickerSheetState
    extends State<_ExerciseCatalogPickerSheet> {
  final _searchController = TextEditingController();
  String? _selectedMuscleGroup;
  String? _selectedEquipment;
  Timer? _debounce;
  bool _initialLoad = false;

  @override
  void initState() {
    super.initState();
    // Carrega lista inicial ao abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _search();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _search);
  }

  Future<void> _search() async {
    if (!mounted) return;
    setState(() => _initialLoad = true);
    try {
      await context.read<WorkoutSheetProvider>().searchCatalog(
            search: _searchController.text.trim().isEmpty
                ? null
                : _searchController.text.trim(),
            muscleGroup: _selectedMuscleGroup,
            equipment: _selectedEquipment,
            limit: 30,
          );
    } catch (_) {
      // Erro já tratado pelo provider
    } finally {
      if (mounted) setState(() => _initialLoad = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      height: screenHeight * 0.88,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Buscar Exercício no Catálogo',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Campo de busca
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Ex: supino, agachamento, rosca...',
                prefixIcon: Icon(Icons.search, color: context.colors.textMuted),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear,
                            color: context.colors.textMuted, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _search();
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.colors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Filtro por equipamento (chips horizontais)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildEquipmentChip(null, 'Todos os Equip.'),
                ...[
                  'peso-do-corpo',
                  'maquina',
                  'halteres',
                  'barra',
                  'cabo',
                  'kettlebell',
                  'faixas',
                ].map((e) => _buildEquipmentChip(e, _equipmentLabel(e))),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Filtro por grupo muscular (chips horizontais)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildMuscleChip(null, 'Todos os Músc.'),
                ...validMuscleGroups.map((g) => _buildMuscleChip(g, _muscleGroupLabel(g))),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: context.colors.border),

          // Lista de resultados
          Expanded(
            child: Consumer<WorkoutSheetProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading && _initialLoad) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (provider.catalogItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.fitness_center_outlined,
                            color: context.colors.textMuted, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhum exercício encontrado',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: context.colors.textMuted),
                        ),
                        if (_searchController.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Tente outro termo de busca',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: context.colors.textMuted),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: provider.catalogItems.length,
                  itemBuilder: (context, index) {
                    return _buildCatalogItem(
                        context, provider.catalogItems[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleChip(String? muscleGroup, String label) {
    final isSelected = _selectedMuscleGroup == muscleGroup;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedMuscleGroup = selected ? muscleGroup : null;
          });
          _search();
        },
        selectedColor: AppColors.primary.withValues(alpha: 0.2),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : context.colors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildEquipmentChip(String? equipment, String label) {
    final isSelected = _selectedEquipment == equipment;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedEquipment = selected ? equipment : null;
          });
          _search();
        },
        selectedColor: AppColors.accent.withValues(alpha: 0.2),
        checkmarkColor: AppColors.accent,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.accent : context.colors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildCatalogItem(
      BuildContext context, ExerciseCatalogItem item) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(item),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colors.surfaceLight,
          border: Border.all(color: context.colors.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            // Ícone/Imagem do exercício
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            _muscleGroupEmoji(item.muscleGroupMapped),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _muscleGroupEmoji(item.muscleGroupMapped),
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Informações do exercício
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (item.muscleGroupMapped != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _muscleGroupLabel(item.muscleGroupMapped!),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (item.equipment != null && item.equipment!.isNotEmpty)
                        Flexible(
                          child: Text(
                            item.equipment!,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: context.colors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            Icon(Icons.arrow_forward_ios,
                color: context.colors.textMuted, size: 14),
          ],
        ),
      ),
    );
  }

  String _muscleGroupLabel(String? group) {
    const labels = {
      'peito': 'Peito',
      'costa': 'Costas',
      'ombro': 'Ombro',
      'bíceps': 'Bíceps',
      'tríceps': 'Tríceps',
      'antebraço': 'Antebraço',
      'core': 'Core',
      'perna_anterior': 'Quadríceps',
      'perna_posterior': 'Posterior',
      'panturrilha': 'Panturrilha',
    };
    return labels[group] ?? (group ?? '');
  }

  String _equipmentLabel(String? equipment) {
    if (equipment == null) return 'Todos os Equip.';
    const labels = {
      'peso-do-corpo': 'Peso do Corpo',
      'maquina': 'Máquina',
      'halteres': 'Halteres',
      'barra': 'Barra',
      'cabo': 'Cabo',
      'kettlebell': 'Kettlebell',
      'faixas': 'Faixas',
    };
    return labels[equipment] ?? equipment;
  }

  String _muscleGroupEmoji(String? group) {
    const emojis = {
      'peito': '💪',
      'costa': '🔙',
      'ombro': '🏋️',
      'bíceps': '💪',
      'tríceps': '💪',
      'antebraço': '🦾',
      'core': '🎯',
      'perna_anterior': '🦵',
      'perna_posterior': '🦵',
      'panturrilha': '🦶',
    };
    return emojis[group] ?? '🏃';
  }
}
