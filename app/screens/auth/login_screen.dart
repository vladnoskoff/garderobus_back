import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';

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

      setState(() => isLoading = false);
      Navigator.pushReplacementNamed(context, '/home');
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
    return Scaffold(
      backgroundColor: const Color(0xFF00BCD4),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Image.asset("assets/logo.png", height: 150),
                const SizedBox(height: 20),
                const Text("Добро пожаловать!", style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: "Email", filled: true, fillColor: Colors.white),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Пароль", filled: true, fillColor: Colors.white),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : login,
                  child: isLoading ? const CircularProgressIndicator() : const Text("Войти"),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: const Text("Нет аккаунта? Зарегистрироваться", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}