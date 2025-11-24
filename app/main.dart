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

  ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: isLight ? const Color(0xFF2B3A67) : const Color(0xFF8FB7FF),
      brightness: brightness,
    );
    final textTheme = (isLight
            ? Typography.material2021().black
            : Typography.material2021().white)
        .apply(
      fontSizeFactor: 1.05,
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      useMaterial3: true,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: 70,
        elevation: 0,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: MaterialStateProperty.all(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        iconTheme: MaterialStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(MaterialState.selected)
                ? colorScheme.onPrimary
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      cardTheme: CardTheme(
        color: colorScheme.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: colorScheme.shadow.withOpacity(0.08),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant,
        labelStyle: textTheme.labelLarge,
        floatingLabelStyle:
            textTheme.labelLarge?.copyWith(color: colorScheme.onSurface),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle:
            textTheme.labelSmall?.copyWith(color: colorScheme.onInverseSurface),
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
              theme: _buildTheme(Brightness.light),
              darkTheme: _buildTheme(Brightness.dark),
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
