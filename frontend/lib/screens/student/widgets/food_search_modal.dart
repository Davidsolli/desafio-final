import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';
import '../../../providers/nutrition_provider.dart';
import '../../../models/diet_models.dart';
import '../../../services/nutrition_service.dart';
import '../../../services/api_client.dart'; // To get ApiClient, or we can get service from context

class FoodSearchModal extends StatefulWidget {
  const FoodSearchModal({super.key});

  @override
  State<FoodSearchModal> createState() => _FoodSearchModalState();
}

class _FoodSearchModalState extends State<FoodSearchModal> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  List<FoodCatalogItem> _searchResults = [];
  String? _error;

  // Selected state
  FoodCatalogItem? _selectedFood;
  final TextEditingController _quantityController = TextEditingController(text: '100');
  String _selectedMeal = 'Almoço'; // Default
  
  final List<String> _mealOptions = [
    'Café da Manhã',
    'Lanche da Manhã',
    'Almoço',
    'Lanche da Tarde',
    'Jantar',
    'Ceia',
  ];

  @override
  void initState() {
    super.initState();
    _quantityController.addListener(() {
      setState(() {}); // Rebuild to update real-time macro calculation
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (query.trim().length >= 2) {
        _performSearch(query.trim());
      } else {
        setState(() {
          _searchResults = [];
          _error = null;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<ApiClient>(); 
      final service = NutritionService(apiClient: apiClient);
      
      final result = await service.searchFoodCatalog(query);
      setState(() {
        _searchResults = result.items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro na busca: $e';
        _isLoading = false;
      });
    }
  }

  void _saveEntry() {
    if (_selectedFood == null) return;
    
    final quantity = double.tryParse(_quantityController.text);
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Insira uma quantidade válida.')),
      );
      return;
    }

    final dto = CreateDietLogbookEntryDTO(
      mealName: _selectedMeal,
      foodId: _selectedFood!.source == 'taco' ? int.tryParse(_selectedFood!.id) : null,
      customFoodId: _selectedFood!.source == 'custom' ? _selectedFood!.id : null,
      quantityG: quantity,
      logDate: DateTime.now(), 
    );

    context.read<NutritionProvider>().addLogbookEntry(dto).then((_) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alimento registrado com sucesso!')),
        );
      }
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 12),
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              
              if (_selectedFood == null) 
                _buildSearchView(controller)
              else 
                _buildQuantityView(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchView(ScrollController controller) {
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar alimento (ex: Frango)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: context.colors.surface,
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(_error!, style: const TextStyle(color: AppColors.accentError)),
            )
          else if (_searchController.text.isNotEmpty && _searchResults.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Text('Nenhum alimento encontrado. Tente outra busca.'),
            )
          else
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: _searchResults.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = _searchResults[index];
                  return ListTile(
                    title: Text(item.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.category ?? "Sem Categoria", style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _macroInfoItem('Kcal', item.energyKcal, AppColors.primary),
                            _macroInfoItem('P', item.proteinG, Colors.orange),
                            _macroInfoItem('C', item.carbohydrateG, Colors.blue),
                            _macroInfoItem('G', item.lipidG, Colors.red),
                          ],
                        ),
                      ],
                    ),
                    trailing: item.source == 'custom' 
                        ? const Icon(Icons.person, size: 16, color: AppColors.primary)
                        : null,
                    isThreeLine: true,
                    onTap: () {
                      setState(() {
                        _selectedFood = item;
                      });
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _macroInfoItem(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(
        '$label: ${value.toStringAsFixed(1)}',
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildQuantityView() {
    final qty = double.tryParse(_quantityController.text) ?? 0.0;
    final ratio = qty / 100.0;
    
    final calcKcal = _selectedFood!.energyKcal * ratio;
    final calcProt = _selectedFood!.proteinG * ratio;
    final calcCarb = _selectedFood!.carbohydrateG * ratio;
    final calcFat = _selectedFood!.lipidG * ratio;

    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _selectedFood = null),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                ),
                Expanded(
                  child: Text(
                    'Detalhes do Consumo',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _selectedFood!.name,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${_selectedFood!.energyKcal.toStringAsFixed(0)} kcal a cada 100g',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 24),
            
            // Calculadora de Macros em Tempo Real
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                children: [
                  Text('Macros para a porção selecionada:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.colors.textSecondary)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _calcMacroItem('Calorias', calcKcal, 'kcal', AppColors.primary),
                      _calcMacroItem('Proteína', calcProt, 'g', Colors.orange),
                      _calcMacroItem('Carbos', calcCarb, 'g', Colors.blue),
                      _calcMacroItem('Gordura', calcFat, 'g', Colors.red),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            const Text('Qual refeição?', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedMeal,
                  items: _mealOptions.map((String meal) {
                    return DropdownMenuItem<String>(
                      value: meal,
                      child: Text(meal),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedMeal = newValue;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),

            const Text('Quantidade consumida (gramas)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                suffixText: 'g',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveEntry,
                child: const Text('Adicionar ao Diário', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calcMacroItem(String label, double value, String unit, Color color) {
    return Column(
      children: [
        Text(
          value.toStringAsFixed(1),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          '$unit\n$label',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: context.colors.textSecondary),
        ),
      ],
    );
  }
}
