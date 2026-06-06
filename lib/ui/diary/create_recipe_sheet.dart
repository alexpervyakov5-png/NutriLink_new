import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/error_handler.dart';
import '../../core/safe_text_controller.dart';
import '../../data/diary_service.dart';
import '../../data/models.dart';
import 'portion_selector.dart';

void showCreateRecipeSheet({
  required BuildContext ctx,
  required MealType type,
  required DiaryService diaryService,
  required Function(BuildContext, MealType, dynamic, DiaryService)
      openPortionSelector,
}) {
  final nameCtrl = SafeTextEditingController();
  final descCtrl = SafeTextEditingController();
  List<RecipeIngredient> ingredients = [];
  double totalCal = 0,
      totalPro = 0,
      totalFat = 0,
      totalCarb = 0,
      totalWeight = 0;

  showModalBottomSheet(
    context: ctx,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (context, setModalState) {
        void recalculate() {
          totalCal = 0;
          totalPro = 0;
          totalFat = 0;
          totalCarb = 0;
          totalWeight = 0;
          for (var ing in ingredients) {
            totalWeight += ing.amountGrams;
            double ratio = ing.amountGrams / 100.0;
            totalCal += ing.product.calories * ratio;
            totalPro += ing.product.protein * ratio;
            totalFat += ing.product.fat * ratio;
            totalCarb += ing.product.carbs * ratio;
          }
          setModalState(() {});
        }

        return Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 24,
              left: 20,
              right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Новый рецепт',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextField(
                  controller: nameCtrl,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                      labelText: 'Название рецепта',
                      labelStyle:
                          TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      errorText:
                          nameCtrl.text.trim().length < 2 &&
                                  nameCtrl.text.isNotEmpty
                              ? 'Минимум 2 символа'
                              : null)),
              const SizedBox(height: 12),
              TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                      labelText: 'Описание (необязательно)',
                      labelStyle:
                          TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10))),
              const SizedBox(height: 16),
              Text('Ингредиенты:',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              SizedBox(
                height: 150,
                child: ingredients.isEmpty
                    ? Center(
                        child: Text('Добавьте продукты',
                            style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 13)))
                    : ListView.builder(
                        itemCount: ingredients.length,
                        itemBuilder: (_, i) {
                          final ing = ingredients[i];
                          return Dismissible(
                            key: Key(ing.product.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                                alignment: Alignment.centerRight,
                                padding:
                                    const EdgeInsets.only(right: 16),
                                child: const Icon(Icons.delete,
                                    color: Colors.red)),
                            onDismissed: (_) {
                              ingredients.removeAt(i);
                              setModalState(() {});
                              recalculate();
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: AppColors.card,
                                  borderRadius:
                                      BorderRadius.circular(8)),
                              child: Row(children: [
                                Expanded(
                                    child: Text(ing.product.name,
                                        style: TextStyle(
                                            color: AppColors
                                                .textPrimary))),
                                Text('${ing.amountGrams.toInt()}г',
                                    style: TextStyle(
                                        color: AppColors
                                            .textSecondary)),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final products =
                              await diaryService.getProducts('');
                          if (!ctx.mounted) return;

                          if (products.isEmpty) {
                            ErrorHandler.showGlobal(
                                'Нет доступных продуктов. Создайте продукт сначала');
                            return;
                          }

                          final chosen = await showDialog<Product>(
                            context: ctx,
                            builder: (_) => SimpleDialog(
                              backgroundColor: AppColors.background,
                              title: Text('Выберите продукт',
                                  style: TextStyle(
                                      color: AppColors.textPrimary)),
                              children: products
                                  .map((p) => SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.pop(ctx, p),
                                        child: Text(p.name,
                                            style: TextStyle(
                                                color: AppColors
                                                    .textPrimary)),
                                      ))
                                  .toList(),
                            ),
                          );
                          if (chosen != null && ctx.mounted) {
                            final gramsCtrl =
                                SafeTextEditingController();
                            final gramsStr = await showDialog<String>(
                              context: ctx,
                              builder: (_) => AlertDialog(
                                backgroundColor: AppColors.background,
                                title: Text('Вес (г)',
                                    style: TextStyle(
                                        color: AppColors.textPrimary)),
                                content: TextField(
                                  controller: gramsCtrl,
                                  keyboardType: TextInputType
                                      .numberWithOptions(decimal: true),
                                  autofocus: true,
                                  style: TextStyle(
                                      color: AppColors.textPrimary),
                                  decoration:
                                      InputDecoration(hintText: '100'),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      final text = gramsCtrl.text;
                                      gramsCtrl.dispose();
                                      Navigator.pop(ctx, text);
                                    },
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            );
                            final grams =
                                double.tryParse(gramsStr ?? '') ?? 100;
                            if (grams <= 0) {
                              ErrorHandler.showGlobal(
                                  'Вес должен быть больше 0');
                              return;
                            }
                            ingredients.add(RecipeIngredient(
                                product: chosen, amountGrams: grams));
                            recalculate();
                          }
                        } catch (e) {
                          if (!ctx.mounted) return;
                          ErrorHandler.showGlobal(
                              ErrorHandler.format(e, context: 'search'));
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Из списка'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.backgroundSecondary,
                        foregroundColor: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final tempNameCtrl = SafeTextEditingController();
                        final tempCalCtrl = SafeTextEditingController();
                        final tempWeightCtrl =
                            SafeTextEditingController(text: '100');

                        showDialog(
                          context: ctx,
                          builder: (dCtx) => AlertDialog(
                            backgroundColor: AppColors.background,
                            title: Text('Новый продукт',
                                style: TextStyle(
                                    color: AppColors.textPrimary)),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: tempNameCtrl,
                                  style: TextStyle(
                                      color: AppColors.textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Название',
                                    labelStyle: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(children: [
                                  Expanded(
                                    child: TextField(
                                      controller: tempCalCtrl,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(
                                          color: AppColors.textPrimary),
                                      decoration: InputDecoration(
                                        labelText: 'Ккал/100г',
                                        labelStyle: TextStyle(
                                            color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: tempWeightCtrl,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(
                                      color: AppColors.textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Вес (г)',
                                    labelStyle: TextStyle(
                                        color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  tempNameCtrl.dispose();
                                  tempCalCtrl.dispose();
                                  tempWeightCtrl.dispose();
                                  Navigator.pop(dCtx);
                                },
                                child: const Text('Отмена'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final name = tempNameCtrl.text.trim();
                                  if (name.isEmpty || name.length < 2) {
                                    ErrorHandler.showGlobal(
                                        'Введите название (мин. 2 символа)');
                                    return;
                                  }
                                  final calories =
                                      double.tryParse(tempCalCtrl.text) ?? 0;
                                  final weight =
                                      double.tryParse(tempWeightCtrl.text) ?? 100;

                                  if (calories < 0 || weight <= 0) {
                                    ErrorHandler.showGlobal(
                                        'Проверьте введённые значения');
                                    return;
                                  }

                                  final newP = Product(
                                    id:
                                        'temp_${DateTime.now().millisecondsSinceEpoch}',
                                    name: name,
                                    calories: calories,
                                    protein: 0,
                                    fat: 0,
                                    carbs: 0,
                                  );
                                  tempNameCtrl.dispose();
                                  tempCalCtrl.dispose();
                                  tempWeightCtrl.dispose();
                                  Navigator.pop(dCtx);
                                  ingredients.add(RecipeIngredient(
                                    product: newP,
                                    amountGrams: weight,
                                  ));
                                  recalculate();
                                },
                                child: const Text('Добавить'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Свой'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              'Итого: ${totalCal.toInt()} ккал',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold))),
                      Text('${totalWeight.toInt()} г',
                          style: TextStyle(color: AppColors.accent)),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                          child: Text('Б: ${totalPro.toInt()}г',
                              style: TextStyle(color: Colors.green))),
                      Expanded(
                          child: Text('Ж: ${totalFat.toInt()}г',
                              style: TextStyle(color: Colors.red))),
                      Expanded(
                          child: Text('У: ${totalCarb.toInt()}г',
                              style:
                                  TextStyle(color: Colors.orange))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: ingredients.isEmpty
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) {
                          ErrorHandler.showGlobal(
                              'Введите название рецепта');
                          return;
                        }
                        if (name.length < 2) {
                          ErrorHandler.showGlobal(
                              'Название должно быть не менее 2 символов');
                          return;
                        }
                        if (ingredients.isEmpty) {
                          ErrorHandler.showGlobal(
                              'Добавьте хотя бы один ингредиент');
                          return;
                        }

                        try {
                          final recipe =
                              await diaryService.createRecipe(
                            name: name,
                            description: descCtrl.text,
                            ingredients: ingredients,
                          );
                          if (!ctx.mounted) return;

                          if (recipe != null) {
                            Navigator.pop(context);
                            Future.microtask(() {
                              if (ctx.mounted) {
                                openPortionSelector(
                                    ctx, type, recipe, diaryService);
                                ErrorHandler.showSuccessGlobal(
                                    'Рецепт создан');
                              }
                            });
                          } else {
                            ErrorHandler.showGlobal(
                                'Не удалось создать рецепт. Попробуйте снова');
                          }
                        } catch (e) {
                          if (!ctx.mounted) return;
                          ErrorHandler.showGlobal(
                              ErrorHandler.format(e, context: 'recipe'));
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Сохранить рецепт',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    ),
  ).whenComplete(() {
    nameCtrl.dispose();
    descCtrl.dispose();
  });
}