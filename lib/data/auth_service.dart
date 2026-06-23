import 'dart:io' show SocketException;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' 
    show SupabaseClient, PostgrestException, AuthException, AuthChangeEvent, OtpType;

import '../core/config.dart';
import '../core/error_handler.dart';
import 'services.dart';
import 'models.dart';

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = SupabaseConfig.client;

  AuthUser? _user;
  bool _loading = false;
  String? _error;
  
  // 🔥 НОВОЕ: флаг, что регистрация прошла, но email не подтверждён
  bool _pendingEmailConfirmation = false;
  String? _pendingEmail;

  AuthUser? get user => _user;
  bool get loading => _loading;
  String? get error => _error;
  bool get isAuth => _user != null;
  bool get pendingEmailConfirmation => _pendingEmailConfirmation;
  String? get pendingEmail => _pendingEmail;

  AuthService() {
    _supabase.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        _user = null;
        _pendingEmailConfirmation = false;
        _pendingEmail = null;
        notifyListeners();
      }
      // 🔥 НОВОЕ: обработка подтверждения email через deep link
      if (data.event == AuthChangeEvent.userUpdated) {
        debugPrint('✅ User updated (email confirmed?)');
      }
    });
  }

  Future<void> checkSession() async {
    _loading = true;
    notifyListeners();
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      final u = _supabase.auth.currentUser;
      
      // 🔥 Если пользователь есть, но email не подтверждён — не пускаем
      if (u != null && u.emailConfirmedAt == null) {
        debugPrint('⚠️ User exists but email not confirmed: ${u.email}');
        _pendingEmailConfirmation = true;
        _pendingEmail = u.email;
        _loading = false;
        notifyListeners();
        return;
      }
      
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
        _pendingEmailConfirmation = false;
        _pendingEmail = null;
      }
    } catch (e) {
      _error = ErrorHandler.format(e, context: 'session');
      debugPrint('❌ checkSession error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// 🔥 Расширенный маппинг ошибок Supabase
  String _mapAuthError(String message) {
    final msg = message.toLowerCase();
    debugPrint('🔍 Маппинг ошибки: "$message"');

    if (msg.contains('email not confirmed') || msg.contains('email not confirmed')) {
      return 'Подтвердите ваш email. Проверьте почту';
    }
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials') ||
        msg.contains('user not found') ||
        msg.contains('wrong password') ||
        msg.contains('invalid email') ||
        msg.contains('identity not found')) {
      return 'Неверный email или пароль';
    }
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Слишком много попыток. Попробуйте позже';
    }
    if (msg.contains('weak password') ||
        msg.contains('password is too weak')) {
      return 'Пароль слишком слабый. Минимум 6 символов';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already exists') ||
        msg.contains('duplicate') ||
        msg.contains('already registered') ||
        msg.contains('unique constraint')) {
      return 'Пользователь с таким email уже зарегистрирован';
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
      return 'Нет подключения к интернету';
    }
    if (msg.contains('timeout')) {
      return 'Время ожидания истекло. Попробуйте снова';
    }
    if (msg.contains('jwt') || msg.contains('token expired') || msg.contains('session')) {
      return 'Сессия истекла. Пожалуйста, войдите снова';
    }
    return 'Ошибка авторизации. Проверьте введённые данные';
  }

  Future<bool> signIn(String email, String password) async {
    _loading = true;
    _error = null;
    _pendingEmailConfirmation = false;
    _pendingEmail = null;
    notifyListeners();

    try {
      debugPrint('🔐 SignIn attempt: $email');
      final result = await retryRequest(() =>
          _supabase.auth.signInWithPassword(
            email: email.trim(),
            password: password,
          ));

      if (result.user == null) {
        debugPrint('❌ SignIn: result.user is null');
        _error = 'Неверный email или пароль';
        _loading = false;
        notifyListeners();
        return false;
      }

      // 🔥 Проверка подтверждения email при входе
      if (result.user!.emailConfirmedAt == null) {
        debugPrint('⚠️ Email not confirmed for: ${result.user!.email}');
        _pendingEmailConfirmation = true;
        _pendingEmail = result.user!.email;
        _error = 'email_not_confirmed'; // Специальный маркер для UI
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

      debugPrint('✅ SignIn success: ${_user?.email}');
      _loading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      debugPrint('SignIn AuthException: ${e.message} (code: ${e.code})');
      
      // 🔥 Специальная обработка ошибки "email not confirmed"
      if (e.message.toLowerCase().contains('email not confirmed')) {
        _pendingEmailConfirmation = true;
        _pendingEmail = email.trim();
        _error = 'email_not_confirmed';
      } else {
        _error = _mapAuthError(e.message);
      }
      
      debugPrint('🔔 Установлена ошибка: $_error');
      _loading = false;
      notifyListeners();
      return false;
    } on SocketException catch (e) {
      debugPrint('SignIn SocketException: $e');
      _error = 'Нет подключения к интернету';
      _loading = false;
      notifyListeners();
      return false;
    } on PostgrestException catch (e) {
      debugPrint('SignIn PostgrestException: ${e.message}');
      _error = ErrorHandler.format(e, context: 'login');
      _loading = false;
      notifyListeners();
      return false;
    } catch (e, stack) {
      debugPrint('SignIn Unknown Error: $e');
      debugPrint('Stack: $stack');
      _error = ErrorHandler.format(e, context: 'login');
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // 🔥 РЕГИСТРАЦИЯ С ПОДТВЕРЖДЕНИЕМ EMAIL
  // ============================================
  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    required UserRole role,
  }) async {
    _loading = true;
    _error = null;
    _pendingEmailConfirmation = false;
    _pendingEmail = null;
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

      debugPrint('👤 [2/5] Creating auth user with email confirmation...');
      
      // 🔥 ВАЖНО: добавляем emailRedirectTo для deep link
      final authResult = await retryRequest(() =>
          _supabase.auth.signUp(
            email: email.trim(),
            password: password,
            emailRedirectTo: 'nutrilink://auth/callback',
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

      // 🔥 ВАЖНО: НЕ создаём запись в public.users сразу!
      // Она создастся автоматически после подтверждения email через триггер.
      // Но если у вас уже есть триггер на создание — можно оставить upsert.
      
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
                'calories_target': 0,
                'protein_target': 0,
                'fat_target': 0,
                'carbs_target': 0,
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

      // 🔥 ВАЖНО: НЕ устанавливаем _user, пока email не подтверждён
      // Вместо этого устанавливаем флаг pendingEmailConfirmation
      _pendingEmailConfirmation = true;
      _pendingEmail = email.trim();
      
      debugPrint('✅ [5/5] SignUp completed. Waiting for email confirmation: $email');
      _loading = false;
      notifyListeners();
      
      // 🔥 Возвращаем true, чтобы UI показал экран подтверждения
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

  // ============================================
  // 🔥 ПОВТОРНАЯ ОТПРАВКА ПИСЬМА ПОДТВЕРЖДЕНИЯ
  // ============================================
  Future<bool> resendConfirmationEmail(String email) async {
    try {
      debugPrint('📧 Resending confirmation email to: $email');
      
      await retryRequest(() => _supabase.auth.resend(
        type: OtpType.signup,
        email: email.trim(),
        emailRedirectTo: 'nutrilink://auth/callback',
      ));
      
      debugPrint('✅ Confirmation email resent');
      return true;
    } on AuthException catch (e) {
      debugPrint('❌ Resend confirmation error: ${e.message}');
      _error = _mapAuthError(e.message);
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('❌ Resend confirmation unknown error: $e');
      _error = 'Не удалось отправить письмо. Попробуйте позже';
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // 🔥 СБРОС СОСТОЯНИЯ ПОДТВЕРЖДЕНИЯ
  // ============================================
  void clearPendingConfirmation() {
    _pendingEmailConfirmation = false;
    _pendingEmail = null;
    _error = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      _user = null;
      _pendingEmailConfirmation = false;
      _pendingEmail = null;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ SignOut error: $e');
    }
  }
}