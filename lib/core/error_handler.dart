import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

/// Централизованная обработка ошибок
class ErrorHandler {
  // Локальные константы для независимости от AppConstants
  static const int _snackBarDurationSeconds = 4;
  static const double _streakRatioMin = 0.9;
  static const double _streakRatioMax = 1.1;

  /// Форматирует ошибку в человекочитаемое сообщение
  static String format(Object? error, {String context = ''}) {
    if (error == null) return 'Произошла непредвиденная ошибка';

    final errorStr = error.toString();

    // Сетевые ошибки
    if (error is SocketException ||
        errorStr.contains('SocketException') ||
        errorStr.contains('Network is unreachable') ||
        errorStr.contains('Connection refused') ||
        errorStr.contains('Connection timed out')) {
      return 'Нет подключения к интернету. Проверьте соединение';
    }

    // Ошибки базы данных / Supabase
    if (errorStr.contains('PostgrestException') ||
        errorStr.contains('database') ||
        error is PostgrestException) {
      if (errorStr.contains('JWT expired') ||
          errorStr.contains('token expired')) {
        return 'Сессия истекла. Пожалуйста, войдите снова';
      }
      if (errorStr.contains('duplicate') || errorStr.contains('unique')) {
        return 'Такая запись уже существует';
      }
      if (errorStr.contains('row-level security') ||
          errorStr.contains('RLS')) {
        return 'Ошибка прав доступа. Обратитесь к поддержке';
      }
      return 'Ошибка сохранения данных. Попробуйте позже';
    }

    // Ошибки авторизации
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid login credentials') ||
          msg.contains('invalid credentials') ||
          msg.contains('user not found') ||
          msg.contains('wrong password')) {
        return 'Неверный email или пароль';
      }
      if (msg.contains('email not confirmed')) {
        return 'Подтвердите ваш email. Проверьте почту';
      }
      if (msg.contains('rate limit')) {
        return 'Слишком много попыток. Попробуйте позже';
      }
      if (msg.contains('weak password')) {
        return 'Пароль слишком слабый. Минимум 6 символов';
      }
      return 'Ошибка авторизации: ${error.message}';
    }

    // Строковые ошибки
    if (error is String) return error;

    // Контекстно-зависимые сообщения
    if (context.isNotEmpty) {
      switch (context) {
        case 'product':
          return 'Не удалось создать продукт. Попробуйте снова';
        case 'recipe':
          return 'Не удалось создать рецепт. Попробуйте снова';
        case 'meal':
          return 'Не удалось добавить приём пищи. Попробуйте снова';
        case 'comment':
          return 'Не удалось сохранить комментарий';
        case 'search':
          return 'Не удалось загрузить результаты поиска';
        case 'session':
          return 'Ошибка сессии. Пожалуйста, войдите снова';
      }
    }

    // По умолчанию
    return 'Произошла непредвиденная ошибка. Попробуйте снова';
  }

  /// Показывает ошибку в SnackBar
  static void show(BuildContext ctx, String message) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: _snackBarDurationSeconds),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(ctx).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  /// Показывает сообщение об успехе
  static void showSuccess(BuildContext ctx, String message) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(message,
                    style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: _snackBarDurationSeconds),
      ),
    );
  }
}