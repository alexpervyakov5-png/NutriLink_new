import 'dart:io' show SocketException;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' 
    show SupabaseClient, PostgrestException, AuthException, AuthChangeEvent;

import '../core/config.dart';
import '../core/error_handler.dart';
import 'services.dart';
import 'models.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = SupabaseConfig.client;

  AuthUser? _user;
  bool _loading = false;
  String? _error;

  AuthUser? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuth => _user != null;

  AuthService() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        _user = null;
        notifyListeners();
      }
    });
  }

  Future<void> checkSession() async {
    _loading = true;
    notifyListeners();
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final u = _supabase.auth.currentUser;
      if (u != null) {
        final d = await retryRequest(() => _supabase
            .from('users')
            .select('username, role_id, code')
            .eq('id', u.id)
            .maybeSingle());

        _user = AuthUser(
          id: u.id,
          email: u.email ?? '',
          username: d?['username'] as String?,
          roleId: d?['role_id'] as String?,
          role: parseRoleFromId(d?['role_id'] as String?),
          code: d?['code'] as String?,
        );
      }
    } catch (e) {
      _error = ErrorHandler.format(e, context: 'session');
      debugPrint('❌ checkSession error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _mapAuthError(String message) {
    final msg = message.toLowerCase();
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
        msg.contains('already exists')) {
      return 'Пользователь с таким email уже зарегистрирован';
    }
    return 'Ошибка авторизации: $message';
  }

  Future<bool> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final result = await retryRequest(() =>
          _supabase.auth.signInWithPassword(
            email: email.trim(),
            password: password,
          ));

      if (result.user == null) {
        _error = 'Неверный email или пароль';
        _loading = false;
        notifyListeners();
        return false;
      }

      final d = await retryRequest(() => _supabase
          .from('users')
          .select('username, role_id, code')
          .eq('id', result.user!.id)
          .maybeSingle());

      _user = AuthUser(
        id: result.user!.id,
        email: result.user!.email ?? '',
        username: d?['username'] as String?,
        roleId: d?['role_id'] as String?,
        role: parseRoleFromId(d?['role_id'] as String?),
        code: d?['code'] as String?,
      );

      _loading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      debugPrint('SignIn AuthException: ${e.message} (code: ${e.code})');
      _error = _mapAuthError(e.message);
      _loading = false;
      notifyListeners();
      return false;
    } on SocketException catch (e) {
      debugPrint('SignIn SocketException: $e');
      _error = 'Нет подключения к интернету';
      _loading = false;
      notifyListeners();
      return false;
    } catch (e, stack) {
      debugPrint('SignIn Unknown Error: $e');
      debugPrint('Stack: $stack');
      _error = 'Ошибка подключения';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    required UserRole role,
  }) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔐 [1/5] SignUp started: $email as $role');

      String? roleId;
      if (role == UserRole.trainer) {
        roleId = SupabaseConfig.trainerRoleId ??
            await SupabaseConfig.getTrainerRoleId();
      } else {
        roleId = SupabaseConfig.clientRoleId ??
            await SupabaseConfig.getClientRoleId();
      }

      if (roleId == null) {
        _error = 'Ошибка: не удалось определить роль';
        debugPrint('❌ [1/5] roleId is null');
        _loading = false;
        notifyListeners();
        return false;
      }
      debugPrint('✅ [1/5] roleId: $roleId');

      debugPrint('👤 [2/5] Creating auth user...');
      final authResult = await retryRequest(() =>
          _supabase.auth.signUp(
            email: email.trim(),
            password: password,
            data: {'username': username, 'role_id': roleId},
          ));

      if (authResult.user == null) {
        _error = 'Ошибка: не удалось создать аккаунт в Auth';
        debugPrint('❌ [2/5] Auth user creation failed');
        _loading = false;
        notifyListeners();
        return false;
      }
      final userId = authResult.user!.id;
      debugPrint('✅ [2/5] Auth user created: $userId');

      debugPrint('📝 [3/5] Creating public.users record...');
      try {
        await retryRequest(() => _supabase.from('users').upsert({
          'id': userId,
          'username': username,
          'email': email.trim(),
          'role_id': roleId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'id'));
        debugPrint('✅ [3/5] public.users record created');
      } catch (e) {
        debugPrint('⚠️ [3/5] Could not create public.users: $e');
      }

      if (role == UserRole.trainer) {
        debugPrint('🎯 [4/5] Creating trainer goals...');
        try {
          await retryRequest(() =>
              _supabase.from('user_goals').insert({
                'user_id': userId,
                'calories_target': 2500,
                'protein_target': 150,
                'fat_target': 80,
                'carbs_target': 280,
                'is_active': true,
              }));
          debugPrint('✅ [4/5] Goals created');
        } catch (e) {
          debugPrint('⚠️ [4/5] Could not create goals: $e');
        }
      }

      String? userCode;
      try {
        final codeData = await _supabase
            .from('users')
            .select('code')
            .eq('id', userId)
            .maybeSingle();
        userCode = codeData?['code'] as String?;
        debugPrint('✅ [5/5] User code: $userCode');
      } catch (e) {
        debugPrint('⚠️ [5/5] Could not load user code: $e');
      }

      _user = AuthUser(
        id: userId,
        email: authResult.user!.email ?? '',
        username: username,
        roleId: roleId,
        role: role,
        code: userCode,
      );

      debugPrint('✅ [5/5] SignUp completed: ${_user?.email}');
      _loading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      debugPrint('❌ AuthException: ${e.message} (code: ${e.code})');
      _error = _mapAuthError(e.message);
    } on PostgrestException catch (e) {
      debugPrint('❌ PostgrestException: ${e.message}');
      debugPrint('   Details: ${e.details}');
      debugPrint('   Hint: ${e.hint}');
      final detailsStr = e.details?.toString() ?? '';
      if (e.message.contains('duplicate') ||
          e.message.contains('unique')) {
        _error = detailsStr.contains('email')
            ? 'Email уже зарегистрирован'
            : 'Имя пользователя занято';
      } else if (e.message.contains('role_id') ||
          e.message.contains('foreign key')) {
        _error = 'Ошибка: не удалось определить роль';
      } else {
        _error = 'Ошибка базы данных: ${e.message}';
      }
    } on SocketException {
      _error = 'Нет подключения к интернету';
    } catch (e, stack) {
      debugPrint('❌ Unexpected error: $e');
      debugPrint('Stack: $stack');
      _error = 'Произошла ошибка: $e';
    }

    _loading = false;
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ SignOut error: $e');
    }
  }
}