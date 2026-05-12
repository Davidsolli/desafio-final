import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/theme_colors.dart';
import '../../../providers/nutrition_provider.dart';
import '../../../models/diet_models.dart';
import '../../../services/nutrition_service.dart';
import '../../../services/api_client.dart';
import 'create_custom_food_dialog.dart';

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

  // Initial State Cache (for when search and filters are empty)
  List<FoodCatalogItem> _recentCustomFoods = [];
  List<FoodCatalogItem> _allAvailableFoods = [];
  bool _isInitialLoading = false;

  // Filters State
  String? _selectedCategory;
  String? _selectedSource; // null (Todos), 'taco', 'custom'
  bool _filterHighProtein = false;
  bool _filterLowCarb = false;
  bool _filterLowFat = false;

  bool get _hasActiveFilters =>
      _selectedCategory != null ||
      _selectedSource != null ||
      _filterHighProtein ||
      _filterLowCarb ||
      _filterLowFat;

  // Exact categories present in the TACO.json database
  static const Map<String, Map<String, String>> _categories = {
    'Cereais e derivados': {'label': 'Cereais', 'icon': '🍞'},
    'Verduras, hortaliças e derivados': {'label': 'Vegetais & Hortaliças', 'icon': '🥦'},
    'Frutas e derivados': {'label': 'Frutas', 'icon': '🍎'},
    'Carnes e derivados': {'label': 'Carnes/Aves', 'icon': '🥩'},
    'Ovos e derivados': {'label': 'Ovos', 'icon': '🥚'},
    'Leite e derivados': {'label': 'Laticínios', 'icon': '🥛'},
    'Leguminosas e derivados': {'label': 'Grãos/Feijão', 'icon': '🫘'},
    'Pescados e frutos do mar': {'label': 'Pescados', 'icon': '🐟'},
    'Gorduras e óleos': {'label': 'Gorduras & Óleos', 'icon': '🥑'},
    'Produtos açucarados': {'label': 'Doces', 'icon': '🍬'},
    'Bebidas (alcoólicas e não alcoólicas)': {'label': 'Bebidas', 'icon': '🥤'},
    'Nozes e sementes': {'label': 'Nozes & Sementes', 'icon': '🌰'},
    'Alimentos preparados': {'label': 'Pratos Prontos', 'icon': '🍛'},
    'Outros alimentos industrializados': {'label': 'Industrializados', 'icon': '🥫'},
    'Miscelâneas': {'label': 'Miscelâneas', 'icon': '🧂'},
  };

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
    _loadInitialFoods();
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
      _performSearch(query.trim());
    });
  }

  void _triggerSearch() {
    _performSearch(_searchController.text.trim());
  }

  Future<void> _loadInitialFoods() async {
    setState(() {
      _isInitialLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<ApiClient>(); 
      final service = NutritionService(apiClient: apiClient);
      
      // Busca alimentos personalizados do usuário (para "Adicionados Recentemente")
      final customResult = await service.searchFoodCatalog('', source: 'custom');
      
      // Busca todos os alimentos disponíveis (TACO + Custom)
      final allResult = await service.searchFoodCatalog('');
      
      setState(() {
        _recentCustomFoods = customResult.items;
        _allAvailableFoods = allResult.items;
        _isInitialLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar alimentos iniciais: $e';
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty && !_hasActiveFilters) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = context.read<ApiClient>(); 
      final service = NutritionService(apiClient: apiClient);
      
      final result = await service.searchFoodCatalog(
        query,
        category: _selectedCategory,
        source: _selectedSource,
        minProtein: _filterHighProtein ? 15.0 : null,
        maxCarbohydrate: _filterLowCarb ? 5.0 : null,
        maxLipid: _filterLowFat ? 3.0 : null,
      );
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

  Future<void> _openCreateCustomFoodDialog() async {
    final newFood = await showDialog<CustomFood?>(
      context: context,
      builder: (context) => const CreateCustomFoodDialog(),
    );

    if (newFood != null && mounted) {
      _loadInitialFoods(); // Atualiza a lista inicial para incluir o recém-adicionado
      
      setState(() {
        _selectedFood = FoodCatalogItem(
          id: newFood.id,
          name: newFood.name,
          category: newFood.category,
          energyKcal: newFood.energyKcal,
          proteinG: newFood.proteinG,
          carbohydrateG: newFood.carbohydrateG,
          lipidG: newFood.lipidG,
          fiberG: newFood.fiberG,
          source: 'custom',
        );
      });
    }
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

  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: const Text('Categorias: Todas'),
              selected: _selectedCategory == null,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedCategory = null;
                  });
                  _triggerSearch();
                }
              },
              selectedColor: AppColors.primary.withOpacity(0.15),
              labelStyle: TextStyle(
                color: _selectedCategory == null ? AppColors.primary : context.colors.textPrimary,
                fontWeight: _selectedCategory == null ? FontWeight.bold : FontWeight.normal,
                fontSize: 12,
              ),
              backgroundColor: context.colors.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: _selectedCategory == null ? AppColors.primary : context.colors.border),
            ),
          ),
          ..._categories.entries.map((entry) {
            final dbKey = entry.key;
            final label = entry.value['label']!;
            final icon = entry.value['icon']!;
            final isSelected = _selectedCategory == dbKey;
            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ChoiceChip(
                label: Text('$icon $label'),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedCategory = selected ? dbKey : null;
                  });
                  _triggerSearch();
                },
                selectedColor: AppColors.primary.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : context.colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                backgroundColor: context.colors.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide(color: isSelected ? AppColors.primary : context.colors.border),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuickFilters() {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip(
            label: 'Base TACO',
            isSelected: _selectedSource == 'taco',
            onSelected: (selected) {
              setState(() {
                _selectedSource = selected ? 'taco' : null;
              });
              _triggerSearch();
            },
          ),
          _buildFilterChip(
            label: 'Personalizados',
            isSelected: _selectedSource == 'custom',
            onSelected: (selected) {
              setState(() {
                _selectedSource = selected ? 'custom' : null;
              });
              _triggerSearch();
            },
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            width: 1,
            color: context.colors.border,
          ),
          _buildFilterChip(
            label: '💪 Rico em Proteína',
            isSelected: _filterHighProtein,
            onSelected: (selected) {
              setState(() {
                _filterHighProtein = selected;
              });
              _triggerSearch();
            },
          ),
          _buildFilterChip(
            label: '🥦 Low Carb',
            isSelected: _filterLowCarb,
            onSelected: (selected) {
              setState(() {
                _filterLowCarb = selected;
              });
              _triggerSearch();
            },
          ),
          _buildFilterChip(
            label: '🔥 Pouca Gordura',
            isSelected: _filterLowFat,
            onSelected: (selected) {
              setState(() {
                _filterLowFat = selected;
              });
              _triggerSearch();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: onSelected,
        selectedColor: AppColors.primary.withOpacity(0.12),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : context.colors.textSecondary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 11,
        ),
        backgroundColor: context.colors.surface,
        showCheckmark: false,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: isSelected ? AppColors.primary : context.colors.border.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }

  Widget _buildSearchView(ScrollController controller) {
    final showInitialState = _searchController.text.isEmpty && !_hasActiveFilters;

    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              autofocus: false,
              decoration: InputDecoration(
                hintText: 'Buscar alimento (ex: Frango)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty || _hasActiveFilters
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _selectedCategory = null;
                            _selectedSource = null;
                            _filterHighProtein = false;
                            _filterLowCarb = false;
                            _filterLowFat = false;
                          });
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
          
          _buildCategoryFilters(),
          const SizedBox(height: 6),
          _buildQuickFilters(),
          const SizedBox(height: 4),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.primary),
                  label: const Text(
                    'Criar Alimento Personalizado',
                    style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _openCreateCustomFoodDialog,
                ),
              ],
            ),
          ),
          if (_isLoading || (_isInitialLoading && showInitialState))
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(_error!, style: const TextStyle(color: AppColors.accentError), textAlign: TextAlign.center),
                ),
              ),
            )
          else if (showInitialState)
            Expanded(
              child: ListView(
                controller: controller,
                children: [
                  if (_recentCustomFoods.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(left: 16, top: 12, bottom: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.history, size: 18, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Adicionados Recentemente',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: context.colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 105,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _recentCustomFoods.length,
                        itemBuilder: (context, idx) {
                          final item = _recentCustomFoods[idx];
                          return Container(
                            width: 170,
                            margin: const EdgeInsets.only(right: 10),
                            child: Card(
                              elevation: 0,
                              color: context.colors.surface,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: context.colors.border.withOpacity(0.5)),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  setState(() {
                                    _selectedFood = item;
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: context.colors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        item.category ?? 'Personalizado',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: context.colors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          _macroMiniBadge('${item.energyKcal.toStringAsFixed(0)} kcal', AppColors.primary),
                                          const SizedBox(width: 4),
                                          _macroMiniBadge('${item.proteinG.toStringAsFixed(1)}g P', Colors.orange),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 24),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4, bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.menu_book, size: 18, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          'Catálogo Geral de Alimentos',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_allAvailableFoods.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Nenhum alimento disponível no momento.',
                        style: TextStyle(color: context.colors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ..._allAvailableFoods.map((item) {
                      return Column(
                        children: [
                          ListTile(
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
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }).toList(),
                ],
              ),
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

  Widget _macroMiniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold),
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
