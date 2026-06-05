import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'data/clients_service.dart';
import 'data/services.dart';
import 'ui/auth_screen.dart';
import 'ui/main_shell.dart';
import 'ui/trainer_clients_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void showGlobalError(String message) {
  final context = navigatorKey.currentContext;
  if (context != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
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
    });
  }
}

void showGlobalSuccess(String message) {
  final context = navigatorKey.currentContext;
  if (context != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.initialize();
  
  // 🔥 Создаем ОДИН экземпляр ClientsService для всего приложения
  final clientsService = ClientsService();
  
  runApp(NutriLinkApp(clientsService: clientsService));
}

class NutriLinkApp extends StatelessWidget {
  final ClientsService clientsService;
  
  const NutriLinkApp({super.key, required this.clientsService});

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          // 🔥 Используем .value(), чтобы использовать созданный выше экземпляр
          ChangeNotifierProvider<ClientsService>.value(value: clientsService),
          
          ChangeNotifierProvider(
            create: (_) => AuthService()..checkSession(),
          ),
          
          // 🔥 Передаем clientsService во все сервисы, чтобы они слушали один и тот же инстанс
          ChangeNotifierProvider(
            create: (context) => ProfileService(clientsService),
          ),
          ChangeNotifierProvider(
            create: (context) => DiaryService(clientsService),
          ),
          ChangeNotifierProvider(
            create: (context) => MeasurementsService(clientsService),
          ),
          ChangeNotifierProvider(
            create: (context) => StatsService(clientsService),
          ),
        ],
        child: MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          navigatorKey: navigatorKey,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ru'), Locale('en')],
          locale: const Locale('ru'),
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.background,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: AppColors.textPrimary),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: AppColors.backgroundSecondary,
              selectedItemColor: AppColors.accentLight,
              unselectedItemColor: Colors.grey,
            ),
          ),
          routes: {
            '/trainer-clients': (context) => const TrainerClientsScreen(),
          },
          home: const _Router(),
        ),
      );
}

class _Router extends StatelessWidget {
  const _Router();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    if (auth.loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.accent),
              SizedBox(height: 16),
              Text(
                AppStrings.appName,
                style: TextStyle(
                  color: AppColors.accentLight,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (auth.isAuth) {
      return const MainShell();
    }
    return const AuthScreen();
  }
}