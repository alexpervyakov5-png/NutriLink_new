import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../data/services.dart';
import '../data/clients_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authEmail = SupabaseConfig.client.auth.currentUser?.email ?? 'Неизвестно';
    final svc = context.read<ProfileService>();
    final clientsSvc = context.watch<ClientsService>();

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Профиль',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ ИСПРАВЛЕНО: isViewingClient вместо isTrainerMode + withValues вместо withOpacity
            if (clientsSvc.isViewingClient) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppColors.accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Вы просматриваете данные клиента. Здесь отображаются настройки вашего аккаунта.',
                        style: TextStyle(color: AppColors.accentLight, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Аккаунт',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email, color: AppColors.accent, size: 24),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Email',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          authEmail,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Безопасность',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showChangePasswordDialog(context, svc),
              icon: const Icon(Icons.lock_reset, size: 20),
              label: const Text('Сменить пароль', style: TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatError(Object? error, {String context = ''}) {
    if (error == null) return 'Произошла непредвиденная ошибка';
    
    if (error is SocketException || 
        error.toString().contains('SocketException') ||
        error.toString().contains('Network is unreachable') ||
        error.toString().contains('Connection refused') ||
        error.toString().contains('Failed host lookup')) {
      return 'Нет подключения к интернету. Проверьте соединение';
    }
    
    if (error is AuthException) {
      final message = error.message.toLowerCase();
      if (message.contains('weak password')) {
        return 'Пароль слишком слабый. Используйте минимум 6 символов';
      }
      if (message.contains('email not confirmed')) {
        return 'Подтвердите ваш email перед сменой пароля';
      }
      if (message.contains('jwt expired') || message.contains('session')) {
        return 'Сессия истекла. Пожалуйста, войдите снова';
      }
      if (message.contains('rate limit')) {
        return 'Слишком много попыток. Попробуйте позже';
      }
      return 'Ошибка авторизации: ${error.message}';
    }
    
    if (error.toString().contains('PostgrestException') || 
        error.toString().contains('database')) {
      if (error.toString().contains('JWT expired')) {
        return 'Сессия истекла. Пожалуйста, войдите снова';
      }
      return 'Ошибка сервера. Попробуйте позже';
    }
    
    if (error is String) return error;
    
    if (context.isNotEmpty) {
      switch (context) {
        case 'password': return 'Не удалось сменить пароль. Попробуйте снова';
      }
    }
    
    return 'Произошла непредвиденная ошибка. Попробуйте снова';
  }

  void _showError(BuildContext ctx, String message) {
    if (!ctx.mounted) return;
    
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
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
          onPressed: () => ScaffoldMessenger.of(ctx).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _showSuccess(BuildContext ctx, String message) {
    if (!ctx.mounted) return;
    
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(color: Colors.white))),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, ProfileService svc) {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Смена пароля',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Новый пароль',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Подтвердите пароль',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Подтвердите пароль';
                  if (v != passCtrl.text) return 'Пароли не совпадают';
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (dialogCtx.mounted) Navigator.pop(dialogCtx);
            },
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              
              if (passCtrl.text != confirmCtrl.text) {
                _showError(dialogCtx, 'Пароли не совпадают');
                return;
              }
              
              try {
                final success = await svc.updatePassword(passCtrl.text);
                
                if (!dialogCtx.mounted) return;
                
                if (success) {
                  Navigator.pop(dialogCtx);
                  _showSuccess(context, 'Пароль успешно изменён');
                  passCtrl.clear();
                  confirmCtrl.clear();
                } else {
                  _showError(
                    dialogCtx,
                    svc.error != null 
                        ? _formatError(svc.error!, context: 'password') 
                        : 'Не удалось сменить пароль',
                  );
                }
              } on AuthException catch (e) {
                if (!dialogCtx.mounted) return;
                _showError(dialogCtx, _formatError(e, context: 'password'));
              } on SocketException catch (e) {
                if (!dialogCtx.mounted) return;
                _showError(dialogCtx, _formatError(e, context: 'password'));
              } catch (e, stack) {
                debugPrint('❌ Change password error: $e');
                debugPrint('Stack: $stack');
                
                if (!dialogCtx.mounted) return;
                _showError(dialogCtx, _formatError(e, context: 'password'));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Изменить'),
          ),
        ],
      ),
    );
  }
}