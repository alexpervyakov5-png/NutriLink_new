import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config.dart';
import '../../../data/models.dart';
import '../../data/auth_service.dart';
import '../../data/profile_service.dart';

class AddClientDialog extends StatefulWidget {
  const AddClientDialog({super.key});

  @override
  State<AddClientDialog> createState() => _AddClientDialogState();
}

class _AddClientDialogState extends State<AddClientDialog> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  Profile? _foundClient;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _searchClient() async {
    final code = _codeController.text.trim().toUpperCase();
    
    if (code.length != 6) {
      setState(() => _error = 'Код должен содержать 6 символов');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _foundClient = null;
    });

    try {
      final client = await context.read<ProfileService>().findClientByCode(code);
      
      if (!mounted) return;
      
      if (client == null) {
        setState(() {
          _isLoading = false;
          _error = 'Клиент с таким кодом не найден';
        });
      } else if (client.trainerId != null) {
        setState(() {
          _isLoading = false;
          _error = 'Этот клиент уже закреплён за другим тренером';
        });
      } else {
        setState(() {
          _isLoading = false;
          _foundClient = client;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Ошибка поиска: $e';
      });
    }
  }

  Future<void> _addClient() async {
    if (_foundClient == null) return;
    
    final trainerId = context.read<AuthService>().user?.id;
    if (trainerId == null) return;

    setState(() => _isLoading = true);

    try {
      final success = await context.read<ProfileService>()
          .addClientToTrainer(trainerId, _foundClient!.id!);
      
      if (!mounted) return;
      
      if (success) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Не удалось добавить клиента';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Ошибка: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Добавить клиента',
        style: TextStyle(color: AppColors.textPrimary),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Введите код клиента (6 символов)',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              maxLength: 6,
              textAlign: TextAlign.center,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: AppColors.accentLight,
              ),
              decoration: InputDecoration(
                hintText: 'ABC123',
                hintStyle: TextStyle(color: AppColors.textHint),
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.accent),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.backgroundSecondary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.accent, width: 2),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            if (_foundClient != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Найден клиент:',
                      style: TextStyle(
                        color: AppColors.accentLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _foundClient!.fullName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    if (_foundClient!.code != null)
                      Text(
                        'Код: ${_foundClient!.code}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () {
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Отмена', style: TextStyle(color: AppColors.textHint)),
        ),
        if (_foundClient == null)
          ElevatedButton(
            onPressed: _isLoading ? null : _searchClient,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Найти'),
          )
        else
          ElevatedButton(
            onPressed: _isLoading ? null : _addClient,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Добавить'),
          ),
      ],
    );
  }
}