/// Глобальные константы приложения
class AppConstants {
  // Ограничения порций
  static const int maxPortionGrams = 10000; // 10 кг
  static const int maxCaloriesPer100g = 10000;
  
  // Параметры для streak-расчётов
  static const double streakRatioMin = 0.9;
  static const double streakRatioMax = 1.1;
  
  // Таймауты и кэширование
  static const Duration cacheDuration = Duration(minutes: 5);
  static const Duration statsCacheDuration = Duration(minutes: 3);
  static const int maxRetryAttempts = 3;
  
  // Валидация
  static const int minNameLength = 2;
  static const int minPasswordLength = 6;
  
  // UI
  static const double bottomSheetHeightRatio = 0.85;
  static const int snackBarDurationSeconds = 4;
}