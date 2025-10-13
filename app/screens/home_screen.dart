import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/theme_controller.dart';
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
      final storedLocationIdString = await storage.read(key: 'selected_location_id');
      final storedLocationId =
          storedLocationIdString != null ? int.tryParse(storedLocationIdString) : null;
      int? resolvedLocationId = storedLocationId;
      if (resolvedLocationId != null &&
          !locations.any((loc) =>
              loc is Map<String, dynamic> && _parseLocationId(loc['id']) == resolvedLocationId)) {
        resolvedLocationId = null;
      }
      resolvedLocationId ??= _deriveDefaultLocation(locations);
      setState(() {
        wardrobeLocations = locations;
        selectedLocationId = resolvedLocationId;
      });
      await _persistSelectedLocation(resolvedLocationId);
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

  Future<void> _persistSelectedLocation(int? locationId) async {
    if (locationId == null) {
      await storage.delete(key: 'selected_location_id');
    } else {
      await storage.write(
        key: 'selected_location_id',
        value: locationId.toString(),
      );
    }
  }

  Future<void> _handleLocationChange(int? value) async {
    setState(() {
      selectedLocationId = value;
    });
    await _persistSelectedLocation(value);
    fetchWeather();
    fetchMannequins();
  }

  int? _locationIdForRequests() {
    if (selectedLocationId == null) {
      return null;
    }
    final selectedLocation = _findLocationById(selectedLocationId);
    if (selectedLocation == null) {
      return null;
    }
    if (selectedLocation['latitude'] == null ||
        selectedLocation['longitude'] == null) {
      return null;
    }
    return selectedLocationId;
  }

  int? _parseLocationId(dynamic rawId) {
    if (rawId is int) return rawId;
    if (rawId is String) {
      return int.tryParse(rawId);
    }
    if (rawId != null) {
      return int.tryParse(rawId.toString());
    }
    return null;
  }

  int? _deriveDefaultLocation(List<dynamic> locations) {
    for (final loc in locations.whereType<Map<String, dynamic>>()) {
      final lat = loc['latitude'];
      final lon = loc['longitude'];
      if (lat != null && lon != null) {
        return _parseLocationId(loc['id']);
      }
    }
    return null;
  }

  Map<String, dynamic>? _findLocationById(int? id) {
    if (id == null) return null;
    for (final loc in wardrobeLocations.whereType<Map<String, dynamic>>()) {
      if (_parseLocationId(loc['id']) == id) {
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
      final locationIdForRequest = _locationIdForRequests();

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

      final locationIdForRequest = _locationIdForRequests();

      final mannequinResults = await ApiService.getMannequinHistory(
        userId!,
        locationId: locationIdForRequest,
        limit: 1,
      );

      if (!mounted) return;
      setState(() {
        mannequins = mannequinResults.take(1).toList();
      });
    } catch (e) {
      print("Ошибка при получении манекенов: $e");
      if (mounted) {
        setState(() {
          mannequins = [];
          mannequinsError = 'Не удалось загрузить историю манекенов';
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

  Future<void> _generateMannequin() async {
    if (userId == null) return;
    try {
      setState(() {
        isMannequinsLoading = true;
        mannequinsError = null;
      });

      final locationIdForRequest = _locationIdForRequests();
      final mannequin = await ApiService.generateMannequin(
        userId!,
        locationId: locationIdForRequest,
      );

      if (!mounted) return;
      setState(() {
        mannequins = [mannequin];
      });
    } catch (e) {
      print('Ошибка при генерации манекена: $e');
      if (!mounted) return;
      setState(() {
        mannequinsError = 'Не удалось создать манекен. Попробуйте снова.';
      });
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


  Widget _buildMannequinCard(
    BuildContext context,
    Map<String, dynamic> mannequin,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageUrl = mannequin['image_url']?.toString() ??
        mannequin['imageUrl']?.toString() ??
        mannequin['url']?.toString();
    final List<Map<String, dynamic>> items = (mannequin['items'] as List?)
            ?.whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
            .toList(growable: false) ??
        const [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Container(
                color: colorScheme.surfaceVariant,
                alignment: Alignment.center,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.broken_image_outlined,
                          color: colorScheme.onSurfaceVariant,
                          size: 40,
                        ),
                      )
                    : Icon(
                        Icons.image_not_supported_outlined,
                        color: colorScheme.onSurfaceVariant,
                        size: 40,
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Манекен',
                  style: theme.textTheme.titleMedium,
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: items.take(4).map((item) {
                      final name = item['name']?.toString() ?? 'Вещь';
                      final category = item['category']?.toString();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.labelLarge,
                            ),
                            if (category != null && category.isNotEmpty)
                              Text(
                                category,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSecondaryContainer.withOpacity(0.7),
                                ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  Text(
                    'Состав образа уточняется...',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final themeNotifier = ThemeScope.of(context);
    final isDarkMode = themeNotifier.themeMode == ThemeMode.dark;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pressureValue = weather?["pressure"];
    final pressureMm = pressureValue is num ? (pressureValue * 0.75006).round() : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Гардеробус"),
        actions: [
          IconButton(
            icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: isDarkMode ? 'Включить светлую тему' : 'Включить тёмную тему',
            onPressed: () async {
              try {
                await themeNotifier.toggleTheme();
                if (!mounted) return;
                final message = themeNotifier.themeMode == ThemeMode.dark
                    ? 'Тёмная тема включена'
                    : 'Светлая тема включена';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Не удалось сменить тему: $error')),
                );
              }
            },
          ),
        ],
      ),
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
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: isLocationsLoading
                              ? const LinearProgressIndicator()
                              : DropdownButton<int?>(
                                  value: selectedLocationId,
                                  isExpanded: true,
                                  hint: const Text('Выберите локацию гардероба'),
                                  dropdownColor: colorScheme.surface,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                  iconEnabledColor: colorScheme.onPrimaryContainer,
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Использовать личные координаты'),
                                    ),
                                    ...wardrobeLocations.whereType<Map<String, dynamic>>().map((map) {
                                      final name = map['name']?.toString() ?? 'Без названия';
                                      final hasCoords =
                                          map['latitude'] != null && map['longitude'] != null;
                                      final subtitle = hasCoords ? '' : ' (нет координат)';
                                      final parsedId = _parseLocationId(map['id']);
                                      if (parsedId == null) {
                                        return null;
                                      }
                                      return DropdownMenuItem<int?>(
                                        value: parsedId,
                                        child: Text('$name$subtitle'),
                                      );
                                    }).whereType<DropdownMenuItem<int?>>(),
                                  ],
                                  onChanged: (value) {
                                    _handleLocationChange(value);
                                  },
                                ),
                        ),
                      // Блок погоды
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 400),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${weather!["temperature"]}°C',
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Влажность: ${weather!["humidity"]}%',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onPrimaryContainer,
                                  ),
                                ),
                                if (pressureMm != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Давление: $pressureMm мм рт. ст.',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            Image.network(
                              weatherIconUrl ?? '',
                              width: 72,
                              height: 72,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.cloud,
                                size: 48,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),
                      // Блок с погодой на 3 дня
                      if (weather?['forecast'] != null)
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 400),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Прогноз на 3 дня:",
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: (weather!['forecast'] as List<dynamic>).map((day) {
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        day['date'],
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onPrimaryContainer,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            '${day['temp']}°C',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: colorScheme.onPrimaryContainer,
                                            ),
                                          ),
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
                        constraints: const BoxConstraints(maxWidth: 480),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weatherComment ?? 'Подождите, загружаем рекомендации...',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: FilledButton.icon(
                                onPressed: isMannequinsLoading ? null : _generateMannequin,
                                icon: const Icon(Icons.autorenew),
                                label: const Text('Создать манекен'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (isMannequinsLoading)
                              const Center(child: CircularProgressIndicator())
                            else if (mannequins.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  mannequinsError ??
                                      'Нажмите «Создать манекен», чтобы ИИ подобрал образ для текущей погоды и гардероба.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              )
                            else
                              SizedBox(
                                height: 320,
                                child: _buildMannequinCard(
                                  context,
                                  mannequins.first,
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
