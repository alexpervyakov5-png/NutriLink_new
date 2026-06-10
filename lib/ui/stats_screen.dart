import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/config.dart';
import '../core/error_handler.dart';
import '../data/models.dart';
import 'widgets/custom_tab_icon.dart';

import '../data/stats_service.dart';

// ============================================
// ВСПОМОГАТЕЛЬНЫЕ КОНСТАНТЫ (локальные)
// ============================================
class _StatsConstants {
  // Настройки графика
  static const double chartPaddingPercent = 0.15;
  static const double chartMinPadding = 2.0;
  static const double chartMaxPadding = 10.0;
  static const double chartSmallRangeCenter = 3.0;
  
  // 🔥 ИСПРАВЛЕНО: убран const, так как double не может быть ключом в const Map
  static final Map<double, double> yIntervals = {
    10: 2,
    20: 5,
    50: 10,
    100: 20,
    200: 50,
  };
  static const double yIntervalDefault = 100;
  
  // Шаги оси X
  static const Map<int, int> xSteps = {
    7: 1,
    14: 2,
    30: 3,
  };
  static const int xStepDefault = 5;
  
  // Метрики
  static const List<String> metrics = ['weight', 'chest', 'waist', 'hips'];
}

// ============================================
// StatsScreen
// ============================================
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  String _selectedMetric = 'weight';
  bool _isInitialized = false;

  final Map<String, Map<String, dynamic>> _metricConfig = {
    'weight': {'title': 'Вес', 'unit': 'кг', 'color': Colors.blue, 'icon': Icons.monitor_weight, 'decimals': 1},
    'chest': {'title': 'Грудь', 'unit': 'см', 'color': Colors.red, 'icon': Icons.straighten, 'decimals': 0},
    'waist': {'title': 'Талия', 'unit': 'см', 'color': Colors.green, 'icon': Icons.straighten, 'decimals': 0},
    'hips': {'title': 'Бёдра', 'unit': 'см', 'color': Colors.orange, 'icon': Icons.straighten, 'decimals': 0},
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized && mounted) {
      _isInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadStats();
        }
      });
    }
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    
    try {
      final svc = context.read<StatsService>();
      if (svc.stats == null && !svc.loading) {
        await svc.load();
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.show(context, ErrorHandler.format(e, context: 'stats_load'));
    }
  }

  Future<void> _refreshStats() async {
    if (!mounted) return;
    
    try {
      final svc = context.read<StatsService>();
      await svc.refresh();
      if (mounted) {
        ErrorHandler.showSuccess(context, 'Данные обновлены');
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.show(context, ErrorHandler.format(e, context: 'stats_refresh'));
    }
  }

  List<TrendPoint> _getTrend(StatsData? data) {
    if (data == null) return [];
    switch (_selectedMetric) {
      case 'weight': return data.weightTrend;
      case 'chest': return data.chestTrend;
      case 'waist': return data.waistTrend;
      case 'hips': return data.hipsTrend;
      default: return data.weightTrend;
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<StatsService>();
    final config = _metricConfig[_selectedMetric]!;
    final trend = _getTrend(svc.stats);

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      body: 
        (svc.loading && svc.stats == null)
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshStats,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: _StatsConstants.metrics.map((key) {
                          final isSelected = _selectedMetric == key;
                          final meta = _metricConfig[key]!;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedMetric = key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  // 🔥 ИСПРАВЛЕНО: с withOpacity на withValues
                                  color: isSelected ? (meta['color'] as Color).withValues(alpha: 0.2) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  meta['title'] as String,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected ? (meta['color'] as Color) : AppColors.textSecondary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                config['icon'] as IconData? ?? Icons.straighten, 
                                color: config['color'] as Color? ?? AppColors.accent, 
                                size: 24
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${config['title'] as String} (${config['unit'] as String})',
                                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: trend.isEmpty
                                ? Center(child: Text('Нет данных за месяц', style: TextStyle(color: AppColors.textHint)))
                                : _buildTrendChart(trend, config),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Питание (за месяц)', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          StatsRow(label: 'Калории', value: '${svc.stats?.nutrition.calories ?? 0}', percent: '', iconPath: '${AppStrings.assetImages}calories.png', color: AppColors.progressCalories),
                          StatsRow(label: 'Белки', value: '${svc.stats?.nutrition.protein ?? 0}г', percent: '${svc.stats?.nutrition.proteinPercent.toStringAsFixed(0)}%', iconPath: '${AppStrings.assetImages}protein.png', color: AppColors.progressProtein),
                          StatsRow(label: 'Жиры', value: '${svc.stats?.nutrition.fats ?? 0}г', percent: '${svc.stats?.nutrition.fatsPercent.toStringAsFixed(0)}%', iconPath: '${AppStrings.assetImages}fats.png', color: AppColors.progressFats),
                          StatsRow(label: 'Углеводы', value: '${svc.stats?.nutrition.carbs ?? 0}г', percent: '${svc.stats?.nutrition.carbsPercent.toStringAsFixed(0)}%', iconPath: '${AppStrings.assetImages}carbs.png', color: AppColors.progressCarbs),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildTrendChart(List<TrendPoint> data, Map<String, dynamic> config) {
    try {
      if (data.isEmpty) return const SizedBox();
      
      final color = (config['color'] as Color?) ?? AppColors.accent;
      final decimals = (config['decimals'] as int?) ?? 0;
      final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();
      
      double minY, maxY;
      try {
        final values = data.map((e) => e.value).toList();
        final minVal = values.reduce((a, b) => a < b ? a : b);
        final maxVal = values.reduce((a, b) => a > b ? a : b);
        final range = maxVal - minVal;
        
        final padding = (range * _StatsConstants.chartPaddingPercent)
            .clamp(_StatsConstants.chartMinPadding, _StatsConstants.chartMaxPadding);
        minY = minVal - padding;
        maxY = maxVal + padding;
        
        if (range < 3) {
          final center = (minVal + maxVal) / 2;
          minY = center - _StatsConstants.chartSmallRangeCenter;
          maxY = center + _StatsConstants.chartSmallRangeCenter;
        }
        
        if (minY < 0) minY = 0;
      } catch (_) {
        minY = 0;
        maxY = 100;
      }

      final int step = _StatsConstants.xSteps.entries
          .firstWhere((e) => data.length <= e.key, orElse: () => MapEntry(999, _StatsConstants.xStepDefault))
          .value;

      final double yInterval = _calculateYInterval(minY, maxY);

      return LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true, 
            drawVerticalLine: false,
            horizontalInterval: yInterval,
            getDrawingHorizontalLine: (value) {
              return FlLine(color: AppColors.backgroundSecondary, strokeWidth: 1);
            },
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, 
                reservedSize: 44,
                interval: yInterval,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toStringAsFixed(decimals), 
                    style: const TextStyle(color: AppColors.textHint, fontSize: 10)
                  );
                }
              )
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, 
                reservedSize: 52,
                interval: step.toDouble(),
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < data.length && index % step == 0) {
                    try {
                      final date = data[index].date;
                      final day = date.day.toString().padLeft(2, '0');
                      final month = date.month.toString().padLeft(2, '0');
                      return Text(
                        '$day.$month', 
                        style: const TextStyle(color: AppColors.textHint, fontSize: 9)
                      );
                    } catch (_) {
                      return const Text('');
                    }
                  }
                  return const Text('');
                }
              )
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: color,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true, 
                // 🔥 ИСПРАВЛЕНО: с withOpacity на withValues
                color: color.withValues(alpha: 0.15),
              ),
              curveSmoothness: 0.3,
            ),
          ],
          minX: 0,
          maxX: data.length > 1 ? (data.length - 1).toDouble() : 1,
          minY: minY,
          maxY: maxY,
          clipData: FlClipData.all(),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Chart error: $e');
      debugPrint('Stack: $stackTrace');
      return Center(
        child: Text(
          ErrorHandler.format(e, context: 'stats_chart'),
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }
  }

  double _calculateYInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 0) return 10;
    
    for (final entry in _StatsConstants.yIntervals.entries) {
      if (range <= entry.key) return entry.value;
    }
    return _StatsConstants.yIntervalDefault;
  }
}

// ==========================================
// ✅ STATS ROW
// ==========================================
class StatsRow extends StatelessWidget {
  final String label, value, percent;
  final String iconPath;
  final Color color;

  const StatsRow({
    super.key,
    required this.label,
    required this.value,
    required this.percent,
    required this.iconPath,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CustomIcon(
              path: iconPath,
              width: 24,
              height: 24,
              color: color,
              fallback: Icon(Icons.circle, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: AppColors.textSecondary)),
                  Text('$value ($percent)',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      );
}