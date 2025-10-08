import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'settings/home_settings/home_screen_settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? weather;
  Map<String, dynamic>? outfit;
  String? weatherComment;
  String? weatherIconUrl;
  final storage = FlutterSecureStorage();
  int? userId;
  List<dynamic> wardrobeLocations = [];
  int? selectedLocationId;
  bool isLocationsLoading = false;

  String cleanText(String input) {
    try {
      return utf8.decode(input.runes.toList());
    } catch (_) {
      return input;
    }
  }
  
  @override
  void initState() {
    super.initState();
    loadUserId();
    fetchWeather();
    fetchOutfit();
    _loadLocations();
    
    // Автообновление погоды каждые 10 секунд
    Timer.periodic(Duration(seconds: 10), (timer) {
      if (mounted) {
        fetchWeather();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> loadUserId() async {
    final idString = await storage.read(key: 'user_id');
    if (idString != null) {
      setState(() {
        userId = int.tryParse(idString);
      });
      fetchWeather();
      fetchOutfit();
      _loadLocations();
      // ✅ вызываем только после загрузки
      await checkInitialSettings();
    }
  }

  Future<void> _loadLocations() async {
    if (userId == null) return;
    setState(() => isLocationsLoading = true);
    try {
      final locations = await ApiService.getWardrobeLocations(userId!);
      setState(() {
        wardrobeLocations = locations;
        selectedLocationId ??= _deriveDefaultLocation(locations);
      });
      fetchWeather();
      fetchOutfit();
    } catch (e) {
      print('Ошибка загрузки локаций: $e');
    } finally {
      if (mounted) {
        setState(() => isLocationsLoading = false);
      }
    }
  }

  int? _deriveDefaultLocation(List<dynamic> locations) {
    for (final loc in locations) {
      final lat = loc['latitude'];
      final lon = loc['longitude'];
      if (lat != null && lon != null) {
        return loc['id'] as int?;
      }
    }
    return null;
  }

  Map<String, dynamic>? _findLocationById(int? id) {
    if (id == null) return null;
    for (final loc in wardrobeLocations) {
      if (loc is Map<String, dynamic> && loc['id'] == id) {
        return loc;
      }
    }
    return null;
  }

  Future<void> checkInitialSettings() async {
    if (userId == null) return;

    try {
      final user = await ApiService.getUser(userId!);

      final weatherKey = user['weather_api_key'];
      final location = user['location'];

      final hasWeatherKey = weatherKey != null && weatherKey.toString().trim().isNotEmpty;
      final hasLocation = location != null && location.toString().trim().isNotEmpty;

      if (!hasWeatherKey || !hasLocation) {
        String missingParts = '';
        if (!hasWeatherKey) missingParts += '• API-ключ погоды\n';
        if (!hasLocation) missingParts += '• Координаты\n';

        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text("Нужна настройка"),
              content: Text(
                "Пожалуйста, укажите следующие параметры:\n\n$missingParts\nчтобы приложение работало корректно.",
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreenSettings()),
                    );
                  },
                  child: const Text("Перейти в настройки"),
                ),
              ],
            ),
          );
        });
      }
    } catch (e) {
      print("Ошибка проверки настроек: $e");
    }
  }


  Future<void> fetchWeather() async {
    if (userId == null) return;
    try {
      int? locationIdForRequest = selectedLocationId;
      final selectedLocation = _findLocationById(selectedLocationId);
      if (selectedLocation != null) {
        if (selectedLocation['latitude'] == null || selectedLocation['longitude'] == null) {
          locationIdForRequest = null;
        }
      }

      final weatherData = await ApiService.getWeatherByUserId(
        userId!,
        locationId: locationIdForRequest,
      );
      if (!mounted) return;
      setState(() {
        weather = weatherData;
        weatherIconUrl = "https://openweathermap.org/img/wn/${weatherData['icon']}@2x.png";
        weatherComment = generateWeatherComment(weatherData);
      });
    } catch (e) {
      print("Ошибка при получении погоды: $e");
    }
  }

  Future<void> fetchOutfit() async {
    if (userId == null) return;
    try {
      /* final outfitData = await ApiService.getOutfit(userId!, city); */
      int? locationIdForRequest = selectedLocationId;
      final selectedLocation = _findLocationById(selectedLocationId);
      if (selectedLocation != null) {
        if (selectedLocation['latitude'] == null || selectedLocation['longitude'] == null) {
          locationIdForRequest = null;
        }
      }

      final outfitData = await ApiService.getOutfit(
        userId!,
        locationId: locationIdForRequest,
      );

      if (!mounted) return;
      setState(() {
        outfit = outfitData;
      });
    } catch (e) {
      print("Ошибка при получении наряда: $e");
    }
  }

  String generateWeatherComment(Map<String, dynamic> weather) {
    final temp = weather['temperature'];
    final wind = weather['wind_speed'];

    if (temp <= 0) return 'Очень холодно, оденься тепло!';
    if (temp > 0 && temp <= 10) return 'Прохладно, надень куртку.';
    if (temp > 10 && temp <= 20) return 'Комфортная температура.';
    if (temp > 20) return 'Жарко, надень что-нибудь лёгкое.';

    if (wind != null && wind > 6) return 'Сильный ветер, одевайся плотнее!';
    return 'Погода нормальная.';
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Гардеробус")),
      body: weather == null
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (wardrobeLocations.isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF62DEFA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: isLocationsLoading
                              ? const LinearProgressIndicator()
                              : DropdownButton<int?>(
                                  value: selectedLocationId,
                                  isExpanded: true,
                                  hint: const Text('Выберите локацию гардероба'),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Использовать личные координаты'),
                                    ),
                                    ...wardrobeLocations.map((loc) {
                                      final map = loc as Map<String, dynamic>;
                                      final name = map['name']?.toString() ?? 'Без названия';
                                      final hasCoords =
                                          map['latitude'] != null && map['longitude'] != null;
                                      final subtitle = hasCoords ? '' : ' (нет координат)';
                                      return DropdownMenuItem<int?>(
                                        value: map['id'] as int,
                                        child: Text('$name$subtitle'),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      selectedLocationId = value;
                                    });
                                    fetchWeather();
                                    fetchOutfit();
                                  },
                                ),
                        ),
                      // Блок погоды
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(maxWidth: 400),
                        height: 100,
                        decoration: BoxDecoration(
                          color: Color(0xFF62DEFA),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${weather!["temperature"]}°C',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 46,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    '${weather!["humidity"]}%',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 24,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Image.network(
                                weatherIconUrl ?? '',
                                width: 64,
                                height: 64,
                                errorBuilder: (_, __, ___) => Icon(Icons.cloud, size: 48),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),
                      // Блок помещения
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(maxWidth: 400),
                        height: 100,
                        decoration: BoxDecoration(
                          color: Color(0xFF62DEFA),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text("25°C", style: TextStyle(fontSize: 30, color: Colors.black)),
                                Text("30%", style: TextStyle(fontSize: 23, color: Colors.black)),
                              ],
                            ),
                            Icon(Icons.house, size: 48, color: Colors.black), // временная иконка
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),
                      // Блок давления
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(maxWidth: 400),
                        decoration: BoxDecoration(
                          color: Color(0xFF62DEFA),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "${(weather!["pressure"] * 0.75006).round()}",
                                      style: TextStyle(fontSize: 38, fontWeight: FontWeight.w500),
                                    ),
                                    Text(
                                      "мм рт. ст.",
                                      style: TextStyle(fontSize: 18),
                                    ),
                                  ],
                                ),
                                Icon(Icons.trending_up, size: 48, color: Colors.black), // или свой SVG
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Container(
                            //   height: 80,
                            //   decoration: BoxDecoration(
                            //     color: Colors.white.withOpacity(0.8),
                            //     borderRadius: BorderRadius.circular(10),
                            //   ),
                            //   child: Center(
                            //     child: Text("🔧 Здесь будет график давления"), // или график через `fl_chart`
                            //   ),
                            // ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),
                      // Блок с погодой на 3 дня
                      if (weather?['forecast'] != null)
                        Container(
                          width: double.infinity,
                          constraints: BoxConstraints(maxWidth: 400),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Color(0xFF62DEFA),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Прогноз на 3 дня:", style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Column(
                                children: (weather!['forecast'] as List<dynamic>).map((day) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(day['date'], style: TextStyle(fontSize: 14)),
                                      Row(
                                        children: [
                                          Text('${day['temp']}°C', style: TextStyle(fontSize: 14)),
                                          const SizedBox(width: 6),
                                          Image.network(
                                            "http://openweathermap.org/img/wn/${day['icon']}@2x.png",
                                            width: 32,
                                            height: 32,
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 10),
                      // Блок с одеждой
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(maxWidth: 400),
                        decoration: BoxDecoration(
                          color: Color(0xFF62DEFA),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  weatherComment ?? '',
                                  style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.w400),
                                ),
                                IconButton(
                                  icon: Icon(Icons.refresh, size: 20, color: Colors.black),
                                  tooltip: 'Обновить лук',
                                  onPressed: () => fetchOutfit(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 12,
                              children: (outfit?['items']?.keys.toList() ?? []).map<Widget>((part) {
                                final item = outfit?['items']?[part];
                                final imageUrl = item is Map && item['image_url'] != null
                                    ? item['image_url']
                                    : null;

                                return Container(
                                  width: 80,
                                  height: 102,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    color: Colors.white,
                                    image: imageUrl != null
                                        ? DecorationImage(
                                            image: NetworkImage(imageUrl),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: imageUrl == null
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: Text(
                                              cleanText(item is String ? item : "Нет"),
                                              style: TextStyle(fontSize: 10, color: Colors.black),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        )
                                      : null,
                                );
                              }).toList(),
                            ),
                          ],
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
