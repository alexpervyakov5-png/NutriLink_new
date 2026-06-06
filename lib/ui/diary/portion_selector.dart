import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/error_handler.dart';
import '../../core/safe_text_controller.dart';
import '../../data/diary_service.dart';
import '../../data/models.dart';
import 'nutrient_card.dart';

class PortionSelectorContent extends StatefulWidget {
  final BuildContext sheetContext;
  final BuildContext ctx;
  final MealType type;
  final dynamic item;
  final DiaryService diaryService;
  final bool isRecipe;
  final double baseValue;

  const PortionSelectorContent({
    super.key,
    required this.sheetContext,
    required this.ctx,
    required this.type,
    required this.item,
    required this.diaryService,
    required this.isRecipe,
    required this.baseValue,
  });

  @override
  State<PortionSelectorContent> createState() => _PortionSelectorContentState();
}

class _PortionSelectorContentState extends State<PortionSelectorContent> {
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
      final recipe = widget.item as Recipe;
      double scale = weight / recipe.baseWeightGrams;
      currentCal = recipe.totalCalories * scale;
      currentPro = recipe.totalProtein * scale;
      currentFat = recipe.totalFat * scale;
      currentCarb = recipe.totalCarbs * scale;
    } else {
      final product = widget.item as Product;
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
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
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
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : const Text('Сохранить',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
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
                  Expanded(
                      child: NutrientCard(
                          'Калории', currentCal.toInt())),
                  const SizedBox(width: 8),
                  Expanded(child: NutrientCard('Жиры', currentFat))
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: NutrientCard(
                          'Углеводы', currentCarb)),
                  const SizedBox(width: 8),
                  Expanded(child: NutrientCard('Белки', currentPro))
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave() async {
    final weightStr = _weightCtrl.text.replaceAll(RegExp(r'\D'), '');
    final portionGrams = weightStr.isEmpty
        ? widget.baseValue
        : (double.tryParse(weightStr) ?? widget.baseValue);

    if (portionGrams <= 0) {
      ErrorHandler.showGlobal('Вес должен быть больше 0');
      return;
    }
    if (portionGrams > 10000) {
      ErrorHandler.showGlobal('Вес не может быть больше 10 кг');
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

      _safeCloseModal();

      if (success) {
        ErrorHandler.showSuccessGlobal('Добавлено в дневник');
      } else {
        ErrorHandler.showGlobal('Не удалось добавить. Попробуйте снова');
      }
    } catch (e) {
      debugPrint('❌ Add food item error: $e');
      _safeCloseModal();
      ErrorHandler.showGlobal(
        ErrorHandler.format(e, context: 'meal'),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _safeCloseModal() {
    try {
      if (mounted && widget.sheetContext.mounted) {
        Navigator.of(widget.sheetContext).pop();
      }
    } catch (_) {
      // Модалка уже закрыта
    }
  }
}