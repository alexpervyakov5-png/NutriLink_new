import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../core/config.dart';
import '../data/models.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextFormField(
              controller: controller,
              obscureText: obscureText,
              keyboardType: keyboardType,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.textHint),
                prefixIcon: Icon(icon, color: AppColors.accent),
                suffixIcon: suffixIcon,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              validator: validator,
            ),
          ),
        ],
      );
}

class RoleSelector extends StatelessWidget {
  final UserRole selectedRole;
  final ValueChanged<UserRole> onChanged;
  const RoleSelector({super.key, required this.selectedRole, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: _RoleCard(
              icon: Icons.person,
              title: 'Клиент',
              subtitle: 'Хочу следить за питанием',
              isSelected: selectedRole == UserRole.client,
              onTap: () => onChanged(UserRole.client),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _RoleCard(
              icon: Icons.fitness_center,
              title: 'Тренер',
              subtitle: 'Хочу вести клиентов',
              isSelected: selectedRole == UserRole.trainer,
              onTap: () => onChanged(UserRole.trainer),
            ),
          ),
        ],
      );
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accent.withValues(alpha: 0.2)
                : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.accent : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? AppColors.accentLight : AppColors.textSecondary,
                  size: 32),
              const SizedBox(height: 8),
              Text(title,
                  style: TextStyle(
                    color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 4),
              Text(subtitle,
                  style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class GoalsSection extends StatelessWidget {
  final DailyGoals goals;
  const GoalsSection({super.key, required this.goals});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            const Text('Цель',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _Cell('Белки', goals.proteinCurrent, goals.proteinTarget,
                        AppColors.progressProtein)),
                const SizedBox(width: 6),
                Expanded(
                    child: _Cell('Жиры', goals.fatsCurrent, goals.fatsTarget,
                        AppColors.progressFats)),
                const SizedBox(width: 6),
                Expanded(
                    child: _Cell('Углеводы', goals.carbsCurrent, goals.carbsTarget,
                        AppColors.progressCarbs)),
                const SizedBox(width: 6),
                Expanded(
                    child: _Cell('Калории', goals.caloriesCurrent,
                        goals.caloriesTarget, AppColors.progressCalories)),
              ],
            ),
          ],
        ),
      );
}

class _Cell extends StatelessWidget {
  final String label;
  final int current, total;
  final Color color;
  const _Cell(this.label, this.current, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? current.toDouble() / total.toDouble() : 0.0;
    return Column(
      children: [
        Text(label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            backgroundColor: AppColors.backgroundSecondary,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 4),
        Text('$current/$total',
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class MealSection extends StatelessWidget {
  final String title, imagePath;
  final int totalCalories;
  final bool isExpanded;
  final VoidCallback onExpansionChanged, onCommentTap, onAddTap;
  final List<Meal> items;

  const MealSection({
    super.key,
    required this.title,
    required this.imagePath,
    required this.totalCalories,
    required this.isExpanded,
    required this.onExpansionChanged,
    required this.onCommentTap,
    required this.onAddTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onExpansionChanged,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.asset(
                          imagePath,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(_icon(title), color: AppColors.accent, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('$totalCalories ккал',
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    if (isExpanded)
                      GestureDetector(
                        onTap: onCommentTap,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.chat_bubble_outline,
                              color: AppColors.accent, size: 18),
                        ),
                      ),
                    const SizedBox(width: 6),
                    if (isExpanded)
                      GestureDetector(
                        onTap: onAddTap,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.add, color: Colors.black, size: 18),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary, size: 20),
                  ],
                ),
              ),
            ),
            if (isExpanded) ...[
              const Divider(height: 1, color: AppColors.background),
              ...items.map((item) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: _MealItem(meal: item),
                  )),
            ],
          ],
        ),
      );

  IconData _icon(String t) => switch (t) {
        'Завтрак' => Icons.free_breakfast,
        'Обед' => Icons.lunch_dining,
        'Ужин' => Icons.dinner_dining,
        'Перекус' => Icons.cookie,
        _ => Icons.restaurant,
      };
}

class _MealItem extends StatelessWidget {
  final Meal meal;
  const _MealItem({required this.meal});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.restaurant, color: AppColors.textSecondary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.name,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                  Text('${meal.weight}г • ${meal.calories} ккал',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

class MeasurementField extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint, suffix;
  final IconData icon;
  final TextInputType? keyboardType;

  const MeasurementField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: AppColors.textHint, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextFormField(
              controller: controller,
              keyboardType:
                  keyboardType ?? const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(
                    color: AppColors.textHint.withValues(alpha: 0.4), fontSize: 15),
                prefixIcon: Icon(icon, color: AppColors.textHint, size: 18),
                suffixText: suffix,
                suffixStyle: TextStyle(color: AppColors.textHint, fontSize: 12),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              validator: (v) =>
                  v != null && v.isNotEmpty && double.tryParse(v) == null
                      ? 'Введите число'
                      : null,
            ),
          ),
        ],
      );
}

class StatsRow extends StatelessWidget {
  final String label, value, percent;
  final Color color;
  final IconData icon;
  final bool isTotal;

  const StatsRow({
    super.key,
    required this.label,
    required this.value,
    required this.percent,
    required this.color,
    required this.icon,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
                      fontSize: isTotal ? 15 : 14,
                      fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal)),
            ),
            Text(value,
                style: TextStyle(
                    color: isTotal ? AppColors.accentLight : color,
                    fontSize: isTotal ? 16 : 14,
                    fontWeight: isTotal ? FontWeight.bold : FontWeight.w600)),
            const SizedBox(width: 16),
            SizedBox(
              width: 50,
              child: Text(percent,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: isTotal ? AppColors.textPrimary : AppColors.textHint,
                      fontSize: 12)),
            ),
          ],
        ),
      );
}

class PieChartWidget extends StatelessWidget {
  final double proteinPercent, fatsPercent, carbsPercent;
  const PieChartWidget(
      {super.key,
      required this.proteinPercent,
      required this.fatsPercent,
      required this.carbsPercent});

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[];
    if (proteinPercent > 0) {
      sections.add(PieChartSectionData(
        value: proteinPercent,
        title: '${proteinPercent.toStringAsFixed(0)}%',
        color: Colors.green,
        radius: 50,
        titleStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (fatsPercent > 0) {
      sections.add(PieChartSectionData(
        value: fatsPercent,
        title: '${fatsPercent.toStringAsFixed(0)}%',
        color: Colors.red,
        radius: 50,
        titleStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (carbsPercent > 0) {
      sections.add(PieChartSectionData(
        value: carbsPercent,
        title: '${carbsPercent.toStringAsFixed(0)}%',
        color: Colors.orange,
        radius: 50,
        titleStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (sections.isEmpty) {
      sections.add(PieChartSectionData(
        value: 100,
        title: '0%',
        color: Colors.grey.withValues(alpha: 0.3),
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, color: Colors.white54),
      ));
    }
    return PieChart(PieChartData(
      sections: sections,
      sectionsSpace: 2,
      centerSpaceRadius: 30,
      startDegreeOffset: -90,
    ));
  }
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Leg('Белки', Colors.green),
          const SizedBox(width: 20),
          _Leg('Жиры', Colors.red),
          const SizedBox(width: 20),
          _Leg('Углеводы', Colors.orange),
        ],
      );
}

class _Leg extends StatelessWidget {
  final String l;
  final Color c;
  const _Leg(this.l, this.c);

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 6),
          Text(l, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      );
}