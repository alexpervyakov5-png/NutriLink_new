import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/error_handler.dart';
import '../../core/safe_text_controller.dart';
import '../../data/diary_service.dart';
import '../../data/models.dart';
import 'create_product_dialog.dart';
import 'create_recipe_sheet.dart';
import 'portion_selector.dart';

void showFoodSearchSheet({
  required BuildContext ctx,
  required MealType type,
}) {
  final searchCtrl = SafeTextEditingController();
  final diaryService = ctx.read<DiaryService>();

  void openPortionSelector(
      BuildContext ctx, MealType type, dynamic item, DiaryService svc) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      builder: (sheetContext) {
        return PortionSelectorContent(
          sheetContext: sheetContext,
          ctx: ctx,
          type: type,
          item: item,
          diaryService: svc,
          isRecipe: item is Recipe,
          baseValue: item is Recipe ? item.baseWeightGrams : 100.0,
        );
      },
    );
  }

  showModalBottomSheet(
    context: ctx,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setModalState) {
        return FutureBuilder<List<dynamic>>(
          future: diaryService
              .getAllFoodItems(searchCtrl.text)
              .catchError((e) {
                debugPrint('❌ Search error: $e');
                return <dynamic>[];
              }),
          builder: (ctx, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      ErrorHandler.format(snapshot.error, context: 'search'),
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setModalState(() {}),
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              );
            }

            final items = snapshot.data ?? [];
            return Container(
              height: MediaQuery.of(ctx).size.height * 0.85,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: searchCtrl,
                            onChanged: (_) => setModalState(() {}),
                            style:
                                TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Поиск еды...',
                              hintStyle:
                                  TextStyle(color: AppColors.textHint),
                              border: InputBorder.none,
                              icon: Icon(Icons.search,
                                  color: AppColors.accent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        icon: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.add,
                              color: Colors.black, size: 24),
                        ),
                        onSelected: (value) {
                          Navigator.of(sheetContext).pop();
                          Future.microtask(() {
                            if (ctx.mounted) {
                              if (value == 'product') {
                                showCreateProductDialog(
                                  ctx: ctx,
                                  type: type,
                                  diaryService: diaryService,
                                  openPortionSelector: openPortionSelector,
                                );
                              } else {
                                showCreateRecipeSheet(
                                  ctx: ctx,
                                  type: type,
                                  diaryService: diaryService,
                                  openPortionSelector: openPortionSelector,
                                );
                              }
                            }
                          });
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'product',
                            child: Row(
                              children: [
                                Icon(Icons.restaurant,
                                    color: AppColors.accent),
                                const SizedBox(width: 8),
                                Text('Новый продукт',
                                    style: TextStyle(
                                        color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'recipe',
                            child: Row(
                              children: [
                                Icon(Icons.menu_book,
                                    color: AppColors.accentLight),
                                const SizedBox(width: 8),
                                Text('Новый рецепт',
                                    style: TextStyle(
                                        color: AppColors.textPrimary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: snapshot.connectionState ==
                            ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off,
                                        size: 48,
                                        color: AppColors.textHint),
                                    const SizedBox(height: 12),
                                    Text(
                                      searchCtrl.text.isEmpty
                                          ? 'Начните вводить название продукта'
                                          : 'Ничего не найдено',
                                      style: TextStyle(
                                          color: AppColors.textSecondary),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: items.length,
                                itemBuilder: (ctx, i) {
                                  final item = items[i];
                                  final isRecipe = item is Recipe;
                                  final name = isRecipe
                                      ? ' ${item.name}'
                                      : item.name;
                                  final subtitle = isRecipe
                                      ? '${item.totalCalories.toInt()} ккал • ${item.baseWeightGrams.toInt()}г'
                                      : '${item.calories.toInt()} ккал/100г';

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(name,
                                        style: TextStyle(
                                            color:
                                                AppColors.textPrimary)),
                                    subtitle: Text(subtitle,
                                        style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12)),
                                    onTap: () {
                                      Navigator.of(sheetContext).pop();
                                      Future.microtask(() {
                                        if (ctx.mounted) {
                                          openPortionSelector(
                                            ctx,
                                            type,
                                            item,
                                            diaryService,
                                          );
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  ).whenComplete(() {
    searchCtrl.dispose();
  });
}