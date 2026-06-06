import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../core/config.dart';
import '../core/error_handler.dart';
import '../core/safe_text_controller.dart';
import '../data/diary_service.dart';
import '../data/models.dart';
import 'widgets.dart';

// ==========================================
// ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
// ==========================================

bool _isSameDate(DateTime a, DateTime? b) =>
    b != null && a.year == b.year && a.month == b.month && a.day == b.day;

// ==========================================
// DiaryScreen
// ==========================================
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isInitialized = false;
  DateTime? _lastLoadedDate;

  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized || !_isSameDate(DateTime.now(), _lastLoadedDate)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<DiaryService>().refresh();
          _lastLoadedDate = DateTime.now();
          _isInitialized = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final svc = context.watch<DiaryService>();
    final images = {
      'Завтрак': '${AppStrings.assetImages}breakfast.png',
      'Обед': '${AppStrings.assetImages}lunch.png',
      'Ужин': '${AppStrings.assetImages}dinner.png',
      'Перекус': '${AppStrings.assetImages}snack.png',
    };

    final goalsWidget = svc.loadingGoals
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(
                color: AppColors.accent,
                strokeWidth: 2,
              ),
            ),
          )
        : svc.goals != null
            ? GoalsSection(goals: svc.goals!)
            : const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await svc.refresh();
          if (mounted) {
            ErrorHandler.showSuccessGlobal('Данные обновлены');
          }
        },
        color: AppColors.accent,
        child: Column(
          children: [
            _Header(
              date: svc.date,
              onDatePick: (DateTime? d) {
                if (d != null) {
                  _isInitialized = false;
                  _lastLoadedDate = d;
                  svc.load(d);
                }
              },
            ),
            goalsWidget,
            Expanded(
              child: svc.loading && svc.meals.values.every((m) => m.isEmpty)
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: MealType.values.map((t) {
                        return MealSection(
                          key: ValueKey(t),
                          title: t.label,
                          imagePath: images[t.label]!,
                          totalCalories:
                              svc.meals[t]!.fold(0, (s, m) => s + m.calories),
                          isExpanded: svc.expanded[t] ?? false,
                          onExpansionChanged: () => svc.toggle(t),
                          onCommentTap: () => _showComment(ctx: context, type: t),
                          onAddTap: () => _openFoodSearch(ctx: context, type: t),
                          items: svc.meals[t]!,
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // КОММЕНТАРИЙ
  // ==========================================
  void _showComment({required BuildContext ctx, required MealType type}) {
    final svc = ctx.read<DiaryService>();
    final currentComment = svc.getCommentForType(type) ??
        svc.meals[type]?.firstOrNull?.comment ??
        '';

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _CommentBottomSheet(
        mealType: type,
        initialComment: currentComment,
        onSave: (String? newComment) async {
          if (sheetContext.mounted) {
            Navigator.pop(sheetContext);
          }

          try {
            final success = await svc.updateComment(
              type: type,
              date: svc.date,
              comment: newComment,
            );
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!success) {
                ErrorHandler.showGlobal('Не удалось сохранить комментарий');
              }
            });
          } catch (e) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ErrorHandler.showGlobal(
                ErrorHandler.format(e, context: 'comment'),
              );
            });
          }
        },
      ),
    );
  }

  // ==========================================
  // ПОИСК ЕДЫ (продукты + рецепты)
  // ==========================================
  void _openFoodSearch({required BuildContext ctx, required MealType type}) {
    final searchCtrl = SafeTextEditingController();
    final diaryService = ctx.read<DiaryService>();

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
                              style: TextStyle(color: AppColors.textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Поиск еды...',
                                hintStyle:
                                    TextStyle(color: AppColors.textHint),
                                border: InputBorder.none,
                                icon:
                                    Icon(Icons.search, color: AppColors.accent),
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
                                  _openCreateProductForm(
                                      ctx: ctx,
                                      type: type,
                                      diaryService: diaryService);
                                } else {
                                  _openRecipeBuilder(
                                      ctx: ctx,
                                      type: type,
                                      diaryService: diaryService);
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
                                    final name =
                                        isRecipe ? ' ${item.name}' : item.name;
                                    final subtitle = isRecipe
                                        ? '${item.totalCalories.toInt()} ккал • ${item.baseWeightGrams.toInt()}г'
                                        : '${item.calories.toInt()} ккал/100г';

                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(name,
                                          style: TextStyle(
                                              color: AppColors.textPrimary)),
                                      subtitle: Text(subtitle,
                                          style: TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12)),
                                      onTap: () {
                                        Navigator.of(sheetContext).pop();
                                        Future.microtask(() {
                                          if (ctx.mounted) {
                                            _openPortionSelector(
                                              ctx: ctx,
                                              type: type,
                                              item: item,
                                              diaryService: diaryService,
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

  // ==========================================
  // ВЫБОР ПОРЦИИ
  // ==========================================
  void _openPortionSelector({
    required BuildContext ctx,
    required MealType type,
    required dynamic item,
    required DiaryService diaryService,
  }) {
    final isRecipe = item is Recipe;
    final baseValue = isRecipe ? item.baseWeightGrams : 100.0;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      builder: (sheetContext) {
        return _PortionSelectorContent(
          sheetContext: sheetContext,
          ctx: ctx,
          type: type,
          item: item,
          diaryService: diaryService,
          isRecipe: isRecipe,
          baseValue: baseValue,
        );
      },
    );
  }

  // ==========================================
  // СОЗДАНИЕ ПРОДУКТА
  // ==========================================
  void _openCreateProductForm({
    required BuildContext ctx,
    required MealType type,
    required DiaryService diaryService,
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              _buildLabeledInput(nameCtrl, 'Название продукта', validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите название';
                }
                if (v.trim().length < 2) {
                  return 'Минимум 2 символа';
                }
                return null;
              }),
              const SizedBox(height: 16),
              _buildLabeledInput(calCtrl, 'Калории (ккал/100г)',
                  isNumber: true, validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null) {
                  return 'Введите число';
                }
                if (val < 0) {
                  return 'Не может быть отрицательным';
                }
                if (val > 10000) {
                  return 'Слишком большое значение';
                }
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
                    child: _buildMacroInput(proCtrl, 'Белки', 'г',
                        isNumber: true, validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null) {
                    return 'Число';
                  }
                  if (val < 0) {
                    return 'Не отрицательное';
                  }
                  return null;
                })),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildMacroInput(fatCtrl, 'Жиры', 'г',
                        isNumber: true, validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null) {
                    return 'Число';
                  }
                  if (val < 0) {
                    return 'Не отрицательное';
                  }
                  return null;
                })),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildMacroInput(carbCtrl, 'Углеводы', 'г',
                        isNumber: true, validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null) {
                    return 'Число';
                  }
                  if (val < 0) {
                    return 'Не отрицательное';
                  }
                  return null;
                })),
              ]),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: TextButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 14)),
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
                        ErrorHandler.show(
                            ctx, 'Введите название продукта');
                        return;
                      }
                      if (name.length < 2) {
                        ErrorHandler.show(ctx,
                            'Название должно быть не менее 2 символов');
                        return;
                      }

                      final calories =
                          double.tryParse(calCtrl.text) ?? 0;
                      final protein =
                          double.tryParse(proCtrl.text) ?? 0;
                      final fat = double.tryParse(fatCtrl.text) ?? 0;
                      final carbs =
                          double.tryParse(carbCtrl.text) ?? 0;

                      if (calories < 0 ||
                          protein < 0 ||
                          fat < 0 ||
                          carbs < 0) {
                        ErrorHandler.show(
                            ctx, 'Значения не могут быть отрицательными');
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

                        if (!dialogContext.mounted) {
                          return;
                        }

                        if (newP != null) {
                          Navigator.of(dialogContext).pop();
                          Future.microtask(() {
                            if (ctx.mounted) {
                              _openPortionSelector(
                                ctx: ctx,
                                type: type,
                                item: newP,
                                diaryService: diaryService,
                              );
                              ErrorHandler.showSuccessGlobal('Продукт создан');
                            }
                          });
                        } else {
                          ErrorHandler.showGlobal(
                              'Не удалось создать продукт. Попробуйте снова');
                        }
                      } catch (e) {
                        if (!dialogContext.mounted) {
                          return;
                        }
                        ErrorHandler.showGlobal(
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
    ).then((_) {
      nameCtrl.dispose();
      calCtrl.dispose();
      proCtrl.dispose();
      fatCtrl.dispose();
      carbCtrl.dispose();
    });
  }

  // ==========================================
  // КОНСТРУКТОР РЕЦЕПТОВ
  // ==========================================
  void _openRecipeBuilder({
    required BuildContext ctx,
    required MealType type,
    required DiaryService diaryService,
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
                        errorText: nameCtrl.text.trim().length < 2 &&
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
                            if (!ctx.mounted) {
                              return;
                            }

                            if (products.isEmpty) {
                              ErrorHandler.showGlobal(
                                  'Нет доступных продуктов. Создайте продукт сначала');
                              return;
                            }

                            final chosen =
                                await showDialog<Product>(
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
                                    decoration: InputDecoration(
                                      hintText: '100',
                                    ),
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
                            if (!ctx.mounted) {
                              return;
                            }
                            ErrorHandler.showGlobal(
                                ErrorHandler.format(e,
                                    context: 'search'));
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
                                        keyboardType:
                                            TextInputType.number,
                                        style: TextStyle(
                                            color: AppColors.textPrimary),
                                        decoration: InputDecoration(
                                          labelText: 'Ккал/100г',
                                          labelStyle: TextStyle(
                                              color:
                                                  AppColors.textSecondary),
                                        ),
                                      ),
                                    ),
                                  ]),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: tempWeightCtrl,
                                    keyboardType:
                                        TextInputType.number,
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
                                    if (name.isEmpty ||
                                        name.length < 2) {
                                      ErrorHandler.showGlobal(
                                          'Введите название (мин. 2 символа)');
                                      return;
                                    }
                                    final calories =
                                        double.tryParse(tempCalCtrl.text) ??
                                            0;
                                    final weight =
                                        double.tryParse(tempWeightCtrl.text) ??
                                            100;

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
                            style:
                                TextStyle(color: AppColors.accent)),
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
                            if (!ctx.mounted) {
                              return;
                            }

                            if (recipe != null) {
                              Navigator.pop(context);
                              Future.microtask(() {
                                if (ctx.mounted) {
                                  _openPortionSelector(
                                    ctx: ctx,
                                    type: type,
                                    item: recipe,
                                    diaryService: diaryService,
                                  );
                                  ErrorHandler.showSuccessGlobal(
                                      'Рецепт создан');
                                }
                              });
                            } else {
                              ErrorHandler.showGlobal(
                                  'Не удалось создать рецепт. Попробуйте снова');
                            }
                          } catch (e) {
                            if (!ctx.mounted) {
                              return;
                            }
                            ErrorHandler.showGlobal(
                                ErrorHandler.format(e,
                                    context: 'recipe'));
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

  // ==========================================
  // ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ
  // ==========================================
  Widget _buildLabeledInput(SafeTextEditingController ctrl, String label,
      {bool isNumber = false, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: ctrl,
            keyboardType: isNumber
                ? TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style:
                TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 12),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroInput(SafeTextEditingController ctrl, String label,
      String unit,
      {bool isNumber = false, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: ctrl,
            keyboardType: isNumber
                ? TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style:
                TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              suffixText: unit,
              suffixStyle:
                  TextStyle(color: AppColors.textHint, fontSize: 12),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// НОВЫЙ ВИДЖЕТ ДЛЯ КОММЕНТАРИЯ (Stateful)
// ==========================================
class _CommentBottomSheet extends StatefulWidget {
  final MealType mealType;
  final String initialComment;
  final Function(String?) onSave;
  
  const _CommentBottomSheet({
    required this.mealType,
    required this.initialComment,
    required this.onSave,
  });
  
  @override
  State<_CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<_CommentBottomSheet> {
  late final SafeTextEditingController _ctrl;
  
  @override
  void initState() {
    super.initState();
    _ctrl = SafeTextEditingController(text: widget.initialComment);
  }
  
  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Комментарий к ${widget.mealType.label}',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _ctrl,
              maxLines: 3,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Например: с маслом',
                hintStyle: TextStyle(color: AppColors.textHint),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final newComment = _ctrl.text.trim().isEmpty
                  ? null
                  : _ctrl.text.trim();
              widget.onSave(newComment);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// НОВЫЙ ВИДЖЕТ ДЛЯ ВЫБОРА ПОРЦИИ (Stateful)
// ==========================================
class _PortionSelectorContent extends StatefulWidget {
  final BuildContext sheetContext;
  final BuildContext ctx;
  final MealType type;
  final dynamic item;
  final DiaryService diaryService;
  final bool isRecipe;
  final double baseValue;

  const _PortionSelectorContent({
    required this.sheetContext,
    required this.ctx,
    required this.type,
    required this.item,
    required this.diaryService,
    required this.isRecipe,
    required this.baseValue,
  });

  @override
  State<_PortionSelectorContent> createState() => _PortionSelectorContentState();
}

class _PortionSelectorContentState extends State<_PortionSelectorContent> {
  late SafeTextEditingController _weightCtrl;
  late SafeTextEditingController _unitCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final baseValue = widget.isRecipe 
        ? (widget.item as Recipe).baseWeightGrams 
        : 100.0;
    _weightCtrl = SafeTextEditingController(text: baseValue.toInt().toString());
    _unitCtrl = SafeTextEditingController(text: 'г');
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weightStr = _weightCtrl.text.replaceAll(RegExp(r'\D'), '');
    double weight = weightStr.isEmpty
        ? widget.baseValue
        : (double.tryParse(weightStr) ?? widget.baseValue);

    double currentCal, currentPro, currentFat, currentCarb;

    if (widget.isRecipe) {
      final recipe = widget.item;
      double scale = weight / recipe.baseWeightGrams;
      currentCal = recipe.totalCalories * scale;
      currentPro = recipe.totalProtein * scale;
      currentFat = recipe.totalFat * scale;
      currentCarb = recipe.totalCarbs * scale;
    } else {
      final product = widget.item;
      double ratio = weight / 100.0;
      currentCal = product.calories * ratio;
      currentPro = product.protein * ratio;
      currentFat = product.fat * ratio;
      currentCarb = product.carbs * ratio;
    }

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.isRecipe ? ' ${widget.item.name}' : widget.item.name,
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
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
                    controller: _weightCtrl,
                    onChanged: (_) => setState(() {}),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      errorText: weight <= 0 ? 'Введите вес больше 0' : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _unitCtrl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                    ),
                    decoration: InputDecoration(border: InputBorder.none),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Text('Сохранить',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: _NutrientCard('Калории', currentCal.toInt())),
                  const SizedBox(width: 8),
                  Expanded(child: _NutrientCard('Жиры', currentFat))
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _NutrientCard('Углеводы', currentCarb)),
                  const SizedBox(width: 8),
                  Expanded(child: _NutrientCard('Белки', currentPro))
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // 🔥 ИСПРАВЛЕНО: finally блок для закрытия модалки
  // ============================================
  Future<void> _handleSave() async {
    // 🔥 Сохраняем значения ДО async операции
    final weightStr = _weightCtrl.text.replaceAll(RegExp(r'\D'), '');
    final portionGrams = weightStr.isEmpty
        ? widget.baseValue
        : (double.tryParse(weightStr) ?? widget.baseValue);

    if (portionGrams <= 0) {
      if (mounted) {
        ErrorHandler.show(widget.sheetContext, 'Вес должен быть больше 0');
      }
      return;
    }
    if (portionGrams > 10000) {
      if (mounted) {
        ErrorHandler.show(widget.sheetContext, 'Вес не может быть больше 10 кг');
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final success = await widget.diaryService.addFoodItemToMeal(
        type: widget.type,
        item: widget.item,
        portionGrams: portionGrams,
      );

      // 🔥 Проверяем mounted перед закрытием
      if (!mounted) return;
      
      // 🔥 Закрываем модалку
      // ignore: use_build_context_synchronously
      Navigator.of(widget.sheetContext).pop();

      // 🔥 Показываем уведомление
      if (success) {
        ErrorHandler.showSuccessGlobal('Добавлено в дневник');
      } else {
        ErrorHandler.showGlobal('Не удалось добавить. Попробуйте снова');
      }
    } catch (e) {
      debugPrint('❌ Add food item error: $e');
      
      // 🔥 Закрываем модалку только если ещё не закрыта
      if (mounted && widget.sheetContext.mounted) {
        try {
          Navigator.of(widget.sheetContext).pop();
        } catch (_) {
          // Модалка уже закрыта
        }
      }
      
      // 🔥 Показываем ошибку
      ErrorHandler.showGlobal(
        ErrorHandler.format(e, context: 'meal'),
      );
    } finally {
      // 🔥 Сбрасываем isLoading ТОЛЬКО если виджет ещё активен
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

// ==========================================
// HEADER
// ==========================================
class _Header extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime?> onDatePick;
  const _Header({required this.date, required this.onDatePick});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: AppColors.backgroundSecondary, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('День',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Text(
            '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500),
          ),
          GestureDetector(
            onTap: () => showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            ).then((DateTime? d) {
              if (d != null) {
                if (context.mounted) {
                  onDatePick(d);
                }
              }
            }),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.calendar_today,
                  color: AppColors.textPrimary, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrientCard extends StatelessWidget {
  final String label;
  final num value;
  const _NutrientCard(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style:
                    TextStyle(color: AppColors.textHint, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value.toStringAsFixed(1),
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      );
}