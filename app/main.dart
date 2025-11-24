import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/garderob/wardrobe_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'services/theme_controller.dart';
import 'screens/auth/pin_unlock_screen.dart';
import 'services/api_service.dart';
import 'services/language_controller.dart';
import 'services/local_storage_service.dart';
import 'services/sync_service.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n_extensions.dart';
import 'widgets/fisheye_navigation_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.initialize();
  final themeNotifier = ThemeNotifier();
  await themeNotifier.initialize();
  final languageNotifier = LanguageNotifier();
  await languageNotifier.initialize();
  await SyncService.instance.initialize();
  runApp(WardrobeApp(
    themeNotifier: themeNotifier,
    languageNotifier: languageNotifier,
  ));
}

class WardrobeApp extends StatelessWidget {
  final ThemeNotifier themeNotifier;
  final LanguageNotifier languageNotifier;

  const WardrobeApp({super.key, required this.themeNotifier, required this.languageNotifier});

  ThemeData _buildLightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F51B5),
      brightness: Brightness.light,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: 70,
        elevation: 0,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: MaterialStateProperty.all(
          TextStyle(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        iconTheme: MaterialStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(MaterialState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: scheme.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF90CAF9),
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 18,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: 70,
        elevation: 0,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: MaterialStateProperty.all(
          TextStyle(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        iconTheme: MaterialStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(MaterialState.selected)
                ? scheme.onPrimary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: scheme.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([themeNotifier, languageNotifier]),
      builder: (context, _) {
        return ThemeScope(
          notifier: themeNotifier,
          child: LanguageScope(
            notifier: languageNotifier,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              onGenerateTitle: (context) => context.l10n.appTitle,
              themeMode: themeNotifier.themeMode,
              theme: _buildLightTheme(),
              darkTheme: _buildDarkTheme(),
              locale: languageNotifier.locale,
              supportedLocales: LanguageNotifier.supportedLocales,
              localizationsDelegates: const [
                AppLocalizationsDelegate(),
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const AuthWrapper(),
              routes: {
                '/login': (context) => const LoginScreen(),
                '/register': (context) => const RegisterScreen(),
                '/home': (context) => const MainNavigation(),
              },
            ),
          ),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

enum _AuthDestination { loading, login, pin, home }

class _AuthWrapperState extends State<AuthWrapper> {
  final storage = const FlutterSecureStorage();
  _AuthDestination _destination = _AuthDestination.loading;
  int? _userId;

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  void checkLoginStatus() async {
    final token = await storage.read(key: "token");
    final userId = await storage.read(key: "user_id");
    if (token != null && userId != null) {
      final parsedId = int.tryParse(userId);
      bool requiresPin = false;
      if (parsedId != null) {
        try {
          final user = await ApiService.getUser(parsedId);
          requiresPin = user['has_pin'] == true;
        } catch (_) {
          requiresPin = await ApiService.loadCachedHasPin();
        }
      }
      if (!mounted) return;
      setState(() {
        _userId = parsedId;
        _destination = requiresPin ? _AuthDestination.pin : _AuthDestination.home;
      });
    } else {
      setState(() {
        _destination = _AuthDestination.login;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (_destination) {
      case _AuthDestination.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case _AuthDestination.login:
        return const LoginScreen();
      case _AuthDestination.pin:
        if (_userId == null) {
          return const LoginScreen();
        }
        return PinUnlockScreen(
          userId: _userId!,
          onUnlocked: (_) async {
            setState(() => _destination = _AuthDestination.home);
          },
          onCancel: (_) async {
            await storage.delete(key: 'user_id');
            await storage.delete(key: 'token');
            if (!mounted) return;
            setState(() {
              _destination = _AuthDestination.login;
              _userId = null;
            });
          },
        );
      case _AuthDestination.home:
        return const MainNavigation();
    }
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0; // Сразу открываем настройки

  final List<Widget> _pages = [
    const HomeScreen(),
    const WardrobeScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 26, right: 26, bottom: 4),
        child: FisheyeNavigationBar(
          currentIndex: _currentIndex,
          onItemSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            FisheyeNavigationBarItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Главная',
            ),
            FisheyeNavigationBarItem(
              icon: Icons.checkroom_outlined,
              selectedIcon: Icons.checkroom,
              label: 'Гардероб',
            ),
            FisheyeNavigationBarItem(
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings,
              label: 'Настройки',
            ),
          ],
        ),
      ),
    );
  }
}
