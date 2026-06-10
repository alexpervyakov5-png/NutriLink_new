import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/profile_service.dart';
import '../core/config.dart';
import '../core/error_handler.dart';
import '../data/clients_service.dart';
import '../data/auth_service.dart';
import '../data/models.dart';
import 'widgets/profile_code_card.dart';
import 'trainer_clients_screen.dart';
import 'widgets/custom_tab_icon.dart';

// ============================================
// ВСПОМОГАТЕЛЬНЫЕ КОНСТАНТЫ (локальные)
// ============================================
class _ProfileConstants {
  static const int minPasswordLength = 6;
  static const String passwordRegex = r'(?=.*[a-zA-Z])(?=.*\d)';
}

// ============================================
// ProfileScreen
// 🔥 ВАЖНО: ВСЕГДА показывает СВОЙ профиль тренера,
// независимо от выбранного клиента в ClientsService.
// ============================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Profile?>? _ownProfileFuture;

  @override
  void initState() {
    super.initState();
    _loadOwnProfile();
  }

  void _loadOwnProfile() {
    final profileSvc = context.read<ProfileService>();
    _ownProfileFuture = profileSvc.loadOwnProfile();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final profileSvc = context.read<ProfileService>();
    final clientsSvc = context.watch<ClientsService>();
    final isTrainer = auth.user?.role == UserRole.trainer;
    final authEmail = SupabaseConfig.client.auth.currentUser?.email ?? 'Неизвестно';

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
            if (!context.mounted) return;
            Navigator.pop(context);
          },
        ),
        actions: isTrainer
            ? [
                IconButton(
                  icon: CustomIcon(
                    path: '${AppStrings.assetIcons}people.png',
                    width: 24,
                    height: 24,
                    color: AppColors.accent,
                    fallback: const Icon(Icons.people, color: AppColors.accent),
                  ),
                  onPressed: () {
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TrainerClientsScreen(),
                      ),
                    );
                  },
                  tooltip: 'Мои клиенты',
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _loadOwnProfile();
          });
        },
        color: AppColors.accent,
        child: FutureBuilder<Profile?>(
          future: _ownProfileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }

            final profile = snapshot.data;
            final userCode = profile?.code ?? auth.user?.code ?? 'Загрузка...';

            return Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Инфо-баннер при просмотре данных клиента
                    if (clientsSvc.isViewingClient) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppColors.accent, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Вы просматриваете данные клиента. Здесь отображаются настройки вашего аккаунта.',
                                style: TextStyle(
                                    color: AppColors.accentLight, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Карточка с кодом пользователя
                    if (userCode != 'Загрузка...' && userCode.isNotEmpty)
                      ProfileCodeCard(
                        code: userCode,
                        isTrainer: isTrainer,
                        onCopy: () {
                          if (!context.mounted) return;
                          Clipboard.setData(ClipboardData(text: userCode));
                          ErrorHandler.showSuccess(
                              context, 'Код скопирован в буфер обмена');
                        },
                      ),
                    const SizedBox(height: 24),

                    // Раздел: Аккаунт
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            iconPath: '${AppStrings.assetIcons}email.png',
                            fallbackIcon: Icons.email,
                            label: 'Email',
                            value: authEmail,
                          ),
                          const Divider(color: AppColors.backgroundSecondary),
                          _buildInfoRow(
                            iconPath: '${AppStrings.assetIcons}person.png',
                            fallbackIcon: Icons.person,
                            label: 'Имя',
                            value: profile?.fullName.isNotEmpty == true
                                ? profile!.fullName
                                : 'Не указано',
                          ),
                          const Divider(color: AppColors.backgroundSecondary),
                          _buildInfoRow(
                            iconPath: isTrainer
                                ? '${AppStrings.assetIcons}school.png'
                                : '${AppStrings.assetIcons}badge.png',
                            fallbackIcon:
                                isTrainer ? Icons.school : Icons.badge,
                            label: 'Роль',
                            value: isTrainer ? 'Тренер' : 'Клиент',
                            valueColor: AppColors.accentLight,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Раздел: Безопасность
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
                      onPressed: () {
                        if (!context.mounted) return;
                        _showChangePasswordDialog(context, profileSvc);
                      },
                      icon: CustomIcon(
                        path: '${AppStrings.assetIcons}lock.png',
                        width: 20,
                        height: 20,
                        fallback: const Icon(Icons.lock_reset, size: 20),
                      ),
                      label: const Text('Сменить пароль',
                          style: TextStyle(fontSize: 16)),
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
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String iconPath,
    required IconData fallbackIcon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          CustomIcon(
            path: iconPath,
            width: 24,
            height: 24,
            color: AppColors.accent,
            fallback: Icon(fallbackIcon, color: AppColors.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, ProfileService svc) {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePass = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (sheetCtx, setState) => AlertDialog(
          backgroundColor: AppColors.background,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  obscureText: obscurePass,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Новый пароль',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePass ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => obscurePass = !obscurePass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Введите пароль';
                    if (v.length < _ProfileConstants.minPasswordLength) {
                      return 'Минимум ${_ProfileConstants.minPasswordLength} символов';
                    }
                    if (!RegExp(_ProfileConstants.passwordRegex).hasMatch(v)) {
                      return 'Пароль должен содержать буквы и цифры';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmCtrl,
                  obscureText: obscureConfirm,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Подтвердите пароль',
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm
                            ? Icons.visibility
                            : Icons.visibility_off,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => obscureConfirm = !obscureConfirm),
                    ),
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
              child: const Text('Отмена',
                  style: TextStyle(color: AppColors.textHint)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                if (passCtrl.text != confirmCtrl.text) {
                  ErrorHandler.show(dialogCtx, 'Пароли не совпадают');
                  return;
                }

                try {
                  final success = await svc.updatePassword(passCtrl.text);

                  if (!sheetCtx.mounted) return;

                  if (success) {
                    Navigator.pop(dialogCtx);
                    if (context.mounted) {
                      ErrorHandler.showSuccess(context, 'Пароль успешно изменён');
                    }
                    passCtrl.clear();
                    confirmCtrl.clear();
                  } else {
                    ErrorHandler.show(
                      dialogCtx,
                      svc.error ?? 'Не удалось сменить пароль',
                    );
                  }
                } on AuthException catch (e) {
                  if (!sheetCtx.mounted) return;
                  ErrorHandler.show(
                    dialogCtx,
                    ErrorHandler.format(e, context: 'password_change'),
                  );
                } on SocketException catch (e) {
                  if (!sheetCtx.mounted) return;
                  ErrorHandler.show(
                    dialogCtx,
                    ErrorHandler.format(e, context: 'password_change'),
                  );
                } catch (e, stack) {
                  debugPrint('❌ Change password error: $e');
                  debugPrint('Stack: $stack');

                  if (!sheetCtx.mounted) return;
                  ErrorHandler.show(
                    dialogCtx,
                    ErrorHandler.format(e, context: 'password_change'),
                  );
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
      ),
    );
  }
}