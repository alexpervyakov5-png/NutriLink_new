import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../data/models.dart';
import '../data/services.dart';
import '../data/clients_service.dart';
import 'widgets.dart';
import 'widgets/custom_tab_icon.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLoaded && mounted) {
        _loadProfile();
        _isLoaded = true;
      }
    });
  }

  Future<void> _loadProfile() async {
    try {
      await context.read<ProfileService>().load();
    } catch (e) {
      if (!mounted) return;
      _showError(_formatError(e, context: 'load'));
    }
  }

  String _formatError(Object error, {String context = ''}) {
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
      if (error.toString().contains('row-level security') || 
          error.toString().contains('permission denied')) {
        return 'Ошибка доступа. Обратитесь в поддержку';
      }
      if (error.toString().contains('duplicate') || 
          error.toString().contains('unique constraint')) {
        return 'Данные уже существуют. Проверьте введённые значения';
      }
      return 'Ошибка сохранения данных. Попробуйте позже';
    }
    
    if (error is String) return error;
    
    if (context.isNotEmpty) {
      switch (context) {
        case 'load': return 'Не удалось загрузить профиль. Попробуйте снова';
        case 'save': return 'Не удалось сохранить изменения. Попробуйте снова';
        case 'update': return 'Не удалось обновить данные';
      }
    }
    
    return 'Произошла непредвиденная ошибка. Попробуйте снова';
  }

  void _showError(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
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
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
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

  String? _validateProfile(Profile p) {
    if (p.firstName.trim().isEmpty) return 'Введите имя';
    if (p.firstName.trim().length < 2) return 'Имя должно быть не менее 2 символов';
    if (p.lastName.trim().isEmpty) return 'Введите фамилию';
    if (p.lastName.trim().length < 2) return 'Фамилия должна быть не менее 2 символов';
    if (p.heightCm != null && (p.heightCm! < 100 || p.heightCm! > 250)) {
      return 'Рост должен быть от 100 до 250 см';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<ProfileService>();
    final clientsSvc = context.watch<ClientsService>();
    final canEdit = clientsSvc.isViewingOwnData;

    if (svc.loading && svc.profile == null) {
      return const Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (svc.profile == null) {
      return Scaffold(
        backgroundColor: AppColors.backgroundSecondary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Не удалось загрузить данные', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: svc.loading ? null : () => _loadProfile(),
                child: const Text('Повторить'),
              ),
            ],
          ),
        ),
      );
    }

    final p = svc.profile!;
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!canEdit) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    CustomIcon(
                      path: '${AppStrings.assetIcons}visibility.png',
                      width: 20,
                      height: 20,
                      color: AppColors.accent,
                      fallback: const Icon(Icons.visibility, color: AppColors.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Режим просмотра. Данные редактируются самим клиентом.',
                        style: TextStyle(color: AppColors.accentLight, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            _Field('Имя', p.firstName, (v) => svc.update((p) => p.copyWith(firstName: v)), enabled: canEdit),
            const SizedBox(height: 16),
            _Field('Фамилия', p.lastName, (v) => svc.update((p) => p.copyWith(lastName: v)), enabled: canEdit),
            const SizedBox(height: 16),
            _DateField('Дата рождения', p.birthDate, (d) => svc.update((p) => p.copyWith(birthDate: d)), enabled: canEdit),
            const SizedBox(height: 16),
            _Dropdown<int>('Рост', p.heightCm, List.generate(41, (i) => 150 + i * 5), (v) => svc.update((p) => p.copyWith(heightCm: v)), enabled: canEdit),
            const SizedBox(height: 16),
            _Dropdown<String>('Пол', 
              p.gender, 
              ['Мужской', 'Женский'], 
              (v) => svc.update((p) => p.copyWith(gender: v)),
              allowNull: true,
              enabled: canEdit,
            ),
            const SizedBox(height: 24),

            _buildSectionTitle('Цель'),
            _Radio('Похудение', 'slim', GoalType.weightLoss, p.goal, (v) => svc.update((p) => p.copyWith(goal: v)), enabled: canEdit),
            _Radio('Поддержание', 'therapy', GoalType.maintenance, p.goal, (v) => svc.update((p) => p.copyWith(goal: v)), enabled: canEdit),
            _Radio('Массонабор', 'strong', GoalType.muscleGain, p.goal, (v) => svc.update((p) => p.copyWith(goal: v)), enabled: canEdit),
            const SizedBox(height: 24),

            if (canEdit)
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: svc.saving ? null : () async {
                    final error = _validateProfile(svc.profile!);
                    if (error != null) {
                      _showError(error);
                      return;
                    }
                    
                    try {
                      final ok = await svc.save();
                      if (!mounted) return;
                      
                      if (ok) {
                        _showSuccess('Изменения сохранены');
                      } else {
                        _showError(svc.error != null ? _formatError(svc.error!, context: 'save') : 'Не удалось сохранить изменения');
                      }
                    } catch (e) {
                      if (!mounted) return;
                      _showError(_formatError(e, context: 'save'));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: svc.saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Сохранить изменения', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }
}

class _Field extends StatelessWidget {
  final String l, v; 
  final ValueChanged<String> c;
  final bool enabled;

  const _Field(this.l, this.v, this.c, {this.enabled = true});
  
  @override 
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: enabled ? AppColors.card : AppColors.card.withOpacity(0.5), 
          borderRadius: BorderRadius.circular(8)
        ),
        child: TextFormField(
          initialValue: v, 
          enabled: enabled,
          style: TextStyle(
            color: enabled ? AppColors.textPrimary : AppColors.textHint,
          ),
          decoration: InputDecoration(
            hintText: 'Введите...', 
            hintStyle: const TextStyle(color: AppColors.textHint),
            border: InputBorder.none, 
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
          ),
          onChanged: (value) {
            if (enabled) c(value.trim());
          },
        ),
      ),
    ],
  );
}

class _DateField extends StatelessWidget {
  final String l; 
  final DateTime? v; 
  final ValueChanged<DateTime?> c;
  final bool enabled;
  
  const _DateField(this.l, this.v, this.c, {this.enabled = true});
  
  @override 
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)), 
      const SizedBox(height: 8),
      InkWell(
        onTap: enabled ? () async {
          try {
            final date = await showDatePicker(
              context: context, 
              initialDate: v ?? DateTime(2000),
              firstDate: DateTime(1900), 
              lastDate: DateTime.now()
            );
            if (date != null && context.mounted) {
              if (date.isAfter(DateTime.now())) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Дата не может быть в будущем'),
                    backgroundColor: Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              c(date);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Не удалось выбрать дату'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        } : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: enabled ? AppColors.card : AppColors.card.withOpacity(0.5), 
            borderRadius: BorderRadius.circular(8)
          ),
          child: Row(children: [
            Expanded(child: Text(
              v != null ? '${v!.day.toString().padLeft(2, '0')}.${v!.month.toString().padLeft(2, '0')}.${v!.year}' : 'Выберите дату',
              style: TextStyle(color: v != null ? (enabled ? AppColors.textPrimary : AppColors.textHint) : AppColors.textHint)
            )),
            CustomIcon(
              path: '${AppStrings.assetIcons}calendar.png',
              width: 20,
              height: 20,
              color: enabled ? AppColors.textHint : AppColors.textHint.withOpacity(0.4),
              fallback: const Icon(Icons.calendar_today, size: 20),
            ),
          ]),
        ),
      ),
    ],
  );
}

class _Dropdown<T> extends StatelessWidget {
  final String l; 
  final T? v; 
  final List<T> items; 
  final ValueChanged<T?> c;
  final bool allowNull;
  final bool enabled;
  
  const _Dropdown(this.l, this.v, this.items, this.c, {this.allowNull = false, this.enabled = true});
  
  @override 
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)), 
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: enabled ? AppColors.card : AppColors.card.withOpacity(0.5), 
          borderRadius: BorderRadius.circular(8)
        ),
        child: DropdownButtonHideUnderline(
          child: ButtonTheme(
            alignedDropdown: true,
            child: DropdownButton<T>(
              isExpanded: true,
              value: (allowNull || items.contains(v)) ? v : (allowNull ? null : items.first),
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Text('Выбрать', style: const TextStyle(color: AppColors.textHint)),
              ),
              dropdownColor: AppColors.card,
              style: TextStyle(
                color: enabled ? AppColors.textPrimary : AppColors.textHint,
                fontSize: 15,
              ),
              icon: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CustomIcon(
                  path: '${AppStrings.assetIcons}arrow_drop_down.png',
                  width: 24,
                  height: 24,
                  color: enabled ? AppColors.textHint : AppColors.textHint.withOpacity(0.4),
                  fallback: const Icon(Icons.arrow_drop_down, size: 24),
                ),
              ),
              items: items.map((i) => DropdownMenuItem<T>(
                value: i, 
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    i.toString(), 
                    style: TextStyle(color: enabled ? AppColors.textPrimary : AppColors.textHint),
                  ),
                ),
              )).toList(), 
              onChanged: enabled ? (value) {
                if (value != null || allowNull) {
                  c(value);
                }
              } : null,
            ),
          ),
        ),
      ),
    ],
  );
}

class _Radio extends StatelessWidget {
  final String l; 
  final String iconKey;
  final dynamic v, g; 
  final ValueChanged<dynamic> c;
  final bool enabled;
  
  const _Radio(this.l, this.iconKey, this.v, this.g, this.c, {this.enabled = true});
  
  @override 
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: enabled ? AppColors.card : AppColors.card.withOpacity(0.5), 
      borderRadius: BorderRadius.circular(8)
    ),
    child: RadioListTile<dynamic>(
      title: Row(children: [
        CustomIcon(
          path: '${AppStrings.assetImages}$iconKey.png',
          width: 20,
          height: 20,
          color: AppColors.accent,
          fallback: Icon(_getFallbackIcon(iconKey), color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 8),
        Text(l, style: TextStyle(color: enabled ? AppColors.textPrimary : AppColors.textHint))
      ]),
      value: v, 
      groupValue: g, 
      onChanged: enabled ? (value) {
        if (value != null) {
          c(value);
        }
      } : null, 
      activeColor: AppColors.accentLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
  );

  IconData _getFallbackIcon(String key) {
    switch (key) {
      case 'slim': return Icons.trending_down;
      case 'therapy': return Icons.balance;
      case 'strong': return Icons.fitness_center;
      default: return Icons.circle;
    }
  }
}