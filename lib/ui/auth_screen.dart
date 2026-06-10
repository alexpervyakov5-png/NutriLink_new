import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_service.dart';
import '../core/config.dart';
import '../core/error_handler.dart';
import '../data/models.dart';

import 'widgets.dart';
import 'widgets/custom_tab_icon.dart';

class _AuthConstants {
  static const int minNameLength = 2;
  static const int minPasswordLength = 6;
  static const String emailHint = 'example@mail.com';
  static const String passwordHint = '••••••••';
  static const String passwordHelper = 'Минимум 6 символов, буквы и цифры';
  static const String deepLinkRedirect = 'nutrilink://auth/callback';
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _isLogin = true;
  bool _obscure = true;
  bool _submitting = false;
  UserRole _role = UserRole.client;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || !mounted || _submitting) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('⚠️ ScaffoldMessenger не найден перед отправкой формы');
      return;
    }

    final auth = context.read<AuthService>();
    final email = _emailCtrl.text.trim();

    setState(() => _submitting = true);

    bool result = false;
    String? errorMsg;
    String? successMsg;

    try {
      result = _isLogin
          ? await auth.signIn(email, _passCtrl.text)
          : await auth.signUp(
              email: email,
              password: _passCtrl.text,
              username: _nameCtrl.text.trim(),
              role: _role,
            );

      if (result) {
        if (_isLogin) {
          successMsg = 'Добро пожаловать!';
        } else {
          // 🔥 РЕГИСТРАЦИЯ ПРОШЛА — показываем диалог подтверждения email
          if (mounted) {
            _showEmailConfirmationDialog(email);
          }
          setState(() => _submitting = false);
          return;
        }
      } else {
        // 🔥 Специальная обработка ошибки "email не подтверждён"
        if (auth.error == 'email_not_confirmed') {
          if (mounted) {
            _showEmailConfirmationDialog(
              auth.pendingEmail ?? email,
              isFromLogin: true,
            );
          }
          setState(() => _submitting = false);
          return;
        }
        errorMsg = auth.error ?? 'Неизвестная ошибка';
      }
    } on AuthException catch (e) {
      debugPrint('❌ AuthException: ${e.message} (code: ${e.code})');
      errorMsg = ErrorHandler.format(e, context: _isLogin ? 'login' : 'signup');
    } on SocketException catch (e) {
      debugPrint('❌ SocketException: $e');
      errorMsg = ErrorHandler.format(e);
    } on PostgrestException catch (e) {
      debugPrint('❌ PostgrestException: ${e.message}');
      errorMsg = ErrorHandler.format(e, context: 'database');
    } catch (e, stack) {
      debugPrint('❌ Unknown auth error: $e');
      debugPrint('Stack: $stack');
      errorMsg =
          ErrorHandler.format(e, context: _isLogin ? 'login' : 'signup');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }

    if (errorMsg != null) {
      debugPrint('🔔 Показываем ошибку: $errorMsg');
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  errorMsg!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () => messenger.hideCurrentSnackBar(),
          ),
        ),
      );
    } else if (successMsg != null) {
      debugPrint('🔔 Показываем успех: $successMsg');
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  successMsg!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      if (mounted) _clearForm();
    }
  }

  // ============================================
  // 🔥 ДИАЛОГ ПОДТВЕРЖДЕНИЯ EMAIL
  // После закрытия автоматически переходит на экран входа
  // ============================================
  void _showEmailConfirmationDialog(String email, {bool isFromLogin = false}) {
    bool isResending = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mark_email_unread,
                    color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Подтвердите email',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFromLogin
                    ? 'Ваш email ещё не подтверждён. Проверьте почту:'
                    : 'Регистрация прошла успешно! Мы отправили письмо со ссылкой для подтверждения на адрес:',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  email,
                  style: const TextStyle(
                    color: AppColors.accentLight,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '1. Откройте письмо\n2. Нажмите на ссылку подтверждения\n3. Вернитесь в приложение и войдите',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              const Text(
                '💡 Если письмо не пришло, проверьте папку "Спам" или нажмите "Отправить снова"',
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isResending
                  ? null
                  : () async {
                      setDialogState(() => isResending = true);

                      final auth = context.read<AuthService>();
                      final success = await auth.resendConfirmationEmail(email);

                      if (!dialogContext.mounted) return;
                      setDialogState(() => isResending = false);

                      if (success) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('Письмо отправлено повторно'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(auth.error ?? 'Ошибка отправки'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isResending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Отправить снова',
                      style: TextStyle(color: AppColors.accent)),
            ),
            ElevatedButton(
              onPressed: () {
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                // 🔥 ПЕРЕКЛЮЧАЕМ НА ЭКРАН ВХОДА с заполненным email
                _switchToLoginWithEmail(email);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
              ),
              child: const Text('К входу'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // 🔥 ПЕРЕКЛЮЧЕНИЕ НА ЭКРАН ВХОДА с заполненным email
  // ============================================
  void _switchToLoginWithEmail(String email) {
    // Сбрасываем состояние подтверждения
    context.read<AuthService>().clearPendingConfirmation();

    // Очищаем форму (кроме email)
    _passCtrl.clear();
    _nameCtrl.clear();

    // Переключаемся на форму входа и подставляем email
    setState(() {
      _isLogin = true;
      _emailCtrl.text = email;
    });

    // Показываем подсказку пользователю
    if (mounted) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'После подтверждения email войдите с вашими данными',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _clearForm() {
    _emailCtrl.clear();
    _passCtrl.clear();
    if (!_isLogin) _nameCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isBusy = auth.loading || _submitting;

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
                Text(
                  _isLogin ? 'Вход' : 'Регистрация',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (!_isLogin) ...[
                  AuthTextField(
                    controller: _nameCtrl,
                    label: 'Имя',
                    hint: 'Ваше имя',
                    iconPath: '${AppStrings.assetIcons}person.png',
                    fallbackIcon: Icons.person,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Введите имя';
                      if (v.trim().length < _AuthConstants.minNameLength) {
                        return 'Имя должно быть не менее ${_AuthConstants.minNameLength} символов';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                AuthTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  hint: _AuthConstants.emailHint,
                  iconPath: '${AppStrings.assetIcons}email.png',
                  fallbackIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Введите email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(v.trim())) {
                      return 'Введите корректный email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _passCtrl,
                  label: 'Пароль',
                  hint: _AuthConstants.passwordHint,
                  iconPath: '${AppStrings.assetIcons}lock.png',
                  fallbackIcon: Icons.lock,
                  obscureText: _obscure,
                  suffixIcon: IconButton(
                    icon: CustomIcon(
                      path: _obscure
                          ? '${AppStrings.assetIcons}visibility_off.png'
                          : '${AppStrings.assetIcons}visibility.png',
                      width: 20,
                      height: 20,
                      color: AppColors.textHint,
                      fallback: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите пароль';
                    if (v.length < _AuthConstants.minPasswordLength) {
                      return 'Минимум ${_AuthConstants.minPasswordLength} символов';
                    }
                    if (!_isLogin &&
                        !RegExp(r'(?=.*[a-zA-Z])(?=.*\d)').hasMatch(v)) {
                      return 'Пароль должен содержать буквы и цифры';
                    }
                    return null;
                  },
                ),
                if (!_isLogin)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      _AuthConstants.passwordHelper,
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (!_isLogin) ...[
                  const Text(
                    'Выберите роль',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RoleSelector(
                    selectedRole: _role,
                    onChanged: (r) => setState(() => _role = r),
                  ),
                  const SizedBox(height: 24),
                ],
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isBusy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: isBusy
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                        : Text(
                            _isLogin ? 'Войти' : 'Зарегистрироваться',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLogin ? 'Нет аккаунта? ' : 'Уже есть аккаунт? ',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() => _isLogin = !_isLogin);
                        _clearForm();
                      },
                      child: Text(
                        _isLogin ? 'Зарегистрироваться' : 'Войти',
                        style: const TextStyle(
                          color: AppColors.accentLight,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_isLogin) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: isBusy ? null : _showForgotPasswordDialog,
                      child: const Text(
                        'Забыли пароль?',
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    bool dialogLoading = false;

    final stateContext = context;

    showDialog(
      context: stateContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.background,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Восстановление пароля',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Введите ваш email, и мы отправим инструкцию по восстановлению пароля',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 16),
              IgnorePointer(
                ignoring: dialogLoading,
                child: AuthTextField(
                  controller: emailCtrl,
                  label: 'Email',
                  hint: _AuthConstants.emailHint,
                  iconPath: '${AppStrings.assetIcons}email.png',
                  fallbackIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: dialogLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Отмена',
                  style: TextStyle(color: AppColors.textHint)),
            ),
            ElevatedButton(
              onPressed: dialogLoading
                  ? null
                  : () async {
                      final email = emailCtrl.text.trim();
                      if (email.isEmpty ||
                          !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(email)) {
                        ErrorHandler.show(ctx, 'Введите корректный email');
                        return;
                      }

                      setDialogState(() => dialogLoading = true);

                      try {
                        await SupabaseConfig.client.auth.resetPasswordForEmail(
                          email,
                          redirectTo: _AuthConstants.deepLinkRedirect,
                        );

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (stateContext.mounted) {
                          ErrorHandler.showSuccess(
                              stateContext, 'Инструкция отправлена на ваш email');
                        }
                      } on AuthException catch (e) {
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (stateContext.mounted) {
                          ErrorHandler.show(
                            stateContext,
                            ErrorHandler.format(
                                e, context: 'password_reset'),
                          );
                        }
                      } catch (e) {
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (stateContext.mounted) {
                          ErrorHandler.show(
                              stateContext, 'Ошибка отправки. Попробуйте позже');
                          debugPrint('Reset password error: $e');
                        }
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => dialogLoading = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.black,
              ),
              child: dialogLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Отправить'),
            ),
          ],
        ),
      ),
    );
  }
}