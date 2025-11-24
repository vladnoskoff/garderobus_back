import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/pin_unlock_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/garderob/clothes_detail_screen.dart';
import '../screens/garderob/wardrobe_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../widgets/fisheye_navigation_bar.dart';
import 'auth_state.dart';
import 'state_restoration_service.dart';

class AppRouter {
  AppRouter(this.authState) {
    router = GoRouter(
      debugLogDiagnostics: false,
      refreshListenable: authState,
      initialLocation: '/home',
      redirect: (context, state) {
        if (!authState.isReady) return null;
        final isLoggingIn =
            state.matchedLocation == '/login' || state.matchedLocation == '/register';
        if (!authState.isAuthenticated) {
          return isLoggingIn ? null : '/login';
        }
        if (authState.requiresPin && state.matchedLocation != '/pin') {
          return '/pin';
        }
        if (!authState.requiresPin && state.matchedLocation == '/pin') {
          return '/home';
        }
        if (isLoggingIn) return '/home';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/pin',
          name: 'pin',
          builder: (context, state) {
            final userId = authState.userId;
            if (userId == null) return const LoginScreen();
            return PinUnlockScreen(
              userId: userId,
              onUnlocked: (_) async => authState.completePinFlow(),
              onCancel: (_) async => authState.logout(),
            );
          },
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainNavigation(shell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  name: 'home',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/wardrobe',
                  name: 'wardrobe',
                  builder: (context, state) => const WardrobeScreen(),
                  routes: [
                    GoRoute(
                      path: 'item/:id',
                      name: 'wardrobe-item',
                      builder: (context, state) {
                        final clothesId = int.tryParse(state.pathParameters['id'] ?? '');
                        if (clothesId == null) return const WardrobeScreen();
                        return ClothesDetailScreen(clothesId: clothesId);
                      },
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  name: 'settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  final AuthState authState;
  late final GoRouter router;
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialTab();
  }

  Future<void> _loadInitialTab() async {
    final restoredIndex = await StateRestorationService.restoreMainTab();
    if (!mounted || restoredIndex == null) return;
    setState(() {
      _currentIndex = restoredIndex;
      widget.shell.goBranch(restoredIndex);
    });
  }

  void _onItemSelected(int index) {
    setState(() => _currentIndex = index);
    widget.shell.goBranch(index);
    StateRestorationService.persistMainTab(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(left: 26, right: 26, bottom: 4),
        child: FisheyeNavigationBar(
          currentIndex: _currentIndex,
          onItemSelected: _onItemSelected,
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
