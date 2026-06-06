import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/config.dart';
import '../core/error_handler.dart';
import 'services.dart';
import 'clients_service.dart';
import 'models.dart';

class MeasurementsService extends ChangeNotifier with ClientAwareService {
  @override
  final ClientsService clientsService;
  final _uuid = const Uuid();
  List<Measurement> _list = [];
  bool _loading = false;
  String? _error;

  MeasurementsService(this.clientsService) {
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
    _list.clear();
    notifyListeners();
    load(force: true);
  }

  List<Measurement> get list => _list;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> load({bool force = false}) async {
    final uid = userId;
    if (uid == null || uid.isEmpty) {
      debugPrint('⚠️ MeasurementsService.load: userId is empty');
      return;
    }

    if (!shouldReload(force: force)) return;

    _loading = true;
    _error = null;
    notifyListeners();
    try {
      debugPrint('📥 Loading measurements for user: $uid (force: $force)');
      final data = await retryRequest(() => SupabaseConfig.client
          .from('body_measurements')
          .select()
          .eq('user_id', uid)
          .order('measured_at', ascending: false)
          .limit(50));
      _list = data.map((j) => Measurement.fromJson(j)).toList();
      onCacheLoaded();
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
    final uid = userId;
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
      await retryRequest(() =>
          SupabaseConfig.client.from('body_measurements').insert(m.toJson()));
      _list.insert(0, m);
      _list.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
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

      await retryRequest(() => SupabaseConfig.client
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
      await retryRequest(() =>
          SupabaseConfig.client.from('body_measurements').delete().eq('id', id));
      _list.removeWhere((m) => m.id == id);
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