import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class Meal {
  final String id;
  final String name;
  final String imageFilePath;
  final DateTime timestamp;
  final List<FoodItem> items;

  Meal({
    required this.id,
    required this.name,
    required this.imageFilePath,
    required this.timestamp,
    required this.items,
  });

  // Add toJson method for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageFilePath': imageFilePath,
      'timestamp': timestamp.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }

  // Add fromJson constructor
  factory Meal.fromJson(Map<String, dynamic> json) {
    return Meal(
      id: json['id'],
      name: json['name'],
      imageFilePath: json['imageFilePath'],
      timestamp: DateTime.parse(json['timestamp']),
      items: (json['items'] as List)
          .map((item) => FoodItem.fromJson(item))
          .toList(),
    );
  }

  double getTotalNutrient(String nutrient) {
    return items.fold(0.0, (sum, item) {
      return sum + (item.macrosPer100g[nutrient] ?? 0) * item.quantity / 100;
    });
  }
}

class FoodItem {
  final String id;
  final String name;
  double quantity;  // Remove final keyword to allow modification
  final Map<String, double> macrosPer100g;

  FoodItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.macrosPer100g,
  });

  // Add toJson method for serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'macrosPer100g': macrosPer100g,
    };
  }

  // Add fromJson constructor
  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'],
      name: json['name'],
      quantity: json['quantity'].toDouble(),
      macrosPer100g: Map<String, double>.from(json['macrosPer100g']),
    );
  }

  // Add copy with method for immutability support
  FoodItem copyWith({
    String? id,
    String? name,
    double? quantity,
    Map<String, double>? macrosPer100g,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      macrosPer100g: macrosPer100g ?? this.macrosPer100g,
    );
  }
}

// filepath: /d:/Work/DEP/snapnutrition/lib/app_data.dart
class AppData {
  static final AppData _instance = AppData._internal();
  static bool _initialized = false;
  static Completer<void>? _initializer;
  static DateTime? _overriddenDate;
  static bool _isTestMode = false;
  static String? _debugDate;
  
  factory AppData() => _instance;
  
  final Map<String, List<Meal>> _meals = {};
  final Map<String, Map<String, int>> _nutritionData = {};  // date -> {nutrient -> value}
  final Map<String, Map<String, double>> _fitnessData = {}; // date -> {metric -> value}
  
  AppData._internal() {
    if (!_initialized && _initializer == null) {
      _initializer = Completer<void>();
      _loadData().then((_) {
        _initialized = true;
        _initializer!.complete();
      });
    }
  }

  Future<void> ensureInitialized() async {
    if (!_initialized) {
      await _initializer?.future;
    }
  }

  // Add this method to handle initialization
  Future<void> _initializeData() async {
    await _loadData();
    print("[DEBUG] AppData initialized with nutrition data: $_nutritionData");
  }

  // Unified addMeal method that handles both Meal objects and direct nutrition data
  Future<void> addMeal({Meal? meal, Map<String, int>? nutrition}) async {
    await ensureInitialized();
    final today = _getCurrentDate();

    // Initialize today's totals if needed
    if (!_nutritionData.containsKey(today)) {
      _nutritionData[today] = {'Protein': 0, 'Carbohydrates': 0, 'Fat': 0};
    }

    if (meal != null) {
      // Store meal with all details
      _meals.putIfAbsent(today, () => []);
      _meals[today]!.add(meal);
      print("[DEBUG] Added meal: ${meal.name} with image: ${meal.imageFilePath}");

      // Calculate and add nutrition totals
      Map<String, int> mealTotals = {
        'Protein': 0,
        'Carbohydrates': 0,
        'Fat': 0,
      };

      for (var item in meal.items) {
        for (var macro in item.macrosPer100g.keys) {
          mealTotals[macro] = (mealTotals[macro] ?? 0) + 
            ((item.macrosPer100g[macro] ?? 0) * item.quantity / 100).round();
        }
      }
      
      // Add to today's totals
      mealTotals.forEach((nutrient, value) {
        _nutritionData[today]![nutrient] = 
            (_nutritionData[today]![nutrient] ?? 0) + value;
      });

    } else if (nutrition != null) {
      // Handle direct nutrition data
      nutrition.forEach((nutrient, value) {
        _nutritionData[today]![nutrient] = 
            (_nutritionData[today]![nutrient] ?? 0) + value;
      });
    }

    await _saveData();
    _debugPrintState('adding meal');
  }

  Future<void> deleteMeal({required Meal meal, required String date}) async {
    // Remove meal from meals list
    _meals[date]?.removeWhere((m) => m.id == meal.id);

    // Subtract meal's macros from the day's nutrition
    final prefs = await SharedPreferences.getInstance();
    final nutritionHistory = await getNutritionHistory();
    final dayData = nutritionHistory[date] ?? {'Protein': 0, 'Carbohydrates': 0, 'Fat': 0};
    dayData['Protein'] = (dayData['Protein'] ?? 0) - meal.getTotalNutrient('Protein').round();
    dayData['Carbohydrates'] = (dayData['Carbohydrates'] ?? 0) - meal.getTotalNutrient('Carbohydrates').round();
    dayData['Fat'] = (dayData['Fat'] ?? 0) - meal.getTotalNutrient('Fat').round();
    // Prevent negative values
    dayData['Protein'] = (dayData['Protein'] ?? 0) < 0 ? 0 : (dayData['Protein'] ?? 0);
    dayData['Carbohydrates'] = (dayData['Carbohydrates'] ?? 0) < 0 ? 0 : (dayData['Carbohydrates'] ?? 0);
    dayData['Fat'] = (dayData['Fat'] ?? 0) < 0 ? 0 : (dayData['Fat'] ?? 0);
    nutritionHistory[date] = dayData;
    await prefs.setString('nutritionData', jsonEncode(nutritionHistory));
  }

  Map<String, int> calculateNutritionTotals(Meal meal) {
    Map<String, int> totals = {
      'Protein': 0,
      'Carbohydrates': 0,
      'Fat': 0,
    };
    
    for (var item in meal.items) {
      for (var macro in item.macrosPer100g.keys) {
        totals[macro] = (totals[macro] ?? 0) + 
          ((item.macrosPer100g[macro] ?? 0) * item.quantity / 100).round();
      }
    }
    return totals;
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Convert meals to JSON
      final mealsJson = _meals.map((date, mealsList) {
        return MapEntry(
          date,
          mealsList.map((meal) => meal.toJson()).toList(),
        );
      });
      
      await prefs.setString('meals', jsonEncode(mealsJson));
      await prefs.setString('nutritionData', jsonEncode(_nutritionData));
      await prefs.setString('fitnessData', jsonEncode(_fitnessData));
      
      print("[DEBUG] Data saved successfully");
      print("[DEBUG] Saved nutrition data: $_nutritionData");
    } catch (e, stackTrace) {
      print("[ERROR] Failed to save data: $e");
      print("[ERROR] Stack trace: $stackTrace");
    }
  }

  final Map<String, int> _dailyTargets = {
    'Carbohydrates': 200,
    'Fat': 70,
    'Protein': 100,
  };

  // Getters
  Map<String, int> get dailyTargets => Map<String, int>.from(_dailyTargets);
  Map<String, List<Meal>> get meals => Map<String, List<Meal>>.from(_meals);
  
  // Methods
  void updateDailyTargets(Map<String, int> newTargets) {
    _dailyTargets.clear();
    _dailyTargets.addAll(newTargets);
    _saveData(); // Save after updating
    _debugPrintState('updating daily targets');
  }

  void updateSingleTarget(String nutrient, int value) {
    if (_dailyTargets.containsKey(nutrient)) {
      _dailyTargets[nutrient] = value;
    }
  }

  List<Meal> getMealsForDate(String date) => _meals[date] ?? [];
  Map<String, int> getNutritionData(String date) => 
    Map<String, int>.from(_nutritionData[date] ?? {});

  // Get all nutrition history without limiting entries
  Future<Map<String, Map<String, int>>> getNutritionHistory() async {
    await ensureInitialized();
    print("[DEBUG] Getting nutrition history: ${_nutritionData.length} entries");
    return Map<String, Map<String, int>>.from(_nutritionData);
  }

  // Fitness methods – re-add these to support fitness tracking
  Future<void> addOrUpdateFitnessData(String metric, String timestamp, double value) async {
    await ensureInitialized();
    
    // Extract date from timestamp (YYYY-MM-DD)
    final date = timestamp.split('T')[0];
    
    if (!_fitnessData.containsKey(date)) {
      _fitnessData[date] = {};
    }
    
    _fitnessData[date]![metric] = value;
    await _saveData();
    print("[DEBUG] Added fitness data for $date: $metric = $value");
  }

  Map<String, double> getFitnessData(String metric) {
    Map<String, double> metricData = {};
    _fitnessData.forEach((date, metrics) {
      if (metrics.containsKey(metric)) {
        metricData[date] = metrics[metric]!;
      }
    });
    return metricData;
  }

  Future<Map<String, Map<String, double>>> getFitnessHistory() async {
    await ensureInitialized();
    print("[DEBUG] Getting fitness history: ${_fitnessData.length} entries");
    return Map<String, Map<String, double>>.from(_fitnessData);
  }

  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final mealsJson = prefs.getString('meals');
      if (mealsJson != null) {
        final decoded = jsonDecode(mealsJson) as Map<String, dynamic>;
        _meals.clear();
        decoded.forEach((date, mealsList) {
          _meals[date] = (mealsList as List)
              .map((mealJson) => Meal.fromJson(mealJson))
              .toList();
        });
      }

      final nutritionJson = prefs.getString('nutritionData');
      if (nutritionJson != null) {
        final decoded = jsonDecode(nutritionJson) as Map<String, dynamic>;
        _nutritionData.clear();
        decoded.forEach((date, data) {
          _nutritionData[date] = Map<String, int>.from(data as Map);
        });
      }

      final fitnessJson = prefs.getString('fitnessData');
      if (fitnessJson != null) {
        final decoded = jsonDecode(fitnessJson);
        _fitnessData.clear();
        decoded.forEach((key, value) {
          _fitnessData[key] = Map<String, double>.from(value);
        });
      }
      
      print("[DEBUG] Data loaded successfully");
      print("[DEBUG] Loaded nutrition data: $_nutritionData");
    } catch (e, stackTrace) {
      print("[ERROR] Failed to load data: $e");
      print("[ERROR] Stack trace: $stackTrace");
    }
  }

  // Add debug print method
  void _debugPrintState(String action) {
    final String today = DateTime.now().toString().split(' ')[0];
    print('\n[DEBUG] AppData State after $action:');
    print('----------------------------------------');
    print('Daily Targets: $_dailyTargets');
    print('Meals for today: ');
    if (_meals[today] != null) {
      for (var meal in _meals[today]!) {
        print('  - ${meal.name}:');
        for (var item in meal.items) {
          print('    * ${item.name}: ${item.quantity}g');
          print('      Macros: ${item.macrosPer100g}');
        }
      }
    } else {
      print('  No meals recorded for today');
    }
    print('Nutrition Totals: ${_nutritionData[today]}');
    print('Fitness Data:');
    _fitnessData.forEach((metric, data) {
      print('  $metric:');
      data.forEach((date, value) {
        print('    $date: $value');
      });
    });
    print('----------------------------------------\n');
  }

  // Modify date format to include time
  String _getCurrentTimestamp() {
    final now = DateTime.now();
    return now.toIso8601String(); // This will include seconds
  }

  // Add method to get recent entries
  List<MapEntry<String, Map<String, int>>> getRecentNutritionEntries(int count) {
    final entries = _nutritionData.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)); // Sort by timestamp descending
    return entries.take(count).toList();
  }

  List<MapEntry<String, double>> getRecentFitnessEntries(String metric, int count) {
    final entries = _fitnessData[metric]?.entries.toList() ?? [];
    entries.sort((a, b) => b.key.compareTo(a.key)); // Sort by timestamp descending
    return entries.take(count).toList();
  }

  void clearNutritionData() {
    _nutritionData.clear();
    _meals.clear();
    _saveData();
    print("[DEBUG] Nutrition data cleared from storage");
  }

  void clearFitnessData() {
    _fitnessData.clear();
    _saveData();
    print("[DEBUG] Fitness data cleared from storage");
  }

  // Add method to get latest nutrition totals
  Map<String, int> getLatestNutritionTotals() {
    if (_nutritionData.isEmpty) return {};
    
    final latest = _nutritionData.entries
      .reduce((a, b) => a.key.compareTo(b.key) > 0 ? a : b);
    return Map<String, int>.from(latest.value);
  }

  Map<String, int> getNutritionForDate(String date) {
    return _nutritionData[date] ?? {'Protein': 0, 'Carbohydrates': 0, 'Fat': 0};
  }

  // Add helper method to get meals with details
  List<Meal> getMealsForDateWithDetails(String date) {
    return _meals[date] ?? [];
  }

  // Add method to get meal images for a date
  List<String> getMealImagesForDate(String date) {
    return _meals[date]?.map((meal) => meal.imageFilePath).toList() ?? [];
  }

  static Future<void> enableTestMode(String dateStr) async {
    try {
      _overriddenDate = DateTime.parse(dateStr);
      _isTestMode = true;
      // Save test mode state to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('test_date', dateStr);
      await prefs.setBool('test_mode', true);
      print("[DEBUG] Test mode enabled. Date set to: $dateStr");
    } catch (e) {
      print("[ERROR] Invalid date format. Use YYYY-MM-DD");
      rethrow;
    }
  }

  static Future<void> disableTestMode() async {
    _overriddenDate = null;
    _isTestMode = false;
    // Clear test mode state from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('test_date');
    await prefs.setBool('test_mode', false);
    print("[DEBUG] Test mode disabled");
  }

  // Add this method
  static void setDebugDate(String? date) {
    if (date != null) {
      try {
        // Validate date format
        DateTime.parse(date);
        _debugDate = date;
        print('[DEBUG] Debug date set to: $date');
      } catch (e) {
        print('[ERROR] Invalid date format. Use YYYY-MM-DD');
      }
    } else {
      _debugDate = null;
      print('[DEBUG] Debug date cleared');
    }
  }

  // Modify this helper method
  String _getCurrentDate() {
    // For debug/testing only
    if (_debugDate != null) {
      return _debugDate!;
    }
    if (_isTestMode && _overriddenDate != null) {
      return _overriddenDate!.toString().split(' ')[0];
    }
    return DateTime.now().toString().split(' ')[0];
  }
}
