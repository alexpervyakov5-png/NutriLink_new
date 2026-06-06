import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

/// Централизованная обработка ошибок
class ErrorHandler {
  static const int _snackBarDurationSeconds = 4;

  /// Форматирует ошибку в человекочитаемое сообщение
  static String format(Object? error, {String context = ''}) {
    if (error == null) return 'Произошла непредвиденная ошибка';

    final errorStr = error.toString();

    // Сетевые ошибки
    if (error is SocketException ||
        errorStr.contains('SocketException') ||
        errorStr.contains('Network is unreachable') ||
        errorStr.contains('Connection refused') ||
        errorStr.contains('Connection timed out') ||
        errorStr.contains('Connection reset by peer') ||
        errorStr.contains('Failed host lookup')) {
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
      if (msg.contains('user already registered') ||
          msg.contains('already exists') ||
          msg.contains('duplicate key')) {
        return 'Пользователь с таким email уже зарегистрирован';
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
        case 'logout':
          return 'Ошибка выхода из аккаунта';
        case 'profile_load':
          return 'Не удалось загрузить профиль. Попробуйте снова';
        case 'profile_save':
          return 'Не удалось сохранить изменения. Попробуйте снова';
        case 'stats_load':
          return 'Не удалось загрузить статистику. Попробуйте снова';
        case 'stats_refresh':
          return 'Не удалось обновить данные. Попробуйте позже';
        case 'stats_chart':
          return 'Не удалось построить график';
        case 'measurements_load':
          return 'Не удалось загрузить замеры. Попробуйте снова';
        case 'measurements_save':
          return 'Не удалось сохранить замер. Попробуйте снова';
        case 'measurements_update':
          return 'Не удалось обновить замер';
        case 'measurements_delete':
          return 'Не удалось удалить замер';
        case 'trainer_clients_load':
          return 'Не удалось загрузить клиентов. Попробуйте снова';
        case 'trainer_clients_remove':
          return 'Не удалось удалить клиента';
        case 'password_change':
          return 'Не удалось сменить пароль. Попробуйте снова';
        case 'password_reset':
          return 'Не удалось отправить инструкцию. Попробуйте позже';
        case 'client_search':
          return 'Не удалось найти клиента';
        case 'clients':
          return 'Ошибка загрузки клиентов';
        case 'login':
          return 'Не удалось войти. Проверьте email и пароль';
        case 'signup':
          return 'Не удалось зарегистрироваться. Попробуйте снова';
      }
    }

    // По умолчанию
    return 'Произошла непредвиденная ошибка. Попробуйте снова';
  }

  /// 🔥 Получает контекст через глобальный navigatorKey
  static BuildContext? _getGlobalContext() {
    // Импортируем navigatorKey из main.dart
    // Если navigatorKey недоступен, пробуем найти через корневой элемент
    try {
      final rootElement = WidgetsBinding.instance.rootElement;
      if (rootElement != null) {
        return rootElement;
      }
    } catch (e) {
      debugPrint('⚠️ Cannot get root element: $e');
    }
    return null;
  }

  /// Показывает ошибку в SnackBar через глобальный контекст
  static void showGlobal(String message) {
    final ctx = _getGlobalContext();
    if (ctx == null) {
      debugPrint('⚠️ ErrorHandler.showGlobal: No context available for: $message');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = ScaffoldMessenger.maybeOf(ctx);
      if (messenger == null) {
        debugPrint('⚠️ ErrorHandler.showGlobal: ScaffoldMessenger not found');
        return;
      }
      
      messenger.showSnackBar(
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
          duration: const Duration(seconds: _snackBarDurationSeconds),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () => messenger.hideCurrentSnackBar(),
          ),
        ),
      );
    });
  }

  /// Показывает сообщение об успехе через глобальный контекст
  static void showSuccessGlobal(String message) {
    final ctx = _getGlobalContext();
    if (ctx == null) {
      debugPrint('⚠️ ErrorHandler.showSuccessGlobal: No context available for: $message');
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = ScaffoldMessenger.maybeOf(ctx);
      if (messenger == null) {
        debugPrint('⚠️ ErrorHandler.showSuccessGlobal: ScaffoldMessenger not found');
        return;
      }
      
      messenger.showSnackBar(
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
          duration: const Duration(seconds: _snackBarDurationSeconds),
        ),
      );
    });
  }

  /// Показывает ошибку в SnackBar (для использования внутри виджетов)
  static void show(BuildContext ctx, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = ScaffoldMessenger.maybeOf(ctx);
      if (messenger == null) {
        debugPrint('️ ErrorHandler.show: ScaffoldMessenger not found');
        return;
      }
      
      messenger.showSnackBar(
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
          duration: const Duration(seconds: _snackBarDurationSeconds),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () => messenger.hideCurrentSnackBar(),
          ),
        ),
      );
    });
  }

  /// Показывает сообщение об успехе (для использования внутри виджетов)
  static void showSuccess(BuildContext ctx, String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messenger = ScaffoldMessenger.maybeOf(ctx);
      if (messenger == null) {
        debugPrint('️ ErrorHandler.showSuccess: ScaffoldMessenger not found');
        return;
      }
      
      messenger.showSnackBar(
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
          duration: const Duration(seconds: _snackBarDurationSeconds),
        ),
      );
    });
  }
}