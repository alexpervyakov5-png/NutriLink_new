import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static String get url => const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://exbzeuakjfulhzasxiyr.supabase.co',
  );
  static String get anonKey => const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV4YnpldWFramZ1bGh6YXN4aXlyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1NDE3MjQsImV4cCI6MjA5MzExNzcyNH0.PgY8qpE_K40JRrrpK9sijqCFaDz2ktdbclvEJ0k6diY',
  );
  static bool _init = false;

  // 🔥 Кэширование ID ролей для быстрого сравнения
  static String? _clientRoleId;
  static String? _trainerRoleId;

  static Future<void> initialize() async {
    if (_init) return;
    await Supabase.initialize(
      url: url, 
      anonKey: anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce, 
        autoRefreshToken: true,
      ),
      debug: true,
    );
    
    // 🔥 Загружаем ID ролей один раз при старте
    await _loadRoleIds();
    
    await Future.delayed(const Duration(milliseconds: 300));
    _init = true;
  }

  // 🔥 Приватный метод загрузки ролей из БД
  static Future<void> _loadRoleIds() async {
    try {
      final roles = await client
          .from('user_roles')
          .select('id, name')
          .inFilter('name', ['client', 'trainer']);
          
      for (final r in roles) {
        if (r['name'] == 'client') _clientRoleId = r['id'] as String;
        if (r['name'] == 'trainer') _trainerRoleId = r['id'] as String;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load role IDs: $e');
      // Fallback: если не загрузились, сравнение по ID работать не будет,
      // но приложение не упадёт — роль определится как client по умолчанию.
    }
  }

  // 🔥 Публичные геттеры для использования в сервисах
  static String? get clientRoleId => _clientRoleId;
  static String? get trainerRoleId => _trainerRoleId;

  static SupabaseClient get client {
    if (!_init) throw Exception('Supabase не инициализирован');
    return Supabase.instance.client;
  }
  
  static String? get currentUserId => client.auth.currentUser?.id;
  static bool get isAuthorized => currentUserId != null;
  static Future<void> signOut() async => await client.auth.signOut();
}

class AppColors {
  static const Color background = Color(0xFF2F2F2F);
  static const Color backgroundSecondary = Color(0xFF3F3F3F);
  static const Color card = Color(0xFF4A4A4A);
  static const Color accent = Color(0xFF69BDA0);
  // ✅ ИСПРАВЛЕНО: правильный ARGB формат (alpha первый)
  static const Color accentTransparent = Color(0xB369BDA0);
  static const Color accentLight = Color(0xFFC3F7CE);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textHint = Colors.white54;
  static const Color progressProtein = Colors.green;
  static const Color progressFats = Colors.red;
  static const Color progressCarbs = Colors.orange;
  static const Color progressCalories = Colors.yellow;
}

class AppStrings {
  static const String appName = 'NutriLink';
  static const String assetIcons = 'assets/icons/';
  static const String assetImages = 'assets/images/';
}