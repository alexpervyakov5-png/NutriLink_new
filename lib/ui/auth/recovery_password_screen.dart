import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config.dart';
import '../../core/error_handler.dart';
import '../../core/safe_text_controller.dart';
import '../widgets.dart';
import '../widgets/custom_tab_icon.dart';

class RecoveryPasswordScreen extends StatefulWidget {
  const RecoveryPasswordScreen({super.key});

  @override
  State<RecoveryPasswordScreen> createState() => _RecoveryPasswordScreenState();
}

class _RecoveryPasswordScreenState extends State<RecoveryPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassCtrl = SafeTextEditingController();
  final _confirmPassCtrl = SafeTextEditingController();
  
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  @override
  void dispose() {
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _submitting) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    setState(() => _submitting = true);

    try {
      final newPassword = _newPassCtrl.text;
      
      // 🔥 Обновляем пароль через Supabase
      await SupabaseConfig.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Пароль успешно изменён! Теперь войдите с новым паролем',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );

      // 🔥 Возвращаемся на экран входа
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/');
      }
    } on AuthException catch (e) {
      debugPrint('❌ Update password error: ${e.message}');
      
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.format(e, context: 'password_change')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Unknown error: $e');
      debugPrint('Stack: $stack');
      
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.format(e, context: 'password_change')),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      '${AppStrings.assetIcons}nutrilink.png',
                      width: 48,
                      height: 48,
                      errorBuilder: (_, __, ___) => CustomIcon(
                        path: '${AppStrings.assetIcons}nutrilink.png',
                        width: 48,
                        height: 48,
                        fallback: const Icon(Icons.restaurant, size: 48),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'NutriLink',
                      style: TextStyle(
                        color: AppColors.accentLight,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_reset,
                          color: AppColors.accent, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Создание нового пароля',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Придумайте надёжный пароль',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                AuthTextField(
                  controller: _newPassCtrl,
                  label: 'Новый пароль',
                  hint: '••••••••',
                  iconPath: '${AppStrings.assetIcons}lock.png',
                  fallbackIcon: Icons.lock,
                  obscureText: _obscureNew,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureNew ? Icons.visibility : Icons.visibility_off,
                      color: AppColors.textHint,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите пароль';
                    if (v.length < 6) return 'Минимум 6 символов';
                    if (!RegExp(r'(?=.*[a-zA-Z])(?=.*\d)').hasMatch(v)) {
                      return 'Пароль должен содержать буквы и цифры';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _confirmPassCtrl,
                  label: 'Подтвердите пароль',
                  hint: '••••••••',
                  iconPath: '${AppStrings.assetIcons}lock.png',
                  fallbackIcon: Icons.lock,
                  obscureText: _obscureConfirm,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility : Icons.visibility_off,
                      color: AppColors.textHint,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Подтвердите пароль';
                    if (v != _newPassCtrl.text) return 'Пароли не совпадают';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : const Text(
                            'Сменить пароль',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: _submitting
                        ? null
                        : () {
                            Navigator.of(context).pushReplacementNamed('/');
                          },
                    child: const Text(
                      'Вернуться ко входу',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}