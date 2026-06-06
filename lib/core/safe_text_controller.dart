import 'package:flutter/material.dart';

/// Безопасный TextEditingController, который не выбрасывает ошибку после dispose
class SafeTextEditingController extends TextEditingController {
  bool _isDisposed = false;

  SafeTextEditingController({String? text}) : super(text: text);

  bool get isDisposed => _isDisposed;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_isDisposed) {
      return const TextSpan(text: '');
    }
    return super.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );
  }

  @override
  String get text => _isDisposed ? '' : super.text;

  @override
  set text(String newText) {
    if (!_isDisposed) {
      super.text = newText;
    }
  }

  @override
  TextSelection get selection => _isDisposed 
      ? const TextSelection.collapsed(offset: 0) 
      : super.selection;

  @override
  set selection(TextSelection newSelection) {
    if (!_isDisposed) {
      super.selection = newSelection;
    }
  }

  @override
  void clear() {
    if (!_isDisposed) {
      super.clear();
    }
  }

  @override
  void clearComposing() {
    if (!_isDisposed) {
      super.clearComposing();
    }
  }
}