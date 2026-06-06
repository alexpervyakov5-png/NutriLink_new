import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';

import '../../core/config.dart';
import '../../core/error_handler.dart';
import '../../data/diary_service.dart';
import '../../data/models.dart';
import '../widgets.dart';
import 'comment_bottom_sheet.dart';
import 'diary_header.dart';
import 'food_search_sheet.dart';

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
                          onExpansionChanged: () => svc.toggle(t),
                          onCommentTap: () =>
                              _showComment(ctx: context, type: t),
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

  void _showComment({required BuildContext ctx, required MealType type}) {
    final svc = ctx.read<DiaryService>();
    final currentComment = svc.getCommentForType(type) ??
        svc.meals[type]?.firstOrNull?.comment ??
        '';

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => CommentBottomSheet(
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

            if (!success) {
              ErrorHandler.showGlobal('Не удалось сохранить комментарий');
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