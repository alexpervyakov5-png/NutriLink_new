import 'package:flutter/material.dart';

import '../../core/config.dart';

class NutrientCard extends StatelessWidget {
  final String label;
  final num value;

  const NutrientCard(this.label, this.value, {super.key});

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