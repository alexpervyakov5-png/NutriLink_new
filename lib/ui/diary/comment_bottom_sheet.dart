import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/safe_text_controller.dart';
import '../../data/models.dart';

class CommentBottomSheet extends StatefulWidget {
  final MealType mealType;
  final String initialComment;
  final Function(String?) onSave;

  const CommentBottomSheet({
    super.key,
    required this.mealType,
    required this.initialComment,
    required this.onSave,
  });

  @override
  State<CommentBottomSheet> createState() => _CommentBottomSheetState();
}

class _CommentBottomSheetState extends State<CommentBottomSheet> {
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