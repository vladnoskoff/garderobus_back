import 'package:flutter/material.dart';
import 'account/account_screen.dart';
import 'home_settings/home_screen_settings.dart';
import 'places/places_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../auth/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Настройки'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            buildSettingsButton(context, 'Аккаунт', AccountScreen()),
            const SizedBox(height: 16),
            buildSettingsButton(context, 'Дом', HomeScreenSettings()),
            const SizedBox(height: 16),
            buildSettingsButton(context, 'Места', PlacesScreen()),
            const Spacer(),
            buildExitButton(context),
          ],
        ),
      ),
    );
  }

  Widget buildSettingsButton(BuildContext context, String text, Widget screen) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
      child: Container(
        width: double.infinity,
        height: 59,
        decoration: BoxDecoration(
          color: const Color(0xFF62DEFA),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildExitButton(BuildContext context) {
  return GestureDetector(
    onTap: () async {
      final storage = FlutterSecureStorage();
      await storage.deleteAll();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    },
    child: Container(
      width: 170,
      height: 59,
      decoration: BoxDecoration(
        color: const Color(0xFFFF0C0C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Text(
          'Выход',
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}
}