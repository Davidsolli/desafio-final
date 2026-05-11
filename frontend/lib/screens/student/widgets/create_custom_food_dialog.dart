import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';
import '../../../models/diet_models.dart';
import '../../../providers/nutrition_provider.dart';

class CreateCustomFoodDialog extends StatefulWidget {
  const CreateCustomFoodDialog({super.key});

  @override
  State<CreateCustomFoodDialog> createState() => _CreateCustomFoodDialogState();
}

class _CreateCustomFoodDialogState extends State<CreateCustomFoodDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _lipidController = TextEditingController();
  final _fiberController = TextEditingController(text: '0.0');

  bool _isSaving = false;
  String? _errorMessage;

  // Live macro state to draw live micro-visualizations
  double _kcal = 0.0;
  double _protein = 0.0;
  double _carbs = 0.0;
  double _fat = 0.0;

  // Standardized Day-To-Day colors for macronutrients
  static const Color colorProtein = Color(0xFF3dba5e); // Green
  static const Color colorCarbs = Color(0xFF4db8ff);   // Blue
  static const Color colorFat = Color(0xFFffc84d);     // Yellow/Gold
  static const Color colorFiber = Color(0xFF8c52ff);   // Purple/Teal

  @override
  void initState() {
    super.initState();
    _proteinController.addListener(_updateLiveValues);
    _carbsController.addListener(_updateLiveValues);
    _lipidController.addListener(_updateLiveValues);
  }

  void _updateLiveValues() {
    setState(() {
      _protein = double.tryParse(_proteinController.text) ?? 0.0;
      _carbs = double.tryParse(_carbsController.text) ?? 0.0;
      _fat = double.tryParse(_lipidController.text) ?? 0.0;
      // Formula to automatically calculate calories from macros:
      // (protein * 4) + (carbs * 4) + (fat * 9)
      _kcal = (_protein * 4) + (_carbs * 4) + (_fat * 9);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _lipidController.dispose();
    _fiberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final provider = context.read<NutritionProvider>();
      final CustomFood newFood = await provider.createCustomFood(
        name: _nameController.text.trim(),
        category: _categoryController.text.trim().isEmpty ? 'Personalizado' : _categoryController.text.trim(),
        energyKcal: _kcal,
        proteinG: double.parse(_proteinController.text),
        carbohydrateG: double.parse(_carbsController.text),
        lipidG: double.parse(_lipidController.text),
        fiberG: double.tryParse(_fiberController.text) ?? 0.0,
      );

      if (mounted) {
        Navigator.of(context).pop(newFood);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalG = _protein + _carbs + _fat;
    final protPct = totalG > 0 ? (_protein / totalG) : 0.0;
    final carbsPct = totalG > 0 ? (_carbs / totalG) : 0.0;
    final fatPct = totalG > 0 ? (_fat / totalG) : 0.0;

    return Dialog(
      backgroundColor: context.colors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Novo Alimento',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Cadastre alimentos fora da base Taco para usar no seu diário.',
                  style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.accentError.withOpacity(0.1),
                      border: Border.all(color: AppColors.accentError),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.accentError, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: AppColors.accentError, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Live Preview Panel (Wow Factor with Standardized Colors!)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withOpacity(0.15),
                        Colors.orange.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _nameController.text.trim().isEmpty
                                  ? 'Pré-visualização (100g)'
                                  : _nameController.text.trim(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          Text(
                            '${_kcal.toStringAsFixed(0)} kcal',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Linear indicator breakdown using standardized daily colors!
                      if (totalG > 0)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: SizedBox(
                            height: 8,
                            child: Row(
                              children: [
                                if (_protein > 0)
                                  Expanded(
                                    flex: (_protein * 10).toInt(),
                                    child: Container(color: colorProtein),
                                  ),
                                if (_carbs > 0)
                                  Expanded(
                                    flex: (_carbs * 10).toInt(),
                                    child: Container(color: colorCarbs),
                                  ),
                                if (_fat > 0)
                                  Expanded(
                                    flex: (_fat * 10).toInt(),
                                    child: Container(color: colorFat),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: context.colors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _previewBadge('Proteína', _protein, 'g', colorProtein, protPct),
                          _previewBadge('Carbs', _carbs, 'g', colorCarbs, carbsPct),
                          _previewBadge('Gordura', _fat, 'g', colorFat, fatPct),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Name input
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Nome do Alimento *',
                    hintText: 'ex: Tapioca com Coco',
                    prefixIcon: const Icon(Icons.restaurant_menu),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, insira o nome do alimento.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category input
                TextFormField(
                  controller: _categoryController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Categoria (Opcional)',
                    hintText: 'ex: Carboidratos, Suplementos',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 20),

                // Nutrition details section label
                Text(
                  'Valores nutricionais (por 100g de porção)',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'As calorias são calculadas de forma automática com base nos macronutrientes inseridos.',
                  style: TextStyle(color: context.colors.textMuted, fontSize: 11),
                ),
                const SizedBox(height: 16),

                // Macros Inputs
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberInput(
                        controller: _proteinController,
                        label: 'Proteínas (g) *',
                        color: colorProtein,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNumberInput(
                        controller: _carbsController,
                        label: 'Carboidratos (g) *',
                        color: colorCarbs,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildNumberInput(
                        controller: _lipidController,
                        label: 'Gorduras (g) *',
                        color: colorFat,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNumberInput(
                        controller: _fiberController,
                        label: 'Fibras (g) - Opcional',
                        color: colorFiber,
                        isRequired: false,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      child: Text(
                        'Cancelar',
                        style: TextStyle(color: context.colors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 1,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Cadastrar Alimento',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _previewBadge(String label, double value, String unit, Color color, double percent) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${value.toStringAsFixed(1)}$unit',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          '${(percent * 100).toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 9, color: context.colors.textMuted),
        ),
      ],
    );
  }

  Widget _buildNumberInput({
    required TextEditingController controller,
    required String label,
    required Color color,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: color, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: (value) {
        if (!isRequired) return null;
        if (value == null || value.trim().isEmpty) {
          return 'Campo obrigatório';
        }
        final val = double.tryParse(value);
        if (val == null || val < 0) {
          return 'Valor inválido';
        }
        return null;
      },
    );
  }
}
