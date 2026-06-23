import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/profile_service.dart';
import '../core/config.dart';
import '../data/clients_service.dart';
import '../data/stats_service.dart';
import '../data/measurements_service.dart';
import '../data/diary_service.dart';
import 'home_screen.dart';
import 'diary/diary_screen.dart';
import 'measurements_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'widgets/custom_tab_icon.dart';

import '../core/error_handler.dart'; 

import 'widgets/client_selector.dart';

import '../main.dart'; 

// ============================================
// MainShell
// ============================================
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
  
  ClientsService? _clientsServiceRef;

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
    _clientsServiceRef = clientsService;
    
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
    if (_clientsInitialized && _clientsServiceRef != null) {
      try {
        _clientsServiceRef!.removeListener(_onClientChanged);
      } catch (e) {
        debugPrint('⚠️ Error removing listener: $e');
      }
      _clientsServiceRef = null;
    }
    super.dispose();
  }

  void _onClientChanged() {
    if (!mounted) return;
    
    final clientsService = _clientsServiceRef;
    if (clientsService == null || clientsService.loading) return;

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
    
    if (!SupabaseConfig.isAuthorized) {
      debugPrint('⚠️ _reloadAllServices: user not authorized, skipping');
      return;
    }
    
    debugPrint('🔄 Reloading ALL services for user: $_lastSelectedUserId');
    
    context.read<ProfileService>().load(force: force);
    context.read<DiaryService>().refresh();
    context.read<MeasurementsService>().load(force: force);
    context.read<StatsService>().load(force: force);
  }

  void _reloadCurrentScreenData({bool force = false}) {
    if (!mounted) return;
    
    if (!SupabaseConfig.isAuthorized) {
      debugPrint('⚠️ _reloadCurrentScreenData: user not authorized, skipping');
      return;
    }
    
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
            CustomIcon(
              path: '${AppStrings.assetIcons}nutrilink.png',
              width: 32,
              height: 32,
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
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: CustomTabIcon(
              iconPath: '${AppStrings.assetIcons}book.png',
              activeIconPath: '${AppStrings.assetIcons}book_active.png',
              isActive: _navIndex == 1,
            ),
            label: 'Дневник',
          ),
          BottomNavigationBarItem(
            icon: CustomTabIcon(
              iconPath: '${AppStrings.assetIcons}measurements.png',
              activeIconPath: '${AppStrings.assetIcons}measurements_active.png',
              isActive: _navIndex == 2,
            ),
            label: 'Замеры',
          ),
          BottomNavigationBarItem(
            icon: CustomTabIcon(
              iconPath: '${AppStrings.assetIcons}stats.png',
              activeIconPath: '${AppStrings.assetIcons}stats_active.png',
              isActive: _navIndex == 3,
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
            // 🔥 ИСПРАВЛЕНИЕ: явно указываем цвет тайла для корректной отрисовки ink splash
            tileColor: AppColors.backgroundSecondary,
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
            // 🔥 ИСПРАВЛЕНИЕ: явно указываем цвет тайла для корректной отрисовки ink splash
            tileColor: AppColors.backgroundSecondary,
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
              Navigator.of(menuContext).pop();
              
              await Future.delayed(const Duration(milliseconds: 300));
              
              if (!mounted) return;
              
              setState(() => _isSigningOut = true);
              try {
                await signOutGlobally();
              } catch (e) {
                if (mounted) {
                  ErrorHandler.show(context, ErrorHandler.format(e, context: 'logout'));
                }
              } finally {
                if (mounted) {
                  setState(() => _isSigningOut = false);
                }
              }
            },
          ),
        ],
      ),
    );
  }
}