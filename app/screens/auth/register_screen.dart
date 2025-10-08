import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  String? selectedGender;
  bool isLoading = false;

  Future<void> register() async {
    setState(() => isLoading = true);
    try {
      final response = await ApiService.register(
        nameController.text.trim(),
        emailController.text.trim(),
        passwordController.text.trim(),
        selectedGender ?? 'not_specified',
      );

      final newUserId = _extractUserId(response);
      if (newUserId != null) {
        try {
          await ApiService.createWardrobeLocation(
            userId: newUserId,
            name: 'Место 1',
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Не удалось создать стартовую локацию: $e')),
            );
          }
        }
      }

      setState(() => isLoading = false);
      Navigator.pop(context);
    } catch (e) {
      setState(() => isLoading = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Ошибка"),
          content: Text("Не удалось зарегистрироваться: $e"),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
        ),
      );
    }
  }

  int? _extractUserId(Map<String, dynamic> response) {
    final idValue = response['user_id'] ?? response['id'];
    if (idValue is int) return idValue;
    if (idValue is String) {
      return int.tryParse(idValue);
    }
    return null;
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
                const Text("Регистрация", style: TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Имя", filled: true, fillColor: Colors.white),
                ),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: const InputDecoration(
                    labelText: "Пол",
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  hint: const Text('Выберите пол'),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Мужской')),
                    DropdownMenuItem(value: 'female', child: Text('Женский')),
                    DropdownMenuItem(value: 'not_specified', child: Text('Не указывать')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedGender = value);
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: isLoading ? null : register,
                  child: isLoading ? const CircularProgressIndicator() : const Text("Создать аккаунт"),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/login'),
                  child: const Text("Есть аккаунт", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}