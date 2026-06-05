import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';

enum UserRole { client, trainer }
enum GoalType { weightLoss, maintenance, muscleGain }
enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeExt on MealType {
  String get label => switch (this) {
        MealType.breakfast => 'Завтрак',
        MealType.lunch => 'Обед',
        MealType.dinner => 'Ужин',
        MealType.snack => 'Перекус',
      };
  String get dbValue => switch (this) {
        MealType.breakfast => 'breakfast',
        MealType.lunch => 'lunch',
        MealType.dinner => 'dinner',
        MealType.snack => 'snack',
      };
}

class AuthUser extends Equatable {
  final String id, email;
  final String? username;
  final UserRole role;
  final String? roleId;
  final String? code;  // 🔥 НОВОЕ ПОЛЕ
  final DateTime? createdAt;

  const AuthUser({
    required this.id,
    required this.email,
    this.username,
    this.role = UserRole.client,
    this.roleId,
    this.code,
    this.createdAt,
  });

  AuthUser copyWith({
    String? id,
    String? email,
    String? username,
    UserRole? role,
    String? roleId,
    String? code,
    DateTime? createdAt,
  }) {
    return AuthUser(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      role: role ?? this.role,
      roleId: roleId ?? this.roleId,
      code: code ?? this.code,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, email, username, role, roleId, code, createdAt];
}

class Profile extends Equatable {
  final String? id;
  final String firstName, lastName;
  final DateTime? birthDate;
  final int? heightCm;
  final String? gender;
  final GoalType goal;
  final String? code;  // 🔥 НОВОЕ ПОЛЕ
  final String? trainerId;
  final String? roleId;

  Profile({
    this.id,
    required this.firstName,
    required this.lastName,
    this.birthDate,
    this.heightCm,
    this.gender,
    required this.goal,
    this.code,
    this.trainerId,
    this.roleId,
  });

  Profile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    DateTime? birthDate,
    int? heightCm,
    String? gender,
    GoalType? goal,
    String? code,
    String? trainerId,
    String? roleId,
  }) =>
      Profile(
        id: id ?? this.id,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        birthDate: birthDate ?? this.birthDate,
        heightCm: heightCm ?? this.heightCm,
        gender: gender ?? this.gender,
        goal: goal ?? this.goal,
        code: code ?? this.code,
        trainerId: trainerId ?? this.trainerId,
        roleId: roleId ?? this.roleId,
      );

  String get fullName => '$firstName $lastName'.trim();

  @override
  List<Object?> get props =>
      [id, firstName, lastName, birthDate, heightCm, gender, goal, code, trainerId, roleId];
}

class DailyGoals extends Equatable {
  final int proteinTarget, fatsTarget, carbsTarget, caloriesTarget;
  final int proteinCurrent, fatsCurrent, carbsCurrent, caloriesCurrent;

  const DailyGoals({
    required this.proteinTarget,
    required this.fatsTarget,
    required this.carbsTarget,
    required this.caloriesTarget,
    required this.proteinCurrent,
    required this.fatsCurrent,
    required this.carbsCurrent,
    required this.caloriesCurrent,
  });

  const DailyGoals.empty()
      : proteinTarget = 100,
        fatsTarget = 65,
        carbsTarget = 285,
        caloriesTarget = 2500,
        proteinCurrent = 0,
        fatsCurrent = 0,
        carbsCurrent = 0,
        caloriesCurrent = 0;

  DailyGoals copyWith({
    int? proteinTarget,
    int? fatsTarget,
    int? carbsTarget,
    int? caloriesTarget,
    int? proteinCurrent,
    int? fatsCurrent,
    int? carbsCurrent,
    int? caloriesCurrent,
  }) =>
      DailyGoals(
        proteinTarget: proteinTarget ?? this.proteinTarget,
        fatsTarget: fatsTarget ?? this.fatsTarget,
        carbsTarget: carbsTarget ?? this.carbsTarget,
        caloriesTarget: caloriesTarget ?? this.caloriesTarget,
        proteinCurrent: proteinCurrent ?? this.proteinCurrent,
        fatsCurrent: fatsCurrent ?? this.fatsCurrent,
        carbsCurrent: carbsCurrent ?? this.carbsCurrent,
        caloriesCurrent: caloriesCurrent ?? this.caloriesCurrent,
      );

  @override
  List<Object?> get props => [
        proteinTarget,
        fatsTarget,
        carbsTarget,
        caloriesTarget,
        proteinCurrent,
        fatsCurrent,
        carbsCurrent,
        caloriesCurrent,
      ];
}

class Meal extends Equatable {
  final String id, name, weight;
  final int calories, protein, fats, carbs;
  final MealType mealType;
  final DateTime createdAt;
  final String? comment;

  const Meal({
    required this.id,
    required this.name,
    required this.weight,
    required this.calories,
    required this.protein,
    required this.fats,
    required this.carbs,
    required this.mealType,
    required this.createdAt,
    this.comment,
  });

  Meal copyWith({
    String? id,
    String? name,
    String? weight,
    int? calories,
    int? protein,
    int? fats,
    int? carbs,
    MealType? mealType,
    DateTime? createdAt,
    String? comment,
  }) =>
      Meal(
        id: id ?? this.id,
        name: name ?? this.name,
        weight: weight ?? this.weight,
        calories: calories ?? this.calories,
        protein: protein ?? this.protein,
        fats: fats ?? this.fats,
        carbs: carbs ?? this.carbs,
        mealType: mealType ?? this.mealType,
        createdAt: createdAt ?? this.createdAt,
        comment: comment ?? this.comment,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        weight,
        calories,
        protein,
        fats,
        carbs,
        mealType,
        createdAt,
        comment,
      ];
}

class Measurement extends Equatable {
  final String id, userId;
  final DateTime measuredAt;
  final double? weightKg, chestCm, waistCm, hipsCm;

  const Measurement({
    required this.id,
    required this.userId,
    required this.measuredAt,
    this.weightKg,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
  });

  Measurement copyWith({
    String? id,
    String? userId,
    DateTime? measuredAt,
    double? weightKg,
    double? chestCm,
    double? waistCm,
    double? hipsCm,
  }) =>
      Measurement(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        measuredAt: measuredAt ?? this.measuredAt,
        weightKg: weightKg ?? this.weightKg,
        chestCm: chestCm ?? this.chestCm,
        waistCm: waistCm ?? this.waistCm,
        hipsCm: hipsCm ?? this.hipsCm,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'measured_at': measuredAt.toIso8601String(),
        'weight_kg': weightKg,
        'chest_cm': chestCm,
        'waist_cm': waistCm,
        'hips_cm': hipsCm,
      };

  factory Measurement.fromJson(Map<String, dynamic> json) => Measurement(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        measuredAt: DateTime.parse(json['measured_at'] as String),
        weightKg: _toDouble(json['weight_kg']),
        chestCm: _toDouble(json['chest_cm']),
        waistCm: _toDouble(json['waist_cm']),
        hipsCm: _toDouble(json['hips_cm']),
      );

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  @override
  List<Object?> get props =>
      [id, userId, measuredAt, weightKg, chestCm, waistCm, hipsCm];
}

class NutritionStats extends Equatable {
  final int protein, fats, carbs, calories;
  final double proteinPercent, fatsPercent, carbsPercent;

  const NutritionStats({
    required this.protein,
    required this.fats,
    required this.carbs,
    required this.calories,
    required this.proteinPercent,
    required this.fatsPercent,
    required this.carbsPercent,
  });

  factory NutritionStats.fromMacros({
    required int protein,
    required int fats,
    required int carbs,
    required int calories,
  }) {
    final total = protein + fats + carbs;
    return NutritionStats(
      protein: protein,
      fats: fats,
      carbs: carbs,
      calories: calories,
      proteinPercent: total > 0 ? (protein / total * 100) : 0,
      fatsPercent: total > 0 ? (fats / total * 100) : 0,
      carbsPercent: total > 0 ? (carbs / total * 100) : 0,
    );
  }

  @override
  List<Object?> get props =>
      [protein, fats, carbs, calories, proteinPercent, fatsPercent, carbsPercent];
}

class TrendPoint extends Equatable {
  final DateTime date;
  final double value;
  const TrendPoint({required this.date, required this.value});
  @override List<Object?> get props => [date, value];
}

class StatsData extends Equatable {
  final NutritionStats nutrition;
  final List<TrendPoint> weightTrend;
  final List<TrendPoint> chestTrend;
  final List<TrendPoint> waistTrend;
  final List<TrendPoint> hipsTrend;
  final int streakDays;

  const StatsData({
    required this.nutrition,
    required this.weightTrend,
    required this.chestTrend,
    required this.waistTrend,
    required this.hipsTrend,
    this.streakDays = 0,
  });

  @override
  List<Object?> get props => [
        nutrition,
        weightTrend,
        chestTrend,
        waistTrend,
        hipsTrend,
        streakDays,
      ];
}

class Product extends Equatable {
  final String id;
  final String name;
  final double calories;
  final double protein;
  final double fat;
  final double carbs;
  final String? userId;

  const Product({
    required this.id,
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.userId,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      calories: (json['calories'] as num).toDouble(),
      protein: (json['protein'] as num).toDouble(),
      fat: (json['fat'] as num).toDouble(),
      carbs: (json['carbs'] as num).toDouble(),
      userId: json['user_id'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, name, calories, protein, fat, carbs, userId];
}

class RecipeIngredient extends Equatable {
  final Product product;
  final double amountGrams;
  const RecipeIngredient({required this.product, required this.amountGrams});
  @override List<Object?> get props => [product, amountGrams];
}

class Recipe extends Equatable {
  final String id, name, description;
  final double baseWeightGrams;
  final double totalCalories, totalProtein, totalFat, totalCarbs;
  final String? userId;
  final List<RecipeIngredient> ingredients;

  const Recipe({
    required this.id,
    required this.name,
    this.description = '',
    required this.baseWeightGrams,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalFat,
    required this.totalCarbs,
    this.userId,
    this.ingredients = const [],
  });

  double get caloriesPer100g => baseWeightGrams > 0 ? (totalCalories / baseWeightGrams) * 100 : 0;
  double get proteinPer100g => baseWeightGrams > 0 ? (totalProtein / baseWeightGrams) * 100 : 0;
  double get fatPer100g => baseWeightGrams > 0 ? (totalFat / baseWeightGrams) * 100 : 0;
  double get carbsPer100g => baseWeightGrams > 0 ? (totalCarbs / baseWeightGrams) * 100 : 0;

  factory Recipe.fromJson(Map<String, dynamic> json,
      [List<RecipeIngredient> ingredients = const []]) {
    return Recipe(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      baseWeightGrams: (json['base_weight_grams'] as num).toDouble(),
      totalCalories: (json['total_calories'] as num).toDouble(),
      totalProtein: (json['total_protein'] as num).toDouble(),
      totalFat: (json['total_fat'] as num).toDouble(),
      totalCarbs: (json['total_carbs'] as num).toDouble(),
      userId: json['created_by'] as String?,
      ingredients: ingredients,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        description,
        baseWeightGrams,
        totalCalories,
        totalProtein,
        totalFat,
        totalCarbs,
        userId,
        ingredients,
      ];
}