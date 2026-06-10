import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:app_links/app_links.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/auth_service.dart';
import 'data/profile_service.dart';
import 'data/diary_service.dart';
import 'data/measurements_service.dart';
import 'data/stats_service.dart';
import 'core/config.dart';
import 'core/error_handler.dart';
import 'data/clients_service.dart';
import 'services/notification_service.dart';
import 'ui/auth_screen.dart';
import 'ui/auth/recovery_password_screen.dart';
import 'ui/main_shell.dart';
import 'ui/trainer_clients_screen.dart';

// ==========================================
// 🔥 ГЛОБАЛЬНЫЙ КЛЮЧ НАВИГАТОРА
// ==========================================
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ==========================================
// 🔥 ГЛОБАЛЬНАЯ ФУНКЦИЯ ВЫХОДА
// ==========================================
Future<void> signOutGlobally() async {
  final navContext = navigatorKey.currentContext;
  if (navContext == null) {
    debugPrint('❌ No navigator context for sign out');
    return;
  }

  try {
    final authService = Provider.of<AuthService>(navContext, listen: false);
    final clientsService = Provider.of<ClientsService>(navContext, listen: false);

    await authService.signOut();
    clientsService.clear();

    await Future.delayed(const Duration(milliseconds: 100));

    final navigator = navigatorKey.currentState;
    if (navigator != null && navContext.mounted) {
      await navigator.pushReplacementNamed('/');
    }
  } catch (e) {
    debugPrint('❌ Global sign out error: $e');
    final context = navigatorKey.currentContext;
    if (context != null && context.mounted) {
      ErrorHandler.show(context, ErrorHandler.format(e, context: 'logout'));
    }
  }
}

// ==========================================
// 🔥 ТОЧКА ВХОДА
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Инициализация Supabase
  await SupabaseConfig.initialize();

  // 2. Инициализация сервиса уведомлений
  try {
    await NotificationService().initialize();
    debugPrint('✅ NotificationService initialized successfully');
  } catch (e, stack) {
    debugPrint('⚠️ NotificationService initialization failed: $e');
  }

  // 3. Создаём ОДИН экземпляр ClientsService для всего приложения
  final clientsService = ClientsService();

  runApp(NutriLinkApp(clientsService: clientsService));
}

// ==========================================
// ✅ NutriLinkApp
// ==========================================
class NutriLinkApp extends StatefulWidget {
  final ClientsService clientsService;

  const NutriLinkApp({super.key, required this.clientsService});

  @override
  State<NutriLinkApp> createState() => _NutriLinkAppState();
}

class _NutriLinkAppState extends State<NutriLinkApp> {
  late final AppLinks _appLinks;
  bool _initialLinkHandled = false;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _initDeepLinks();
  }

  // ==========================================
  // 🔥 ОБРАБОТКА DEEP LINKS
  // ==========================================
  Future<void> _initDeepLinks() async {
    // Обработка deep link при запуске приложения
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null && !_initialLinkHandled) {
        _initialLinkHandled = true;
        _handleDeepLink(uri);
      }
    } catch (e) {
      debugPrint('⚠️ Error getting initial link: $e');
    }

    // Обработка deep links во время работы приложения
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('🔗 Deep link received: $uri');

    // Проверяем что это deep link для авторизации/восстановления
    if (uri.scheme == 'nutrilink' && uri.host == 'auth') {
      // 🔥 Проверяем наличие токена восстановления в URL
      final accessToken = uri.queryParameters['access_token'];
      final type = uri.queryParameters['type'];
      
      debugPrint('🔗 Access token: ${accessToken != null ? "present" : "null"}');
      debugPrint('🔗 Type: $type');

      if (accessToken != null && type == 'recovery') {
        // 🔥 Это ссылка для восстановления пароля
        // Supabase автоматически применит токен при вызове updateUser
        debugPrint('✅ Recovery link detected, navigating to recovery screen');
        
        Future.delayed(const Duration(milliseconds: 500), () {
          final navigator = navigatorKey.currentState;
          if (navigator != null) {
            navigator.pushReplacement(
              MaterialPageRoute(
                builder: (_) => const RecoveryPasswordScreen(),
              ),
            );
          }
        });
      } else if (accessToken != null && type == 'signup') {
        // 🔥 Это ссылка для подтверждения email
        debugPrint('✅ Email confirmation link detected');
        
        // Supabase автоматически подтвердит email
        // Пользователь может войти
        Future.delayed(const Duration(milliseconds: 500), () {
          final navigator = navigatorKey.currentState;
          if (navigator != null) {
            navigator.pushReplacementNamed('/');
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => MultiProvider(
        providers: [
          ChangeNotifierProvider<ClientsService>.value(value: widget.clientsService),
          ChangeNotifierProvider(
            create: (_) => AuthService()..checkSession(),
          ),
          ChangeNotifierProvider(
            create: (context) => ProfileService(widget.clientsService),
          ),
          ChangeNotifierProvider(
            create: (context) => DiaryService(widget.clientsService),
          ),
          ChangeNotifierProvider(
            create: (context) => MeasurementsService(widget.clientsService),
          ),
          ChangeNotifierProvider(
            create: (context) => StatsService(widget.clientsService),
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
            colorScheme: ColorScheme.dark(
              primary: AppColors.accent,
              secondary: AppColors.accentLight,
              surface: AppColors.backgroundSecondary,
              background: AppColors.background,
              error: Colors.red.shade700,
            ),
          ),
          routes: {
            '/': (context) => const _Router(),
            '/recovery': (context) => const RecoveryPasswordScreen(),
            '/trainer-clients': (context) => const TrainerClientsScreen(),
          },
        ),
      );
}

// ==========================================
// ✅ ROUTER — определяет, показывать AuthScreen или MainShell
// ==========================================
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