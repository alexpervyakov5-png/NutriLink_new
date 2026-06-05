import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/config.dart';
import '../../../data/clients_service.dart';

class ClientSelector extends StatelessWidget {
  const ClientSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClientsService>(
      builder: (context, clientsService, child) {
        if (!clientsService.hasClients) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(
              bottom: BorderSide(color: AppColors.backgroundSecondary, width: 1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  clientsService.isViewingOwnData
                      ? Icons.person
                      : Icons.person_outline,
                  color: clientsService.isViewingOwnData
                      ? AppColors.accentLight
                      : AppColors.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clientsService.isViewingOwnData
                          ? 'Вы просматриваете свои данные'
                          : 'Просмотр данных клиента',
                      style: TextStyle(
                        color: AppColors.textHint,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    DropdownButton<ClientInfo>(
                      value: clientsService.selectedClient,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: AppColors.backgroundSecondary,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      icon: Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.accent,
                        size: 20,
                      ),
                      items: clientsService.clients.map((client) {
                        return DropdownMenuItem<ClientInfo>(
                          value: client,
                          child: Row(
                            children: [
                              Icon(
                                client.isMe
                                    ? Icons.person
                                    : Icons.person_outline,
                                color: client.isMe
                                    ? AppColors.accentLight
                                    : AppColors.textSecondary,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  client.isMe
                                      ? 'Вы (${client.name})'
                                      : client.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: client.isMe
                                        ? AppColors.accentLight
                                        : AppColors.textPrimary,
                                    fontWeight: client.isMe
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (client) {
                        if (client != null) {
                          clientsService.selectClient(client);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}