import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/error_handler.dart';
import '../../data/diary_service.dart';

/// Открывает нижнюю панель для редактирования дневных целей
void showGoalsEditSheet({
  required BuildContext ctx,
  required int initialProtein,
  required int initialFat,
  required int initialCarbs,
  required int initialCalories,
  DateTime? date,
}) {
  final proCtrl = TextEditingController(
    text: initialProtein > 0 ? initialProtein.toString() : '',
  );
  final fatCtrl = TextEditingController(
    text: initialFat > 0 ? initialFat.toString() : '',
  );
  final carbCtrl = TextEditingController(
    text: initialCarbs > 0 ? initialCarbs.toString() : '',
  );
  final calCtrl = TextEditingController(
    text: initialCalories > 0 ? initialCalories.toString() : '',
  );

  showModalBottomSheet(
    context: ctx,
    backgroundColor: AppColors.background,
    isScrollControlled: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 24,
            left: 20,
            right: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Редактировать цели',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildInputField(proCtrl, 'Белки (г)', Icons.egg_alt),
              const SizedBox(height: 12),
              _buildInputField(fatCtrl, 'Жиры (г)', Icons.water_drop),
              const SizedBox(height: 12),
              _buildInputField(carbCtrl, 'Углеводы (г)', Icons.grain),
              const SizedBox(height: 12),
              _buildInputField(
                  calCtrl, 'Калории (ккал)', Icons.local_fire_department),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  final pro = int.tryParse(proCtrl.text) ?? 0;
                  final fat = int.tryParse(fatCtrl.text) ?? 0;
                  final carb = int.tryParse(carbCtrl.text) ?? 0;
                  final cal = int.tryParse(calCtrl.text) ?? 0;

                  if (pro == 0 && fat == 0 && carb == 0 && cal == 0) {
                    ErrorHandler.showGlobal('Укажите хотя бы одну цель');
                    return;
                  }

                  final svc = ctx.read<DiaryService>();
                  final success = await svc.updateGoals(
                    protein: pro,
                    fat: fat,
                    carbs: carb,
                    calories: cal,
                    date: date,
                  );

                  if (context.mounted) Navigator.pop(context);

                  if (success) {
                    await svc.refresh();
                    ErrorHandler.showSuccessGlobal('Цели сохранены');
                  } else {
                    ErrorHandler.showGlobal('Не удалось сохранить цели');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Сохранить',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    ),
  ).whenComplete(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      proCtrl.dispose();
      fatCtrl.dispose();
      carbCtrl.dispose();
      calCtrl.dispose();
    });
  });
}

Widget _buildInputField(
    TextEditingController ctrl, String label, IconData icon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: AppColors.backgroundSecondary,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Icon(icon, color: AppColors.textHint, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(color: AppColors.textHint),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    ),
  );
}