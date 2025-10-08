import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../services/api_service.dart';
import 'Location_Picker_Screen.dart';

class HomeScreenSettings extends StatefulWidget {
  const HomeScreenSettings({super.key});

  @override
  _HomeScreenSettingsState createState() => _HomeScreenSettingsState();
}

class _HomeScreenSettingsState extends State<HomeScreenSettings> {
  String location = 'Нет координат';
  String openAiKey = 'Нет ключа';
  String weatherKey = 'Нет ключа';
  String serialNumber = '0000001'; // Пока просто UI
  int? userId;

  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    loadUserId();
  }

  Future<void> loadUserId() async {
    final id = await storage.read(key: 'user_id');
    if (id != null) {
      final parsedId = int.tryParse(id);
      setState(() => userId = parsedId);

      if (parsedId != null) {
        try {
          final userData = await ApiService.getUser(parsedId);
          setState(() {
            location = userData['location'] ?? location;
            openAiKey = userData['openai_api_key'] ?? openAiKey;
            weatherKey = userData['weather_api_key'] ?? weatherKey;
          });
        } catch (e) {
          print("❌ Ошибка загрузки данных пользователя: $e");
        }
      }
    }
  }

  Future<void> updateKeys() async {
    if (userId == null) return;
    try {
      await ApiService.updateApiKeys(userId!, openAiKey, weatherKey);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API-ключи обновлены')),
      );
    } catch (e) {
      print('❌ Ошибка обновления API-ключей: $e');
    }
  }

  Future<void> updateLocation(String newLoc) async {
    if (userId == null) return;
    try {
      await ApiService.updateLocation(userId!, newLoc);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Координаты обновлены')),
      );
    } catch (e) {
      print("❌ Ошибка при сохранении координат: $e");
    }
  }

  void showEditDialog(String title, String currentValue, Function(String) onEdit) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Изменить $title'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(border: OutlineInputBorder(), labelText: title),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onEdit(controller.text);
              }
              Navigator.pop(context);
              if (title.contains("API")) updateKeys(); // обновить API
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  String shortenKey(String key, {int start = 5, int end = 4}) {
    if (key.length <= start + end) return key;
    return '${key.substring(0, start)}...${key.substring(key.length - end)}';
  }

  Widget buildOption(IconData icon, String title, String value, Function() onTap) {
    final isApiKey = title.contains('API');
    final displayedValue = isApiKey ? shortenKey(value) : value;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      width: double.infinity,
      height: 59,
      decoration: BoxDecoration(
        color: const Color(0xFF62DEFA),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Stack(
        children: [
          Positioned(left: 16, top: 12, child: Icon(icon, size: 28, color: Colors.black)),
          Positioned(
            left: 60,
            top: 14,
            child: Text(
              displayedValue,
              style: const TextStyle(color: Colors.black, fontSize: 18),
            ),
          ),
          Positioned(
            right: 16,
            top: 12,
            child: GestureDetector(
              onTap: onTap,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Дом'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            buildOption(CupertinoIcons.location, 'Координаты', location, () async {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => LocationPickerScreen(initialLocation: location),
                ),
              );
              if (result != null) {
                print("📍 Получено из Navigator.pop: $result");
                setState(() => location = result);
                await updateLocation(result);
              }
            }),
            buildOption(CupertinoIcons.lock, 'OpenAI API', openAiKey, () {
              showEditDialog('OpenAI API', openAiKey, (value) {
                setState(() => openAiKey = value);
              });
            }),
            buildOption(CupertinoIcons.cloud, 'OpenWeather API', weatherKey, () {
              showEditDialog('OpenWeather API', weatherKey, (value) {
                setState(() => weatherKey = value);
              });
            }),
            buildOption(CupertinoIcons.wifi, 'SN', serialNumber, () {
              showEditDialog('SN', serialNumber, (value) {
                setState(() => serialNumber = value);
              });
            }),
          ],
        ),
      ),
    );
  }
}
