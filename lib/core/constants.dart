import 'package:flutter/material.dart';
import '../core/config.dart';
// 🔥 УБРАЛИ: import '../core/constants.dart'; — не используется

class InputValidator {
  // Диапазоны значений
  static const int minAge = 14;
  static const int maxAge = 100;
  static const int minWeight = 30;
  static const int maxWeight = 300;
  static const int minHeight = 100;
  static const int maxHeight = 250;
  
  // Для целей (goals)
  static const int minCalories = 800;
  static const int maxCalories = 4000;
  static const int minProtein = 20;
  static const int maxProtein = 500;
  static const int minFat = 20;
  static const int maxFat = 400;
  static const int minCarbs = 50;
  static const int maxCarbs = 800;
  
  // Для замеров (measurements)
  static const int minChest = 50;
  static const int maxChest = 200;
  static const int minWaist = 40;
  static const int maxWaist = 200;
  static const int minHips = 50;
  static const int maxHips = 200;

  /// Запрос подтверждения при выходе за рамки
  static Future<bool?> showOutOfRangeConfirmation({
    required BuildContext context,
    required String fieldName,
    required dynamic value,
    required String unit,
    required int min,
    required int max,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange,
          size: 48,
        ),
        title: Text(
          'Значение вне диапазона',
          style: TextStyle(color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        content: Text(
          'Вы ввели $value $unit для поля "$fieldName".\n\n'
          'Рекомендуемый диапазон: $min–$max $unit.\n\n'
          'Вы уверены, что хотите использовать это значение?',
          style: TextStyle(color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, false);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textHint,
            ),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.black,
            ),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
  }

  /// Валидация с подтверждением для целых чисел
  static Future<bool> validateIntWithConfirmation({
    required BuildContext context,
    required int value,
    required String fieldName,
    required String unit,
    required int min,
    required int max,
  }) async {
    if (value < min || value > max) {
      final confirmed = await showOutOfRangeConfirmation(
        context: context,
        fieldName: fieldName,
        value: value,
        unit: unit,
        min: min,
        max: max,
      );
      return confirmed == true;
    }
    return true;
  }

  /// Валидация с подтверждением для чисел с плавающей точкой
  static Future<bool> validateDoubleWithConfirmation({
    required BuildContext context,
    required double value,
    required String fieldName,
    required String unit,
    required double min,
    required double max,
  }) async {
    if (value < min || value > max) {
      final confirmed = await showOutOfRangeConfirmation(
        context: context,
        fieldName: fieldName,
        value: value.toStringAsFixed(1),
        unit: unit,
        min: min.toInt(),
        max: max.toInt(),
      );
      return confirmed == true;
    }
    return true;
  }

  // ============================================
  // ВАЛИДАЦИЯ ПРОФИЛЯ
  // ============================================
  
  /// Валидация возраста
  static Future<bool> validateAge({
    required BuildContext context,
    required int age,
  }) {
    return validateIntWithConfirmation(
      context: context,
      value: age,
      fieldName: 'Возраст',
      unit: 'лет',
      min: minAge,
      max: maxAge,
    );
  }

  /// Валидация роста
  static Future<bool> validateHeight({
    required BuildContext context,
    required int height,
  }) {
    return validateIntWithConfirmation(
      context: context,
      value: height,
      fieldName: 'Рост',
      unit: 'см',
      min: minHeight,
      max: maxHeight,
    );
  }

  // ============================================
  // ВАЛИДАЦИЯ ЦЕЛЕЙ (GOALS)
  // ============================================
  
  /// Валидация калорий
  static Future<bool> validateCalories({
    required BuildContext context,
    required int calories,
  }) {
    return validateIntWithConfirmation(
      context: context,
      value: calories,
      fieldName: 'Калории',
      unit: 'ккал',
      min: minCalories,
      max: maxCalories,
    );
  }

  /// Валидация белков
  static Future<bool> validateProtein({
    required BuildContext context,
    required int protein,
  }) {
    return validateIntWithConfirmation(
      context: context,
      value: protein,
      fieldName: 'Белки',
      unit: 'г',
      min: minProtein,
      max: maxProtein,
    );
  }

  /// Валидация жиров
  static Future<bool> validateFat({
    required BuildContext context,
    required int fat,
  }) {
    return validateIntWithConfirmation(
      context: context,
      value: fat,
      fieldName: 'Жиры',
      unit: 'г',
      min: minFat,
      max: maxFat,
    );
  }

  /// Валидация углеводов
  static Future<bool> validateCarbs({
    required BuildContext context,
    required int carbs,
  }) {
    return validateIntWithConfirmation(
      context: context,
      value: carbs,
      fieldName: 'Углеводы',
      unit: 'г',
      min: minCarbs,
      max: maxCarbs,
    );
  }

  // ============================================
  // ВАЛИДАЦИЯ ЗАМЕРОВ (MEASUREMENTS)
  // ============================================
  
  /// Валидация веса
  static Future<bool> validateWeight({
    required BuildContext context,
    required double weight,
  }) {
    return validateDoubleWithConfirmation(
      context: context,
      value: weight,
      fieldName: 'Вес',
      unit: 'кг',
      min: minWeight.toDouble(),
      max: maxWeight.toDouble(),
    );
  }

  /// Валидация груди
  static Future<bool> validateChest({
    required BuildContext context,
    required double chest,
  }) {
    return validateDoubleWithConfirmation(
      context: context,
      value: chest,
      fieldName: 'Грудь',
      unit: 'см',
      min: minChest.toDouble(),
      max: maxChest.toDouble(),
    );
  }

  /// Валидация талии
  static Future<bool> validateWaist({
    required BuildContext context,
    required double waist,
  }) {
    return validateDoubleWithConfirmation(
      context: context,
      value: waist,
      fieldName: 'Талия',
      unit: 'см',
      min: minWaist.toDouble(),
      max: maxWaist.toDouble(),
    );
  }

  /// Валидация бедер
  static Future<bool> validateHips({
    required BuildContext context,
    required double hips,
  }) {
    return validateDoubleWithConfirmation(
      context: context,
      value: hips,
      fieldName: 'Бедра',
      unit: 'см',
      min: minHips.toDouble(),
      max: maxHips.toDouble(),
    );
  }
}