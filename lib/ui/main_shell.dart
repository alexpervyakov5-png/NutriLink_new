import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../data/clients_service.dart';
import '../data/services.dart';
import 'auth_screen.dart';
import 'diary_screen.dart';
import 'home_screen.dart';
import 'measurements_screen.dart';
import 'profile_screen.dart';
import 'stats_screen.dart';
import '../widgets/client_selector.dart'; // ✅ ИСПРАВЛЕНО: правильный путь

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _navIndex = 0;
  bool _isSigningOut = false;
  bool _clientsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_clientsInitialized) {
        context.read<ClientsService>().loadClients();
        _clientsInitialized = true;
        context.read<ClientsService>().addListener(_onClientChanged);
      }
    });
  }

  @override
  void dispose() {
    context.read<ClientsService>().removeListener(_onClientChanged);
    super.dispose();
  }

  void _onClientChanged() {
    final clientsService = context.read<ClientsService>();
    if (clientsService.loading) return;

    switch (_navIndex) {
      case 0:
        context.read<ProfileService>().load(force: true);
        break;
      case 1:
        context.read<DiaryService>().refresh();
        break;
      case 2:
        context.read<MeasurementsService>().load(force: true);
        break;
      case 3:
        context.read<StatsService>().refresh();
        break;
    }
  }

  String _formatError(Object? error) {
    if (error == null) return 'Произошла непредвиденная ошибка';
    
    if (error is SocketException || 
        error.toString().contains('SocketException') ||
        error.toString().contains('Network is unreachable')) {
      return 'Нет подключения к интернету. Проверьте соединение';
    }
    if (error.toString().contains('JWT expired') || 
        error.toString().contains('session')) {
      return 'Сессия истекла. Пожалуйста, войдите снова';
    }
    if (error.toString().contains('permission') || 
        error.toString().contains('unauthorized')) {
      return 'Ошибка доступа. Пожалуйста, войдите снова';
    }
    return 'Не удалось выйти. Попробуйте снова';
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

  Future<void> _signOut(BuildContext ctx) async {
    if (_isSigningOut) return;
    
    setState(() => _isSigningOut = true);
    
    try {
      final authService = Provider.of<AuthService>(ctx, listen: false);
      await authService.signOut();
      context.read<ClientsService>().clear();
      
      if (!ctx.mounted) return;
      Navigator.of(ctx).pushNamedAndRemoveUntil('/auth', (route) => false);
    } catch (e) {
      if (!ctx.mounted) return;
      _showError(ctx, _formatError(e));
    } finally {
      if (mounted) {
        setState(() => _isSigningOut = false);
      }
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
            Image.asset(
              '${AppStrings.assetIcons}nutrilink.png',
              width: 32,
              height: 32,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.restaurant, color: AppColors.accentLight),
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
            icon: const Icon(Icons.menu, color: AppColors.textPrimary),
            onPressed: () => _showMenu(context),
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
          if (index != _navIndex) {
            setState(() => _navIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            activeIcon: Icon(Icons.home),
            label: 'Главная',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book),
            activeIcon: Icon(Icons.book),
            label: 'Дневник',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.straighten),
            activeIcon: Icon(Icons.straighten),
            label: 'Замеры',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Статистика',
          ),
        ],
      ),
    );
  }

  Widget _buildScreen(int index) {
    switch (index) {
      case 0:
        return const HomeScreen(key: ValueKey('home'));
      case 1:
        return const DiaryScreen(key: ValueKey('diary'));
      case 2:
        return const MeasurementsScreen(key: ValueKey('measurements'));
      case 3:
        return const StatsScreen(key: ValueKey('stats'));
      default:
        return const HomeScreen(key: ValueKey('home'));
    }
  }

  void _showMenu(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
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
            leading: const Icon(Icons.person, color: AppColors.textPrimary),
            title: const Text('Профиль',
                style: TextStyle(color: AppColors.textPrimary)),
            onTap: () {
              if (!context.mounted) return;
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          ListTile(
            leading: _isSigningOut 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
                : const Icon(Icons.logout, color: Colors.red),
            title: const Text('Выйти', style: TextStyle(color: Colors.red)),
            enabled: !_isSigningOut,
            onTap: () {
              // ✅ ИСПРАВЛЕНО: без async, чтобы избежать use_build_context_synchronously
              if (!context.mounted) return;
              Navigator.pop(context);
              _signOut(context);
            },
          ),
        ],
      ),
    );
  }
}