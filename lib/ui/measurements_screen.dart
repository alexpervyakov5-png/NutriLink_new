import 'package:Nutrilink/core/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/error_handler.dart';
import '../core/constants.dart';

import '../data/models.dart';

import '../data/clients_service.dart';
import 'widgets.dart';

import '../data/measurements_service.dart';

// ============================================
// MeasurementsScreen
// ============================================
class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadMeasurements();
          _isInitialized = true;
        }
      });
    }
  }

  Future<void> _loadMeasurements() async {
    try {
      final svc = context.read<MeasurementsService>();
      if (svc.list.isEmpty && !svc.loading) {
        await svc.load();
      }
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.show(context, ErrorHandler.format(e, context: 'measurements_load'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<MeasurementsService>();
    final clientsSvc = context.watch<ClientsService>();
    final canEdit = clientsSvc.isViewingOwnData;

    return Container(
      color: AppColors.backgroundSecondary,
      child: Column(
        children: [
          Expanded(
            child: svc.loading && svc.list.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : svc.list.isEmpty
                    ? _Empty()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: svc.list.length,
                        itemBuilder: (ctx, i) => _Card(
                          m: svc.list[i], 
                          canEdit: canEdit,
                        ),
                      ),
          ),
          if (canEdit)
            Container(
              padding: const EdgeInsets.all(20),
              color: AppColors.backgroundSecondary,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: svc.loading
                      ? null
                      : () => _showForm(ctx: context, svc: svc),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: svc.loading
                          ? AppColors.backgroundSecondary
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: svc.loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 20,
                                    color: AppColors.textPrimary),
                                SizedBox(width: 8),
                                Text('Добавить замер',
                                    style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500)),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================
// ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ
// ============================================

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.straighten, size: 48,
                color: AppColors.textHint.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('Нет данных',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Добавьте первый замер',
                style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  final Measurement m;
  final bool canEdit;
  
  const _Card({required this.m, required this.canEdit});

  @override
  Widget build(BuildContext context) => Dismissible(
        key: Key(m.id),
        direction: canEdit ? DismissDirection.endToStart : DismissDirection.none,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.red, size: 24),
        ),
        confirmDismiss: (_) async {
          final result = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Удалить замер?',
                  style: TextStyle(color: AppColors.textPrimary)),
              content: Text(
                  '${m.measuredAt.day.toString().padLeft(2, '0')}.${m.measuredAt.month.toString().padLeft(2, '0')}.${m.measuredAt.year}',
                  style: const TextStyle(color: AppColors.textSecondary)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Отмена')),
                TextButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Удалить',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          );
          return result ?? false;
        },
        onDismissed: (_) async {
          try {
            await context.read<MeasurementsService>().delete(m.id);
            if (context.mounted) {
              ErrorHandler.showSuccess(context, 'Удалено');
            }
          } catch (e) {
            if (context.mounted) {
              ErrorHandler.show(
                context, 
                ErrorHandler.format(e, context: 'measurements_delete'),
              );
            }
          }
        },
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: canEdit ? () => _showForm(ctx: context, svc: context.read<MeasurementsService>(), edit: m) : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${m.measuredAt.day.toString().padLeft(2, '0')} ${_month(m.measuredAt.month)} ${m.measuredAt.year} г',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const Spacer(),
                      if (canEdit)
                        const Icon(Icons.edit, size: 16,
                            color: AppColors.textHint),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (m.weightKg != null)
                        Expanded(child: _Stat('${m.weightKg!.toStringAsFixed(1)} кг', 'Вес')),
                      if (m.chestCm != null)
                        Expanded(child: _Stat('${m.chestCm!.toInt()} см', 'Грудь')),
                      if (m.waistCm != null)
                        Expanded(child: _Stat('${m.waistCm!.toInt()} см', 'Талия')),
                      if (m.hipsCm != null)
                        Expanded(child: _Stat('${m.hipsCm!.toInt()} см', 'Бёдра')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  String _month(int m) => [
        'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
      ][m - 1];
}

class _Stat extends StatelessWidget {
  final String v, l;
  const _Stat(this.v, this.l);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(l, style: TextStyle(color: AppColors.textHint, fontSize: 11)),
          ],
        ),
      );
}

// ==========================================
// ФОРМА ДОБАВЛЕНИЯ/РЕДАКТИРОВАНИЯ
// ==========================================
void _showForm({
  required BuildContext ctx,
  required MeasurementsService svc,
  Measurement? edit,
}) {
  final formKey = GlobalKey<FormState>();
  DateTime selectedDate = edit?.measuredAt ?? DateTime.now();
  
  final wCtrl = TextEditingController(text: edit?.weightKg?.toStringAsFixed(1) ?? '');
  final chCtrl = TextEditingController(text: edit?.chestCm?.toString() ?? '');
  final waCtrl = TextEditingController(text: edit?.waistCm?.toString() ?? '');
  final hiCtrl = TextEditingController(text: edit?.hipsCm?.toString() ?? '');

  showModalBottomSheet(
    context: ctx,
    backgroundColor: AppColors.backgroundSecondary,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => StatefulBuilder(builder: (sheetCtx, setModalState) => Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20),
      decoration: const BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 32,
                height: 3,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textHint.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              edit != null ? 'Редактировать' : 'Новый замер',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: () async {
                try {
                  final nd = await showDatePicker(
                    context: sheetCtx,
                    initialDate: selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (nd != null && sheetCtx.mounted) {
                    setModalState(() => selectedDate = nd);
                  }
                } catch (e) {
                  if (sheetCtx.mounted) {
                    ErrorHandler.show(sheetCtx, 'Не удалось выбрать дату');
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18,
                        color: AppColors.textHint),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${selectedDate.day.toString().padLeft(2, '0')} ${_monthName(selectedDate.month)} ${selectedDate.year}',
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontSize: 14),
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 18,
                        color: AppColors.textHint),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            MeasurementField(
                controller: wCtrl,
                label: 'Вес',
                hint: '0',
                icon: Icons.monitor_weight,
                suffix: 'кг',
                keyboardType: TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 14),
            MeasurementField(
                controller: chCtrl,
                label: 'Грудь',
                hint: '0',
                icon: Icons.check_box_outline_blank,
                suffix: 'см',
                keyboardType: TextInputType.number),
            const SizedBox(height: 14),
            MeasurementField(
                controller: waCtrl,
                label: 'Талия',
                hint: '0',
                icon: Icons.line_axis,
                suffix: 'см',
                keyboardType: TextInputType.number),
            const SizedBox(height: 14),
            MeasurementField(
                controller: hiCtrl,
                label: 'Бёдра',
                hint: '0',
                icon: Icons.circle,
                suffix: 'см',
                keyboardType: TextInputType.number),
            const SizedBox(height: 28),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  final weight = double.tryParse(wCtrl.text);
                  final chest = double.tryParse(chCtrl.text);
                  final waist = double.tryParse(waCtrl.text);
                  final hips = double.tryParse(hiCtrl.text);
                  
                  if (weight == null && chest == null && waist == null && hips == null) {
                    ErrorHandler.show(sheetCtx, 'Заполните хотя бы одно поле');
                    return;
                  }
                  
                  // 🔥 ВАЛИДАЦИЯ С ПОДТВЕРЖДЕНИЕМ
                  bool allValid = true;
                  
                  if (weight != null) {
                    final weightValid = await InputValidator.validateWeight(
                      context: sheetCtx,
                      weight: weight,
                    );
                    if (!weightValid) allValid = false;
                  }
                  
                  if (allValid && chest != null) {
                    final chestValid = await InputValidator.validateChest(
                      context: sheetCtx,
                      chest: chest,
                    );
                    if (!chestValid) allValid = false;
                  }
                  
                  if (allValid && waist != null) {
                    final waistValid = await InputValidator.validateWaist(
                      context: sheetCtx,
                      waist: waist,
                    );
                    if (!waistValid) allValid = false;
                  }
                  
                  if (allValid && hips != null) {
                    final hipsValid = await InputValidator.validateHips(
                      context: sheetCtx,
                      hips: hips,
                    );
                    if (!hipsValid) allValid = false;
                  }
                  
                  if (!allValid) {
                    return; // Пользователь отменил
                  }
                  
                  try {
                    if (edit != null) {
                      final success = await svc.update(
                        id: edit.id,
                        at: selectedDate,
                        w: weight,
                        ch: chest,
                        wa: waist,
                        hi: hips,
                      );
                      if (!sheetCtx.mounted) return;
                      if (success) {
                        ErrorHandler.showSuccess(sheetCtx, 'Замер обновлён');
                        Navigator.pop(sheetCtx);
                      } else {
                        ErrorHandler.show(sheetCtx, svc.error ?? 'Не удалось обновить замер');
                      }
                    } else {
                      final success = await svc.save(
                        at: selectedDate,
                        w: weight,
                        ch: chest,
                        wa: waist,
                        hi: hips,
                      );
                      if (!sheetCtx.mounted) return;
                      if (success) {
                        ErrorHandler.showSuccess(sheetCtx, 'Замер добавлен');
                        Navigator.pop(sheetCtx);
                      } else {
                        ErrorHandler.show(sheetCtx, svc.error ?? 'Не удалось сохранить замер');
                      }
                    }
                  } catch (e) {
                    if (!sheetCtx.mounted) return;
                    ErrorHandler.show(
                      sheetCtx, 
                      ErrorHandler.format(e, context: edit != null ? 'measurements_update' : 'measurements_save'),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      edit != null ? 'Сохранить изменения' : 'Сохранить',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    )),
  );
}

String _monthName(int m) => [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
    ][m - 1];