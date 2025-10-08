import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/garderob/wardrobe_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'services/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeNotifier = ThemeNotifier();
  await themeNotifier.initialize();
  runApp(WardrobeApp(themeNotifier: themeNotifier));
}

class WardrobeApp extends StatelessWidget {
  final ThemeNotifier themeNotifier;

  const WardrobeApp({super.key, required this.themeNotifier});

  ThemeData _buildLightTheme() {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light);
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      useMaterial3: true,
      appBarTheme: AppBarTheme(backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary),
    );
  }

  ThemeData _buildDarkTheme() {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blueGrey, brightness: Brightness.dark);
    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
      useMaterial3: true,
      appBarTheme: AppBarTheme(backgroundColor: scheme.surface, foregroundColor: scheme.onSurface),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeNotifier,
      builder: (context, _) {
        return ThemeScope(
          notifier: themeNotifier,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Гардеробус',
            themeMode: themeNotifier.themeMode,
            theme: _buildLightTheme(),
            darkTheme: _buildDarkTheme(),
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/register': (context) => const RegisterScreen(),
              '/home': (context) => const MainNavigation(),
            },
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

class _AuthWrapperState extends State<AuthWrapper> {
  final storage = const FlutterSecureStorage();
  String? _initialScreen;

  @override
  void initState() {
    super.initState();
    checkLoginStatus();
  }

  void checkLoginStatus() async {
    final token = await storage.read(key: "token");
    final userId = await storage.read(key: "user_id");

    setState(() {
      _initialScreen = (token != null && userId != null) ? 'main' : 'login';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialScreen == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _initialScreen == 'main' ? const MainNavigation() : const LoginScreen();
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
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.checkroom), label: ''),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: ''),
        ],
      ),
    );
  }
}