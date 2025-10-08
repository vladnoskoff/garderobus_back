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
  List<Map<String, dynamic>> mannequins = [];
  String? weatherComment;
  String? weatherIconUrl;
  final storage = FlutterSecureStorage();
  int? userId;
  List<dynamic> wardrobeLocations = [];
  int? selectedLocationId;
  bool isLocationsLoading = false;
  bool isMannequinsLoading = false;
  String? mannequinsError;

  @override
  void initState() {
    super.initState();
    loadUserId();
    fetchWeather();
    fetchMannequins();
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
      fetchMannequins();
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
      fetchMannequins();
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

  Future<void> fetchMannequins() async {
    if (userId == null) return;
    try {
      if (mounted) {
        setState(() {
          isMannequinsLoading = true;
          mannequinsError = null;
        });
      }

      int? locationIdForRequest = selectedLocationId;
      final selectedLocation = _findLocationById(selectedLocationId);
      if (selectedLocation != null) {
        if (selectedLocation['latitude'] == null || selectedLocation['longitude'] == null) {
          locationIdForRequest = null;
        }
      }

      final mannequinResults = await ApiService.getMannequins(
        userId!,
        locationId: locationIdForRequest,
      );

      if (!mounted) return;
      setState(() {
        mannequins = mannequinResults.length > 3
            ? mannequinResults.take(3).toList()
            : mannequinResults;
      });
    } catch (e) {
      print("Ошибка при получении манекенов: $e");
      if (mounted) {
        setState(() {
          mannequins = [];
          mannequinsError = 'Не удалось загрузить рекомендации';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isMannequinsLoading = false;
        });
      }
    }
  }

  String generateWeatherComment(Map<String, dynamic> weather) {
    final temp = (weather['temperature'] as num?)?.toDouble();
    final wind = (weather['wind_speed'] as num?)?.toDouble() ?? 0;
    final condition = weather['condition']?.toString().toLowerCase() ?? '';

    if (temp == null) {
      return 'Следите за погодой и подбирайте одежду по ощущениям.';
    }

    String recommendation;
    if (temp < -10) {
      recommendation = 'Экстремальный холод — утепляйтесь по максимуму.';
    } else if (temp < 0) {
      recommendation = 'Очень холодно, одевайтесь теплее и добавьте аксессуары для защиты от мороза.';
    } else if (temp < 10) {
      recommendation = 'Прохладно — наденьте тёплый верхний слой.';
    } else if (temp < 18) {
      recommendation = 'Лёгкая прохлада, возьмите ветровку или кардиган.';
    } else if (temp < 25) {
      recommendation = 'Комфортно, можно выбрать лёгкий повседневный образ.';
    } else {
      recommendation = 'Жарко, выбирайте лёгкие ткани и дышащую одежду.';
    }

    if (condition.contains('дожд') || condition.contains('rain')) {
      recommendation += ' Возьмите зонт или дождевик.';
    } else if (condition.contains('снег') || condition.contains('snow')) {
      recommendation += ' Не забудьте тёплую верхнюю одежду и обувь для снега.';
    }

    if (wind >= 8) {
      recommendation += ' На улице ветрено — выбирайте закрытые верхние слои.';
    }

    return recommendation;
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
                                    fetchMannequins();
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
                      // Блок с манекенами
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(maxWidth: 400),
                        decoration: BoxDecoration(
                          color: Color(0xFF62DEFA),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    weatherComment ?? 'Подождите, загружаем рекомендации...',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.refresh, size: 20, color: Colors.black),
                                  tooltip: 'Обновить манекены',
                                  onPressed: () => fetchMannequins(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (isMannequinsLoading)
                              const Center(child: CircularProgressIndicator())
                            else if (mannequins.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Text(
                                  mannequinsError ?? 'Манекены пока недоступны. Попробуйте обновить или добавьте больше одежды.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.black87, fontSize: 13),
                                ),
                              )
                            else
                              SizedBox(
                                height: 200,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: mannequins.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final mannequin = mannequins[index];
                                    final imageUrl = mannequin['image_url'] ??
                                        mannequin['imageUrl'] ??
                                        mannequin['url'];

                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(16),
                                      child: imageUrl != null
                                          ? Image.network(
                                              imageUrl,
                                              width: 140,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                width: 140,
                                                color: Colors.white,
                                                alignment: Alignment.center,
                                                child: const Text(
                                                  'Ошибка загрузки',
                                                  style: TextStyle(color: Colors.black54, fontSize: 12),
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: 140,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                'Нет изображения',
                                                style: TextStyle(color: Colors.black54, fontSize: 12),
                                              ),
                                            ),
                                    );
                                  },
                                ),
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
