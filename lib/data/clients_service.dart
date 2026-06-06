import 'package:flutter/foundation.dart';
import '../core/config.dart';
import '../core/error_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException, AuthException;

class ClientInfo {
  final String id;
  final String name;
  final String? email;
  final String? code;
  final bool isMe;

  const ClientInfo({
    required this.id,
    required this.name,
    this.email,
    this.code,
    this.isMe = false,
  });

  @override
  String toString() => 'ClientInfo(id: $id, name: $name, isMe: $isMe)';
}

class ClientsService extends ChangeNotifier {
  static int _instanceCounter = 0;
  final int _instanceId;
  
  List<ClientInfo> _clients = [];
  ClientInfo? _selectedClient;
  bool _loading = false;
  String? _error;
  bool _isTrainer = false;
  bool _isInitialized = false;

  ClientsService() : _instanceId = ++_instanceCounter {
    if (kDebugMode) {
      debugPrint('🆔 ClientsService instance #$_instanceId created');
    }
  }

  List<ClientInfo> get clients => List.unmodifiable(_clients);
  ClientInfo? get selectedClient => _selectedClient;
  bool get loading => _loading;
  String? get error => _error;
  bool get isTrainer => _isTrainer;
  bool get hasClients => _isTrainer && _clients.any((c) => !c.isMe);
  bool get isLoaded => _isInitialized;
  
  bool get isViewingClient => _selectedClient != null && !_selectedClient!.isMe;
  bool get isViewingOwnData => _selectedClient?.isMe == true || !_isTrainer;

  String? get selectedUserId {
    final clientUserId = _selectedClient?.id;
    final currentUserId = SupabaseConfig.currentUserId;
    final result = clientUserId ?? currentUserId;
    
    if (kDebugMode) {
      debugPrint('🔍 [Instance #$_instanceId] selectedUserId: '
          'client="${_selectedClient?.name}" → "$result"');
    }
    
    if (result == null) {
      debugPrint('⚠️ [Instance #$_instanceId] selectedUserId is null - user may be signed out');
    }
    
    return result;
  }

  Future<void> loadClients() async {
    final currentUserId = SupabaseConfig.currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) {
      debugPrint('⚠️ loadClients: No authenticated user (currentUserId is null/empty)');
      _error = 'Требуется авторизация';
      notifyListeners();
      return;
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final user = await SupabaseConfig.client
          .from('users')
          .select('role_id, username, email, code')
          .eq('id', currentUserId)
          .maybeSingle();

      if (user == null) {
        _error = 'Пользователь не найден';
        return;
      }

      final userRoleId = user['role_id'] as String?;
      final trainerRoleId = await SupabaseConfig.getTrainerRoleId();
      _isTrainer = userRoleId != null && trainerRoleId != null && userRoleId == trainerRoleId;

      final me = ClientInfo(
        id: currentUserId,
        name: user['username'] as String? ?? 'Вы',
        email: user['email'] as String?,
        code: user['code'] as String?,
        isMe: true,
      );

      if (!_isTrainer) {
        _clients = [me];
        _selectedClient = me;
        _isInitialized = true;
        debugPrint('✅ Client loaded: ${me.name}');
        return;
      }

      final clientsData = await SupabaseConfig.client
          .from('users')
          .select('id, username, email, code')
          .eq('trainer_id', currentUserId)
          .order('username', ascending: true);

      _clients = [
        me,
        ...clientsData.map((c) => ClientInfo(
              id: c['id'] as String,
              name: c['username'] as String? ?? 'Без имени',
              email: c['email'] as String?,
              code: c['code'] as String?,
              isMe: false,
            )),
      ];

      final prevSelectedId = _selectedClient?.id;
      _selectedClient = _clients.firstWhere(
        (c) => c.id == prevSelectedId,
        orElse: () => _clients.first,
      );
      
      _isInitialized = true;
      debugPrint('✅ Trainer loaded with ${_clients.length - 1} clients');
      
    } on PostgrestException catch (e) {
      _error = ErrorHandler.format(e, context: 'clients');
      debugPrint('❌ PostgrestException in loadClients: ${e.message}');
    } on AuthException catch (e) {
      _error = ErrorHandler.format(e);
      debugPrint('❌ AuthException in loadClients: ${e.message}');
    } catch (e, stackTrace) {
      _error = ErrorHandler.format(e, context: 'clients');
      debugPrint('❌ Load clients error: $e');
      debugPrint('Stack: $stackTrace');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _isInitialized = false;
    await loadClients();
  }

  void selectClient(ClientInfo client) {
    if (!_clients.any((c) => c.id == client.id)) {
      debugPrint('⚠️ [Instance #$_instanceId] Attempted to select unknown client: ${client.id}');
      return;
    }
    
    if (_selectedClient?.id != client.id) {
      if (kDebugMode) {
        debugPrint('👤 [Instance #$_instanceId] SWITCHING: ${_selectedClient?.name} → ${client.name}');
        debugPrint('🆔 New client: id=${client.id}, isMe=${client.isMe}');
      }
      _selectedClient = client;
      if (kDebugMode) {
        debugPrint('🔍 selectedUserId now: "$selectedUserId"');
      }
      notifyListeners();
    }
  }

  void resetToMe() {
    if (_clients.isEmpty) return;
    
    final me = _clients.firstWhere(
      (c) => c.isMe,
      orElse: () => _clients.first,
    );
    selectClient(me);
  }

  void clear() {
    if (kDebugMode) {
      debugPrint('🧹 [Instance #$_instanceId] Clearing ClientsService');
    }
    _clients.clear();
    _selectedClient = null;
    _isTrainer = false;
    _isInitialized = false;
    _error = null;
    _loading = false;
    notifyListeners();
  }
  
  bool get isAuthenticated {
    final userId = SupabaseConfig.currentUserId;
    return userId != null && userId.isNotEmpty;
  }

  @override
  void dispose() {
    if (kDebugMode) {
      debugPrint('🗑️ [Instance #$_instanceId] ClientsService disposed');
    }
    super.dispose();
  }
}