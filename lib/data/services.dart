import 'dart:async';
import 'dart:io' show SocketException;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' 
    show PostgrestException;

import '../core/config.dart';
import 'clients_service.dart';
import 'models.dart';

// ============================================
// ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ============================================

int toIntSafe(dynamic v, {int defaultValue = 0}) {
  if (v == null) return defaultValue;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v) ?? defaultValue;
  return defaultValue;
}

double toDoubleSafe(dynamic v, {double defaultValue = 0.0}) {
  if (v == null) return defaultValue;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? defaultValue;
  return defaultValue;
}

Future<T> retryRequest<T>(Future<T> Function() request, {int maxAttempts = 3}) async {
  int attempt = 0;
  while (attempt < maxAttempts) {
    try {
      return await request();
    } on SocketException catch (e) {
      attempt++;
      debugPrint('⚠️ Network error (attempt $attempt/$maxAttempts): $e');
      if (attempt == maxAttempts) rethrow;
      await Future.delayed(Duration(milliseconds: 500 * attempt));
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST303' && e.message.contains('JWT expired')) {
        await SupabaseConfig.signOut();
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
  throw Exception('Failed after $maxAttempts attempts');
}

UserRole parseRoleFromId(String? roleId) {
  if (roleId == null) return UserRole.client;
  if (roleId == SupabaseConfig.trainerRoleId) return UserRole.trainer;
  if (roleId == SupabaseConfig.clientRoleId) return UserRole.client;
  return UserRole.client;
}

// ============================================
// БАЗОВЫЙ СЕРВИС С ПОДДЕРЖКОЙ КЛИЕНТОВ
// ============================================

mixin ClientAwareService on ChangeNotifier {
  ClientsService get clientsService;
  
  String? get userId => clientsService.selectedUserId;
  
  DateTime? _lastLoaded;
  String? _lastLoadedUserId;

  bool shouldReload({required bool force}) {
    final uid = userId;
    if (uid == null || uid.isEmpty) return false;
    
    if (_lastLoadedUserId != uid) {
      debugPrint('🔄 ${runtimeType}: User changed ($_lastLoadedUserId → $uid) - FORCING RELOAD');
      _lastLoadedUserId = uid;
      return true;
    }
    
    if (!force &&
        _lastLoaded != null &&
        DateTime.now().difference(_lastLoaded!) < const Duration(minutes: 5)) {
      debugPrint('📋 ${runtimeType}: using cached data for $uid');
      return false;
    }
    
    return true;
  }

  void onCacheLoaded() {
    _lastLoaded = DateTime.now();
    _lastLoadedUserId = userId;
  }

  void onClientChanged() {
    final newUserId = clientsService.selectedUserId;
    if (_lastLoadedUserId != newUserId) {
      debugPrint('🔄 ${runtimeType}: Client changed ($_lastLoadedUserId → $newUserId), clearing cache');
      _lastLoaded = null;
      _lastLoadedUserId = newUserId;
      notifyListeners();
    }
  }
}