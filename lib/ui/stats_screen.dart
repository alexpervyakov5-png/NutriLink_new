import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/config.dart';
import '../data/models.dart';
import '../data/services.dart';
import 'widgets.dart';

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
    if (!_isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadStats();
          _isInitialized = true;
        }
      });
    }
  }

  Future<void> _loadStats() async {
    try {
      final svc = context.read<StatsService>();
      if (svc.stats == null && !svc.loading) {
        await svc.load();
      }
    } catch (e) {
      if (!mounted) return;
      _showError(_formatError(e, context: 'load'));
    }
  }

  Future<void> _refreshStats() async {
    try {
      final svc = context.read<StatsService>();
      await svc.refresh();
      if (mounted) {
        _showSuccess('Данные обновлены');
      }
    } catch (e) {
      if (!mounted) return;
      _showError(_formatError(e, context: 'refresh'));
    }
  }

  String _formatError(Object? error, {String context = ''}) {
    if (error == null) return 'Произошла непредвиденная ошибка';
    
    if (error is SocketException || 
        error.toString().contains('SocketException') ||
        error.toString().contains('Network is unreachable') ||
        error.toString().contains('Connection refused') ||
        error.toString().contains('Failed host lookup')) {
      return 'Нет подключения к интернету. Проверьте соединение';
    }
    
    if (error.toString().contains('PostgrestException') || 
        error.toString().contains('database')) {
      if (error.toString().contains('JWT expired')) {
        return 'Сессия истекла. Пожалуйста, войдите снова';
      }
      if (error.toString().contains('row-level security') || 
          error.toString().contains('permission denied')) {
        return 'Ошибка доступа. Обратитесь в поддержку';
      }
      return 'Ошибка загрузки данных. Попробуйте позже';
    }
    
    if (error is String) return error;
    
    if (context.isNotEmpty) {
      switch (context) {
        case 'load': return 'Не удалось загрузить статистику. Попробуйте снова';
        case 'refresh': return 'Не удалось обновить данные. Попробуйте позже';
        case 'chart': return 'Не удалось построить график';
      }
    }
    
    return 'Произошла непредвиденная ошибка. Попробуйте снова';
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Статистика', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
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
                        children: ['weight', 'chest', 'waist', 'hips'].map((key) {
                          final isSelected = _selectedMetric == key;
                          final meta = _metricConfig[key]!;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedMetric = key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? (meta['color'] as Color).withOpacity(0.2) : Colors.transparent,
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
                              Icon(config['icon'] as IconData, color: config['color'] as Color, size: 24),
                              const SizedBox(width: 8),
                              Text('${config['title'] as String} (${config['unit'] as String})',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: trend.isEmpty
                                ? Center(child: Text('Нет данных за период', style: TextStyle(color: AppColors.textHint)))
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
                          const Text('Питание (за период)', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          StatsRow(label: 'Калории', value: '${svc.stats?.nutrition.calories ?? 0}', percent: '', color: AppColors.progressCalories, icon: Icons.local_fire_department),
                          StatsRow(label: 'Белки', value: '${svc.stats?.nutrition.protein ?? 0}г', percent: '${svc.stats?.nutrition.proteinPercent.toStringAsFixed(0)}%', color: AppColors.progressProtein, icon: Icons.egg),
                          StatsRow(label: 'Жиры', value: '${svc.stats?.nutrition.fats ?? 0}г', percent: '${svc.stats?.nutrition.fatsPercent.toStringAsFixed(0)}%', color: AppColors.progressFats, icon: Icons.water_drop),
                          StatsRow(label: 'Углеводы', value: '${svc.stats?.nutrition.carbs ?? 0}г', percent: '${svc.stats?.nutrition.carbsPercent.toStringAsFixed(0)}%', color: AppColors.progressCarbs, icon: Icons.grain),
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
      
      final color = config['color'] as Color;
      final decimals = config['decimals'] as int;
      final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();
      
      double minY, maxY;
      try {
        final values = data.map((e) => e.value).toList();
        final minVal = values.reduce((a, b) => a < b ? a : b);
        final maxVal = values.reduce((a, b) => a > b ? a : b);
        final range = maxVal - minVal;
        
        final padding = (range * 0.15).clamp(2.0, 10.0);
        minY = minVal - padding;
        maxY = maxVal + padding;
        
        if (range < 3) {
          final center = (minVal + maxVal) / 2;
          minY = center - 3;
          maxY = center + 3;
        }
        
        if (minY < 0) minY = 0;
      } catch (_) {
        minY = 0;
        maxY = 100;
      }

      // Определяем шаг для подписей дат на оси X
      final int step;
      if (data.length <= 7) {
        step = 1;
      } else if (data.length <= 14) {
        step = 2;
      } else if (data.length <= 30) {
        step = 3;
      } else {
        step = 5;
      }

      // Рассчитываем интервал для оси Y
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
                color: color.withOpacity(0.15),
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
          'Не удалось отобразить график',
          style: TextStyle(color: AppColors.textHint),
        ),
      );
    }
  }

  double _calculateYInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 0) return 10;
    if (range <= 10) return 2;
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    if (range <= 100) return 20;
    if (range <= 200) return 50;
    return 100;
  }
}