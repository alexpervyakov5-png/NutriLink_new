import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';
import '../core/error_handler.dart';
import 'services.dart';
import 'clients_service.dart';
import 'models.dart';

class DiaryService extends ChangeNotifier with ClientAwareService {
  @override
  final ClientsService clientsService;
  final _uuid = const Uuid();
  DailyGoals? _goals = const DailyGoals.empty();

  final Map<MealType, List<Meal>> _meals = {
    for (var t in MealType.values) t: [],
  };
  final Map<MealType, DateTime?> _mealsCacheTime = {
    for (var t in MealType.values) t: null,
  };
  final Map<MealType, bool> _expanded = {
    MealType.breakfast: true,
    MealType.lunch: true,
    MealType.dinner: false,
    MealType.snack: false,
  };

  final Map<MealType, String?> _typeComments = {};
  String? getCommentForType(MealType type) => _typeComments[type];

  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _loadingGoals = false;
  String? _error;
  
  Timer? _summaryUpdateTimer;

  // 🔥 КЭШИ для продуктов и рецептов
  List<Product>? _cachedProducts;
  DateTime? _productsCacheTime;
  List<Recipe>? _cachedRecipes;
  DateTime? _recipesCacheTime;
  
  // 🔥 КЭШИ для дневника (meals и goals)
  Map<MealType, List<Meal>>? _cachedMeals;
  DateTime? _mealsDataCacheTime;
  DailyGoals? _cachedGoals;
  DateTime? _goalsCacheTime;
  
  static const Duration _cacheDuration = Duration(minutes: 2); // 🔥 Кэш живёт 2 минуты
  static const Duration _shortCacheDuration = Duration(minutes: 1); // 🔥 Короткий кэш для частых обновлений

  DiaryService(this.clientsService) {
    clientsService.addListener(onClientChanged);
  }

  @override
  void dispose() {
    _summaryUpdateTimer?.cancel();
    clientsService.removeListener(onClientChanged);
    super.dispose();
  }

  @override
  void onClientChanged() {
    super.onClientChanged();
    for (var t in MealType.values) {
      _mealsCacheTime[t] = null;
    }
    _goals = null;
    _cachedProducts = null;
    _cachedRecipes = null;
    _productsCacheTime = null;
    _recipesCacheTime = null;
    _cachedMeals = null;
    _mealsDataCacheTime = null;
    _cachedGoals = null;
    _goalsCacheTime = null;
    notifyListeners();
    refresh();
  }

  DailyGoals? get goals => _goals;
  Map<MealType, List<Meal>> get meals => _meals;
  Map<MealType, bool> get expanded => _expanded;
  DateTime get date => _date;
  bool get loading => _loading;
  bool get loadingGoals => _loadingGoals;
  String? get error => _error;

  // ============================================
  // 🔥 КЭШИРОВАНИЕ GOALS
  // ============================================
  Future<void> _loadGoalsOnly(DateTime d, {bool force = false}) async {
    final uid = userId;
    if (uid == null || uid.isEmpty) return;
    final ds = d.toIso8601String().split('T')[0];

    // 🔥 Проверяем кэш (если не force и кэш свежий)
    if (!force && 
        _cachedGoals != null && 
        _goalsCacheTime != null &&
        DateTime.now().difference(_goalsCacheTime!) < _cacheDuration) {
      debugPrint('📦 Using cached goals');
      _goals = _cachedGoals;
      return;
    }

    try {
      debugPrint(' Fetching goals from network...');
      final [sum, gol] = await Future.wait([
        retryRequest(() => SupabaseConfig.client
            .from('daily_summary')
            .select('protein_actual, fat_actual, carbs_actual, calories_actual')
            .eq('user_id', uid)
            .eq('date', ds)
            .maybeSingle()),
        retryRequest(() => SupabaseConfig.client
            .from('user_goals')
            .select('protein_target, fat_target, carbs_target, calories_target')
            .eq('user_id', uid)
            .eq('is_active', true)
            .maybeSingle()),
      ]);
      
      _goals = DailyGoals(
        proteinTarget: toIntSafe(gol?['protein_target'], defaultValue: 100),
        fatsTarget: toIntSafe(gol?['fat_target'], defaultValue: 65),
        carbsTarget: toIntSafe(gol?['carbs_target'], defaultValue: 285),
        caloriesTarget: toIntSafe(gol?['calories_target'], defaultValue: 2500),
        proteinCurrent: toIntSafe(sum?['protein_actual']),
        fatsCurrent: toIntSafe(sum?['fat_actual']),
        carbsCurrent: toIntSafe(sum?['carbs_actual']),
        caloriesCurrent: toIntSafe(sum?['calories_actual']),
      );
      
      //  Сохраняем в кэш
      _cachedGoals = _goals;
      _goalsCacheTime = DateTime.now();
      debugPrint('💾 Cached goals');
    } catch (e) {
      debugPrint('❌ Goals load error: $e');
      _goals = const DailyGoals.empty();
    }
  }

  // ============================================
  //  КЭШИРОВАНИЕ MEALS
  // ============================================
  Future<void> _loadMealsOfType(MealType type, DateTime d, {bool force = false}) async {
    _mealsCacheTime[type] = null;
    final uid = userId;
    if (uid == null || uid.isEmpty) return;
    final ds = d.toIso8601String().split('T')[0];

    // 🔥 Проверяем кэш (если не force и кэш свежий)
    if (!force && 
        _cachedMeals != null && 
        _mealsDataCacheTime != null &&
        DateTime.now().difference(_mealsDataCacheTime!) < _cacheDuration) {
      debugPrint('📦 Using cached meals for $type');
      _meals[type] = _cachedMeals![type] ?? [];
      return;
    }

    try {
      debugPrint('🌐 Loading meals for type=$type, date=$ds from network...');
      
      final mealsData = await retryRequest(() => SupabaseConfig.client
          .from('meals')
          .select(
              'id, meal_type, eaten_at, comment, meal_items(id, amount_grams, product_id, recipe_id, calories, protein, fat, carbs, products(name), recipes(name))')
          .eq('user_id', uid)
          .eq('meal_type', type.dbValue)
          .eq('date', ds)
          .order('eaten_at', ascending: false));

      debugPrint(' Got ${mealsData.length} meals');

      final List<Map<String, dynamic>> allItems = [];
      String? comment;
      DateTime? eatenAt;
      
      for (var j in mealsData) {
        final items = j['meal_items'] as List? ?? [];
        if (j['comment'] != null && j['comment'].toString().isNotEmpty) {
          comment = j['comment'] as String?;
        }
        if (eatenAt == null && j['eaten_at'] != null) {
          eatenAt = DateTime.parse(j['eaten_at'] as String);
        }
        
        for (var it in items) {
          allItems.add({
            'id': it['id'],
            'amount_grams': it['amount_grams'],
            'product_id': it['product_id'],
            'recipe_id': it['recipe_id'],
            'calories': it['calories'],
            'protein': it['protein'],
            'fat': it['fat'],
            'carbs': it['carbs'],
            'products': it['products'],
            'recipes': it['recipes'],
          });
        }
      }

      if (allItems.isEmpty) {
        if (comment != null && comment.isNotEmpty) {
          _typeComments[type] = comment;
        }
        _meals[type] = [];
        
        // 🔥 Обновляем кэш
        _cachedMeals ??= {};
        _cachedMeals![type] = [];
        _mealsDataCacheTime = DateTime.now();
        return;
      }

      final Map<String, Map<String, dynamic>> groupedItems = {};
      
      for (var it in allItems) {
        final productId = it['product_id'] as String?;
        final recipeId = it['recipe_id'] as String?;
        
        final key = productId ?? (recipeId != null ? 'recipe_$recipeId' : 'item_${it['id']}');
        
        if (groupedItems.containsKey(key)) {
          final existing = groupedItems[key]!;
          existing['amount_grams'] = toIntSafe(existing['amount_grams']) + toIntSafe(it['amount_grams']);
          existing['calories'] = toIntSafe(existing['calories']) + toIntSafe(it['calories']);
          existing['protein'] = toIntSafe(existing['protein']) + toIntSafe(it['protein']);
          existing['fat'] = toIntSafe(existing['fat']) + toIntSafe(it['fat']);
          existing['carbs'] = toIntSafe(existing['carbs']) + toIntSafe(it['carbs']);
        } else {
          groupedItems[key] = {
            'id': it['id'],
            'amount_grams': it['amount_grams'],
            'product_id': productId,
            'recipe_id': recipeId,
            'calories': it['calories'],
            'protein': it['protein'],
            'fat': it['fat'],
            'carbs': it['carbs'],
            'products': it['products'],
            'recipes': it['recipes'],
          };
        }
      }

      final List<Meal> meals = [];
      
      for (var it in groupedItems.values) {
        String? nm;
        bool isRecipe = false;
        
        final productsRaw = it['products'];
        if (productsRaw is List && productsRaw.isNotEmpty) {
          nm = (productsRaw[0] as Map?)?['name'] as String?;
          isRecipe = false;
        } else if (productsRaw is Map) {
          nm = productsRaw['name'] as String?;
          isRecipe = false;
        }
        
        if (nm == null) {
          final recipesRaw = it['recipes'];
          if (recipesRaw is List && recipesRaw.isNotEmpty) {
            nm = ' ${(recipesRaw[0] as Map?)?['name'] as String?}';
            isRecipe = true;
          } else if (recipesRaw is Map) {
            nm = '🍳 ${recipesRaw['name'] as String?}';
            isRecipe = true;
          }
        }
        
        meals.add(Meal(
          id: _uuid.v4(),
          name: nm ?? 'Блюдо',
          weight: '${toIntSafe(it['amount_grams'])}г',
          calories: toIntSafe(it['calories']),
          protein: toIntSafe(it['protein']),
          fats: toIntSafe(it['fat']),
          carbs: toIntSafe(it['carbs']),
          mealType: type,
          createdAt: eatenAt ?? DateTime.now(),
          comment: comment,
          isRecipe: isRecipe,
        ));
      }
      
      _meals[type] = meals;
      
      //  Обновляем кэш
      _cachedMeals ??= {};
      _cachedMeals![type] = meals;
      _mealsDataCacheTime = DateTime.now();
      
      debugPrint('✅ Loaded and cached ${meals.length} meals for $type');
    } catch (e, stackTrace) {
      debugPrint('❌ Meals load error ($type): $e');
      debugPrint('❌ Stack: $stackTrace');
    }
  }

  Future<void> load(DateTime d, {MealType? loadMealsOfType, bool force = false}) async {
    _date = d;
    
    // 🔥 Если сменилась дата — сбрасываем кэш
    if (_mealsDataCacheTime != null && 
        DateTime.now().difference(_mealsDataCacheTime!) > _cacheDuration) {
      debugPrint('️ Meals cache expired, clearing...');
      _cachedMeals = null;
      _mealsDataCacheTime = null;
      _cachedGoals = null;
      _goalsCacheTime = null;
    }
    
    if (shouldReload(force: force)) {
      for (var t in MealType.values) {
        _mealsCacheTime[t] = null;
      }
    }

    _loadingGoals = true;
    notifyListeners();
    try {
      await _loadGoalsOnly(d, force: force);
    } finally {
      _loadingGoals = false;
      notifyListeners();
    }

    if (loadMealsOfType != null || force) {
      _loading = true;
      notifyListeners();
      try {
        if (force) {
          await Future.wait(MealType.values.map((t) => _loadMealsOfType(t, d, force: force)));
        } else if (loadMealsOfType != null) {
          await _loadMealsOfType(loadMealsOfType, d, force: force);
        }
      } finally {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async => await load(_date, force: true);

  void ensureMealsLoaded(MealType type) {
    _loadMealsOfType(type, _date).then((_) => notifyListeners());
  }

  // ============================================
  // 🔥 КЭШИРОВАНИЕ ПРОДУКТОВ
  // ============================================
  Future<List<Product>> getProducts(String query) async {
    try {
      if (query.isEmpty && 
          _cachedProducts != null && 
          _productsCacheTime != null &&
          DateTime.now().difference(_productsCacheTime!) < _cacheDuration) {
        debugPrint('📦 Using cached products (${_cachedProducts!.length} items)');
        return _cachedProducts!;
      }

      var q = SupabaseConfig.client.from('products').select('id,name,calories,protein,fat,carbs,user_id');
      if (query.isNotEmpty) {
        q = q.ilike('name', '%$query%');
      }
      final uid = userId;
      if (uid == null) return [];
      
      debugPrint('🌐 Fetching products from network...');
      final response = await retryRequest(() =>
          q.or('user_id.is.null,user_id.eq.$uid').limit(50));
      
      final products = response.map((j) => Product.fromJson(j)).toList();
      
      if (query.isEmpty) {
        _cachedProducts = products;
        _productsCacheTime = DateTime.now();
        debugPrint('💾 Cached ${products.length} products');
      }
      
      return products;
    } catch (e) {
      debugPrint('❌ Get products error: $e');
      return [];
    }
  }

  Future<Product?> createProduct(
      String name, double cal, double pro, double fat, double carb) async {
    try {
      final uid = userId;
      if (uid == null) return null;
      final res = await retryRequest(() =>
          SupabaseConfig.client.from('products').insert({
            'name': name,
            'calories': cal,
            'protein': pro,
            'fat': fat,
            'carbs': carb,
            'user_id': uid,
          }).select('id,name,calories,protein,fat,carbs,user_id').single());
      
      final product = Product.fromJson(res);
      
      _cachedProducts = null;
      _productsCacheTime = null;
      
      return product;
    } catch (e) {
      debugPrint('❌ Create product error: $e');
      return null;
    }
  }

  Future<bool> updateProduct({
    required String id,
    required String name,
    required double cal,
    required double pro,
    required double fat,
    required double carb,
  }) async {
    try {
      await retryRequest(() => SupabaseConfig.client.from('products').update({
        'name': name,
        'calories': cal,
        'protein': pro,
        'fat': fat,
        'carbs': carb,
      }).eq('id', id));
      
      _cachedProducts = null;
      _productsCacheTime = null;
      
      return true;
    } catch (e) {
      debugPrint('❌ Update product error: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      await retryRequest(() =>
          SupabaseConfig.client.from('products').delete().eq('id', productId));
      
      _cachedProducts = null;
      _productsCacheTime = null;
      
      return true;
    } catch (e) {
      debugPrint('❌ Delete product error: $e');
      return false;
    }
  }

  // ============================================
  // 🔥 КЭШИРОВАНИЕ РЕЦЕПТОВ
  // ============================================
  Future<List<dynamic>> getAllFoodItems(String query) async {
    try {
      final uid = userId;
      if (uid == null) return [];

      List<Product> products;
      if (query.isEmpty && 
          _cachedProducts != null && 
          _productsCacheTime != null &&
          DateTime.now().difference(_productsCacheTime!) < _cacheDuration) {
        debugPrint('📦 Using cached products');
        products = _cachedProducts!;
      } else {
        debugPrint('🌐 Fetching products from network...');
        var productsQuery = SupabaseConfig.client
            .from('products')
            .select('id,name,calories,protein,fat,carbs,user_id');
        if (query.isNotEmpty) {
          productsQuery = productsQuery.ilike('name', '%$query%');
        }
        final productsResponse = await retryRequest(() => productsQuery
            .or('user_id.is.null,user_id.eq.$uid')
            .limit(50));
        products = productsResponse.map((j) => Product.fromJson(j)).toList();
        
        if (query.isEmpty) {
          _cachedProducts = products;
          _productsCacheTime = DateTime.now();
        }
      }

      List<Recipe> recipes;
      if (query.isEmpty && 
          _cachedRecipes != null && 
          _recipesCacheTime != null &&
          DateTime.now().difference(_recipesCacheTime!) < _cacheDuration) {
        debugPrint('📦 Using cached recipes');
        recipes = _cachedRecipes!;
      } else {
        debugPrint(' Fetching recipes from network...');
        var recipesQuery = SupabaseConfig.client.from('recipes').select(
            'id,name,description,base_weight_grams,total_calories,total_protein,total_fat,total_carbs,created_by,recipe_products(amount_grams,product_id,products(id,name,calories,protein,fat,carbs,user_id))');
        if (query.isNotEmpty) {
          recipesQuery = recipesQuery.ilike('name', '%$query%');
        }
        final recipesResponse = await retryRequest(() => recipesQuery
            .or('created_by.is.null,created_by.eq.$uid')
            .limit(50));
        recipes = recipesResponse.map((j) {
          final ingredients = (j['recipe_products'] as List? ?? []).map((rp) {
            return RecipeIngredient(
              product: Product.fromJson(rp['products']),
              amountGrams: (rp['amount_grams'] as num).toDouble(),
            );
          }).toList();
          return Recipe.fromJson(j, ingredients);
        }).toList();
        
        if (query.isEmpty) {
          _cachedRecipes = recipes;
          _recipesCacheTime = DateTime.now();
        }
      }

      final all = [...products, ...recipes];
      all.sort((a, b) {
        final nameA = a is Product ? a.name : (a is Recipe ? a.name : '');
        final nameB = b is Product ? b.name : (b is Recipe ? b.name : '');
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });
      return all;
    } catch (e) {
      debugPrint('❌ Get all food items error: $e');
      return [];
    }
  }

  Future<Recipe?> createRecipe({
    required String name,
    String description = '',
    required List<RecipeIngredient> ingredients,
  }) async {
    try {
      final uid = userId;
      if (uid == null) return null;

      double baseWeight = 0;
      double totalCal = 0;
      double totalPro = 0;
      double totalFat = 0;
      double totalCarb = 0;

      for (var ing in ingredients) {
        baseWeight += ing.amountGrams;
        double ratio = ing.amountGrams / 100.0;
        totalCal += ing.product.calories * ratio;
        totalPro += ing.product.protein * ratio;
        totalFat += ing.product.fat * ratio;
        totalCarb += ing.product.carbs * ratio;
      }

      final recipeRes = await retryRequest(() =>
          SupabaseConfig.client.from('recipes').insert({
            'name': name,
            'description': description,
            'base_weight_grams': baseWeight,
            'total_calories': totalCal,
            'total_protein': totalPro,
            'total_fat': totalFat,
            'total_carbs': totalCarb,
            'created_by': uid,
          }).select('id').single());

      final recipeId = recipeRes['id'] as String;

      if (ingredients.isNotEmpty) {
        final productIds = ingredients.map((ing) => ing.product.id).toList();
        final accessible = await retryRequest(() => SupabaseConfig.client
            .from('products')
            .select('id')
            .inFilter('id', productIds)
            .or('user_id.is.null,user_id.eq.$uid'));

        if (accessible.length != productIds.length) {
          throw Exception('Не все продукты доступны для добавления в рецепт');
        }

        await retryRequest(() =>
            SupabaseConfig.client.from('recipe_products').insert(
              ingredients
                  .map((ing) => {
                        'recipe_id': recipeId,
                        'product_id': ing.product.id,
                        'amount_grams': ing.amountGrams,
                      })
                  .toList(),
            ));
      }

      _cachedRecipes = null;
      _recipesCacheTime = null;

      return Recipe(
        id: recipeId,
        name: name,
        description: description,
        baseWeightGrams: baseWeight,
        totalCalories: totalCal,
        totalProtein: totalPro,
        totalFat: totalFat,
        totalCarbs: totalCarb,
        userId: uid,
        ingredients: ingredients,
      );
    } catch (e) {
      debugPrint('❌ Create recipe error: $e');
      _error = ErrorHandler.format(e, context: 'recipe');
      notifyListeners();
      return null;
    }
  }

  Future<bool> _addMealItemCore({
    required MealType type,
    required String productName,
    required int calories,
    required int protein,
    required int fat,
    required int carbs,
    required double portionGrams,
    required String dateStr,
    String? comment,
    String? productId,
    String? recipeId,
  }) async {
    final uid = userId;
    if (uid == null || uid.isEmpty) throw Exception('Не авторизован');

    try {
      debugPrint('🔵 _addMealItemCore: type=$type, product=$productName');

      debugPrint('📝 Searching for existing meal...');
      final existingMeal = await retryRequest(() => SupabaseConfig.client
          .from('meals')
          .select('id')
          .eq('user_id', uid)
          .eq('meal_type', type.dbValue)
          .eq('date', dateStr)
          .maybeSingle());

      String mealId;
      
      if (existingMeal == null) {
        debugPrint('📝 Creating new meal...');
        final newMeal = await retryRequest(() => SupabaseConfig.client
            .from('meals')
            .insert({
              'user_id': uid,
              'meal_type': type.dbValue,
              'date': dateStr,
              'eaten_at': DateTime.now().toIso8601String(),
              if (comment != null && comment.isNotEmpty) 'comment': comment,
            })
            .select('id')
            .single());
        
        mealId = newMeal['id'] as String;
        debugPrint('✅ New meal created: $mealId');
      } else {
        mealId = existingMeal['id'] as String;
        debugPrint('✅ Found existing meal: $mealId');
        
        if (comment != null && comment.isNotEmpty) {
          await retryRequest(() => SupabaseConfig.client
              .from('meals')
              .update({'comment': comment})
              .eq('id', mealId));
        }
      }

      final insertData = <String, dynamic>{
        'meal_id': mealId,
        'amount_grams': portionGrams,
        'calories': calories,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
      };
      
      if (productId != null) {
        insertData['product_id'] = productId;
      }
      if (recipeId != null) {
        insertData['recipe_id'] = recipeId;
      }

      debugPrint(' Inserting meal_item: $insertData');

      await retryRequest(() => SupabaseConfig.client
          .from('meal_items')
          .insert(insertData));

      debugPrint('✅ Meal item inserted successfully');

      final newMeal = Meal(
        id: _uuid.v4(),
        name: productName,
        weight: '${portionGrams.toInt()}г',
        calories: calories,
        protein: protein,
        fats: fat,
        carbs: carbs,
        mealType: type,
        createdAt: DateTime.now(),
        comment: comment,
        isRecipe: recipeId != null,
      );
      if (_meals[type] != null) {
        _meals[type] = [..._meals[type]!, newMeal];
      }
      if (_goals != null) {
        _goals = _goals!.copyWith(
          caloriesCurrent: _goals!.caloriesCurrent + calories,
          proteinCurrent: _goals!.proteinCurrent + protein,
          fatsCurrent: _goals!.fatsCurrent + fat,
          carbsCurrent: _goals!.carbsCurrent + carbs,
        );
      }
      notifyListeners();

      // 🔥 Инвалидируем кэш meals после добавления
      _cachedMeals = null;
      _mealsDataCacheTime = null;
      _cachedGoals = null;
      _goalsCacheTime = null;

      _scheduleSummaryUpdate(uid, dateStr);

      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ _addMealItemCore error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      rethrow;
    }
  }

  void _scheduleSummaryUpdate(String uid, String dateStr) {
    _summaryUpdateTimer?.cancel();
    _summaryUpdateTimer = Timer(const Duration(milliseconds: 500), () {
      _updateDailySummaryInBackground(uid, dateStr).catchError((e) {
        debugPrint('⚠️ Background daily summary update failed: $e');
      });
    });
  }

  Future<void> _updateDailySummaryInBackground(String uid, String dateStr) async {
    try {
      final meals = await retryRequest(() => SupabaseConfig.client
          .from('meals')
          .select('meal_items(calories, protein, fat, carbs)')
          .eq('user_id', uid)
          .eq('date', dateStr));

      int c = 0, p = 0, f = 0, cb = 0;
      for (var m in meals) {
        final items = m['meal_items'] as List? ?? [];
        for (var it in items) {
          c += toIntSafe(it['calories']);
          p += toIntSafe(it['protein']);
          f += toIntSafe(it['fat']);
          cb += toIntSafe(it['carbs']);
        }
      }

      await retryRequest(() => SupabaseConfig.client.from('daily_summary').upsert({
        'user_id': uid,
        'date': dateStr,
        'calories_actual': c,
        'protein_actual': p,
        'fat_actual': f,
        'carbs_actual': cb,
      }, onConflict: 'user_id,date'), maxAttempts: 2);
    } catch (e) {
      debugPrint('❌ _updateDailySummaryInBackground error: $e');
      rethrow;
    }
  }

  Future<bool> addFoodItemToMeal({
    required MealType type,
    required dynamic item,
    required double portionGrams,
    String? comment,
  }) async {
    try {
      final ds = _date.toIso8601String().split('T')[0];

      int cal, pro, fat, cb;
      String itemName;
      String? productId;
      String? recipeId;

      if (item is Product) {
        double ratio = portionGrams / 100.0;
        cal = (item.calories * ratio).round();
        pro = (item.protein * ratio).round();
        fat = (item.fat * ratio).round();
        cb = (item.carbs * ratio).round();
        itemName = item.name;
        productId = item.id;
        recipeId = null;
        debugPrint('🟢 Adding Product: ${item.name} (${item.id})');
      } else if (item is Recipe) {
        double scale = portionGrams / item.baseWeightGrams;
        cal = (item.totalCalories * scale).round();
        pro = (item.totalProtein * scale).round();
        fat = (item.totalFat * scale).round();
        cb = (item.totalCarbs * scale).round();
        itemName = '🍳 ${item.name}';
        productId = null;
        recipeId = item.id;
        debugPrint('🟡 Adding Recipe: ${item.name} (${item.id})');
      } else {
        throw Exception('Unknown food item type: ${item.runtimeType}');
      }

      final result = await _addMealItemCore(
        type: type,
        productName: itemName,
        calories: cal,
        protein: pro,
        fat: fat,
        carbs: cb,
        portionGrams: portionGrams,
        dateStr: ds,
        comment: comment,
        productId: productId,
        recipeId: recipeId,
      );
      
      debugPrint('✅ addFoodItemToMeal completed: $result');
      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ Add food item error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  Future<bool> updateComment({
    required MealType type,
    required DateTime date,
    String? comment,
  }) async {
    try {
      final uid = userId;
      if (uid == null || uid.isEmpty) return false;
      final ds = date.toIso8601String().split('T')[0];
      final trimmed = comment?.trim().isEmpty == true ? null : comment?.trim();

      _typeComments[type] = trimmed;
      if (_meals[type]!.isNotEmpty && trimmed != null) {
        final updated = List<Meal>.from(_meals[type]!);
        updated[0] = updated[0].copyWith(comment: trimmed);
        _meals[type] = updated;
      }
      notifyListeners();

      final existing = await retryRequest(() => SupabaseConfig.client
          .from('meals')
          .select('id')
          .eq('user_id', uid)
          .eq('date', ds)
          .eq('meal_type', type.dbValue)
          .maybeSingle());

      if (existing == null) {
        await SupabaseConfig.client.from('meals').insert({
          'id': _uuid.v4(),
          'user_id': uid,
          'meal_type': type.dbValue,
          'date': ds,
          'eaten_at': DateTime.now().toIso8601String(),
          'comment': trimmed,
        });
      } else {
        await SupabaseConfig.client
            .from('meals')
            .update({'comment': trimmed})
            .eq('id', existing['id'] as String);
      }
      
      // 🔥 Инвалидируем кэш
      _cachedMeals = null;
      _mealsDataCacheTime = null;
      
      return true;
    } catch (e) {
      debugPrint('❌ updateComment error: $e');
      return false;
    }
  }

  Future<bool> add({
    required MealType type,
    String? pid,
    required String pname,
    required String w,
    required int cal,
    required int pro,
    required int fat,
    required int cb,
    String? comment,
  }) async {
    try {
      final ds = _date.toIso8601String().split('T')[0];
      final weightValue = int.parse(w.replaceAll(RegExp(r'\D'), ''));
      if (weightValue <= 0) throw Exception('Вес > 0');

      return await _addMealItemCore(
        type: type,
        productName: pname,
        calories: cal,
        protein: pro,
        fat: fat,
        carbs: cb,
        portionGrams: weightValue.toDouble(),
        dateStr: ds,
        comment: comment,
        productId: pid,
      );
    } catch (e) {
      debugPrint('❌ Add meal error: $e');
      return false;
    }
  }

  Future<bool> delete(String mealId, MealType type) async {
    try {
      final uid = userId;
      if (uid == null || uid.isEmpty) throw Exception('Не авторизован');

      final items = await SupabaseConfig.client
          .from('meal_items')
          .select('calories, protein, fat, carbs')
          .eq('meal_id', mealId);

      await SupabaseConfig.client
          .from('meal_items')
          .delete()
          .eq('meal_id', mealId);
      await SupabaseConfig.client
          .from('meals')
          .delete()
          .eq('id', mealId)
          .eq('user_id', uid);

      final ds = _date.toIso8601String().split('T')[0];
      await _updateDailySummaryInBackground(uid, ds);

      _mealsCacheTime[type] = null;
      
      // 🔥 Инвалидируем кэш
      _cachedMeals = null;
      _mealsDataCacheTime = null;
      _cachedGoals = null;
      _goalsCacheTime = null;
      
      await _loadGoalsOnly(_date, force: true);
      await _loadMealsOfType(type, _date, force: true);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      return false;
    }
  }

  void toggle(MealType t) {
    _expanded[t] = !(_expanded[t] ?? false);
    if (_expanded[t] == true) {
      ensureMealsLoaded(t);
    }
    notifyListeners();
  }
}