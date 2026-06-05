import 'package:flutter/foundation.dart';
import '../core/config.dart';

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
  // 🔥 Диагностика: отслеживаем экземпляр сервиса
  static int _instanceCounter = 0;
  final int _instanceId;
  
  List<ClientInfo> _clients = [];
  ClientInfo? _selectedClient;
  bool _loading = false;
  String? _error;
  bool _isTrainer = false;
  bool _isInitialized = false;

  ClientsService() : _instanceId = ++_instanceCounter {
    debugPrint('🆔 ClientsService instance #$_instanceId created');
  }

  List<ClientInfo> get clients => _clients;
  ClientInfo? get selectedClient => _selectedClient;
  bool get loading => _loading;
  String? get error => _error;
  bool get isTrainer => _isTrainer;
  bool get hasClients => _clients.length > 1 && _isTrainer;
  bool get isLoaded => _isInitialized;
  
  bool get isViewingClient => _selectedClient != null && !_selectedClient!.isMe;
  bool get isViewingOwnData => _selectedClient?.isMe == true || !_isTrainer;

  String get selectedUserId {
    final result = _selectedClient?.id ?? SupabaseConfig.currentUserId!;
    if (kDebugMode) {
      debugPrint('🔍 [Instance #$_instanceId] selectedUserId: "${_selectedClient?.name}" → "$result"');
    }
    return result;
  }

  Future<void> loadClients() async {
    if (_isInitialized) return;
    final currentUserId = SupabaseConfig.currentUserId;
    if (currentUserId == null) return;

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
        _loading = false;
        notifyListeners();
        return;
      }

      final userRoleId = user['role_id'] as String?;
      _isTrainer = userRoleId == SupabaseConfig.trainerRoleId;

      final trainerInfo = ClientInfo(
        id: currentUserId,
        name: user['username'] as String? ?? 'Вы',
        email: user['email'] as String?,
        code: user['code'] as String?,
        isMe: true,
      );

      if (!_isTrainer) {
        _clients = [trainerInfo];
        _selectedClient = trainerInfo;
        _isInitialized = true;
        _loading = false;
        notifyListeners();
        debugPrint('✅ Client loaded: ${trainerInfo.name}');
        return;
      }

      final clientsData = await SupabaseConfig.client
          .from('users')
          .select('id, username, email, code')
          .eq('trainer_id', currentUserId)
          .order('username', ascending: true);

      _clients = [
        trainerInfo,
        ...clientsData.map((c) => ClientInfo(
              id: c['id'] as String,
              name: c['username'] as String? ?? 'Без имени',
              email: c['email'] as String?,
              code: c['code'] as String?,
              isMe: false,
            )),
      ];

      _selectedClient = _clients.first;
      _isInitialized = true;
      debugPrint('✅ Trainer loaded with ${_clients.length - 1} clients');
    } catch (e, stackTrace) {
      _error = 'Ошибка загрузки клиентов: $e';
      debugPrint('❌ Load clients error: $e');
      debugPrint('Stack: $stackTrace');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void selectClient(ClientInfo client) {
    if (_selectedClient?.id != client.id) {
      debugPrint('👤 [Instance #$_instanceId] SWITCHING: ${_selectedClient?.name} → ${client.name}');
      debugPrint('🆔 New client: id=${client.id}, isMe=${client.isMe}');
      _selectedClient = client;
      debugPrint('🔍 selectedUserId now: "${selectedUserId}"');
      notifyListeners();
    }
  }

  void resetToMe() {
    final me = _clients.firstWhere(
      (c) => c.isMe,
      orElse: () => _clients.first,
    );
    selectClient(me);
  }

  void clear() {
    _clients.clear();
    _selectedClient = null;
    _isTrainer = false;
    _isInitialized = false;
    notifyListeners();
  }
}