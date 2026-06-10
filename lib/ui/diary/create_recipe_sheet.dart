import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/error_handler.dart';
import '../../core/safe_text_controller.dart';
import '../../data/diary_service.dart';
import '../../data/models.dart';
import 'create_product_dialog.dart';

void showCreateRecipeSheet({
  required BuildContext ctx,
  required MealType type,
  required DiaryService diaryService,
  required Function(BuildContext, MealType, dynamic, DiaryService)
      openPortionSelector,
  Function(Recipe)? onRecipeCreated,
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
                          if (!context.mounted) return;

                          if (products.isEmpty) {
                            ErrorHandler.showGlobal(
                                'Нет доступных продуктов. Создайте продукт сначала');
                            return;
                          }

                          final chosen = await showDialog<Product>(
                            context: context,
                            builder: (_) => SimpleDialog(
                              backgroundColor: AppColors.background,
                              title: Text('Выберите продукт',
                                  style: TextStyle(
                                      color: AppColors.textPrimary)),
                              children: products
                                  .map((p) => SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.pop(context, p),
                                        child: Text(p.name,
                                            style: TextStyle(
                                                color: AppColors
                                                    .textPrimary)),
                                      ))
                                  .toList(),
                            ),
                          );
                          if (chosen != null && context.mounted) {
                            final grams = await showDialog<double>(
                              context: context,
                              builder: (dialogContext) {
                                final gramsCtrl = SafeTextEditingController(text: '100');
                                return AlertDialog(
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
                                        Navigator.pop(dialogContext);
                                      },
                                      child: const Text('Отмена'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        final gramsValue = double.tryParse(gramsCtrl.text) ?? 100.0;
                                        Navigator.pop(dialogContext, gramsValue);
                                      },
                                      child: const Text('OK'),
                                    ),
                                  ],
                                );
                              },
                            );
                            
                            if (!context.mounted) return;
                            
                            if (grams != null && grams > 0) {
                              ingredients.add(RecipeIngredient(
                                  product: chosen, amountGrams: grams));
                              recalculate();
                            } else {
                              ErrorHandler.showGlobal(
                                  'Вес должен быть больше 0');
                            }
                          }
                        } catch (e) {
                          if (!context.mounted) return;
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
                        showCreateProductDialog(
                          ctx: context,
                          type: type,
                          diaryService: diaryService,
                          openPortionSelector: openPortionSelector,
                          onProductCreated: (Product newProduct) {
                            final weightCtrl = SafeTextEditingController(text: '100');
                            
                            showDialog(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                backgroundColor: AppColors.background,
                                title: Text('Вес продукта (г)',
                                    style: TextStyle(
                                        color: AppColors.textPrimary)),
                                content: TextField(
                                  controller: weightCtrl,
                                  keyboardType: TextInputType.number,
                                  autofocus: true,
                                  style: TextStyle(
                                      color: AppColors.textPrimary),
                                  decoration: InputDecoration(
                                      hintText: '100'),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                    },
                                    child: const Text('Отмена'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      final weight = double.tryParse(weightCtrl.text) ?? 100.0;
                                      if (weight > 0) {
                                        ingredients.add(RecipeIngredient(
                                          product: newProduct,
                                          amountGrams: weight,
                                        ));
                                        recalculate();
                                      }
                                      if (dialogContext.mounted) {
                                        Navigator.pop(dialogContext);
                                      }
                                    },
                                    child: const Text('Добавить'),
                                  ),
                                ],
                              ),
                            );
                          },
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
                        final description = descCtrl.text;
                        
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
                            description: description,
                            ingredients: ingredients,
                          );
                          
                          if (context.mounted) {
                            Navigator.pop(context);
                          }

                          if (recipe != null) {
                            ErrorHandler.showSuccessGlobal(
                                'Рецепт создан');
                            
                            // 🔥 Просто возвращаемся назад, без модалки выбора порции
                            if (onRecipeCreated != null) {
                              await Future.delayed(const Duration(milliseconds: 300));
                              onRecipeCreated(recipe);
                            }
                          } else {
                            ErrorHandler.showGlobal(
                                'Не удалось создать рецепт. Попробуйте снова');
                          }
                        } catch (e) {
                          if (!context.mounted) return;
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
  );
}

// ============================================
// 🔥 РЕДАКТИРОВАНИЕ РЕЦЕПТА
// ============================================
void showEditRecipeDialog({
  required BuildContext ctx,
  required Recipe recipe,
  required DiaryService diaryService,
  required Function() onUpdated,
}) {
  final nameCtrl = SafeTextEditingController(text: recipe.name);
  final descCtrl = SafeTextEditingController(text: recipe.description);
  List<RecipeIngredient> ingredients = List.from(recipe.ingredients);
  double totalCal = recipe.totalCalories;
  double totalPro = recipe.totalProtein;
  double totalFat = recipe.totalFat;
  double totalCarb = recipe.totalCarbs;
  double totalWeight = recipe.baseWeightGrams;

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
              Text('Редактировать рецепт',
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
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10))),
              const SizedBox(height: 12),
              TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                      labelText: 'Описание (необязательно)',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
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
                                color: AppColors.textHint, fontSize: 13)))
                    : ListView.builder(
                        itemCount: ingredients.length,
                        itemBuilder: (_, i) {
                          final ing = ingredients[i];
                          return Dismissible(
                            key: Key(ing.product.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                child: const Icon(Icons.delete, color: Colors.red)),
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
                                  borderRadius: BorderRadius.circular(8)),
                              child: Row(children: [
                                Expanded(
                                    child: Text(ing.product.name,
                                        style: TextStyle(
                                            color: AppColors.textPrimary))),
                                Text('${ing.amountGrams.toInt()}г',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)),
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
                          final products = await diaryService.getProducts('');
                          if (!context.mounted) return;

                          if (products.isEmpty) {
                            ErrorHandler.showGlobal(
                                'Нет доступных продуктов. Создайте продукт сначала');
                            return;
                          }

                          final chosen = await showDialog<Product>(
                            context: context,
                            builder: (_) => SimpleDialog(
                              backgroundColor: AppColors.background,
                              title: Text('Выберите продукт',
                                  style: TextStyle(
                                      color: AppColors.textPrimary)),
                              children: products
                                  .map((p) => SimpleDialogOption(
                                        onPressed: () =>
                                            Navigator.pop(context, p),
                                        child: Text(p.name,
                                            style: TextStyle(
                                                color: AppColors.textPrimary)),
                                      ))
                                  .toList(),
                            ),
                          );
                          if (chosen != null && context.mounted) {
                            final grams = await showDialog<double>(
                              context: context,
                              builder: (dialogContext) {
                                final gramsCtrl = SafeTextEditingController(text: '100');
                                return AlertDialog(
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
                                    decoration: InputDecoration(hintText: '100'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(dialogContext);
                                      },
                                      child: const Text('Отмена'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        final gramsValue = double.tryParse(gramsCtrl.text) ?? 100.0;
                                        Navigator.pop(dialogContext, gramsValue);
                                      },
                                      child: const Text('OK'),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (!context.mounted) return;

                            if (grams != null && grams > 0) {
                              ingredients.add(RecipeIngredient(
                                  product: chosen, amountGrams: grams));
                              recalculate();
                            } else {
                              ErrorHandler.showGlobal('Вес должен быть больше 0');
                            }
                          }
                        } catch (e) {
                          if (!context.mounted) return;
                          ErrorHandler.showGlobal(
                              ErrorHandler.format(e, context: 'search'));
                        }
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Добавить'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.backgroundSecondary,
                        foregroundColor: AppColors.textPrimary,
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
                          child: Text('Итого: ${totalCal.toInt()} ккал',
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
                              style: TextStyle(color: Colors.orange))),
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
                          ErrorHandler.showGlobal('Введите название рецепта');
                          return;
                        }
                        if (name.length < 2) {
                          ErrorHandler.showGlobal(
                              'Название должно быть не менее 2 символов');
                          return;
                        }

                        try {
                          final success = await diaryService.updateRecipe(
                            id: recipe.id,
                            name: name,
                            description: descCtrl.text,
                            ingredients: ingredients,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                          }

                          if (success) {
                            ErrorHandler.showSuccessGlobal('Рецепт обновлён');
                            onUpdated();
                          } else {
                            ErrorHandler.showGlobal(
                                'Не удалось обновить рецепт');
                          }
                        } catch (e) {
                          if (!context.mounted) return;
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
                child: Text('Сохранить изменения',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    ),
  );
}