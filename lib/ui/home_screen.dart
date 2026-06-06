
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/error_handler.dart'; // 🔥 ИСПРАВЛЕНО: используем централизованный ErrorHandler
import '../data/models.dart';

import '../data/clients_service.dart';

import 'widgets/custom_tab_icon.dart';
import '../data/profile_service.dart';

// ============================================
// ВСПОМОГАТЕЛЬНЫЕ КОНСТАНТЫ (локальные)
// ============================================
class _HomeConstants {
  static const int minNameLength = 2;
  static const int minHeight = 100;
  static const int maxHeight = 250;
  static const int heightStep = 5;
  static const int heightStart = 150;
}

// ============================================
// HomeScreen
// ============================================
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
      // 🔥 ИСПРАВЛЕНО: используем централизованный ErrorHandler
      ErrorHandler.show(context, ErrorHandler.format(e, context: 'profile_load'));
    }
  }

  // 🔥 УДАЛЕНО: _formatError, _showError, _showSuccess
  // Теперь используем ErrorHandler из core/error_handler.dart

  String? _validateProfile(Profile p) {
    // 🔥 ИСПРАВЛЕНО: используем локальные константы
    if (p.firstName.trim().isEmpty) return 'Введите имя';
    if (p.firstName.trim().length < _HomeConstants.minNameLength) {
      return 'Имя должно быть не менее ${_HomeConstants.minNameLength} символов';
    }
    if (p.lastName.trim().isEmpty) return 'Введите фамилию';
    if (p.lastName.trim().length < _HomeConstants.minNameLength) {
      return 'Фамилия должна быть не менее ${_HomeConstants.minNameLength} символов';
    }
    if (p.heightCm != null && 
        (p.heightCm! < _HomeConstants.minHeight || p.heightCm! > _HomeConstants.maxHeight)) {
      return 'Рост должен быть от ${_HomeConstants.minHeight} до ${_HomeConstants.maxHeight} см';
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
            _Dropdown<int>('Рост', p.heightCm, 
              List.generate(21, (i) => _HomeConstants.heightStart + i * _HomeConstants.heightStep), 
              (v) => svc.update((p) => p.copyWith(heightCm: v)), 
              enabled: canEdit),
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
            _Radio<GoalType>('Похудение', 'slim', GoalType.weightLoss, p.goal, (v) => svc.update((p) => p.copyWith(goal: v)), enabled: canEdit),
            _Radio<GoalType>('Поддержание', 'therapy', GoalType.maintenance, p.goal, (v) => svc.update((p) => p.copyWith(goal: v)), enabled: canEdit),
            _Radio<GoalType>('Массонабор', 'strong', GoalType.muscleGain, p.goal, (v) => svc.update((p) => p.copyWith(goal: v)), enabled: canEdit),
            const SizedBox(height: 24),

            if (canEdit)
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: svc.saving ? null : () async {
                    final error = _validateProfile(svc.profile!);
                    if (error != null) {
                      // 🔥 ИСПРАВЛЕНО: используем ErrorHandler
                      ErrorHandler.show(context, error);
                      return;
                    }
                    
                    try {
                      final ok = await svc.save();
                      if (!mounted) return;
                      
                      if (ok) {
                        // 🔥 ИСПРАВЛЕНО: используем ErrorHandler
                        ErrorHandler.showSuccess(context, 'Изменения сохранены');
                      } else {
                        // 🔥 ИСПРАВЛЕНО: svc.error уже отформатирован в сервисе
                        ErrorHandler.show(context, svc.error ?? 'Не удалось сохранить изменения');
                      }
                    } catch (e) {
                      if (!mounted) return;
                      // 🔥 ИСПРАВЛЕНО: используем централизованный ErrorHandler
                      ErrorHandler.show(context, ErrorHandler.format(e, context: 'profile_save'));
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

// ============================================
// ВСПОМОГАТЕЛЬНЫЕ ВИДЖЕТЫ
// ============================================

class _Field extends StatelessWidget {
  final String label, value; 
  final ValueChanged<String> onChanged;
  final bool enabled;

  const _Field(this.label, this.value, this.onChanged, {this.enabled = true});
  
  @override 
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: enabled ? AppColors.card : AppColors.card.withOpacity(0.5), 
          borderRadius: BorderRadius.circular(8)
        ),
        child: TextFormField(
          initialValue: value, 
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
          onChanged: (val) {
            if (enabled) onChanged(val.trim());
          },
        ),
      ),
    ],
  );
}

class _DateField extends StatelessWidget {
  final String label; 
  final DateTime? value; 
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;
  
  const _DateField(this.label, this.value, this.onChanged, {this.enabled = true});
  
  @override 
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)), 
      const SizedBox(height: 8),
      InkWell(
        onTap: enabled ? () async {
          try {
            final date = await showDatePicker(
              context: context, 
              initialDate: value ?? DateTime(2000),
              firstDate: DateTime(1900), 
              lastDate: DateTime.now()
            );
            // 🔥 ИСПРАВЛЕНО: проверяем mounted у состояния, а не у параметра context
            if (date != null && context.mounted) {
              if (date.isAfter(DateTime.now())) {
                // 🔥 ИСПРАВЛЕНО: используем ErrorHandler
                ErrorHandler.show(context, 'Дата не может быть в будущем');
                return;
              }
              onChanged(date);
            }
          } catch (e) {
            if (context.mounted) {
              // 🔥 ИСПРАВЛЕНО: используем ErrorHandler
              ErrorHandler.show(context, 'Не удалось выбрать дату');
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
              value != null 
                  ? '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}' 
                  : 'Выберите дату',
              style: TextStyle(
                color: value != null 
                    ? (enabled ? AppColors.textPrimary : AppColors.textHint) 
                    : AppColors.textHint
              )
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
  final String label; 
  final T? value; 
  final List<T> items; 
  final ValueChanged<T?> onChanged;
  final bool allowNull;
  final bool enabled;
  
  const _Dropdown(this.label, this.value, this.items, this.onChanged, {this.allowNull = false, this.enabled = true});
  
  @override 
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)), 
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
              // 🔥 ИСПРАВЛЕНО: безопасная работа с пустым списком
              value: items.isEmpty 
                  ? (allowNull ? null : null) 
                  : (allowNull || items.contains(value)) 
                      ? value 
                      : items.first,
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
              onChanged: enabled ? (val) {
                if (val != null || allowNull) {
                  onChanged(val);
                }
              } : null,
            ),
          ),
        ),
      ),
    ],
  );
}

// 🔥 ИСПРАВЛЕНО: добавлен дженерик <T> вместо dynamic
class _Radio<T> extends StatelessWidget {
  final String label; 
  final String iconKey;
  final T value;
  final T groupValue; 
  final ValueChanged<T> onChanged;
  final bool enabled;
  
  const _Radio(this.label, this.iconKey, this.value, this.groupValue, this.onChanged, {this.enabled = true});
  
  @override 
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: enabled ? AppColors.card : AppColors.card.withOpacity(0.5), 
      borderRadius: BorderRadius.circular(8)
    ),
    child: RadioListTile<T>(
      title: Row(children: [
        CustomIcon(
          path: '${AppStrings.assetImages}$iconKey.png',
          width: 20,
          height: 20,
          color: AppColors.accent,
          fallback: Icon(_getFallbackIcon(iconKey), color: AppColors.accent, size: 20),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: enabled ? AppColors.textPrimary : AppColors.textHint))
      ]),
      value: value, 
      groupValue: groupValue, 
      onChanged: enabled ? (val) {
        if (val != null) {
          onChanged(val);
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