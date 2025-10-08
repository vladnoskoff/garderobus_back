import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../services/api_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  _AccountScreenState createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  String name = '';
  String email = '';
  String password = '******';
  String phone = '+7 900 000 0000'; // TODO: заглушка, пока не реализовано
  int? userId;

  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    final id = await storage.read(key: 'user_id');
    if (id == null) return;

    try {
      final data = await ApiService.getUser(int.parse(id));
      setState(() {
        userId = data['id'];
        name = data['name'];
        email = data['email'];
      });
    } catch (e) {
      print('Ошибка при загрузке данных пользователя: $e');
    }
  }

  Future<void> updateField(String field, String value) async {
    if (userId == null) return;
    try {
      await ApiService.updateUser(userId!, field, value);
      await loadUserData(); // Перезагружаем данные
    } catch (e) {
      print("Ошибка при обновлении поля $field: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Аккаунт'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            buildAccountOption(Icons.person, 'ФИО', name, (value) {
              setState(() => name = value);
              updateField("name", value); // TODO: обновить сервер при редактировании
            }),
            const SizedBox(height: 16),
            buildAccountOption(Icons.phone, 'Телефон', phone, (value) {
              setState(() => phone = value);
            }),
            const SizedBox(height: 16),
            buildAccountOption(Icons.email, 'Почта', email, (value) {
              setState(() => email = value);
              updateField("email", value); // TODO: обновить сервер при редактировании
            }),
            const SizedBox(height: 16),
            buildAccountOption(Icons.lock, 'Пароль', password, (value) {
              setState(() => password = value);
              updateField("password", value); // TODO: обновить сервер при редактировании
            }),
            const Spacer(),
            buildDeleteButton(),
          ],
        ),
      ),
    );
  }

  Widget buildAccountOption(
      IconData icon, String title, String value, Function(String) onEdit) {
    return Container(
      width: double.infinity,
      height: 59,
      decoration: BoxDecoration(
        color: const Color(0xFF62DEFA),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          Positioned(left: 16, top: 12, child: Icon(icon, size: 24, color: Colors.black)),
          Positioned(
            left: 60,
            top: 10,
            child: Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text(value, style: const TextStyle(fontSize: 16)),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: GestureDetector(
              onTap: () => showEditDialog(title, value, onEdit),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFFCFDDE0),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Icon(Icons.edit, color: Colors.black, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void showEditDialog(String title, String currentValue, Function(String) onEdit) {
    final TextEditingController controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Изменить $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            labelText: title,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onEdit(controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Widget buildDeleteButton() {
  return GestureDetector(
    onTap: () async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Удалить аккаунт"),
          content: Text("Вы уверены, что хотите удалить аккаунт?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text("Отмена")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Удалить", style: TextStyle(color: Colors.red))),
          ],
        ),
      );

      if (confirm == true && userId != null) {
        try {
          await ApiService.deleteUser(userId!);
          await storage.deleteAll(); // Очистка токенов
          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/login');
        } catch (e) {
          print("Ошибка при удалении аккаунта: $e");
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Не удалось удалить аккаунт")));
        }
      }
    },
    child: Container(
      width: 170,
      height: 59,
      decoration: BoxDecoration(
        color: const Color(0xFFFF0C0C),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: Text('Удалить', style: TextStyle(fontSize: 20)),
      ),
    ),
  );
}
}