import 'package:flutter/foundation.dart';
import '../core/config.dart';

class ClientInfo {
  final String id;
  final String name;
  final String? email;
  final bool isMe;

  const ClientInfo({
    required this.id,
    required this.name,
    this.email,
    this.isMe = false,
  });

  @override
  String toString() => 'ClientInfo(id: $id, name: $name, isMe: $isMe)';
}

class ClientsService extends ChangeNotifier {
  List<ClientInfo> _clients = [];
  ClientInfo? _selectedClient;
  bool _loading = false;
  String? _error;
  bool _isTrainer = false;
  bool _isInitialized = false;

  List<ClientInfo> get clients => _clients;
  ClientInfo? get selectedClient => _selectedClient;
  bool get loading => _loading;
  String? get error => _error;
  bool get isTrainer => _isTrainer;
  bool get hasClients => _clients.length > 1 && _isTrainer;
  bool get isLoaded => _isInitialized;
  
  /// true, если тренер смотрит данные клиента (не свои)
  bool get isViewingClient => _selectedClient != null && !_selectedClient!.isMe;
  
  /// true, если пользователь смотрит свои данные
  bool get isViewingOwnData => _selectedClient?.isMe == true || !_isTrainer;

  String get selectedUserId {
    return _selectedClient?.id ?? SupabaseConfig.currentUserId!;
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
          .select('role_id, username, email')
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
        isMe: true,
      );

      if (!_isTrainer) {
        _clients = [trainerInfo];
        _selectedClient = trainerInfo;
        _isInitialized = true;
        _loading = false;
        notifyListeners();
        return;
      }

      final clientsData = await SupabaseConfig.client
          .from('users')
          .select('id, username, email')
          .eq('trainer_id', currentUserId)
          .order('username', ascending: true);

      _clients = [
        trainerInfo,
        ...clientsData.map((c) => ClientInfo(
              id: c['id'] as String,
              name: c['username'] as String? ?? 'Без имени',
              email: c['email'] as String?,
              isMe: false,
            )),
      ];

      _selectedClient = _clients.first;
      _isInitialized = true;
      debugPrint('✅ ClientsService loaded: ${_clients.length} users');
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
      _selectedClient = client;
      debugPrint('👤 Switched to: ${client.name} (${client.id})');
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