import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/theme_controller.dart';
import 'services/api_service.dart';
import 'services/language_controller.dart';
import 'services/local_storage_service.dart';
import 'services/sync_service.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n_extensions.dart';
import 'services/app_router.dart';
import 'services/auth_state.dart';
import 'services/auth_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.initialize();
  final themeNotifier = ThemeNotifier();
  await themeNotifier.initialize();
  final languageNotifier = LanguageNotifier();
  await languageNotifier.initialize();
  await SyncService.instance.initialize();
  final authState = AuthState();
  await authState.initialize();
  final router = AppRouter(authState);
  runApp(WardrobeApp(
    themeNotifier: themeNotifier,
    languageNotifier: languageNotifier,
    appRouter: router,
  ));
}

class WardrobeApp extends StatelessWidget {
  final ThemeNotifier themeNotifier;
  final LanguageNotifier languageNotifier;
  final AppRouter appRouter;

  const WardrobeApp({
    super.key,
    required this.themeNotifier,
    required this.languageNotifier,
    required this.appRouter,
  });

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
            child: AuthScope(
              notifier: appRouter.authState,
              child: MaterialApp.router(
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
                routerConfig: appRouter.router,
              ),
            ),
          ),
        );
      },
    );
  }
}

