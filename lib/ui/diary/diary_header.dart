import 'package:flutter/material.dart';

import '../../core/config.dart';

class DiaryHeader extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime?> onDatePick;

  const DiaryHeader({
    super.key,
    required this.date,
    required this.onDatePick,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.backgroundSecondary,
            width: 1,
          ),
        ),
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
              if (d != null && context.mounted) {
                onDatePick(d);
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