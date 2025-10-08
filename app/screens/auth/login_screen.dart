import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';
import '../../services/theme_controller.dart';
import 'pin_unlock_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool isLoading = false;

  void login() async {
    setState(() => isLoading = true);
    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      final response = await ApiService.login(email, password);
      final storage = const FlutterSecureStorage();
      await storage.write(key: "user_id", value: response["user_id"].toString());
      await storage.write(key: "token", value: response["access_token"]);

      try {
        final themeNotifier = ThemeScope.of(context);
        await themeNotifier.refreshFromRemote();
      } catch (_) {
        // Если тема недоступна, продолжаем без ошибок.
      }

      setState(() => isLoading = false);
      if (!mounted) return;
      final userId = int.tryParse(response["user_id"].toString());
      final hasPin = response["has_pin"] == true;

      if (hasPin && userId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PinUnlockScreen(
              userId: userId,
              onUnlocked: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              onCancel: () async {
                await storage.deleteAll();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      setState(() => isLoading = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Ошибка входа"),
          content: Text("Неверный логин или пароль.\n$e"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Image.asset("assets/logo.png", height: 150),
                const SizedBox(height: 20),
                Text(
                  "Добро пожаловать!",
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: "Email"),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Пароль"),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading ? null : login,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Войти"),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: Text(
                    "Нет аккаунта? Зарегистрироваться",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}