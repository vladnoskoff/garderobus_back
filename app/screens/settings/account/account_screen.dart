import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../services/api_service.dart';
import '../../../widgets/rounded_back_button.dart';
import 'pin_setup_screen.dart';

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
  bool hasPin = false;
  int? userId;
  String gender = 'not_specified';

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
        hasPin = data['has_pin'] == true;
        gender = (data['gender'] ?? 'not_specified') as String;
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
      appBar: AppBar(
        leading: const RoundedBackButton(),
        title: const Text('Аккаунт'),
        centerTitle: true,
      ),
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
            buildGenderOption(),
            const SizedBox(height: 16),
            buildAccountOption(Icons.lock, 'Пароль', password, (value) {
              setState(() => password = value);
              updateField("password", value); // TODO: обновить сервер при редактировании
            }),
            const SizedBox(height: 16),
            buildPinNavigation(),
            const Spacer(),
            buildDeleteButton(),
          ],
        ),
      ),
    );
  }

  Widget buildPinNavigation() {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PinSetupScreen()),
        );
        await loadUserData();
      },
      child: Container(
        width: double.infinity,
        height: 59,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.shield, color: colorScheme.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PIN-код',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ) ??
                        TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 18),
                  ),
                  Text(
                    hasPin ? 'Установлен' : 'Не задан',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ) ??
                        TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 14),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.onSecondaryContainer),
          ],
        ),
      ),
    );
  }

  Widget buildAccountOption(
      IconData icon, String title, String value, Function(String) onEdit) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 59,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 16,
            top: 12,
            child: Icon(icon, size: 24, color: colorScheme.onSecondaryContainer),
          ),
          Positioned(
            left: 60,
            top: 10,
            child: Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ) ??
                      TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                      ) ??
                      TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 16),
                ),
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
                  color: colorScheme.onSecondaryContainer.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(Icons.edit, color: colorScheme.onSecondaryContainer, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildGenderOption() {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => showGenderDialog(),
      child: Container(
        width: double.infinity,
        height: 59,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(Icons.transgender, size: 24, color: colorScheme.onSecondaryContainer),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Пол',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ) ??
                        TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _genderLabel(gender),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ) ??
                        TextStyle(color: colorScheme.onSecondaryContainer, fontSize: 16),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colorScheme.onSecondaryContainer),
          ],
        ),
      ),
    );
  }

  void showGenderDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String tempGender = gender;
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('Выберите пол'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    value: 'male',
                    groupValue: tempGender,
                    onChanged: (newValue) {
                      if (newValue == null) return;
                      setLocalState(() {
                        tempGender = newValue;
                      });
                    },
                    title: const Text('Мужской'),
                  ),
                  RadioListTile<String>(
                    value: 'female',
                    groupValue: tempGender,
                    onChanged: (newValue) {
                      if (newValue == null) return;
                      setLocalState(() {
                        tempGender = newValue;
                      });
                    },
                    title: const Text('Женский'),
                  ),
                  RadioListTile<String>(
                    value: 'not_specified',
                    groupValue: tempGender,
                    onChanged: (newValue) {
                      if (newValue == null) return;
                      setLocalState(() {
                        tempGender = newValue;
                      });
                    },
                    title: const Text('Не указывать'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    if (tempGender != gender) {
                      setState(() => gender = tempGender);
                      updateField('gender', tempGender);
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _genderLabel(String value) {
    switch (value) {
      case 'male':
        return 'Мужской';
      case 'female':
        return 'Женский';
      default:
        return 'Не указывать';
    }
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
            title: const Text("Удалить аккаунт"),
            content: const Text("Вы уверены, что хотите удалить аккаунт?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Отмена")),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Удалить", style: TextStyle(color: Colors.red)),
              ),
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
            ScaffoldMessenger.of(context)
                .showSnackBar(const SnackBar(content: Text("Не удалось удалить аккаунт")));
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
