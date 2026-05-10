class FoodCatalogItem {
  final String id;
  final String name;
  final String? category;
  final double energyKcal;
  final double proteinG;
  final double carbohydrateG;
  final double lipidG;
  final double fiberG;
  final String source;

  FoodCatalogItem({
    required this.id,
    required this.name,
    this.category,
    required this.energyKcal,
    required this.proteinG,
    required this.carbohydrateG,
    required this.lipidG,
    required this.fiberG,
    required this.source,
  });

  factory FoodCatalogItem.fromJson(Map<String, dynamic> json) {
    return FoodCatalogItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      energyKcal: (json['energy_kcal'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      carbohydrateG: (json['carbohydrate_g'] as num).toDouble(),
      lipidG: (json['lipid_g'] as num).toDouble(),
      fiberG: (json['fiber_g'] as num).toDouble(),
      source: json['source'] as String? ?? 'taco',
    );
  }
}

class PaginatedFoodCatalogDTO {
  final List<FoodCatalogItem> items;
  final int total;
  final int page;
  final int limit;

  PaginatedFoodCatalogDTO({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
  });

  factory PaginatedFoodCatalogDTO.fromJson(Map<String, dynamic> json) {
    return PaginatedFoodCatalogDTO(
      items: (json['items'] as List<dynamic>)
          .map((e) => FoodCatalogItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
    );
  }
}

// ---------------------------------------------------------------------------
// Alimento Personalizado (Custom Food)
// ---------------------------------------------------------------------------

class CustomFood {
  final String id;
  final String userId;
  final String name;
  final String? category;
  final double energyKcal;
  final double proteinG;
  final double carbohydrateG;
  final double lipidG;
  final double fiberG;
  final DateTime createdAt;

  CustomFood({
    required this.id,
    required this.userId,
    required this.name,
    this.category,
    required this.energyKcal,
    required this.proteinG,
    required this.carbohydrateG,
    required this.lipidG,
    required this.fiberG,
    required this.createdAt,
  });

  factory CustomFood.fromJson(Map<String, dynamic> json) {
    return CustomFood(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String?,
      energyKcal: (json['energy_kcal'] as num).toDouble(),
      proteinG: (json['protein_g'] as num).toDouble(),
      carbohydrateG: (json['carbohydrate_g'] as num).toDouble(),
      lipidG: (json['lipid_g'] as num).toDouble(),
      fiberG: (json['fiber_g'] as num? ?? 0.0).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// Dieta (Plano Alimentar Prescrito)
// ---------------------------------------------------------------------------

class DietItem {
  final String id;
  final String mealId;
  final int? foodId;
  final String? customFoodId;
  final String foodName;
  final double quantityG;
  final String? observations;
  final double kcal;
  final double protein;
  final double carbs;
  final double fats;

  DietItem({
    required this.id,
    required this.mealId,
    this.foodId,
    this.customFoodId,
    required this.foodName,
    required this.quantityG,
    this.observations,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fats,
  });

  factory DietItem.fromJson(Map<String, dynamic> json) {
    return DietItem(
      id: json['id'] as String,
      mealId: json['meal_id'] as String,
      foodId: json['food_id'] as int?,
      customFoodId: json['custom_food_id'] as String?,
      foodName: json['food_name'] as String? ?? '',
      quantityG: (json['quantity_g'] as num).toDouble(),
      observations: json['observations'] as String?,
      kcal: (json['kcal'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fats: (json['fats'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DietMeal {
  final String id;
  final String dietId;
  final String name;
  final String? time;
  final int order;
  final List<DietItem> items;
  final double subtotalKcal;
  final double subtotalProtein;
  final double subtotalCarbs;
  final double subtotalFats;

  DietMeal({
    required this.id,
    required this.dietId,
    required this.name,
    this.time,
    required this.order,
    required this.items,
    required this.subtotalKcal,
    required this.subtotalProtein,
    required this.subtotalCarbs,
    required this.subtotalFats,
  });

  factory DietMeal.fromJson(Map<String, dynamic> json) {
    return DietMeal(
      id: json['id'] as String,
      dietId: json['diet_id'] as String,
      name: json['name'] as String,
      time: json['time'] as String?,
      order: json['order'] as int? ?? 1,
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => DietItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      subtotalKcal: (json['subtotal_kcal'] as num?)?.toDouble() ?? 0.0,
      subtotalProtein: (json['subtotal_protein'] as num?)?.toDouble() ?? 0.0,
      subtotalCarbs: (json['subtotal_carbs'] as num?)?.toDouble() ?? 0.0,
      subtotalFats: (json['subtotal_fats'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class Diet {
  final String id;
  final String userId;
  final String? professionalId;
  final bool isCustom;
  final String name;
  final String? goal;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<DietMeal> meals;
  final double totalKcal;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;

  Diet({
    required this.id,
    required this.userId,
    this.professionalId,
    required this.isCustom,
    required this.name,
    this.goal,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.meals,
    required this.totalKcal,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
  });

  factory Diet.fromJson(Map<String, dynamic> json) {
    return Diet(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      professionalId: json['professional_id'] as String?,
      isCustom: json['is_custom'] as bool? ?? false,
      name: json['name'] as String,
      goal: json['goal'] as String?,
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      meals: (json['meals'] as List<dynamic>?)
          ?.map((e) => DietMeal.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      totalKcal: (json['total_kcal'] as num?)?.toDouble() ?? 0.0,
      totalProtein: (json['total_protein'] as num?)?.toDouble() ?? 0.0,
      totalCarbs: (json['total_carbs'] as num?)?.toDouble() ?? 0.0,
      totalFats: (json['total_fats'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PaginatedDietsDTO {
  final int total;
  final int page;
  final int limit;
  final List<Diet> data;

  PaginatedDietsDTO({
    required this.total,
    required this.page,
    required this.limit,
    required this.data,
  });

  factory PaginatedDietsDTO.fromJson(Map<String, dynamic> json) {
    return PaginatedDietsDTO(
      total: json['total'] as int,
      page: json['page'] as int,
      limit: json['limit'] as int,
      data: (json['data'] as List<dynamic>)
          .map((e) => Diet.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Diário Alimentar (Logbook Consumido)
// ---------------------------------------------------------------------------

class DietLogbookEntry {
  final String id;
  final String logbookId;
  final String mealName;
  final int? foodId;
  final String? customFoodId;
  final String foodName;
  final double quantityG;
  final double kcal;
  final double protein;
  final double carbs;
  final double fats;

  DietLogbookEntry({
    required this.id,
    required this.logbookId,
    required this.mealName,
    this.foodId,
    this.customFoodId,
    required this.foodName,
    required this.quantityG,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fats,
  });

  factory DietLogbookEntry.fromJson(Map<String, dynamic> json) {
    return DietLogbookEntry(
      id: json['id'] as String,
      logbookId: json['logbook_id'] as String,
      mealName: json['meal_name'] as String,
      foodId: json['food_id'] as int?,
      customFoodId: json['custom_food_id'] as String?,
      foodName: json['food_name'] as String? ?? '',
      quantityG: (json['quantity_g'] as num).toDouble(),
      kcal: (json['kcal'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      fats: (json['fats'] as num).toDouble(),
    );
  }
}

class DietLogbook {
  final String id;
  final String userId;
  final DateTime date;
  final double totalKcal;
  final double totalProtein;
  final double totalCarbs;
  final double totalFats;
  final DateTime createdAt;
  final List<DietLogbookEntry> entries;

  DietLogbook({
    required this.id,
    required this.userId,
    required this.date,
    required this.totalKcal,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFats,
    required this.createdAt,
    required this.entries,
  });

  factory DietLogbook.fromJson(Map<String, dynamic> json) {
    return DietLogbook(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      date: DateTime.parse(json['date'] as String),
      totalKcal: (json['total_kcal'] as num).toDouble(),
      totalProtein: (json['total_protein'] as num).toDouble(),
      totalCarbs: (json['total_carbs'] as num).toDouble(),
      totalFats: (json['total_fats'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      entries: (json['entries'] as List<dynamic>?)
          ?.map((e) => DietLogbookEntry.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
    );
  }
}

class CreateDietLogbookEntryDTO {
  final String mealName;
  final int? foodId;
  final String? customFoodId;
  final double quantityG;
  final DateTime? logDate;

  CreateDietLogbookEntryDTO({
    required this.mealName,
    this.foodId,
    this.customFoodId,
    required this.quantityG,
    this.logDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'meal_name': mealName,
      if (foodId != null) 'food_id': foodId,
      if (customFoodId != null) 'custom_food_id': customFoodId,
      'quantity_g': quantityG,
      if (logDate != null) 'log_date': logDate!.toIso8601String().split('T')[0],
    };
  }
}
