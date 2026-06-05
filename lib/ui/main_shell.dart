import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../data/clients_service.dart';
import '../data/services.dart';
import 'home_screen.dart';
import 'diary_screen.dart';
import 'measurements_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'widgets/client_selector.dart';
import 'widgets/custom_tab_icon.dart';
import '../main.dart'; // 🔥 Импорт для доступа к signOutGlobally и navigatorKey

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _navIndex = 0;
  bool _isSigningOut = false;
  bool _clientsInitialized = false;
  String? _lastSelectedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_clientsInitialized) {
        _initializeClients();
      }
    });
  }

  Future<void> _initializeClients() async {
    if (!mounted) return;
    
    final clientsService = context.read<ClientsService>();
    await clientsService.loadClients();
    _clientsInitialized = true;
    _lastSelectedUserId = clientsService.selectedUserId;
    
    if (mounted) {
      clientsService.addListener(_onClientChanged);
      _reloadCurrentScreenData(force: true);
    }
  }

  @override
  void dispose() {
    // 🔥 Сначала удаляем listener перед dispose
    if (_clientsInitialized) {
      try {
        context.read<ClientsService>().removeListener(_onClientChanged);
      } catch (e) {
        debugPrint('⚠️ Error removing listener: $e');
      }
    }
    // 🔥 Затем вызываем super.dispose()
    super.dispose();
  }

  void _onClientChanged() {
    if (!mounted) return;
    
    final clientsService = context.read<ClientsService>();
    if (clientsService.loading) return;

    final newUserId = clientsService.selectedUserId;
    
    if (_lastSelectedUserId != newUserId) {
      debugPrint('🔔 CLIENT CHANGED: $_lastSelectedUserId → $newUserId');
      _lastSelectedUserId = newUserId;
      
      _reloadAllServices(force: true);
      _reloadCurrentScreenData(force: true);
    }
  }

  void _reloadAllServices({bool force = false}) {
    if (!mounted) return;
    
    debugPrint('🔄 Reloading ALL services for user: $_lastSelectedUserId');
    
    context.read<ProfileService>().load(force: force);
    context.read<DiaryService>().refresh();
    context.read<MeasurementsService>().load(force: force);
    context.read<StatsService>().load(force: force);
  }

  void _reloadCurrentScreenData({bool force = false}) {
    if (!mounted) return;
    
    debugPrint('📥 Reloading screen $_navIndex for user: $_lastSelectedUserId');
    
    switch (_navIndex) {
      case 0:
        context.read<ProfileService>().load(force: force);
        break;
      case 1:
        context.read<DiaryService>().refresh();
        break;
      case 2:
        context.read<MeasurementsService>().load(force: force);
        break;
      case 3:
        context.read<StatsService>().load(force: force);
        break;
    }
  }

  String _formatError(Object? error) {
    if (error == null) return 'Произошла непредвиденная ошибка';
    
    final errorStr = error.toString();
    if (error is SocketException || 
        errorStr.contains('SocketException') ||
        errorStr.contains('Network is unreachable') ||
        errorStr.contains('Connection refused') ||
        errorStr.contains('Failed host lookup')) {
      return 'Нет подключения к интернету';
    }
    
    if (errorStr.contains('JWT expired') || errorStr.contains('session')) {
      return 'Сессия истекла. Войдите снова';
    }
    return 'Ошибка: $error';
  }

  void _showError(BuildContext ctx, String message) {
    if (!ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 🔥 МЕТОД _signOut() УДАЛЁН — используем signOutGlobally() из main.dart

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔥 Логотип БЕЗ color параметра, чтобы сохранить оригинальные цвета
            CustomIcon(
              path: '${AppStrings.assetIcons}nutrilink.png',
              width: 32,
              height: 32,
              // color: AppColors.accentLight, // <--- УДАЛЕНО!
              fallback: const Icon(Icons.restaurant, size: 32),
            ),
            const SizedBox(width: 8),
            const Text(
              AppStrings.appName,
              style: TextStyle(
                color: AppColors.accentLight,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: CustomIcon(
              path: '${AppStrings.assetIcons}menu.png',
              width: 24,
              height: 24,
              color: AppColors.textPrimary,
              fallback: const Icon(Icons.menu, color: AppColors.textPrimary),
            ),
            onPressed: () {
              if (!context.mounted) return;
              _showMenu(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const ClientSelector(),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _buildScreen(_navIndex),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.backgroundSecondary,
        selectedItemColor: AppColors.accentLight,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (!mounted) return;
          if (index != _navIndex) {
            setState(() => _navIndex = index);
            _reloadCurrentScreenData(force: true);
          }
        },
        items: [
          BottomNavigationBarItem(
            icon: CustomTabIcon(
              iconPath: '${AppStrings.assetIcons}home.png',
              activeIconPath: '${AppStrings.assetIcons}home_active.png',
              isActive: _navIndex == 0,
            ),
            activeIcon: CustomTabIcon(
              iconPath: '${AppStrings.assetIcons}home.png',
              activeIconPath: '${AppStrings.assetIcons}home_active.png',
              isActive: true,
            ),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: CustomTabIcon(
              iconPath: '${AppStrings.assetIcons}book.png',
              activeIconPath: '${AppStrings.assetIcons}book_active.png',
              isActive: _navIndex == 1,
            ),
            activeIcon: CustomTabIcon(
              iconPath: '${AppStrings.assetIcons}book.png',
              activeIconPath: '${AppStrings.assetIcons}book_active.png',
              isActive: true,
            ),
            label: 'Дневник',
          ),
          BottomNavigationBarItem(
            icon: CustomTabIcon(
              iconPath: '${AppStrings.assetIcons}measurements.png',
              activeIconPath: '${AppStrings.assetIcons}measurements_active.png',
              isActive: _navIndex == 2,
            ),
            activeIcon: CustomTabIcon(
              iconPath: '${AppStrings.assetIcons}measurements.png',
              activeIconPath: '${AppStrings.assetIcons}measurements_active.png',
              isActive: true,
            ),
            label: 'Замеры',
          ),
          BottomNavigationBarItem(
            icon: CustomTabIcon(
              iconPath: '${AppStrings.assetIcons}stats.png',
              activeIconPath: '${AppStrings.assetIcons}stats_active.png',
              isActive: _navIndex == 3,
            ),
            activeIcon: CustomTabIcon(
              iconPath: '${AppStrings.assetIcons}stats.png',
              activeIconPath: '${AppStrings.assetIcons}stats_active.png',
              isActive: true,
            ),
            label: 'Статистика',
          ),
        ],
      ),
    );
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0: return const HomeScreen(key: ValueKey('home'));
      case 1: return const DiaryScreen(key: ValueKey('diary'));
      case 2: return const MeasurementsScreen(key: ValueKey('measurements'));
      case 3: return const StatsScreen(key: ValueKey('stats'));
      default: return const HomeScreen(key: ValueKey('home'));
    }
  }

  void _showMenu(BuildContext ctx) {
    if (!ctx.mounted) return;
    
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (menuContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: CustomIcon(
              path: '${AppStrings.assetIcons}person.png',
              width: 24,
              height: 24,
              color: AppColors.textPrimary,
              fallback: const Icon(Icons.person, color: AppColors.textPrimary),
            ),
            title: const Text('Профиль', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              Navigator.of(menuContext).pop();
              Future.microtask(() {
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                }
              });
            },
          ),
          ListTile(
            leading: _isSigningOut 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : CustomIcon(
                    path: '${AppStrings.assetIcons}logout.png',
                    width: 24,
                    height: 24,
                    color: Colors.red,
                    fallback: const Icon(Icons.logout, color: Colors.red),
                  ),
            title: const Text('Выйти', style: TextStyle(color: Colors.red)),
            enabled: !_isSigningOut,
            onTap: () async {
              // 🔥 Закрываем меню
              Navigator.of(menuContext).pop();
              
              // 🔥 Ждем закрытия меню
              await Future.delayed(const Duration(milliseconds: 300));
              
              // 🔥 Проверяем, что виджет еще активен
              if (!mounted) return;
              
              // 🔥 ВЫЗЫВАЕМ ГЛОБАЛЬНУЮ ФУНКЦИЮ — она не зависит от контекста виджета!
              signOutGlobally();
            },
          ),
        ],
      ),
    );
  }
}