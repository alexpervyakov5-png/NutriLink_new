import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/safe_text_controller.dart';

Widget buildLabeledInput(
  SafeTextEditingController ctrl,
  String label, {
  bool isNumber = false,
  String? Function(String?)? validator,
}) {
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
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
          validator: validator,
        ),
      ),
    ],
  );
}

Widget buildMacroInput(
  SafeTextEditingController ctrl,
  String label,
  String unit, {
  bool isNumber = false,
  String? Function(String?)? validator,
}) {
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
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
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