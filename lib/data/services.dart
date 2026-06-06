import 'dart:async';
import 'dart:io' show SocketException;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart' 
    show SupabaseClient, PostgrestException, AuthException, AuthChangeEvent, UserAttributes;

import '../core/config.dart';
import '../core/error_handler.dart';
import 'clients_service.dart';
import 'models.dart';

// ============================================
// ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ============================================

int _toIntSafe(dynamic v, {int defaultValue = 0}) {
  if (v == null) return defaultValue;
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v) ?? defaultValue;
  return defaultValue;
}

double _toDoubleSafe(dynamic v, {double defaultValue = 0.0}) {
  if (v == null) return defaultValue;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? defaultValue;
  return defaultValue;
}

Future<T> _retryRequest<T>(Future<T> Function() request, {int maxAttempts = 3}) async {
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

UserRole _parseRoleFromId(String? roleId) {
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
  
  String? get _userId => clientsService.selectedUserId;
  
  DateTime? _lastLoaded;
  String? _lastLoadedUserId;

  bool _shouldReload({required bool force}) {
    final uid = _userId;
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

  void _onCacheLoaded() {
    _lastLoaded = DateTime.now();
    _lastLoadedUserId = _userId;
  }

  void _onClientChanged() {
    final newUserId = clientsService.selectedUserId;
    if (_lastLoadedUserId != newUserId) {
      debugPrint('🔄 ${runtimeType}: Client changed ($_lastLoadedUserId → $newUserId), clearing cache');
      _lastLoaded = null;
      _lastLoadedUserId = newUserId;
      notifyListeners();
    }
  }
}

// ============================================
// AuthService
// ============================================

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
        final d = await _retryRequest(() => _supabase
            .from('users')
            .select('username, role_id, code')
            .eq('id', u.id)
            .maybeSingle());

        _user = AuthUser(
          id: u.id,
          email: u.email ?? '',
          username: d?['username'] as String?,
          roleId: d?['role_id'] as String?,
          role: _parseRoleFromId(d?['role_id'] as String?),
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
      final result = await _retryRequest(() =>
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

      final d = await _retryRequest(() => _supabase
          .from('users')
          .select('username, role_id, code')
          .eq('id', result.user!.id)
          .maybeSingle());

      _user = AuthUser(
        id: result.user!.id,
        email: result.user!.email ?? '',
        username: d?['username'] as String?,
        roleId: d?['role_id'] as String?,
        role: _parseRoleFromId(d?['role_id'] as String?),
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
      final authResult = await _retryRequest(() =>
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
        await _retryRequest(() => _supabase.from('users').upsert({
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
          await _retryRequest(() =>
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

// ============================================
// ProfileService
// ============================================

class ProfileService extends ChangeNotifier with ClientAwareService {
  @override
  final ClientsService clientsService;
  Profile? _profile;
  bool _loading = false, _saving = false;
  String? _error;

  Profile? get profile => _profile;
  bool get loading => _loading;
  bool get saving => _saving;
  String? get error => _error;

  ProfileService(this.clientsService) {
    clientsService.addListener(_onClientChanged);
  }

  @override
  void dispose() {
    clientsService.removeListener(_onClientChanged);
    super.dispose();
  }

  @override
  void _onClientChanged() {
    super._onClientChanged();
    _profile = null;
    load(force: true);
  }

  Future<void> load({bool force = false}) async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) {
      debugPrint('⚠️ ProfileService.load: userId is empty');
      return;
    }

    if (!_shouldReload(force: force)) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('📥 Loading profile for user: $uid (force: $force)');
      final response = await _retryRequest(() => SupabaseConfig.client
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle());

      if (response == null) {
        debugPrint('⚠️ Profile not found for $uid, creating empty profile');
        _profile = Profile(
          id: uid,
          firstName: '',
          lastName: '',
          goal: GoalType.maintenance,
        );
      } else {
        _profile = Profile(
          id: response['id'] as String,
          firstName: _parseFirst(response['username']),
          lastName: _parseLast(response['username']),
          birthDate: response['date_of_birth'] != null
              ? DateTime.parse(response['date_of_birth'] as String)
              : null,
          heightCm: _toIntSafe(response['height_cm']),
          gender: response['gender'] as String?,
          goal: _parseGoal(response['goal'] as String?),
          code: response['code'] as String?,
          trainerId: response['trainer_id'] as String?,
          roleId: response['role_id'] as String?,
        );
        debugPrint('✅ Profile loaded: ${_profile!.fullName}');
      }
      _onCacheLoaded();
    } catch (e) {
      _error = ErrorHandler.format(e);
      if (e.toString().contains('JWT expired')) {
        await SupabaseConfig.signOut();
      }
      debugPrint('❌ Profile load error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> save() async {
    if (_profile == null) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final uid = _userId;
      if (uid == null || uid.isEmpty) throw Exception('Не авторизован');
      final username = '${_profile!.firstName} ${_profile!.lastName}'.trim();

      await _retryRequest(() => SupabaseConfig.client.from('users').update({
        'username': username.isEmpty ? null : username,
        'height_cm': _profile!.heightCm,
        'gender': _profile!.gender,
        'goal': _profile!.goal.toString().split('.').last,
        'date_of_birth': _profile!.birthDate?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid));

      _lastLoaded = null;
      return true;
    } catch (e) {
      _error = ErrorHandler.format(e);
      debugPrint('❌ Profile save error: $e');
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    try {
      await SupabaseConfig.client.auth
          .updateUser(UserAttributes(password: newPassword));
      return true;
    } catch (e) {
      _error = 'Ошибка смены пароля: $e';
      notifyListeners();
      return false;
    }
  }

  Future<Profile?> findClientByCode(String code) async {
    try {
      final response = await _retryRequest(() => SupabaseConfig.client
          .from('users')
          .select('id, username, email, code, role_id, trainer_id')
          .eq('code', code.toUpperCase().trim())
          .maybeSingle());

      if (response == null) return null;

      final roleId = response['role_id'] as String?;
      final isClient = roleId == SupabaseConfig.clientRoleId;

      if (!isClient) return null;

      return Profile(
        id: response['id'] as String,
        firstName: _parseFirst(response['username']),
        lastName: _parseLast(response['username']),
        birthDate: null,
        heightCm: null,
        gender: null,
        goal: GoalType.maintenance,
        code: response['code'] as String?,
        trainerId: response['trainer_id'] as String?,
        roleId: roleId,
      );
    } catch (e) {
      debugPrint('❌ Find client by code error: $e');
      return null;
    }
  }

  Future<bool> addClientToTrainer(String trainerId, String clientId) async {
    try {
      await _retryRequest(() => SupabaseConfig.client
          .from('users')
          .update({
            'trainer_id': trainerId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', clientId));
      return true;
    } catch (e) {
      debugPrint('❌ Add client to trainer error: $e');
      return false;
    }
  }

  Future<bool> removeClientFromTrainer(String clientId) async {
    try {
      await _retryRequest(() => SupabaseConfig.client
          .from('users')
          .update({
            'trainer_id': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', clientId));
      return true;
    } catch (e) {
      debugPrint('❌ Remove client from trainer error: $e');
      return false;
    }
  }

  Future<List<Profile>> getTrainerClients(String trainerId) async {
    try {
      final response = await _retryRequest(() => SupabaseConfig.client
          .from('users')
          .select('id, username, email, code, role_id, trainer_id')
          .eq('trainer_id', trainerId)
          .order('username', ascending: true));

      return response.map((item) => Profile(
        id: item['id'] as String,
        firstName: _parseFirst(item['username']),
        lastName: _parseLast(item['username']),
        birthDate: null,
        heightCm: null,
        gender: null,
        goal: GoalType.maintenance,
        code: item['code'] as String?,
        trainerId: item['trainer_id'] as String?,
        roleId: item['role_id'] as String?,
      )).toList();
    } catch (e) {
      debugPrint('❌ Get trainer clients error: $e');
      return [];
    }
  }

  void update(Profile Function(Profile) fn) {
    if (_profile != null) {
      _profile = fn(_profile!);
      notifyListeners();
    }
  }

  String _parseFirst(dynamic v) =>
      v == null ? '' : v.toString().trim().split(' ').first;

  String _parseLast(dynamic v) {
    final n = v.toString().trim();
    return n.isEmpty
        ? ''
        : (n.split(' ').length > 1
            ? n.split(' ').skip(1).join(' ')
            : '');
  }

  GoalType _parseGoal(String? v) => v == null
      ? GoalType.maintenance
      : GoalType.values.firstWhere(
          (e) => e.toString().split('.').last == v,
          orElse: () => GoalType.maintenance,
        );
}

// ============================================
// DiaryService
// ============================================

class DiaryService extends ChangeNotifier with ClientAwareService {
  @override
  final ClientsService clientsService;
  final _uuid = const Uuid();
  DailyGoals? _goals = const DailyGoals.empty();

  final Map<MealType, List<Meal>> _meals = {
    for (var t in MealType.values) t: [],
  };
  final Map<MealType, DateTime?> _mealsCacheTime = {
    for (var t in MealType.values) t: null,
  };
  final Map<MealType, bool> _expanded = {
    MealType.breakfast: true,
    MealType.lunch: true,
    MealType.dinner: false,
    MealType.snack: false,
  };

  final Map<MealType, String?> _typeComments = {};
  String? getCommentForType(MealType type) => _typeComments[type];

  DateTime _date = DateTime.now();
  bool _loading = false;
  bool _loadingGoals = false;
  String? _error;
  
  // 🔥 ОПТИМИЗАЦИЯ: Debounce для обновления daily_summary
  Timer? _summaryUpdateTimer;

  DiaryService(this.clientsService) {
    clientsService.addListener(_onClientChanged);
  }

  @override
  void dispose() {
    _summaryUpdateTimer?.cancel();
    clientsService.removeListener(_onClientChanged);
    super.dispose();
  }

  @override
  void _onClientChanged() {
    super._onClientChanged();
    for (var t in MealType.values) {
      _mealsCacheTime[t] = null;
    }
    _goals = null;
    notifyListeners();
    refresh();
  }

  DailyGoals? get goals => _goals;
  Map<MealType, List<Meal>> get meals => _meals;
  Map<MealType, bool> get expanded => _expanded;
  DateTime get date => _date;
  bool get loading => _loading;
  bool get loadingGoals => _loadingGoals;
  String? get error => _error;

  Future<void> _loadGoalsOnly(DateTime d) async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    final ds = d.toIso8601String().split('T')[0];

    try {
      final [sum, gol] = await Future.wait([
        _retryRequest(() => SupabaseConfig.client
            .from('daily_summary')
            .select('protein_actual, fat_actual, carbs_actual, calories_actual')
            .eq('user_id', uid)
            .eq('date', ds)
            .maybeSingle()),
        _retryRequest(() => SupabaseConfig.client
            .from('user_goals')
            .select('protein_target, fat_target, carbs_target, calories_target')
            .eq('user_id', uid)
            .eq('is_active', true)
            .maybeSingle()),
      ]);
      _goals = DailyGoals(
        proteinTarget: _toIntSafe(gol?['protein_target'], defaultValue: 100),
        fatsTarget: _toIntSafe(gol?['fat_target'], defaultValue: 65),
        carbsTarget: _toIntSafe(gol?['carbs_target'], defaultValue: 285),
        caloriesTarget: _toIntSafe(gol?['calories_target'], defaultValue: 2500),
        proteinCurrent: _toIntSafe(sum?['protein_actual']),
        fatsCurrent: _toIntSafe(sum?['fat_actual']),
        carbsCurrent: _toIntSafe(sum?['carbs_actual']),
        caloriesCurrent: _toIntSafe(sum?['calories_actual']),
      );
    } catch (e) {
      debugPrint('❌ Goals load error: $e');
      if (e.toString().contains('JWT expired')) {
        await SupabaseConfig.signOut();
      }
      _goals = const DailyGoals.empty();
    }
  }

  Future<void> _loadMealsOfType(MealType type, DateTime d) async {
    _mealsCacheTime[type] = null;
    final uid = _userId;
    if (uid == null || uid.isEmpty) return;
    final ds = d.toIso8601String().split('T')[0];

    try {
      final mealsData = await _retryRequest(() => SupabaseConfig.client
          .from('meals')
          .select(
              'id, meal_type, eaten_at, comment, meal_items(id, amount_grams, product_id, product_name, calories, protein, fat, carbs)')
          .eq('user_id', uid)
          .eq('meal_type', type.dbValue)
          .eq('date', ds)
          .order('eaten_at', ascending: false));

      _meals[type] = mealsData.map((j) {
        final items = j['meal_items'] as List? ?? [];
        final comment = j['comment'] as String?;

        if (items.isEmpty) {
          if (comment != null && comment.isNotEmpty) {
            _typeComments[type] = comment;
          }
          return null;
        }

        int w = 0, c = 0, p = 0, f = 0, cb = 0;
        String? nm;
        for (var it in items) {
          w += _toIntSafe(it['amount_grams']);
          c += _toIntSafe(it['calories']);
          p += _toIntSafe(it['protein']);
          f += _toIntSafe(it['fat']);
          cb += _toIntSafe(it['carbs']);
          nm ??= it['product_name'] as String?;
        }
        return Meal(
          id: j['id'] as String,
          name: nm ?? 'Блюдо',
          weight: '${w}г',
          calories: c,
          protein: p,
          fats: f,
          carbs: cb,
          mealType: type,
          createdAt: DateTime.parse(j['eaten_at'] as String),
          comment: comment,
        );
      }).whereType<Meal>().toList();
    } catch (e) {
      debugPrint('Meals load error ($type): $e');
      if (e.toString().contains('JWT expired')) {
        await SupabaseConfig.signOut();
      }
    }
  }

  Future<void> load(DateTime d, {MealType? loadMealsOfType, bool force = false}) async {
    _date = d;
    
    if (_shouldReload(force: force)) {
      for (var t in MealType.values) {
        _mealsCacheTime[t] = null;
      }
    }

    _loadingGoals = true;
    notifyListeners();
    try {
      await _loadGoalsOnly(d);
    } finally {
      _loadingGoals = false;
      notifyListeners();
    }

    if (loadMealsOfType != null || force) {
      _loading = true;
      notifyListeners();
      try {
        if (force) {
          await Future.wait(MealType.values.map((t) => _loadMealsOfType(t, d)));
        } else if (loadMealsOfType != null) {
          await _loadMealsOfType(loadMealsOfType, d);
        }
      } finally {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() async => await load(_date, force: true);

  void ensureMealsLoaded(MealType type) {
    _loadMealsOfType(type, _date).then((_) => notifyListeners());
  }

  Future<List<Product>> getProducts(String query) async {
    try {
      var q = SupabaseConfig.client.from('products').select('id,name,calories,protein,fat,carbs,user_id');
      if (query.isNotEmpty) {
        q = q.ilike('name', '%$query%');
      }
      final uid = _userId;
      if (uid == null) return [];
      final response = await _retryRequest(() =>
          q.or('user_id.is.null,user_id.eq.$uid').limit(50));
      return response.map((j) => Product.fromJson(j)).toList();
    } catch (e) {
      debugPrint('❌ Get products error: $e');
      if (e.toString().contains('JWT expired')) {
        await SupabaseConfig.signOut();
      }
      return [];
    }
  }

  Future<Product?> createProduct(
      String name, double cal, double pro, double fat, double carb) async {
    try {
      final uid = _userId;
      if (uid == null) return null;
      final res = await _retryRequest(() =>
          SupabaseConfig.client.from('products').insert({
            'name': name,
            'calories': cal,
            'protein': pro,
            'fat': fat,
            'carbs': carb,
            'user_id': uid,
          }).select('id,name,calories,protein,fat,carbs,user_id').single());
      return Product.fromJson(res);
    } catch (e) {
      debugPrint('❌ Create product error: $e');
      return null;
    }
  }

  Future<bool> updateProduct({
    required String id,
    required String name,
    required double cal,
    required double pro,
    required double fat,
    required double carb,
  }) async {
    try {
      await _retryRequest(() => SupabaseConfig.client.from('products').update({
        'name': name,
        'calories': cal,
        'protein': pro,
        'fat': fat,
        'carbs': carb,
      }).eq('id', id));
      return true;
    } catch (e) {
      debugPrint('❌ Update product error: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      await _retryRequest(() =>
          SupabaseConfig.client.from('products').delete().eq('id', productId));
      return true;
    } catch (e) {
      debugPrint('❌ Delete product error: $e');
      return false;
    }
  }

  Future<List<dynamic>> getAllFoodItems(String query) async {
    try {
      final uid = _userId;
      if (uid == null) return [];

      var productsQuery = SupabaseConfig.client
          .from('products')
          .select('id,name,calories,protein,fat,carbs,user_id');
      if (query.isNotEmpty) {
        productsQuery = productsQuery.ilike('name', '%$query%');
      }
      final productsResponse = await _retryRequest(() => productsQuery
          .or('user_id.is.null,user_id.eq.$uid')
          .limit(50));
      final products = productsResponse.map((j) => Product.fromJson(j)).toList();

      var recipesQuery = SupabaseConfig.client.from('recipes').select(
          'id,name,description,base_weight_grams,total_calories,total_protein,total_fat,total_carbs,created_by,recipe_products(amount_grams,product_id,products(id,name,calories,protein,fat,carbs,user_id))');
      if (query.isNotEmpty) {
        recipesQuery = recipesQuery.ilike('name', '%$query%');
      }
      final recipesResponse = await _retryRequest(() => recipesQuery
          .or('created_by.is.null,created_by.eq.$uid')
          .limit(50));
      final recipes = recipesResponse.map((j) {
        final ingredients = (j['recipe_products'] as List? ?? []).map((rp) {
          return RecipeIngredient(
            product: Product.fromJson(rp['products']),
            amountGrams: (rp['amount_grams'] as num).toDouble(),
          );
        }).toList();
        return Recipe.fromJson(j, ingredients);
      }).toList();

      final all = [...products, ...recipes];
      all.sort((a, b) {
        final nameA = a is Product ? a.name : (a is Recipe ? a.name : '');
        final nameB = b is Product ? b.name : (b is Recipe ? b.name : '');
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });
      return all;
    } catch (e) {
      debugPrint('❌ Get all food items error: $e');
      return [];
    }
  }

  Future<Recipe?> createRecipe({
    required String name,
    String description = '',
    required List<RecipeIngredient> ingredients,
  }) async {
    try {
      final uid = _userId;
      if (uid == null) return null;

      double baseWeight = 0;
      double totalCal = 0;
      double totalPro = 0;
      double totalFat = 0;
      double totalCarb = 0;

      for (var ing in ingredients) {
        baseWeight += ing.amountGrams;
        double ratio = ing.amountGrams / 100.0;
        totalCal += ing.product.calories * ratio;
        totalPro += ing.product.protein * ratio;
        totalFat += ing.product.fat * ratio;
        totalCarb += ing.product.carbs * ratio;
      }

      final recipeRes = await _retryRequest(() =>
          SupabaseConfig.client.from('recipes').insert({
            'name': name,
            'description': description,
            'base_weight_grams': baseWeight,
            'total_calories': totalCal,
            'total_protein': totalPro,
            'total_fat': totalFat,
            'total_carbs': totalCarb,
            'created_by': uid,
          }).select('id').single());

      final recipeId = recipeRes['id'] as String;

      if (ingredients.isNotEmpty) {
        final productIds = ingredients.map((ing) => ing.product.id).toList();
        final accessible = await _retryRequest(() => SupabaseConfig.client
            .from('products')
            .select('id')
            .inFilter('id', productIds)
            .or('user_id.is.null,user_id.eq.$uid'));

        if (accessible.length != productIds.length) {
          throw Exception('Не все продукты доступны для добавления в рецепт');
        }

        await _retryRequest(() =>
            SupabaseConfig.client.from('recipe_products').insert(
              ingredients
                  .map((ing) => {
                        'recipe_id': recipeId,
                        'product_id': ing.product.id,
                        'amount_grams': ing.amountGrams,
                      })
                  .toList(),
            ));
      }

      return Recipe(
        id: recipeId,
        name: name,
        description: description,
        baseWeightGrams: baseWeight,
        totalCalories: totalCal,
        totalProtein: totalPro,
        totalFat: totalFat,
        totalCarbs: totalCarb,
        userId: uid,
        ingredients: ingredients,
      );
    } on PostgrestException catch (e) {
      debugPrint('❌ Create recipe PostgrestException: $e');
      if (e.message.contains('row-level security')) {
        _error = 'Ошибка прав доступа. Проверьте настройки RLS в Supabase для таблицы recipe_products.';
      } else {
        _error = 'Ошибка базы данных: ${e.message}';
      }
      notifyListeners();
      return null;
    } on SocketException catch (e) {
      debugPrint('❌ Create recipe network error: $e');
      _error = 'Проблема с соединением. Проверьте интернет и попробуйте снова.';
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('❌ Create recipe error: $e');
      _error = 'Ошибка: $e';
      notifyListeners();
      return null;
    }
  }

  // 🔥 ОПТИМИЗИРОВАННЫЙ МЕТОД ДОБАВЛЕНИЯ ПРОДУКТА
  Future<bool> _addMealItemCore({
    required MealType type,
    required String productName,
    required int calories,
    required int protein,
    required int fat,
    required int carbs,
    required double portionGrams,
    required String dateStr,
    String? comment,
    String? productId,
  }) async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) throw Exception('Не авторизован');

    try {
      // 🔥 ОПТИМИЗАЦИЯ 1: Используем upsert вместо select + insert/update
      final mealResult = await _retryRequest(() => SupabaseConfig.client
          .from('meals')
          .upsert({
            'user_id': uid,
            'meal_type': type.dbValue,
            'date': dateStr,
            'eaten_at': DateTime.now().toIso8601String(),
            if (comment != null && comment.isNotEmpty) 'comment': comment,
          }, onConflict: 'user_id,date,meal_type')
          .select('id')
          .single());

      final mealId = mealResult['id'] as String;

      // 🔥 ОПТИМИЗАЦИЯ 2: Добавляем meal_item
      await _retryRequest(() => SupabaseConfig.client.from('meal_items').insert({
        'meal_id': mealId,
        'product_id': productId,
        'product_name': productName,
        'amount_grams': portionGrams,
        'calories': calories,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
      }));

      // 🔥 Обновляем UI сразу
      _mealsCacheTime[type] = null;
      final newMeal = Meal(
        id: _uuid.v4(),
        name: productName,
        weight: '${portionGrams.toInt()}г',
        calories: calories,
        protein: protein,
        fats: fat,
        carbs: carbs,
        mealType: type,
        createdAt: DateTime.now(),
        comment: comment,
      );
      if (_meals[type] != null) {
        _meals[type] = [..._meals[type]!, newMeal];
      }
      if (_goals != null) {
        _goals = _goals!.copyWith(
          caloriesCurrent: _goals!.caloriesCurrent + calories,
          proteinCurrent: _goals!.proteinCurrent + protein,
          fatsCurrent: _goals!.fatsCurrent + fat,
          carbsCurrent: _goals!.carbsCurrent + carbs,
        );
      }
      notifyListeners();

      // 🔥 ОПТИМИЗАЦИЯ 3: Обновляем daily_summary В ФОНЕ (не блокируем)
      _scheduleSummaryUpdate(uid, dateStr);

      return true;
    } catch (e) {
      debugPrint('❌ _addMealItemCore error: $e');
      rethrow;
    }
  }

  // 🔥 ОПТИМИЗАЦИЯ 4: Debounce для обновления daily_summary
  void _scheduleSummaryUpdate(String uid, String dateStr) {
    _summaryUpdateTimer?.cancel();
    _summaryUpdateTimer = Timer(const Duration(milliseconds: 500), () {
      _updateDailySummaryInBackground(uid, dateStr).catchError((e) {
        debugPrint('⚠️ Background daily summary update failed: $e');
      });
    });
  }

  Future<void> _updateDailySummaryInBackground(String uid, String dateStr) async {
    try {
      final meals = await _retryRequest(() => SupabaseConfig.client
          .from('meals')
          .select('meal_items(calories, protein, fat, carbs)')
          .eq('user_id', uid)
          .eq('date', dateStr));

      int c = 0, p = 0, f = 0, cb = 0;
      for (var m in meals) {
        final items = m['meal_items'] as List? ?? [];
        for (var it in items) {
          c += _toIntSafe(it['calories']);
          p += _toIntSafe(it['protein']);
          f += _toIntSafe(it['fat']);
          cb += _toIntSafe(it['carbs']);
        }
      }

      await _retryRequest(() => SupabaseConfig.client.from('daily_summary').upsert({
        'user_id': uid,
        'date': dateStr,
        'calories_actual': c,
        'protein_actual': p,
        'fat_actual': f,
        'carbs_actual': cb,
      }, onConflict: 'user_id,date'), maxAttempts: 2);
    } catch (e) {
      debugPrint('❌ _updateDailySummaryInBackground error: $e');
      rethrow;
    }
  }

  Future<bool> addFoodItemToMeal({
    required MealType type,
    required dynamic item,
    required double portionGrams,
    String? comment,
  }) async {
    try {
      final ds = _date.toIso8601String().split('T')[0];

      int cal, pro, fat, cb;
      String itemName;
      String? productId;

      if (item is Product) {
        double ratio = portionGrams / 100.0;
        cal = (item.calories * ratio).round();
        pro = (item.protein * ratio).round();
        fat = (item.fat * ratio).round();
        cb = (item.carbs * ratio).round();
        itemName = item.name;
        productId = item.id;
      } else if (item is Recipe) {
        double scale = portionGrams / item.baseWeightGrams;
        cal = (item.totalCalories * scale).round();
        pro = (item.totalProtein * scale).round();
        fat = (item.totalFat * scale).round();
        cb = (item.totalCarbs * scale).round();
        itemName = '🍳 ${item.name}';
      } else {
        throw Exception('Unknown food item type: ${item.runtimeType}');
      }

      return await _addMealItemCore(
        type: type,
        productName: itemName,
        calories: cal,
        protein: pro,
        fat: fat,
        carbs: cb,
        portionGrams: portionGrams,
        dateStr: ds,
        comment: comment,
        productId: productId,
      );
    } catch (e) {
      debugPrint('❌ Add food item error: $e');
      return false;
    }
  }

  Future<bool> updateComment({
    required MealType type,
    required DateTime date,
    String? comment,
  }) async {
    try {
      final uid = _userId;
      if (uid == null || uid.isEmpty) return false;
      final ds = date.toIso8601String().split('T')[0];
      final trimmed = comment?.trim().isEmpty == true ? null : comment?.trim();

      _typeComments[type] = trimmed;
      if (_meals[type]!.isNotEmpty && trimmed != null) {
        final updated = List<Meal>.from(_meals[type]!);
        updated[0] = updated[0].copyWith(comment: trimmed);
        _meals[type] = updated;
      }
      notifyListeners();

      final existing = await _retryRequest(() => SupabaseConfig.client
          .from('meals')
          .select('id')
          .eq('user_id', uid)
          .eq('date', ds)
          .eq('meal_type', type.dbValue)
          .maybeSingle());

      if (existing == null) {
        await SupabaseConfig.client.from('meals').insert({
          'id': _uuid.v4(),
          'user_id': uid,
          'meal_type': type.dbValue,
          'date': ds,
          'eaten_at': DateTime.now().toIso8601String(),
          'comment': trimmed,
        });
      } else {
        await SupabaseConfig.client
            .from('meals')
            .update({'comment': trimmed})
            .eq('id', existing['id'] as String);
      }
      return true;
    } catch (e) {
      debugPrint('❌ updateComment error: $e');
      return false;
    }
  }

  Future<bool> add({
    required MealType type,
    String? pid,
    required String pname,
    required String w,
    required int cal,
    required int pro,
    required int fat,
    required int cb,
    String? comment,
  }) async {
    try {
      final ds = _date.toIso8601String().split('T')[0];
      final weightValue = int.parse(w.replaceAll(RegExp(r'\D'), ''));
      if (weightValue <= 0) throw Exception('Вес > 0');

      return await _addMealItemCore(
        type: type,
        productName: pname,
        calories: cal,
        protein: pro,
        fat: fat,
        carbs: cb,
        portionGrams: weightValue.toDouble(),
        dateStr: ds,
        comment: comment,
        productId: pid,
      );
    } catch (e) {
      debugPrint('❌ Add meal error: $e');
      return false;
    }
  }

  Future<bool> delete(String mealId, MealType type) async {
    try {
      final uid = _userId;
      if (uid == null || uid.isEmpty) throw Exception('Не авторизован');

      final items = await SupabaseConfig.client
          .from('meal_items')
          .select('calories, protein, fat, carbs')
          .eq('meal_id', mealId);

      int totalCal = 0, totalPro = 0, totalFat = 0, totalCarb = 0;
      for (var item in items) {
        totalCal += _toIntSafe(item['calories']);
        totalPro += _toIntSafe(item['protein']);
        totalFat += _toIntSafe(item['fat']);
        totalCarb += _toIntSafe(item['carbs']);
      }

      await SupabaseConfig.client
          .from('meal_items')
          .delete()
          .eq('meal_id', mealId);
      await SupabaseConfig.client
          .from('meals')
          .delete()
          .eq('id', mealId)
          .eq('user_id', uid);

      final ds = _date.toIso8601String().split('T')[0];
      await _updateDailySummaryInBackground(uid, ds);

      _mealsCacheTime[type] = null;
      await _loadGoalsOnly(_date);
      await _loadMealsOfType(type, _date);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      return false;
    }
  }

  void toggle(MealType t) {
    _expanded[t] = !(_expanded[t] ?? false);
    if (_expanded[t] == true) {
      ensureMealsLoaded(t);
    }
    notifyListeners();
  }
}

// ============================================
// MeasurementsService
// ============================================

class MeasurementsService extends ChangeNotifier with ClientAwareService {
  @override
  final ClientsService clientsService;
  final _uuid = const Uuid();
  List<Measurement> _list = [];
  bool _loading = false;
  String? _error;

  MeasurementsService(this.clientsService) {
    clientsService.addListener(_onClientChanged);
  }

  @override
  void dispose() {
    clientsService.removeListener(_onClientChanged);
    super.dispose();
  }

  @override
  void _onClientChanged() {
    super._onClientChanged();
    _list.clear();
    notifyListeners();
    load(force: true);
  }

  List<Measurement> get list => _list;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) {
      debugPrint('⚠️ MeasurementsService.load: userId is empty');
      return;
    }

    if (!_shouldReload(force: force)) return;

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      debugPrint('📥 Loading measurements for user: $uid (force: $force)');
      final data = await _retryRequest(() => SupabaseConfig.client
          .from('body_measurements')
          .select()
          .eq('user_id', uid)
          .order('measured_at', ascending: false)
          .limit(50));
      _list = data.map((j) => Measurement.fromJson(j)).toList();
      _onCacheLoaded();
      debugPrint('✅ Loaded ${_list.length} measurements for $uid');
    } catch (e) {
      _error = ErrorHandler.format(e);
      if (e.toString().contains('JWT expired')) {
        await SupabaseConfig.signOut();
      }
      debugPrint('❌ Measurements load error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> save({
    required DateTime at,
    double? w,
    double? ch,
    double? wa,
    double? hi,
  }) async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) return false;
    try {
      final m = Measurement(
        id: _uuid.v4(),
        userId: uid,
        measuredAt: at,
        weightKg: w,
        chestCm: ch,
        waistCm: wa,
        hipsCm: hi,
      );
      await _retryRequest(() =>
          SupabaseConfig.client.from('body_measurements').insert(m.toJson()));
      _list.insert(0, m);
      _list.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
      _lastLoaded = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = ErrorHandler.format(e);
      debugPrint('❌ Measurements save error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> update({
    required String id,
    required DateTime at,
    double? w,
    double? ch,
    double? wa,
    double? hi,
  }) async {
    try {
      final data = <String, dynamic>{
        'measured_at': at.toIso8601String(),
        if (w != null) 'weight_kg': w,
        if (ch != null) 'chest_cm': ch,
        if (wa != null) 'waist_cm': wa,
        if (hi != null) 'hips_cm': hi,
      };
      if (data.isEmpty) return true;

      await _retryRequest(() => SupabaseConfig.client
          .from('body_measurements')
          .update(data)
          .eq('id', id));

      final i = _list.indexWhere((m) => m.id == id);
      if (i != -1) {
        _list[i] = _list[i].copyWith(
          measuredAt: at,
          weightKg: w,
          chestCm: ch,
          waistCm: wa,
          hipsCm: hi,
        );
        notifyListeners();
      }
      return true;
    } catch (e) {
      _error = ErrorHandler.format(e);
      debugPrint('❌ Measurements update error: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _retryRequest(() =>
          SupabaseConfig.client.from('body_measurements').delete().eq('id', id));
      _list.removeWhere((m) => m.id == id);
      _lastLoaded = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = ErrorHandler.format(e);
      debugPrint('❌ Measurements delete error: $e');
      notifyListeners();
      return false;
    }
  }
}

// ============================================
// StatsService
// ============================================

class StatsService extends ChangeNotifier with ClientAwareService {
  @override
  final ClientsService clientsService;
  StatsData? _stats;
  bool _loading = false, _refreshing = false;
  String? _error;
  DateTime _start = DateTime.now().subtract(const Duration(days: 30));
  DateTime _end = DateTime.now();

  StatsService(this.clientsService) {
    clientsService.addListener(_onClientChanged);
  }

  @override
  void dispose() {
    clientsService.removeListener(_onClientChanged);
    super.dispose();
  }

  @override
  void _onClientChanged() {
    super._onClientChanged();
    _stats = null;
    notifyListeners();
    load(force: true);
  }

  StatsData? get stats => _stats;
  bool get loading => _loading;
  bool get refreshing => _refreshing;
  String? get error => _error;
  DateTime get startDate => _start;
  DateTime get endDate => _end;

  Future<void> load({DateTime? start, DateTime? end, bool force = false}) async {
    final uid = _userId;
    if (uid == null || uid.isEmpty) {
      debugPrint('⚠️ StatsService.load: userId is empty');
      return;
    }

    if (!_shouldReload(force: force)) return;

    if (start != null) _start = start;
    if (end != null) _end = end;

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      debugPrint('📊 Loading stats for user: $uid (force: $force)');
      final s = _start.toIso8601String().split('T')[0];
      final e = _end.toIso8601String().split('T')[0];

      final [nutr, measurements] = await Future.wait([
        _retryRequest(() => SupabaseConfig.client
            .from('daily_summary')
            .select('protein_actual, fat_actual, carbs_actual, calories_actual')
            .eq('user_id', uid)
            .gte('date', s)
            .lte('date', e)),
        _retryRequest(() => SupabaseConfig.client
            .from('body_measurements')
            .select('measured_at, weight_kg, chest_cm, waist_cm, hips_cm')
            .eq('user_id', uid)
            .gte('measured_at', _start.toIso8601String())
            .lte('measured_at', _end.toIso8601String())
            .order('measured_at', ascending: true)),
      ]);

      int tp = 0, tf = 0, tc = 0, tk = 0;
      for (final r in nutr) {
        tp += _toIntSafe(r['protein_actual']);
        tf += _toIntSafe(r['fat_actual']);
        tc += _toIntSafe(r['carbs_actual']);
        tk += _toIntSafe(r['calories_actual']);
      }
      final ns = NutritionStats.fromMacros(protein: tp, fats: tf, carbs: tc, calories: tk);

      List<TrendPoint> weightTrend = [],
          chestTrend = [],
          waistTrend = [],
          hipsTrend = [];
      for (final row in measurements) {
        final date = DateTime.parse(row['measured_at'] as String);
        if (row['weight_kg'] != null)
          weightTrend.add(TrendPoint(date: date, value: _toDoubleSafe(row['weight_kg'])));
        if (row['chest_cm'] != null)
          chestTrend.add(TrendPoint(date: date, value: _toDoubleSafe(row['chest_cm'])));
        if (row['waist_cm'] != null)
          waistTrend.add(TrendPoint(date: date, value: _toDoubleSafe(row['waist_cm'])));
        if (row['hips_cm'] != null)
          hipsTrend.add(TrendPoint(date: date, value: _toDoubleSafe(row['hips_cm'])));
      }

      _stats = StatsData(
        nutrition: ns,
        weightTrend: weightTrend,
        chestTrend: chestTrend,
        waistTrend: waistTrend,
        hipsTrend: hipsTrend,
        streakDays: await _streak(uid, e),
      );
      _onCacheLoaded();
      debugPrint('✅ Stats loaded for $uid');
    } catch (e) {
      _error = ErrorHandler.format(e);
      if (e.toString().contains('JWT expired')) {
        await SupabaseConfig.signOut();
      }
      debugPrint('❌ Stats load error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _refreshing = true;
    notifyListeners();
    await load(force: true);
    _refreshing = false;
    notifyListeners();
  }

  Future<int> _streak(String uid, String end) async {
    try {
      final r = await _retryRequest(() => SupabaseConfig.client
          .from('daily_summary')
          .select('calories_actual')
          .eq('user_id', uid)
          .order('date', ascending: false)
          .limit(30));
      if (r.isEmpty) return 0;

      final g = await _retryRequest(() => SupabaseConfig.client
          .from('user_goals')
          .select('calories_target')
          .eq('user_id', uid)
          .eq('is_active', true)
          .maybeSingle());
      final target = g != null
          ? _toIntSafe(g['calories_target'], defaultValue: 2500)
          : 2500;

      int streak = 0;
      for (final row in r) {
        final act = _toIntSafe(row['calories_actual']);
        final ratio = target > 0 ? act / target : 0;
        if (ratio >= 0.9 && ratio <= 1.1) {
          streak++;
        } else {
          break;
        }
      }
      return streak;
    } catch (_) {
      return 0;
    }
  }
}