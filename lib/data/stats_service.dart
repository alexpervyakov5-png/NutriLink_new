import 'package:flutter/foundation.dart';

import '../core/config.dart';
import '../core/error_handler.dart';
import 'services.dart';
import 'clients_service.dart';
import 'models.dart';

class StatsService extends ChangeNotifier with ClientAwareService {
  @override
  final ClientsService clientsService;
  StatsData? _stats;
  bool _loading = false, _refreshing = false;
  String? _error;
  DateTime _start = DateTime.now().subtract(const Duration(days: 30));
  DateTime _end = DateTime.now();

  StatsService(this.clientsService) {
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
    final uid = userId;
    if (uid == null || uid.isEmpty) {
      debugPrint('⚠️ StatsService.load: userId is empty');
      return;
    }

    if (!shouldReload(force: force)) return;

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
        retryRequest(() => SupabaseConfig.client
            .from('daily_summary')
            .select('protein_actual, fat_actual, carbs_actual, calories_actual')
            .eq('user_id', uid)
            .gte('date', s)
            .lte('date', e)),
        retryRequest(() => SupabaseConfig.client
            .from('body_measurements')
            .select('measured_at, weight_kg, chest_cm, waist_cm, hips_cm')
            .eq('user_id', uid)
            .gte('measured_at', _start.toIso8601String())
            .lte('measured_at', _end.toIso8601String())
            .order('measured_at', ascending: true)),
      ]);

      int tp = 0, tf = 0, tc = 0, tk = 0;
      for (final r in nutr) {
        tp += toIntSafe(r['protein_actual']);
        tf += toIntSafe(r['fat_actual']);
        tc += toIntSafe(r['carbs_actual']);
        tk += toIntSafe(r['calories_actual']);
      }
      final ns = NutritionStats.fromMacros(protein: tp, fats: tf, carbs: tc, calories: tk);

      List<TrendPoint> weightTrend = [],
          chestTrend = [],
          waistTrend = [],
          hipsTrend = [];
      for (final row in measurements) {
        final date = DateTime.parse(row['measured_at'] as String);
        if (row['weight_kg'] != null)
          weightTrend.add(TrendPoint(date: date, value: toDoubleSafe(row['weight_kg'])));
        if (row['chest_cm'] != null)
          chestTrend.add(TrendPoint(date: date, value: toDoubleSafe(row['chest_cm'])));
        if (row['waist_cm'] != null)
          waistTrend.add(TrendPoint(date: date, value: toDoubleSafe(row['waist_cm'])));
        if (row['hips_cm'] != null)
          hipsTrend.add(TrendPoint(date: date, value: toDoubleSafe(row['hips_cm'])));
      }

      _stats = StatsData(
        nutrition: ns,
        weightTrend: weightTrend,
        chestTrend: chestTrend,
        waistTrend: waistTrend,
        hipsTrend: hipsTrend,
        streakDays: await _streak(uid, e),
      );
      onCacheLoaded();
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
      final r = await retryRequest(() => SupabaseConfig.client
          .from('daily_summary')
          .select('calories_actual')
          .eq('user_id', uid)
          .order('date', ascending: false)
          .limit(30));
      if (r.isEmpty) return 0;

      final g = await retryRequest(() => SupabaseConfig.client
          .from('user_goals')
          .select('calories_target')
          .eq('user_id', uid)
          .eq('is_active', true)
          .maybeSingle());
      final target = g != null
          ? toIntSafe(g['calories_target'], defaultValue: 2500)
          : 2500;

      int streak = 0;
      for (final row in r) {
        final act = toIntSafe(row['calories_actual']);
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