import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/error_handler.dart';

import 'widgets/add_client_dialog.dart';
import '../data/profile_service.dart';
import '../data/auth_service.dart';
import '../data/clients_service.dart';

import '../data/models.dart';

class TrainerClientsScreen extends StatefulWidget {
  const TrainerClientsScreen({super.key});

  @override
  State<TrainerClientsScreen> createState() => _TrainerClientsScreenState();
}

class _TrainerClientsScreenState extends State<TrainerClientsScreen> {
  List<Profile> _clients = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final trainerId = context.read<AuthService>().user?.id;
    if (trainerId == null) return;

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final clients = await context.read<ProfileService>()
          .getTrainerClients(trainerId);
      
      if (!mounted) return;
      
      setState(() {
        _clients = clients.where((c) => c.id != null).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _error = ErrorHandler.format(e, context: 'trainer_clients_load');
        _isLoading = false;
      });
    }
  }

  Future<void> _addClient() async {
    if (!mounted) return;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AddClientDialog(),
    );
    
    if (result == true && mounted) {
      await _loadClients();
      if (mounted) {
        ErrorHandler.showSuccess(context, 'Клиент успешно добавлен');
      }
    }
  }

  Future<void> _removeClient(String clientId, String clientName) async {
    if (!mounted) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Удалить клиента?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          'Вы уверены, что хотите удалить $clientName из списка клиентов?\n\nЭто не удалит аккаунт клиента, а только разорвёт связь с вами как с тренером.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) Navigator.pop(context, false);
            },
            child: const Text('Отмена', style: TextStyle(color: AppColors.textHint)),
          ),
          ElevatedButton(
            onPressed: () {
              if (context.mounted) Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        final success = await context.read<ProfileService>()
            .removeClientFromTrainer(clientId);
        
        if (!mounted) return;
        
        if (success) {
          await _loadClients();
          if (mounted) {
            ErrorHandler.showSuccess(context, 'Клиент удалён');
          }
        } else {
          throw Exception('Не удалось удалить');
        }
      } catch (e) {
        if (!mounted) return;
        ErrorHandler.show(
          context, 
          ErrorHandler.format(e, context: 'trainer_clients_remove'),
        );
      }
    }
  }

  void _viewClientData(Profile client) {
    if (client.id == null) return;
    
    final clientsService = context.read<ClientsService>();
    
    final clientInfo = clientsService.clients.firstWhere(
      (c) => c.id == client.id,
      orElse: () => ClientInfo(
        id: client.id!,
        name: client.fullName,
        email: null,
        code: client.code,
        isMe: false,
      ),
    );
    
    clientsService.selectClient(clientInfo);
    
    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'Мои клиенты',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (context.mounted) Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.accent),
            onPressed: _isLoading ? null : _addClient,
            tooltip: 'Добавить клиента',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : RefreshIndicator(
              onRefresh: _loadClients,
              color: AppColors.accent,
              child: _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 48),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(color: AppColors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadClients,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    )
                  : _clients.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 80,
                                color: AppColors.textHint,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'У вас пока нет клиентов',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Добавьте клиента по коду',
                                style: TextStyle(
                                  color: AppColors.textHint,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _addClient,
                                icon: const Icon(Icons.add),
                                label: const Text('Добавить клиента'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _clients.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final client = _clients[index];
                            return Dismissible(
                              key: ValueKey(client.id!),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.white,
                                ),
                              ),
                              onDismissed: (_) {
                                _removeClient(client.id!, client.fullName);
                              },
                              child: GestureDetector(
                                onTap: () => _viewClientData(client),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundSecondary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.person,
                                          color: AppColors.accentLight,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              client.fullName,
                                              style: const TextStyle(
                                                color: AppColors.textPrimary,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (client.code != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Код: ${client.code}',
                                                style: TextStyle(
                                                  color: AppColors.textHint,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Text(
                                              'назад',
                                              style: TextStyle(
                                                color: AppColors.accent,
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        color: AppColors.accent,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
    );
  }
}