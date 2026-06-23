import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/error_handler.dart';
import '../../core/safe_text_controller.dart';
import '../../data/diary_service.dart';
import '../../data/clients_service.dart';
import '../../data/models.dart';
import 'create_product_dialog.dart';
import 'create_recipe_sheet.dart';
import 'portion_selector.dart';

void showFoodSearchSheet({
  required BuildContext ctx,
  required MealType type,
}) {
  final diaryService = ctx.read<DiaryService>();

  showModalBottomSheet(
    context: ctx,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    builder: (sheetContext) => _FoodSearchContent(
      sheetContext: sheetContext,
      ctx: ctx,
      type: type,
      diaryService: diaryService,
    ),
  );
}

class _FoodSearchContent extends StatefulWidget {
  final BuildContext sheetContext;
  final BuildContext ctx;
  final MealType type;
  final DiaryService diaryService;

  const _FoodSearchContent({
    required this.sheetContext,
    required this.ctx,
    required this.type,
    required this.diaryService,
  });

  @override
  State<_FoodSearchContent> createState() => _FoodSearchContentState();
}

class _FoodSearchContentState extends State<_FoodSearchContent> {
  late final SafeTextEditingController _searchCtrl;
  late Future<List<dynamic>> _searchFuture;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = SafeTextEditingController();
    _searchFuture = widget.diaryService.getAllFoodItems('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reloadList() {
    setState(() {
      _searchFuture = widget.diaryService.getAllFoodItems(_searchCtrl.text);
    });
  }

  void _openPortionSelector(dynamic item) {
    if (mounted && widget.sheetContext.mounted) {
      Navigator.of(widget.sheetContext).pop();
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      if (widget.ctx.mounted) {
        showModalBottomSheet(
          context: widget.ctx,
          backgroundColor: AppColors.background,
          isScrollControlled: true,
          builder: (portionContext) {
            return PortionSelectorContent(
              sheetContext: portionContext,
              ctx: widget.ctx,
              type: widget.type,
              item: item,
              diaryService: widget.diaryService,
              isRecipe: item is Recipe,
              baseValue: item is Recipe
                  ? item.baseWeightGrams
                  : 100.0,
            );
          },
        );
      }
    });
  }

  void _showDeleteProductConfirmation(Product product) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Удалить продукт?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Вы уверены, что хотите удалить "${product.name}"?\n\nЭтот продукт будет удалён из общего списка.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: Text('Отмена', style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              final success = await widget.diaryService.deleteProduct(product.id);

              if (success) {
                ErrorHandler.showSuccessGlobal('Продукт удалён');
                _reloadList();
              } else {
                ErrorHandler.showGlobal('Не удалось удалить продукт');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _showDeleteRecipeConfirmation(Recipe recipe) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(
          'Удалить рецепт?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Вы уверены, что хотите удалить "${recipe.name}"?\n\nЭтот рецепт будет удалён из общего списка.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: Text('Отмена', style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }

              final success = await widget.diaryService.deleteRecipe(recipe.id);

              if (success) {
                ErrorHandler.showSuccessGlobal('Рецепт удалён');
                _reloadList();
              } else {
                ErrorHandler.showGlobal('Не удалось удалить рецепт');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(Product product) {
    showEditProductDialog(
      ctx: context,
      product: product,
      diaryService: widget.diaryService,
      onUpdated: _reloadList,
    );
  }

  void _showEditRecipeDialog(Recipe recipe) {
    showEditRecipeDialog(
      ctx: context,
      recipe: recipe,
      diaryService: widget.diaryService,
      onUpdated: _reloadList,
    );
  }

  void _onSearchChanged(String query) {
    if (query != _lastQuery) {
      _lastQuery = query;
      setState(() {
        _searchFuture = widget.diaryService.getAllFoodItems(query);
      });
    }
  }

  bool _isOwnedByUser(dynamic item, String? userId) {
    if (userId == null) return false;
    if (item is Product) return item.userId == userId;
    if (item is Recipe) return item.userId == userId;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final clientsSvc = context.watch<ClientsService>();
    final canEdit = clientsSvc.isViewingOwnData;
    final currentUserId = clientsSvc.selectedUserId;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return FutureBuilder<List<dynamic>>(
          future: _searchFuture,
          builder: (ctx, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      ErrorHandler.format(snapshot.error, context: 'search'),
                      style: TextStyle(color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _reloadList(),
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
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: _onSearchChanged,
                            style: TextStyle(color: AppColors.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Поиск еды...',
                              hintStyle: TextStyle(color: AppColors.textHint),
                              border: InputBorder.none,
                              icon: Icon(Icons.search, color: AppColors.accent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (canEdit)
                        PopupMenuButton<String>(
                          icon: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.add, color: Colors.black, size: 24),
                          ),
                          onSelected: (value) {
                            if (widget.sheetContext.mounted) {
                              Navigator.of(widget.sheetContext).pop();
                            }
                            Future.microtask(() {
                              if (widget.ctx.mounted) {
                                if (value == 'product') {
                                  showCreateProductDialog(
                                    ctx: widget.ctx,
                                    type: widget.type,
                                    diaryService: widget.diaryService,
                                    openPortionSelector: (c, t, item, svc) {
                                      Navigator.of(c).pop();
                                      _openPortionSelector(item);
                                    },
                                  );
                                } else {
                                  showCreateRecipeSheet(
                                    ctx: widget.ctx,
                                    type: widget.type,
                                    diaryService: widget.diaryService,
                                    openPortionSelector: (c, t, item, svc) {
                                      Navigator.of(c).pop();
                                      _openPortionSelector(item);
                                    },
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
                                  Icon(Icons.restaurant, color: AppColors.accent),
                                  const SizedBox(width: 8),
                                  Text('Новый продукт',
                                      style: TextStyle(color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'recipe',
                              child: Row(
                                children: [
                                  Icon(Icons.menu_book, color: AppColors.accentLight),
                                  const SizedBox(width: 8),
                                  Text('Новый рецепт',
                                      style: TextStyle(color: AppColors.textPrimary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (canEdit)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Свайп ← удалить • Долгое нажатие — редактировать',
                              style: TextStyle(
                                color: AppColors.textHint,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator())
                        : items.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off,
                                        size: 48, color: AppColors.textHint),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchCtrl.text.isEmpty
                                          ? 'Начните вводить название продукта'
                                          : 'Ничего не найдено',
                                      style: TextStyle(color: AppColors.textSecondary),
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
                                  final isProduct = item is Product;
                                  final name = isRecipe ? '🍳 ${item.name}' : item.name;
                                  final subtitle = isRecipe
                                      ? '${item.totalCalories.toInt()} ккал • ${item.baseWeightGrams.toInt()}г'
                                      : '${item.calories.toInt()} ккал/100г • Б:${item.protein.toInt()} Ж:${item.fat.toInt()} У:${item.carbs.toInt()}';

                                  final isOwned = _isOwnedByUser(item, currentUserId);
                                  final canEditItem = canEdit && isOwned;

                                  Widget tile = Padding(
                                    // 🔥 ИСПРАВЛЕНО: используем Padding вместо margin
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: ListTile(
                                      tileColor: AppColors.backgroundSecondary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 4),
                                      leading: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          isRecipe ? Icons.restaurant_menu : Icons.restaurant,
                                          color: AppColors.accent,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(name,
                                          style: TextStyle(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w500)),
                                      subtitle: Text(subtitle,
                                          style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12)),
                                      trailing: canEditItem
                                          ? Icon(Icons.edit_outlined,
                                              color: AppColors.textHint, size: 20)
                                          : null,
                                      onTap: () => _openPortionSelector(item),
                                      onLongPress: canEditItem
                                          ? () {
                                              if (isProduct) {
                                                _showEditProductDialog(item);
                                              } else if (isRecipe) {
                                                _showEditRecipeDialog(item);
                                              }
                                            }
                                          : null,
                                    ),
                                  );

                                  if (canEditItem && (isProduct || isRecipe)) {
                                    tile = Dismissible(
                                      key: Key('${isProduct ? "product" : "recipe"}_${item.id}'),
                                      direction: DismissDirection.endToStart,
                                      confirmDismiss: (direction) async {
                                        if (isProduct) {
                                          _showDeleteProductConfirmation(item);
                                        } else if (isRecipe) {
                                          _showDeleteRecipeConfirmation(item);
                                        }
                                        return false;
                                      },
                                      background: Container(
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 16),
                                        margin: const EdgeInsets.symmetric(vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            const Icon(Icons.delete_outline,
                                                color: Colors.red, size: 24),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Удалить',
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                        ),
                                      ),
                                      child: tile,
                                    );
                                  }

                                  return tile;
                                },
                              ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}