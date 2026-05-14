import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/openfoodfacts_service.dart';
import '../../services/nutrition_service.dart';
import '../../services/api_client.dart';
import '../../models/diet_models.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_colors.dart';
import '../../providers/nutrition_provider.dart';

class BarcodeFoodConfirmScreen extends StatefulWidget {
  final OpenFoodProduct product;

  const BarcodeFoodConfirmScreen({super.key, required this.product});

  @override
  State<BarcodeFoodConfirmScreen> createState() => _BarcodeFoodConfirmScreenState();
}

class _BarcodeFoodConfirmScreenState extends State<BarcodeFoodConfirmScreen> {
  final _quantityController = TextEditingController(text: '100');
  String _selectedMeal = 'Almoço';
  bool _isLoading = false;

  static const _meals = ['Café da Manhã', 'Almoço', 'Lanche', 'Jantar'];

  double get _qty => double.tryParse(_quantityController.text) ?? 100.0;

  double get _kcal => widget.product.kcalPer100g * _qty / 100;
  double get _protein => widget.product.proteinPer100g * _qty / 100;
  double get _carbs => widget.product.carbsPer100g * _qty / 100;
  double get _fat => widget.product.fatPer100g * _qty / 100;

  Future<void> _confirm() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final apiClient = context.read<ApiClient>();
      final nutritionService = NutritionService(apiClient: apiClient);

      final customFood = await nutritionService.createCustomFood(
        name: widget.product.name,
        category: 'Escaneado',
        energyKcal: widget.product.kcalPer100g,
        proteinG: widget.product.proteinPer100g,
        carbohydrateG: widget.product.carbsPer100g,
        lipidG: widget.product.fatPer100g,
      );

      await nutritionService.addLogbookEntry(
        CreateDietLogbookEntryDTO(
          mealName: _selectedMeal,
          customFoodId: customFood.id,
          quantityG: _qty,
        ),
      );

      if (mounted) {
        context.read<NutritionProvider>().loadTodayData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${widget.product.name} adicionado ao logbook!')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao adicionar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        title: const Text('Confirmar alimento'),
        backgroundColor: context.colors.surface,
        foregroundColor: context.colors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.qr_code_scanner, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.product.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: context.colors.textPrimary,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Valores por 100g',
                    style: TextStyle(fontSize: 12, color: context.colors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMacroChip('Kcal', widget.product.kcalPer100g, Colors.orange),
                      _buildMacroChip('Prot', widget.product.proteinPer100g, Colors.blue),
                      _buildMacroChip('Carb', widget.product.carbsPer100g, Colors.green),
                      _buildMacroChip('Gord', widget.product.fatPer100g, Colors.red),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Quantidade (g)', style: TextStyle(fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                suffixText: 'g',
                filled: true,
                fillColor: context.colors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Refeição', style: TextStyle(fontWeight: FontWeight.w600, color: context.colors.textPrimary)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedMeal,
              onChanged: (v) => setState(() => _selectedMeal = v ?? _selectedMeal),
              items: _meals.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              decoration: InputDecoration(
                filled: true,
                fillColor: context.colors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroChip('Kcal', _kcal, Colors.orange),
                  _buildMacroChip('Prot', _protein, Colors.blue),
                  _buildMacroChip('Carb', _carbs, Colors.green),
                  _buildMacroChip('Gord', _fat, Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _confirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Adicionar ao Logbook', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroChip(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
        ),
        Text(label, style: TextStyle(fontSize: 11, color: context.colors.textMuted)),
      ],
    );
  }
}
