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

  // 🔥 Храним комментарии секций И их статус прочтения
  final Map<MealType, String?> _sectionComments = {};
  final Map<MealType, bool> _sectionCommentsUnread = {};
  
  String? getSectionComment(MealType type) => _sectionComments[type];
  bool isSectionCommentUnread(MealType type) => _sectionCommentsUnread[type] ?? false;

  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _loadingGoals = false;
  String? _error;

  Timer? _summaryUpdateTimer;

  List<Product>? _cachedProducts;
  DateTime? _productsCacheTime;
  List<Recipe>? _cachedRecipes;
  DateTime? _recipesCacheTime;

  Map<MealType, List<Meal>>? _cachedMeals;
  DateTime? _mealsDataCacheTime;
  DailyGoals? _cachedGoals;
  DateTime? _goalsCacheTime;

  bool _isFoodPreloaded = false;
  bool get isFoodPreloaded => _isFoodPreloaded;

  static const Duration _cacheDuration = Duration(minutes: 2);

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
    _clearAllCaches();
    notifyListeners();
    refresh();
  }

  void _clearAllCaches() {
    _cachedProducts = null;
    _productsCacheTime = null;
    _cachedRecipes = null;
    _recipesCacheTime = null;
    _cachedMeals = null;
    _mealsDataCacheTime = null;
    _cachedGoals = null;
    _goalsCacheTime = null;
    _isFoodPreloaded = false;
    _sectionComments.clear();
    _sectionCommentsUnread.clear();
  }

  void _clearFoodCaches() {
    _cachedProducts = null;
    _productsCacheTime = null;
    _cachedRecipes = null;
    _recipesCacheTime = null;
    _isFoodPreloaded = false;
  }

  void _clearMealsCaches() {
    _cachedMeals = null;
    _mealsDataCacheTime = null;
    _cachedGoals = null;
    _goalsCacheTime = null;
    _sectionComments.clear();
    _sectionCommentsUnread.clear();
  }

  DailyGoals? get goals => _goals;
  Map<MealType, List<Meal>> get meals => _meals;
  Map<MealType, bool> get expanded => _expanded;
  DateTime get date => _date;
  bool get loading => _loading;
  bool get loadingGoals => _loadingGoals;
  String? get error => _error;

  // ============================================
  // 🔥 ПРОВЕРКА НАЛИЧИЯ НЕПРОЧИТАННЫХ КОММЕНТАРИЕВ
  // ============================================
  bool hasUnreadCommentsForType(MealType type) {
    final meals = _meals[type] ?? [];
    final hasUnreadInMeals = meals.any((m) => 
        !m.isRead && m.comment != null && m.comment!.isNotEmpty);
    
    final hasUnreadSection = _sectionCommentsUnread[type] ?? false;
    
    final result = hasUnreadInMeals || hasUnreadSection;
    debugPrint('🔍 hasUnreadCommentsForType($type): meals=$hasUnreadInMeals, section=$hasUnreadSection → $result');
    return result;
  }

  // ============================================
  // ПРЕДЗАГРУЗКА ДАННЫХ
  // ============================================
  Future<void> preloadFoodItems() async {
    if (_isFoodPreloaded) {
      debugPrint('📦 Food items already preloaded');
      return;
    }

    final uid = userId;
    if (uid == null || uid.isEmpty) return;

    debugPrint('🚀 Preloading food items in background...');

    try {
      await Future.wait([
        getProducts(''),
        _preloadRecipes(),
      ]);

      _isFoodPreloaded = true;
      debugPrint('✅ Food items preloaded successfully');
    } catch (e) {
      debugPrint('❌ Preload food items error: $e');
    }
  }

  Future<void> _preloadRecipes() async {
    try {
      final uid = userId;
      if (uid == null) return;

      if (_cachedRecipes != null &&
          _recipesCacheTime != null &&
          DateTime.now().difference(_recipesCacheTime!) < _cacheDuration) {
        return;
      }

      final recipesResponse = await retryRequest(() =>
          SupabaseConfig.client.from('recipes').select(
              'id,name,description,base_weight_grams,total_calories,total_protein,total_fat,total_carbs,created_by,recipe_products(amount_grams,product_id,products(id,name,calories,protein,fat,carbs,user_id))').or(
              'created_by.is.null,created_by.eq.$uid').limit(50));

      _cachedRecipes = recipesResponse.map((j) {
        final ingredients = (j['recipe_products'] as List? ?? []).map((rp) {
          return RecipeIngredient(
            product: Product.fromJson(rp['products']),
            amountGrams: (rp['amount_grams'] as num).toDouble(),
          );
        }).toList();
        return Recipe.fromJson(j, ingredients);
      }).toList();

      _recipesCacheTime = DateTime.now();
      debugPrint('💾 Preloaded ${_cachedRecipes!.length} recipes');
    } catch (e) {
      debugPrint('❌ Preload recipes error: $e');
    }
  }

  // ============================================
  // 🔥 ЗАГРУЗКА ЦЕЛЕЙ (для конкретной даты)
  // ============================================
  Future<void> _loadGoalsOnly(DateTime d, {bool force = false}) async {
    final uid = userId;
    if (uid == null || uid.isEmpty) return;
    final ds = d.toIso8601String().split('T')[0];

    if (!force &&
        _cachedGoals != null &&
        _goalsCacheTime != null &&
        DateTime.now().difference(_goalsCacheTime!) < _cacheDuration) {
      debugPrint('📦 Using cached goals');
      _goals = _cachedGoals;
      return;
    }

    try {
      debugPrint('🌐 Fetching goals from network...');
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
            .eq('date', ds)
            .maybeSingle()),
      ]);

      _goals = DailyGoals(
        proteinTarget: toIntSafe(gol?['protein_target'], defaultValue: 0),
        fatsTarget: toIntSafe(gol?['fat_target'], defaultValue: 0),
        carbsTarget: toIntSafe(gol?['carbs_target'], defaultValue: 0),
        caloriesTarget: toIntSafe(gol?['calories_target'], defaultValue: 0),
        proteinCurrent: toIntSafe(sum?['protein_actual']),
        fatsCurrent: toIntSafe(sum?['fat_actual']),
        carbsCurrent: toIntSafe(sum?['carbs_actual']),
        caloriesCurrent: toIntSafe(sum?['calories_actual']),
      );

      _cachedGoals = _goals;
      _goalsCacheTime = DateTime.now();
      debugPrint('💾 Cached goals for $ds');
    } catch (e) {
      debugPrint('❌ Goals load error: $e');
      _goals = const DailyGoals.empty();
    }
  }

  // ============================================
  // 🔥 ЗАГРУЗКА MEALS С ГРУППИРОВКОЙ + СЕКЦИОННЫЕ КОММЕНТАРИИ + is_read
  // ============================================
  Future<void> _loadMealsOfType(MealType type, DateTime d,
      {bool force = false}) async {
    _mealsCacheTime[type] = null;
    final uid = userId;
    if (uid == null || uid.isEmpty) return;
    final ds = d.toIso8601String().split('T')[0];

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
              'id, meal_type, eaten_at, comment, is_read, meal_items(id, amount_grams, product_id, recipe_id, calories, protein, fat, carbs, products(name), recipes(name))')
          .eq('user_id', uid)
          .eq('meal_type', type.dbValue)
          .eq('date', ds)
          .order('eaten_at', ascending: false));

      debugPrint('📦 Got ${mealsData.length} meals');

      String? sectionComment;
      bool sectionIsUnread = false;
      for (var j in mealsData) {
        final comment = j['comment'] as String?;
        if (comment != null && comment.isNotEmpty) {
          sectionComment = comment;
          final isRead = (j['is_read'] as bool?) ?? true;
          sectionIsUnread = !isRead;
          debugPrint('💬 Found section comment: "$comment" (isRead: $isRead)');
          break;
        }
      }
      _sectionComments[type] = sectionComment;
      _sectionCommentsUnread[type] = sectionIsUnread;
      debugPrint('💬 Section comment for $type: "$sectionComment" (isUnread: $sectionIsUnread)');

      final List<Map<String, dynamic>> allItems = [];
      
      for (var j in mealsData) {
        final mealId = j['id'] as String;
        final comment = j['comment'] as String?;
        final isRead = (j['is_read'] as bool?) ?? true;
        final items = j['meal_items'] as List? ?? [];
        DateTime? eatenAt;
        if (j['eaten_at'] != null) {
          eatenAt = DateTime.parse(j['eaten_at'] as String);
        }

        if (items.isEmpty) {
          debugPrint('⚠️ Meal $mealId has no items, skipping (comment: $comment, isRead: $isRead)');
          continue;
        }

        for (var it in items) {
          allItems.add({
            'meal_id': mealId,
            'meal_comment': comment,
            'is_read': isRead,
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
            'eaten_at': eatenAt,
          });
        }
      }

      if (allItems.isEmpty) {
        _meals[type] = [];
        _cachedMeals ??= {};
        _cachedMeals![type] = [];
        _mealsDataCacheTime = DateTime.now();
        debugPrint('✅ No meal items found for $type (section comment: $sectionComment)');
        notifyListeners();
        return;
      }

      final Map<String, Map<String, dynamic>> groupedItems = {};

      for (var it in allItems) {
        final productId = it['product_id'] as String?;
        final recipeId = it['recipe_id'] as String?;
        final key = productId ??
            (recipeId != null ? 'recipe_$recipeId' : 'item_${it['id']}');

        if (groupedItems.containsKey(key)) {
          final existing = groupedItems[key]!;
          existing['amount_grams'] =
              toIntSafe(existing['amount_grams']) + toIntSafe(it['amount_grams']);
          existing['calories'] =
              toIntSafe(existing['calories']) + toIntSafe(it['calories']);
          existing['protein'] =
              toIntSafe(existing['protein']) + toIntSafe(it['protein']);
          existing['fat'] = toIntSafe(existing['fat']) + toIntSafe(it['fat']);
          existing['carbs'] =
              toIntSafe(existing['carbs']) + toIntSafe(it['carbs']);

          final existingItemIds =
              (existing['meal_item_ids'] as List<String>? ?? []);
          existingItemIds.add(it['id'] as String);
          existing['meal_item_ids'] = existingItemIds;

          final existingMealIds =
              (existing['db_meal_ids'] as List<String>? ?? []);
          final mealId = it['meal_id'] as String;
          if (!existingMealIds.contains(mealId)) {
            existingMealIds.add(mealId);
          }
          existing['db_meal_ids'] = existingMealIds;

          if ((existing['comment'] == null || (existing['comment'] as String).isEmpty) &&
              it['meal_comment'] != null &&
              (it['meal_comment'] as String).isNotEmpty) {
            existing['comment'] = it['meal_comment'] as String;
          }

          final existingIsRead = (existing['is_read'] as bool?) ?? true;
          final currentIsRead = (it['is_read'] as bool?) ?? true;
          existing['is_read'] = existingIsRead && currentIsRead;
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
            'meal_item_ids': [it['id'] as String],
            'db_meal_ids': [it['meal_id'] as String],
            'comment': it['meal_comment'] as String?,
            'is_read': (it['is_read'] as bool?) ?? true,
            'eaten_at': it['eaten_at'] as DateTime?,
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
            nm = '🍳 ${(recipesRaw[0] as Map?)?['name'] as String?}';
            isRecipe = true;
          } else if (recipesRaw is Map) {
            nm = '🍳 ${recipesRaw['name'] as String?}';
            isRecipe = true;
          }
        }

        meals.add(Meal(
          id: _uuid.v4(),
          name: nm ?? 'Блюдо',
          weight: '${toIntSafe(it['amount_grams'])}',
          calories: toIntSafe(it['calories']),
          protein: toIntSafe(it['protein']),
          fats: toIntSafe(it['fat']),
          carbs: toIntSafe(it['carbs']),
          mealType: type,
          createdAt: (it['eaten_at'] as DateTime?) ?? DateTime.now(),
          comment: it['comment'] as String?,
          isRecipe: isRecipe,
          mealItemIds: (it['meal_item_ids'] as List<String>?) ?? [],
          dbMealIds: (it['db_meal_ids'] as List<String>?) ?? [],
          isRead: (it['is_read'] as bool?) ?? true,
        ));
      }

      _meals[type] = meals;
      _cachedMeals ??= {};
      _cachedMeals![type] = meals;
      _mealsDataCacheTime = DateTime.now();

      debugPrint('✅ Loaded and cached ${meals.length} meals for $type');
    } catch (e, stackTrace) {
      debugPrint('❌ Meals load error ($type): $e');
      debugPrint('❌ Stack: $stackTrace');
    }
  }

  Future<void> load(DateTime d,
      {MealType? loadMealsOfType, bool force = false}) async {
    _date = d;

    if (_mealsDataCacheTime != null &&
        DateTime.now().difference(_mealsDataCacheTime!) > _cacheDuration) {
      debugPrint('🗑️ Meals cache expired, clearing...');
      _clearMealsCaches();
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
          await Future.wait(MealType.values
              .map((t) => _loadMealsOfType(t, d, force: force)));
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
  // ПРОДУКТЫ
  // ============================================
  Future<List<Product>> getProducts(String query) async {
    try {
      if (query.isEmpty &&
          _cachedProducts != null &&
          _productsCacheTime != null &&
          DateTime.now().difference(_productsCacheTime!) < _cacheDuration) {
        debugPrint(
            '📦 Using cached products (${_cachedProducts!.length} items)');
        return _cachedProducts!;
      }

      var q = SupabaseConfig.client
          .from('products')
          .select('id,name,calories,protein,fat,carbs,user_id');
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

      _clearFoodCaches();

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

      _clearFoodCaches();

      return true;
    } catch (e) {
      debugPrint('❌ Update product error: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      await retryRequest(() => SupabaseConfig.client
          .from('products')
          .delete()
          .eq('id', productId));

      _clearFoodCaches();

      return true;
    } catch (e) {
      debugPrint('❌ Delete product error: $e');
      return false;
    }
  }

  // ============================================
  // СПИСОК ЕДЫ (продукты + рецепты)
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
        debugPrint('🌐 Fetching recipes from network...');
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

      _clearFoodCaches();

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

  Future<bool> deleteRecipe(String recipeId) async {
    try {
      final uid = userId;
      if (uid == null) return false;

      debugPrint('🗑️ Deleting recipe: $recipeId');

      await retryRequest(() => SupabaseConfig.client
          .from('recipe_products')
          .delete()
          .eq('recipe_id', recipeId));

      await retryRequest(() => SupabaseConfig.client
          .from('recipes')
          .delete()
          .eq('id', recipeId)
          .eq('created_by', uid));

      _clearFoodCaches();
      debugPrint('✅ Recipe deleted successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Delete recipe error: $e');
      return false;
    }
  }

  Future<bool> updateRecipe({
    required String id,
    required String name,
    String description = '',
    required List<RecipeIngredient> ingredients,
  }) async {
    try {
      final uid = userId;
      if (uid == null) return false;

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

      await retryRequest(() => SupabaseConfig.client.from('recipes').update({
            'name': name,
            'description': description,
            'base_weight_grams': baseWeight,
            'total_calories': totalCal,
            'total_protein': totalPro,
            'total_fat': totalFat,
            'total_carbs': totalCarb,
          }).eq('id', id).eq('created_by', uid));

      await retryRequest(() => SupabaseConfig.client
          .from('recipe_products')
          .delete()
          .eq('recipe_id', id));

      if (ingredients.isNotEmpty) {
        await retryRequest(() => SupabaseConfig.client
            .from('recipe_products')
            .insert(ingredients
                .map((ing) => {
                      'recipe_id': id,
                      'product_id': ing.product.id,
                      'amount_grams': ing.amountGrams,
                    })
                .toList()));
      }

      _clearFoodCaches();
      debugPrint('✅ Recipe updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Update recipe error: $e');
      return false;
    }
  }

  // ============================================
  // ДОБАВЛЕНИЕ ПРОДУКТА В ПРИЁМ ПИЩИ
  // ============================================
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
          .select('id, comment')
          .eq('user_id', uid)
          .eq('meal_type', type.dbValue)
          .eq('date', dateStr)
          .maybeSingle());

      String mealId;
      String? existingComment;

      if (existingMeal == null) {
        debugPrint('📝 Creating new meal...');
        final newMeal = await retryRequest(() => SupabaseConfig.client
            .from('meals')
            .insert({
              'user_id': uid,
              'meal_type': type.dbValue,
              'date': dateStr,
              'eaten_at': DateTime.now().toIso8601String(),
              'is_read': true,
            })
            .select('id')
            .single());

        mealId = newMeal['id'] as String;
        debugPrint('✅ New meal created: $mealId');
      } else {
        mealId = existingMeal['id'] as String;
        existingComment = existingMeal['comment'] as String?;
        debugPrint('✅ Found existing meal: $mealId (comment: $existingComment)');
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

      debugPrint('📝 Inserting meal_item: $insertData');

      final insertedItem = await retryRequest(() => SupabaseConfig.client
          .from('meal_items')
          .insert(insertData)
          .select('id')
          .single());

      debugPrint('✅ Meal item inserted successfully');

      final newMealItemId = insertedItem['id'] as String;

      final newMeal = Meal(
        id: _uuid.v4(),
        name: productName,
        weight: '${portionGrams.toInt()}',
        calories: calories,
        protein: protein,
        fats: fat,
        carbs: carbs,
        mealType: type,
        createdAt: DateTime.now(),
        comment: existingComment,
        isRecipe: recipeId != null,
        mealItemIds: [newMealItemId],
        dbMealIds: [mealId],
        isRead: true,
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

      _clearMealsCaches();

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

  Future<void> _updateDailySummaryInBackground(
      String uid, String dateStr) async {
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

      await retryRequest(
          () => SupabaseConfig.client.from('daily_summary').upsert({
                'user_id': uid,
                'date': dateStr,
                'calories_actual': c,
                'protein_actual': p,
                'fat_actual': f,
                'carbs_actual': cb,
              }, onConflict: 'user_id,date'),
          maxAttempts: 2);
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

  // ============================================
  // 🔥 ОБНОВЛЕНИЕ КОММЕНТАРИЯ СЕКЦИИ
  // 🔥 С RETRY для всех запросов к БД
  // ============================================
  Future<bool> updateComment({
    required MealType type,
    required DateTime date,
    String? comment,
    List<String>? mealIds,
    bool isTrainerWriting = false,
  }) async {
    try {
      final uid = userId;
      if (uid == null || uid.isEmpty) return false;
      final ds = date.toIso8601String().split('T')[0];
      final trimmed =
          comment?.trim().isEmpty == true ? null : comment?.trim();

      final isReadValue = isTrainerWriting ? false : true;

      debugPrint('💬 updateComment called:');
      debugPrint('   - type: $type');
      debugPrint('   - isTrainerWriting: $isTrainerWriting');
      debugPrint('   - comment: "$trimmed"');
      debugPrint('   - current user (uid): $uid');
      debugPrint('   - selectedUserId (client): ${clientsService.selectedUserId}');

      _sectionComments[type] = trimmed;
      _sectionCommentsUnread[type] = isTrainerWriting && trimmed != null;
      debugPrint('💬 Updated local cache: comment="$trimmed", isUnread=${_sectionCommentsUnread[type]}');
      notifyListeners();

      // 🔥 ВАЖНО: если пишет тренер, обновляем meals клиента, а не свои!
      final targetUserId = isTrainerWriting 
          ? (clientsService.selectedUserId ?? uid)
          : uid;

      debugPrint('💬 Target user ID: $targetUserId');

      if (mealIds != null && mealIds.isNotEmpty) {
        debugPrint('💬 Updating comment for ${mealIds.length} meals');
        
        // 🔥 ОБЁРНУТО В retryRequest
        for (final mealId in mealIds) {
          await retryRequest(() => SupabaseConfig.client
              .from('meals')
              .update({
                'comment': trimmed,
                'is_read': isReadValue,
              })
              .eq('id', mealId)
              .eq('user_id', targetUserId));
        }
        
        debugPrint('✅ Updated ${mealIds.length} meals');
      } else {
        debugPrint('💬 Searching for meals to update comment...');
        
        // 🔥 ОБЁРНУТО В retryRequest
        final existingMeals = await retryRequest(() => SupabaseConfig.client
            .from('meals')
            .select('id')
            .eq('user_id', targetUserId)
            .eq('date', ds)
            .eq('meal_type', type.dbValue));

        debugPrint('💬 Found ${existingMeals.length} existing meals');

        if (existingMeals.isEmpty) {
          if (trimmed != null) {
            debugPrint('💬 Creating new meal with comment for $type');
            
            // 🔥 ОБЁРНУТО В retryRequest
            await retryRequest(() => SupabaseConfig.client.from('meals').insert({
              'id': _uuid.v4(),
              'user_id': targetUserId,
              'meal_type': type.dbValue,
              'date': ds,
              'eaten_at': DateTime.now().toIso8601String(),
              'comment': trimmed,
              'is_read': isReadValue,
            }));
            
            debugPrint('✅ New meal created');
          }
        } else {
          debugPrint('💬 Updating ${existingMeals.length} existing meals');
          
          // 🔥 ОБЁРНУТО В retryRequest
          for (final m in existingMeals) {
            await retryRequest(() => SupabaseConfig.client
                .from('meals')
                .update({
                  'comment': trimmed,
                  'is_read': isReadValue,
                })
                .eq('id', m['id'] as String)
                .eq('user_id', targetUserId));
          }
          
          debugPrint('✅ Updated ${existingMeals.length} meals');
        }
      }

      _clearMealsCaches();
      await _loadMealsOfType(type, date, force: true);
      notifyListeners();

      // 🔥 Если тренер пишет — отправить email КЛИЕНТУ
      if (isTrainerWriting && trimmed != null) {
        final targetClientId = clientsService.selectedUserId;
        
        debugPrint('📧 [EMAIL] Checking conditions:');
        debugPrint('   - isTrainerWriting: $isTrainerWriting');
        debugPrint('   - trimmed: "$trimmed"');
        debugPrint('   - targetClientId: $targetClientId');
        
        if (targetClientId != null && targetClientId.isNotEmpty) {
          debugPrint('📧 [EMAIL] Sending email to CLIENT: $targetClientId');
          
          // 🔥 Запускаем в фоне, не блокируем UI
          unawaited(_sendCommentNotificationToClient(
            clientId: targetClientId,
            mealType: type.label,
            comment: trimmed,
          ));
        } else {
          debugPrint('⚠️ [EMAIL] Cannot send: selectedUserId is null or empty');
        }
      }

      return true;
    } catch (e, stack) {
      debugPrint('❌ updateComment error: $e');
      debugPrint('❌ Stack: $stack');
      return false;
    }
  }

  // ============================================
  // 🔥 ОТПРАВКА EMAIL-УВЕДОМЛЕНИЯ КЛИЕНТУ (через Edge Function)
  // 🔥 С ПОВТОРНЫМИ ПОПЫТКАМИ при ошибке сети
  // ============================================
  Future<void> _sendCommentNotificationToClient({
    required String clientId,
    required String mealType,
    required String comment,
  }) async {
    debugPrint('📧 [EMAIL] ========== START ==========');
    
    try {
      // 🔥 ШАГ 1: Получаем ID текущего пользователя (тренера)
      debugPrint('📧 [EMAIL] Step 1: Getting current user...');
      
      String? currentUserId;
      try {
        currentUserId = SupabaseConfig.client.auth.currentUser?.id;
        debugPrint('📧 [EMAIL]   - currentUserId: $currentUserId');
      } catch (e) {
        debugPrint('⚠️ [EMAIL]   - Error getting current user: $e');
      }
      
      if (currentUserId == null || currentUserId.isEmpty) {
        currentUserId = SupabaseConfig.currentUserId;
        debugPrint('📧 [EMAIL]   - Fallback currentUserId: $currentUserId');
      }
      
      // 🔥 ШАГ 2: Получаем имя тренера
      debugPrint('📧 [EMAIL] Step 2: Getting trainer name...');
      String trainerName = 'Ваш тренер';
      
      if (currentUserId != null && currentUserId.isNotEmpty) {
        try {
          final response = await SupabaseConfig.client
              .from('users')
              .select('username')
              .eq('id', currentUserId)
              .maybeSingle();
          
          if (response != null && response['username'] != null) {
            final username = response['username'];
            if (username != null && username.toString().isNotEmpty) {
              trainerName = username.toString();
            }
          }
          debugPrint('📧 [EMAIL]   - Trainer name: $trainerName');
        } catch (e) {
          debugPrint('⚠️ [EMAIL]   - Error fetching trainer name: $e');
        }
      }
      
      // 🔥 ШАГ 3: Вызываем Edge Function С ПОВТОРНЫМИ ПОПЫТКАМИ
      debugPrint('📧 [EMAIL] Step 3: Calling Edge Function...');
      
      const maxAttempts = 3;
      const delayBetweenAttempts = Duration(seconds: 2);
      
      for (int attempt = 1; attempt <= maxAttempts; attempt++) {
        debugPrint('📧 [EMAIL]   - Attempt $attempt of $maxAttempts');
        
        try {
          final response = await SupabaseConfig.client.functions.invoke(
            'send-comment-email',
            body: {
              'client_id': clientId,
              'meal_type': mealType,
              'comment': comment,
              'trainer_name': trainerName,
            },
          );

          debugPrint('📧 [EMAIL]   - Status: ${response.status}');
          debugPrint('📧 [EMAIL]   - Data: ${response.data}');

          if (response.status == 200) {
            debugPrint('✅ [EMAIL] Email sent successfully!');
            debugPrint('📧 [EMAIL] ========== END ==========');
            return; // ✅ Успех — выходим
          } else {
            debugPrint('⚠️ [EMAIL] Failed with status: ${response.status}');
          }
        } catch (e) {
          debugPrint('⚠️ [EMAIL] Attempt $attempt failed: $e');
          
          if (attempt < maxAttempts) {
            debugPrint('📧 [EMAIL]   - Waiting ${delayBetweenAttempts.inSeconds}s before retry...');
            await Future.delayed(delayBetweenAttempts);
          }
        }
      }
      
      debugPrint('❌ [EMAIL] All $maxAttempts failed. Giving up.');
      
    } catch (e, stack) {
      debugPrint('❌ [EMAIL] UNEXPECTED ERROR: $e');
      debugPrint('❌ [EMAIL] Stack: $stack');
    }
    
    debugPrint('📧 [EMAIL] ========== END ==========');
  }

  // ============================================
  // 🔥 ПОМЕТИТЬ КОММЕНТАРИЙ КАК ПРОЧИТАННЫЙ
  // ============================================
  Future<bool> markCommentAsRead(MealType type) async {
    try {
      final uid = userId;
      if (uid == null || uid.isEmpty) return false;

      debugPrint('📖 markCommentAsRead called for $type');

      final meals = _meals[type] ?? [];
      final unreadMealIds = <String>{};
      
      for (final m in meals) {
        if (!m.isRead && m.comment != null && m.comment!.isNotEmpty) {
          unreadMealIds.addAll(m.dbMealIds);
        }
      }

      if (_sectionCommentsUnread[type] == true) {
        final ds = _date.toIso8601String().split('T')[0];
        final sectionMeals = await retryRequest(() => SupabaseConfig.client
            .from('meals')
            .select('id')
            .eq('user_id', uid)
            .eq('date', ds)
            .eq('meal_type', type.dbValue)
            .eq('is_read', false)
            .not('comment', 'is', null));
        
        for (final m in sectionMeals) {
          unreadMealIds.add(m['id'] as String);
        }
      }

      if (unreadMealIds.isEmpty) {
        debugPrint('ℹ️ No unread meals to mark for $type');
        return true;
      }

      debugPrint('📖 Marking ${unreadMealIds.length} meals as read for $type');

      for (final mealId in unreadMealIds) {
        await retryRequest(() => SupabaseConfig.client
            .from('meals')
            .update({'is_read': true})
            .eq('id', mealId)
            .eq('user_id', uid));
      }

      _meals[type] = meals.map((m) => m.copyWith(isRead: true)).toList();
      _sectionCommentsUnread[type] = false;
      notifyListeners();

      debugPrint('✅ Comments marked as read for $type');
      return true;
    } catch (e) {
      debugPrint('❌ markCommentAsRead error: $e');
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

  // ============================================
  // 🔥 УДАЛЕНИЕ ПРОДУКТА ИЗ ПРИЁМА ПИЩИ
  // ============================================
  Future<bool> deleteMealItem({
    required Meal meal,
  }) async {
    try {
      final uid = userId;
      if (uid == null || uid.isEmpty) throw Exception('Не авторизован');

      debugPrint('🗑️ Deleting meal item: ${meal.name}');
      debugPrint('📋 Meal IDs to delete: ${meal.mealItemIds}');

      if (meal.mealItemIds.isEmpty) {
        debugPrint('⚠️ No meal_item_ids found for ${meal.name}');
        return false;
      }

      String? parentMealId;
      try {
        final firstItemData = await retryRequest(() => SupabaseConfig.client
            .from('meal_items')
            .select('meal_id')
            .eq('id', meal.mealItemIds.first)
            .maybeSingle());
        parentMealId = firstItemData?['meal_id'] as String?;
        debugPrint('🔍 Parent meal ID: $parentMealId');
      } catch (e) {
        debugPrint('⚠️ Error getting parent meal ID: $e');
      }

      for (final itemId in meal.mealItemIds) {
        try {
          debugPrint('🗑️ Deleting meal_item: $itemId');
          await retryRequest(() => SupabaseConfig.client
              .from('meal_items')
              .delete()
              .eq('id', itemId));
          debugPrint('✅ Deleted meal_item: $itemId');
        } catch (e) {
          debugPrint('❌ Error deleting meal_item $itemId: $e');
        }
      }

      if (parentMealId != null && parentMealId.isNotEmpty) {
        try {
          final remainingItems = await retryRequest(() => SupabaseConfig.client
              .from('meal_items')
              .select('id')
              .eq('meal_id', parentMealId!)
              .limit(1));

          debugPrint(
              '🔍 Remaining items in parent meal: ${remainingItems.length}');

          if (remainingItems.isEmpty) {
            await retryRequest(() => SupabaseConfig.client
                .from('meals')
                .delete()
                .eq('id', parentMealId!)
                .eq('user_id', uid));
            debugPrint('✅ Deleted empty parent meal: $parentMealId');
          }
        } catch (e) {
          debugPrint('⚠️ Error checking/removing parent meal: $e');
        }
      }

      final ds = _date.toIso8601String().split('T')[0];
      await _updateDailySummaryInBackground(uid, ds);

      _clearMealsCaches();

      await _loadGoalsOnly(_date, force: true);
      await _loadMealsOfType(meal.mealType, _date, force: true);

      notifyListeners();
      debugPrint('✅ Meal item deleted successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Delete meal item error: $e');
      debugPrint('❌ Stack trace: $stackTrace');
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

  // ============================================
  // 🔥 ОБНОВЛЕНИЕ ЦЕЛЕЙ (для конкретной даты)
  // ============================================
  Future<bool> updateGoals({
    required int protein,
    required int fat,
    required int carbs,
    required int calories,
    DateTime? date,
  }) async {
    try {
      final uid = userId;
      if (uid == null || uid.isEmpty) return false;

      final targetDate = date ?? _date;
      final ds = targetDate.toIso8601String().split('T')[0];

      debugPrint(
          '💾 Updating goals for $ds: P=$protein F=$fat C=$carbs K=$calories');

      await retryRequest(() => SupabaseConfig.client
          .from('user_goals')
          .upsert({
            'user_id': uid,
            'date': ds,
            'protein_target': protein,
            'fat_target': fat,
            'carbs_target': carbs,
            'calories_target': calories,
            'is_active': true,
          }, onConflict: 'user_id,date'));

      _cachedGoals = null;
      _goalsCacheTime = null;

      debugPrint('✅ Goals updated successfully for $ds');
      return true;
    } catch (e) {
      debugPrint('❌ Update goals error: $e');
      return false;
    }
  }
}