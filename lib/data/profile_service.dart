import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;

import '../core/config.dart';
import '../core/error_handler.dart';
import 'services.dart';
import 'clients_service.dart';
import 'models.dart';

/// ProfileService работает с выбранным пользователем через ClientsService.
/// Для HomeScreen это позволяет показывать данные тренера ИЛИ клиента.
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
    clientsService.addListener(onClientChanged);
  }

  @override
  void dispose() {
    clientsService.removeListener(onClientChanged);
    super.dispose();
  }

  @override
  void onClientChanged() {
    super.onClientChanged();
    _profile = null;
    load(force: true);
  }

  Future<void> load({bool force = false}) async {
    final uid = userId;
    if (uid == null || uid.isEmpty) {
      debugPrint('⚠️ ProfileService.load: userId is empty');
      return;
    }

    if (!shouldReload(force: force)) return;

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('📥 Loading profile for user: $uid (force: $force)');
      final response = await retryRequest(() => SupabaseConfig.client
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
          heightCm: toIntSafe(response['height_cm']),
          gender: response['gender'] as String?,
          goal: _parseGoal(response['goal'] as String?),
          code: response['code'] as String?,
          trainerId: response['trainer_id'] as String?,
          roleId: response['role_id'] as String?,
        );
        debugPrint('✅ Profile loaded: ${_profile!.fullName}');
      }
      onCacheLoaded();
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

  /// 🔥 Загружает профиль КОНКРЕТНОГО пользователя (для ProfileScreen тренера)
  Future<Profile?> loadOwnProfile() async {
    final uid = SupabaseConfig.currentUserId;
    if (uid == null || uid.isEmpty) return null;

    try {
      final response = await retryRequest(() => SupabaseConfig.client
          .from('users')
          .select()
          .eq('id', uid)
          .maybeSingle());

      if (response == null) return null;

      return Profile(
        id: response['id'] as String,
        firstName: _parseFirst(response['username']),
        lastName: _parseLast(response['username']),
        birthDate: response['date_of_birth'] != null
            ? DateTime.parse(response['date_of_birth'] as String)
            : null,
        heightCm: toIntSafe(response['height_cm']),
        gender: response['gender'] as String?,
        goal: _parseGoal(response['goal'] as String?),
        code: response['code'] as String?,
        trainerId: response['trainer_id'] as String?,
        roleId: response['role_id'] as String?,
      );
    } catch (e) {
      debugPrint('❌ Load own profile error: $e');
      return null;
    }
  }

  Future<bool> save() async {
    if (_profile == null) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final uid = userId;
      if (uid == null || uid.isEmpty) throw Exception('Не авторизован');
      final username = '${_profile!.firstName} ${_profile!.lastName}'.trim();

      await retryRequest(() => SupabaseConfig.client.from('users').update({
        'username': username.isEmpty ? null : username,
        'height_cm': _profile!.heightCm,
        'gender': _profile!.gender,
        'goal': _profile!.goal.toString().split('.').last,
        'date_of_birth': _profile!.birthDate?.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', uid));

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
      final response = await retryRequest(() => SupabaseConfig.client
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
      await retryRequest(() => SupabaseConfig.client.from('users').update({
        'trainer_id': trainerId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', clientId));
      return true;
    } catch (e) {
      debugPrint('❌ Add client to trainer error: $e');
      return false;
    }
  }

  Future<bool> removeClientFromTrainer(String clientId) async {
    try {
      await retryRequest(() => SupabaseConfig.client.from('users').update({
        'trainer_id': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', clientId));
      return true;
    } catch (e) {
      debugPrint('❌ Remove client from trainer error: $e');
      return false;
    }
  }

  Future<List<Profile>> getTrainerClients(String trainerId) async {
    try {
      final response = await retryRequest(() => SupabaseConfig.client
          .from('users')
          .select('id, username, email, code, role_id, trainer_id')
          .eq('trainer_id', trainerId)
          .order('username', ascending: true));

      return response
          .map((item) => Profile(
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
              ))
          .toList();
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
        : (n.split(' ').length > 1 ? n.split(' ').skip(1).join(' ') : '');
  }

  GoalType _parseGoal(String? v) => v == null
      ? GoalType.maintenance
      : GoalType.values.firstWhere(
          (e) => e.toString().split('.').last == v,
          orElse: () => GoalType.maintenance,
        );
}