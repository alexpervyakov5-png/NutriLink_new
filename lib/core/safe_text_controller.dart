import 'package:flutter/material.dart';

/// Безопасный TextEditingController, который не выбрасывает ошибку после dispose
class SafeTextEditingController extends TextEditingController {
  bool _isDisposed = false;

  SafeTextEditingController({String? text}) : super(text: text ?? '');

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
  String get text {
    if (_isDisposed) return '';
    try {
      return super.text;
    } catch (_) {
      return '';
    }
  }

  @override
  set text(String newText) {
    if (!_isDisposed) {
      try {
        super.text = newText;
      } catch (_) {
        // Игнорируем ошибку
      }
    }
  }

  @override
  TextSelection get selection {
    if (_isDisposed) {
      return const TextSelection.collapsed(offset: 0);
    }
    try {
      return super.selection;
    } catch (_) {
      return const TextSelection.collapsed(offset: 0);
    }
  }

  @override
  set selection(TextSelection newSelection) {
    if (!_isDisposed) {
      try {
        super.selection = newSelection;
      } catch (_) {
        // Игнорируем ошибку
      }
    }
  }

  @override
  void clear() {
    if (!_isDisposed) {
      try {
        super.clear();
      } catch (_) {
        // Игнорируем ошибку
      }
    }
  }

  @override
  void clearComposing() {
    if (!_isDisposed) {
      try {
        super.clearComposing();
      } catch (_) {
        // Игнорируем ошибку
      }
    }
  }

  /// Безопасная замена текста с регулярным выражением
  String safeReplaceAll(Pattern from, String replace) {
    if (_isDisposed) return '';
    try {
      return super.text.replaceAll(from, replace);
    } catch (_) {
      return '';
    }
  }

  /// Безопасный trim
  String safeTrim() {
    if (_isDisposed) return '';
    try {
      return super.text.trim();
    } catch (_) {
      return '';
    }
  }

  /// Безопасная проверка isEmpty
  bool get safeIsEmpty {
    if (_isDisposed) return true;
    try {
      return super.text.isEmpty;
    } catch (_) {
      return true;
    }
  }
}