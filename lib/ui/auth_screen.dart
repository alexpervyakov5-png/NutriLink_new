import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../data/models.dart';
import '../data/services.dart';
import 'widgets.dart';
import 'widgets/custom_tab_icon.dart';

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
  UserRole _role = UserRole.client;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  String _formatAuthError(Object error, {bool isLogin = true}) {
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      final code = error.code?.toLowerCase() ?? '';
      
      if (isLogin) {
        if (message.contains('invalid login credentials') || 
            message.contains('invalid credentials') ||
            code.contains('invalid_credentials')) {
          return 'Неверный email или пароль';
        }
        if (message.contains('user not found') || 
            message.contains('not found') ||
            code.contains('user_not_found')) {
          return 'Пользователь с таким email не найден';
        }
        if (message.contains('wrong password') || 
            message.contains('incorrect password') ||
            code.contains('wrong_password')) {
          return 'Неверный пароль';
        }
        if (message.contains('email not confirmed')) {
          return 'Подтвердите ваш email. Проверьте почту';
        }
      }
      
      if (!isLogin) {
        if (message.contains('user already registered') || 
            message.contains('user already exists') ||
            code.contains('user_already_exists')) {
          return 'Пользователь с таким email уже зарегистрирован';
        }
        if (message.contains('weak password') || code.contains('weak_password')) {
          return 'Пароль слишком слабый. Используйте минимум 6 символов';
        }
        if (message.contains('email address is already in use') ||
            message.contains('duplicate key')) {
          return 'Этот email уже используется';
        }
      }
      
      if (message.contains('over request rate limit') || 
          message.contains('rate limit') ||
          code.contains('rate_limit')) {
        return 'Слишком много попыток. Попробуйте позже';
      }
      if (message.contains('jwt expired')) {
        return 'Сессия истекла. Пожалуйста, войдите снова';
      }
      if (message.contains('database error') || message.contains('database')) {
        return 'Ошибка сервера. Попробуйте позже';
      }
      return 'Ошибка авторизации: ${error.message}';
    }
    
    if (error is SocketException || 
        error.toString().contains('SocketException') ||
        error.toString().contains('Network is unreachable') ||
        error.toString().contains('Connection refused') ||
        error.toString().contains('Failed host lookup')) {
      return 'Нет подключения к интернету. Проверьте соединение';
    }
    
    if (error.toString().contains('PostgrestException') || 
        error.toString().contains('database')) {
      if (error.toString().contains('JWT expired')) {
        return 'Сессия истекла. Пожалуйста, войдите снова';
      }
      return 'Ошибка базы данных. Попробуйте позже';
    }
    
    if (error is String) return error;
    
    final errorMsg = error.toString().toLowerCase();
    if (errorMsg.contains('404') || errorMsg.contains('not found')) {
      return isLogin ? 'Пользователь не найден' : 'Ошибка регистрации';
    }
    if (errorMsg.contains('401') || errorMsg.contains('unauthorized')) {
      return 'Неверные данные для входа';
    }
    if (errorMsg.contains('400')) {
      return 'Некорректные данные. Проверьте поля';
    }
    if (errorMsg.contains('500') || errorMsg.contains('502') || errorMsg.contains('503')) {
      return 'Ошибка сервера. Попробуйте позже';
    }
    
    return 'Произошла непредвиденная ошибка. Попробуйте снова';
  }

  void _showError(String message) {
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CustomIcon(
                path: '${AppStrings.assetIcons}error.png',
                width: 20,
                height: 20,
                color: Colors.white,
                fallback: const Icon(Icons.error_outline, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
    });
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              CustomIcon(
                path: '${AppStrings.assetIcons}check.png',
                width: 20,
                height: 20,
                color: Colors.white,
                fallback: const Icon(Icons.check_circle, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    
    final auth = context.read<AuthService>();
    
    try {
      final result = _isLogin
          ? await auth.signIn(_emailCtrl.text.trim(), _passCtrl.text)
          : await auth.signUp(
              email: _emailCtrl.text.trim(),
              password: _passCtrl.text,
              username: _nameCtrl.text.trim(),
              role: _role,
            );
      
      if (!mounted) return;
      
      if (result == true) {
        _showSuccess(_isLogin ? 'Добро пожаловать!' : 'Аккаунт создан!');
        _emailCtrl.clear();
        _passCtrl.clear();
        if (!_isLogin) _nameCtrl.clear();
      } else {
        final errorMessage = auth.error?.isNotEmpty == true 
            ? _formatAuthError(auth.error!, isLogin: _isLogin)
            : (_isLogin 
                ? 'Не удалось войти. Проверьте email и пароль'
                : 'Не удалось зарегистрироваться. Попробуйте снова');
        _showError(errorMessage);
      }
      
    } on AuthException catch (e) {
      if (!mounted) return;
      debugPrint('❌ AuthException: ${e.message} (code: ${e.code})');
      _showError(_formatAuthError(e, isLogin: _isLogin));
      
    } on SocketException catch (e) {
      if (!mounted) return;
      debugPrint('❌ SocketException: $e');
      _showError(_formatAuthError(e, isLogin: _isLogin));
      
    } on PostgrestException catch (e) {
      if (!mounted) return;
      debugPrint('❌ PostgrestException: ${e.message}');
      _showError(_formatAuthError(e, isLogin: _isLogin));
      
    } catch (e, stack) {
      if (!mounted) return;
      debugPrint('❌ Unknown auth error: $e');
      debugPrint('Stack: $stack');
      _showError(_formatAuthError(e, isLogin: _isLogin));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    
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
                    // 🔥 Логотип БЕЗ color параметра, чтобы сохранить оригинальные цвета
                    Image.asset(
                      '${AppStrings.assetIcons}nutrilink.png',
                      width: 48,
                      height: 48,
                      errorBuilder: (_, __, ___) => CustomIcon(
                        path: '${AppStrings.assetIcons}nutrilink.png',
                        width: 48,
                        height: 48,
                        // color удалён
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
                      if (v.trim().length < 2) return 'Имя должно быть не менее 2 символов';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                AuthTextField(
                  controller: _emailCtrl,
                  label: 'Email',
                  hint: 'example@mail.com',
                  iconPath: '${AppStrings.assetIcons}email.png',
                  fallbackIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Введите email';
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                      return 'Введите корректный email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  controller: _passCtrl,
                  label: 'Пароль',
                  hint: '••••••••',
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
                    if (v.length < 6) return 'Минимум 6 символов';
                    if (!_isLogin && !RegExp(r'(?=.*[a-zA-Z])(?=.*\d)').hasMatch(v)) {
                      return 'Пароль должен содержать буквы и цифры';
                    }
                    return null;
                  },
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
                    onPressed: auth.loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: auth.loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
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
                        _emailCtrl.clear();
                        _passCtrl.clear();
                        if (!_isLogin) _nameCtrl.clear();
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
                      onPressed: () => _showForgotPasswordDialog(),
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
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
            AuthTextField(
              controller: emailCtrl,
              label: 'Email',
              hint: 'example@mail.com',
              iconPath: '${AppStrings.assetIcons}email.png',
              fallbackIcon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена', style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
                _showError('Введите корректный email');
                return;
              }
              
              Navigator.pop(ctx);
              
              try {
                await SupabaseConfig.client.auth.resetPasswordForEmail(
                  email,
                  redirectTo: '${SupabaseConfig.url}/auth/callback',
                );
                if (mounted) {
                  _showSuccess('Инструкция отправлена на ваш email');
                }
              } on AuthException catch (e) {
                if (mounted) {
                  _showError(_formatAuthError(e, isLogin: true));
                }
              } catch (e) {
                if (mounted) {
                  _showError('Ошибка отправки. Попробуйте позже');
                  debugPrint('Reset password error: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Отправить'),
          ),
        ],
      ),
    );
  }
}