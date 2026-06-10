import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';

/// Сервис для управления уведомлениями
/// - Локальные уведомления (когда приложение в фоне)
/// - Сохранение FCM токенов для push (требует настройки FCM)
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Инициализация сервиса уведомлений
  /// 🔥 Безопасная инициализация — не падает если плагин не зарегистрирован
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _initialized = true;
      debugPrint('✅ NotificationService initialized');
    } catch (e, stack) {
      debugPrint('⚠️ NotificationService initialization failed: $e');
      debugPrint('Stack: $stack');
      _initialized = false;
      // 🔥 Не пробрасываем ошибку — приложение продолжит работать
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // TODO: Навигация к дневнику при тапе на уведомление
  }

  /// Показывает локальное уведомление о новом комментарии
  Future<void> showCommentNotification({
    required String trainerName,
    required String mealType,
    String? commentPreview,
  }) async {
    if (!_initialized) {
      debugPrint('⚠️ NotificationService не инициализирован');
      return;
    }

    try {
      const androidDetails = AndroidNotificationDetails(
        'comment_channel',
        'Комментарии тренера',
        channelDescription: 'Уведомления о новых комментариях от вашего тренера',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final title = '💬 Новый комментарий от $trainerName';
      final body = commentPreview != null && commentPreview.isNotEmpty
          ? '$mealType: ${commentPreview.length > 50 ? '${commentPreview.substring(0, 50)}...' : commentPreview}'
          : '$mealType: тренер оставил комментарий';

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, // уникальный ID
        title,
        body,
        details,
        payload: jsonEncode({'type': 'comment', 'mealType': mealType}),
      );
      debugPrint('🔔 Local notification shown: $title');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }

  /// Сохраняет FCM токен в БД для push-уведомлений
  Future<void> saveFcmToken(String token) async {
    try {
      final userId = SupabaseConfig.currentUserId;
      if (userId == null) return;

      await SupabaseConfig.client.from('user_tokens').upsert({
        'user_id': userId,
        'fcm_token': token,
        'device_info': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'fcm_token');

      debugPrint('✅ FCM token saved for user $userId');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Удаляет FCM токен при выходе
  Future<void> removeFcmToken(String token) async {
    try {
      await SupabaseConfig.client
          .from('user_tokens')
          .delete()
          .eq('fcm_token', token);
      debugPrint('✅ FCM token removed');
    } catch (e) {
      debugPrint('❌ Error removing FCM token: $e');
    }
  }
}