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
    // 🔥 Инициализируем Future ОДИН РАЗ при создании виджета
    _searchFuture = widget.diaryService.getAllFoodItems('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
                  ? (item as Recipe).baseWeightGrams 
                  : 100.0,
            );
          },
        );
      }
    });
  }

  void _onSearchChanged(String query) {
    // 🔥 Пересоздаём Future только если запрос изменился
    if (query != _lastQuery) {
      _lastQuery = query;
      setState(() {
        _searchFuture = widget.diaryService.getAllFoodItems(query);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      onPressed: () {
                        setState(() {
                          _searchFuture = widget.diaryService
                              .getAllFoodItems(_searchCtrl.text);
                        });
                      },
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
                            controller: _searchCtrl,
                            onChanged: _onSearchChanged,
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
                                      _searchCtrl.text.isEmpty
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
                                    onTap: () => _openPortionSelector(item),
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
    );
  }
}