import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenFoodProduct {
  final String name;
  final double kcalPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;

  const OpenFoodProduct({
    required this.name,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
  });
}

class OpenFoodFactsService {
  static const _baseUrl = 'https://world.openfoodfacts.org/api/v2/product';
  static const _fields = 'product_name,nutriments';

  static Future<OpenFoodProduct?> lookupBarcode(String barcode) async {
    try {
      final uri = Uri.parse('$_baseUrl/$barcode.json?fields=$_fields');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 1) return null;

      final product = data['product'] as Map<String, dynamic>?;
      if (product == null) return null;

      final name = (product['product_name'] as String?)?.trim();
      if (name == null || name.isEmpty) return null;

      final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

      double parseNutriment(String key) {
        final v = nutriments[key];
        if (v == null) return 0.0;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString()) ?? 0.0;
      }

      return OpenFoodProduct(
        name: name,
        kcalPer100g: parseNutriment('energy-kcal_100g'),
        proteinPer100g: parseNutriment('proteins_100g'),
        carbsPer100g: parseNutriment('carbohydrates_100g'),
        fatPer100g: parseNutriment('fat_100g'),
      );
    } catch (_) {
      return null;
    }
  }
}
