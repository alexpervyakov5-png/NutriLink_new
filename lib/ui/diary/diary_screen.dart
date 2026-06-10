import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/error_handler.dart';
import '../../data/diary_service.dart';
import '../../data/clients_service.dart';
import '../../data/models.dart';
import '../widgets.dart';
import 'comment_bottom_sheet.dart';
import 'diary_header.dart';
import 'food_search_sheet.dart';
import 'goals_edit_sheet.dart';

bool _isSameDate(DateTime a, DateTime? b) =>
    b != null && a.year == b.year && a.month == b.month && a.day == b.day;

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
          final diaryService = context.read<DiaryService>();
          diaryService.refresh();
          diaryService.preloadFoodItems();
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
    final clientsSvc = context.watch<ClientsService>();
    final isViewingClient = clientsSvc.isViewingClient;
    final canEdit = clientsSvc.isViewingOwnData;
    final clientName = clientsSvc.selectedClient?.name;

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
            ? Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: GoalsSection(
                  goals: svc.goals!,
                  onTap: () => showGoalsEditSheet(
                    ctx: context,
                    initialProtein: svc.goals!.proteinTarget,
                    initialFat: svc.goals!.fatsTarget,
                    initialCarbs: svc.goals!.carbsTarget,
                    initialCalories: svc.goals!.caloriesTarget,
                    date: svc.date,
                  ),
                ),
              )
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
            if (isViewingClient)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                color: AppColors.accent.withValues(alpha: 0.15),
                child: Row(
                  children: [
                    Icon(Icons.visibility,
                        color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Просмотр клиента: $clientName',
                        style: TextStyle(
                          color: AppColors.accentLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            DiaryHeader(
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
                          totalCalories: svc.meals[t]!
                              .fold(0, (s, m) => s + m.calories),
                          isExpanded: svc.expanded[t] ?? false,
                          canEdit: canEdit,
                          hasUnreadComment: svc.hasUnreadCommentsForType(t),
                          onExpansionChanged: () => svc.toggle(t),
                          onCommentTap: () {
                            final meals = svc.meals[t] ?? [];
                            final allMealIds = <String>{};
                            for (final m in meals) {
                              allMealIds.addAll(m.dbMealIds);
                            }
                            final sectionComment = svc.getSectionComment(t);
                            _showComment(
                              ctx: context,
                              type: t,
                              mealIds: allMealIds.toList(),
                              initialComment: sectionComment,
                            );
                          },
                          onAddTap: () =>
                              _openFoodSearch(ctx: context, type: t),
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

  void _showComment({
    required BuildContext ctx,
    required MealType type,
    List<String>? mealIds,
    String? initialComment,
  }) {
    final svc = ctx.read<DiaryService>();
    final clientsSvc = ctx.read<ClientsService>();

    svc.markCommentAsRead(type);

    final isTrainerWriting = clientsSvc.isViewingClient;

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => CommentBottomSheet(
        mealType: type,
        initialComment: initialComment ?? '',
        onSave: (String? newComment) async {
          if (sheetContext.mounted) {
            Navigator.pop(sheetContext);
          }

          try {
            final success = await svc.updateComment(
              type: type,
              date: svc.date,
              comment: newComment,
              mealIds: mealIds,
              isTrainerWriting: isTrainerWriting,
            );

            if (!success) {
              ErrorHandler.showGlobal('Не удалось сохранить комментарий');
            } else {
              ErrorHandler.showSuccessGlobal('Комментарий сохранён');
            }
          } catch (e) {
            ErrorHandler.showGlobal(
              ErrorHandler.format(e, context: 'comment'),
            );
          }
        },
      ),
    );
  }

  void _openFoodSearch({required BuildContext ctx, required MealType type}) {
    showFoodSearchSheet(ctx: ctx, type: type);
  }
}