import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/error_handler.dart';
import '../../core/safe_text_controller.dart';
import '../../data/diary_service.dart';
import '../../data/models.dart';
import 'input_helpers.dart';

// ============================================
// 🔥 СОЗДАНИЕ НОВОГО ПРОДУКТА
// ============================================
void showCreateProductDialog({
  required BuildContext ctx,
  required MealType type,
  required DiaryService diaryService,
  required Function(BuildContext, MealType, dynamic, DiaryService)
      openPortionSelector,
  Function(Product)? onProductCreated,
}) {
  final nameCtrl = SafeTextEditingController();
  final calCtrl = SafeTextEditingController();
  final proCtrl = SafeTextEditingController();
  final fatCtrl = SafeTextEditingController();
  final carbCtrl = SafeTextEditingController();

  showDialog(
    context: ctx,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Новый продукт',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            buildLabeledInput(nameCtrl, 'Название продукта', validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Введите название';
              if (v.trim().length < 2) return 'Минимум 2 символа';
              return null;
            }),
            const SizedBox(height: 16),
            buildLabeledInput(calCtrl, 'Калории (ккал/100г)',
                isNumber: true, validator: (v) {
              final val = double.tryParse(v ?? '');
              if (val == null) return 'Введите число';
              if (val < 0) return 'Не может быть отрицательным';
              if (val > 10000) return 'Слишком большое значение';
              return null;
            }),
            const SizedBox(height: 16),
            Text('Макронутриенты на 100г',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: buildMacroInput(proCtrl, 'Белки', 'г',
                      isNumber: true, validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null) return 'Число';
                if (val < 0) return 'Не отрицательное';
                return null;
              })),
              const SizedBox(width: 8),
              Expanded(
                  child: buildMacroInput(fatCtrl, 'Жиры', 'г',
                      isNumber: true, validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null) return 'Число';
                if (val < 0) return 'Не отрицательное';
                return null;
              })),
              const SizedBox(width: 8),
              Expanded(
                  child: buildMacroInput(carbCtrl, 'Углеводы', 'г',
                      isNumber: true, validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null) return 'Число';
                if (val < 0) return 'Не отрицательное';
                return null;
              })),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text('Отмена',
                      style: TextStyle(
                          color: AppColors.textHint, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ErrorHandler.show(dialogContext, 'Введите название продукта');
                      return;
                    }
                    if (name.length < 2) {
                      ErrorHandler.show(dialogContext,
                          'Название должно быть не менее 2 символов');
                      return;
                    }

                    final calories = double.tryParse(calCtrl.text) ?? 0;
                    final protein = double.tryParse(proCtrl.text) ?? 0;
                    final fat = double.tryParse(fatCtrl.text) ?? 0;
                    final carbs = double.tryParse(carbCtrl.text) ?? 0;

                    if (calories < 0 ||
                        protein < 0 ||
                        fat < 0 ||
                        carbs < 0) {
                      ErrorHandler.show(dialogContext,
                          'Значения не могут быть отрицательными');
                      return;
                    }

                    try {
                      final newP = await diaryService.createProduct(
                        name,
                        calories,
                        protein,
                        fat,
                        carbs,
                      );

                      if (!dialogContext.mounted) return;

                      Navigator.of(dialogContext).pop();

                      if (newP != null) {
                        if (onProductCreated != null) {
                          onProductCreated(newP);
                        } else {
                          ErrorHandler.showSuccessGlobal('Продукт создан');
                        }
                      }
                    } catch (e) {
                      if (!dialogContext.mounted) return;
                      ErrorHandler.show(dialogContext,
                          ErrorHandler.format(e, context: 'product'));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Создать',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ])
          ],
        ),
      ),
    ),
  );
}

// ============================================
// 🔥 РЕДАКТИРОВАНИЕ ПРОДУКТА
// ============================================
void showEditProductDialog({
  required BuildContext ctx,
  required Product product,
  required DiaryService diaryService,
  required Function() onUpdated,
}) {
  final nameCtrl = SafeTextEditingController(text: product.name);
  final calCtrl = SafeTextEditingController(text: product.calories.toStringAsFixed(0));
  final proCtrl = SafeTextEditingController(text: product.protein.toStringAsFixed(0));
  final fatCtrl = SafeTextEditingController(text: product.fat.toStringAsFixed(0));
  final carbCtrl = SafeTextEditingController(text: product.carbs.toStringAsFixed(0));

  showDialog(
    context: ctx,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Редактировать продукт',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            buildLabeledInput(nameCtrl, 'Название продукта'),
            const SizedBox(height: 16),
            buildLabeledInput(calCtrl, 'Калории (ккал/100г)', isNumber: true),
            const SizedBox(height: 16),
            Text('Макронутриенты на 100г',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: buildMacroInput(proCtrl, 'Белки', 'г', isNumber: true)),
              const SizedBox(width: 8),
              Expanded(child: buildMacroInput(fatCtrl, 'Жиры', 'г', isNumber: true)),
              const SizedBox(width: 8),
              Expanded(child: buildMacroInput(carbCtrl, 'Углеводы', 'г', isNumber: true)),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    if (dialogContext.mounted) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text('Отмена',
                      style: TextStyle(
                          color: AppColors.textHint, fontSize: 15)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty || name.length < 2) {
                      ErrorHandler.show(dialogContext,
                          'Название должно быть не менее 2 символов');
                      return;
                    }

                    final calories = double.tryParse(calCtrl.text) ?? 0;
                    final protein = double.tryParse(proCtrl.text) ?? 0;
                    final fat = double.tryParse(fatCtrl.text) ?? 0;
                    final carbs = double.tryParse(carbCtrl.text) ?? 0;

                    if (calories < 0 || protein < 0 || fat < 0 || carbs < 0) {
                      ErrorHandler.show(dialogContext,
                          'Значения не могут быть отрицательными');
                      return;
                    }

                    try {
                      final success = await diaryService.updateProduct(
                        id: product.id,
                        name: name,
                        cal: calories,
                        pro: protein,
                        fat: fat,
                        carb: carbs,
                      );

                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop();

                      if (success) {
                        ErrorHandler.showSuccessGlobal('Продукт обновлён');
                        onUpdated();
                      } else {
                        ErrorHandler.showGlobal('Не удалось обновить продукт');
                      }
                    } catch (e) {
                      if (!dialogContext.mounted) return;
                      ErrorHandler.show(dialogContext,
                          ErrorHandler.format(e, context: 'product'));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Сохранить',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ])
          ],
        ),
      ),
    ),
  );
}