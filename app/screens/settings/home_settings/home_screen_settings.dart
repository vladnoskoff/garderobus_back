import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../services/api_service.dart';
import 'Location_Picker_Screen.dart';

Future<void> showHomeSettingsSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: HomeSettingsSheet(sheetContext: sheetContext),
      );
    },
  );
}

class HomeSettingsSheet extends StatefulWidget {
  const HomeSettingsSheet({required this.sheetContext, super.key});

  final BuildContext sheetContext;

  @override
  State<HomeSettingsSheet> createState() => _HomeSettingsSheetState();
}

class _HomeSettingsSheetState extends State<HomeSettingsSheet> {
  String location = 'Нет координат';
  String openAiKey = 'Нет ключа';
  String weatherKey = 'Нет ключа';
  String serialNumber = '0000001';
  int? userId;
  List<Map<String, dynamic>> locations = [];
  int? selectedWardrobeLocationId;
  bool isLocationsLoading = false;

  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    loadUserId();
  }

  Future<void> loadUserId() async {
    final id = await storage.read(key: 'user_id');
    if (id == null) return;

    final parsedId = int.tryParse(id);
    setState(() => userId = parsedId);

    if (parsedId == null) {
      return;
    }

    try {
      final userData = await ApiService.getUser(parsedId);
      if (!mounted) return;
      setState(() {
        location = userData['location'] ?? location;
        openAiKey = userData['openai_api_key'] ?? openAiKey;
        weatherKey = userData['weather_api_key'] ?? weatherKey;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки данных пользователя: $e');
    }

    await _loadLocations(parsedId);
  }

  int? _parseLocationId(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value != null) {
      return int.tryParse(value.toString());
    }
    return null;
  }

  double? _parseCoordinate(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      final normalised = value.replaceAll(',', '.');
      return double.tryParse(normalised.trim());
    }
    return null;
  }

  String _formatCoordinates(dynamic latitude, dynamic longitude) {
    final lat = _parseCoordinate(latitude);
    final lon = _parseCoordinate(longitude);
    if (lat == null || lon == null) {
      return 'Координаты не указаны';
    }
    return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
  }

  Map<String, dynamic>? _currentLocation() {
    final targetId = selectedWardrobeLocationId;
    if (targetId == null) return null;
    for (final loc in locations) {
      if (_parseLocationId(loc['id']) == targetId) {
        return loc;
      }
    }
    return null;
  }

  Future<void> _loadLocations(int userId) async {
    setState(() => isLocationsLoading = true);
    try {
      final storedIdString = await storage.read(key: 'selected_location_id');
      final storedId = storedIdString != null ? int.tryParse(storedIdString) : null;
      final response = await ApiService.getWardrobeLocations(userId);
      final mapped = response.whereType<Map<String, dynamic>>().toList(growable: false);

      int? resolvedId = storedId;
      if (resolvedId != null &&
          !mapped.any((loc) => _parseLocationId(loc['id']) == resolvedId)) {
        resolvedId = null;
      }

      if (mounted) {
        setState(() {
          locations = mapped;
          selectedWardrobeLocationId = resolvedId;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки локаций: $e');
    } finally {
      if (mounted) {
        setState(() => isLocationsLoading = false);
      }
    }
  }

  Future<void> _onLocationSelected(int? newLocationId) async {
    setState(() => selectedWardrobeLocationId = newLocationId);
    if (newLocationId == null) {
      await storage.delete(key: 'selected_location_id');
    } else {
      await storage.write(key: 'selected_location_id', value: newLocationId.toString());
    }
  }

  Future<void> updateKeys() async {
    if (userId == null) return;
    try {
      await ApiService.updateApiKeys(userId!, openAiKey, weatherKey);
      _showSnack('API-ключи обновлены');
    } catch (e) {
      debugPrint('Ошибка обновления API-ключей: $e');
      _showSnack('Не удалось обновить API-ключи');
    }
  }

  Future<void> updateLocation(String newLoc) async {
    if (userId == null) return;
    try {
      await ApiService.updateLocation(userId!, newLoc);
      _showSnack('Координаты обновлены');
    } catch (e) {
      debugPrint('Ошибка при сохранении координат: $e');
      _showSnack('Не удалось сохранить координаты');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(widget.sheetContext).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _renameLocation(Map<String, dynamic> locationData) async {
    if (userId == null) return;
    final locationId = _parseLocationId(locationData['id']);
    if (locationId == null) return;

    final controller = TextEditingController(text: locationData['name']?.toString() ?? '');
    final newName = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Переименовать место'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Название места',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.pop(dialogContext, value.isEmpty ? null : value);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (newName == null) return;

    try {
      await ApiService.updateWardrobeLocation(
        userId: userId!,
        locationId: locationId,
        name: newName,
      );
      _showSnack('Название обновлено');
      await _loadLocations(userId!);
    } catch (e) {
      _showSnack('Не удалось обновить название: $e');
    }
  }

  Future<void> _editLocationCoordinates(Map<String, dynamic> locationData) async {
    if (userId == null) return;
    final locationId = _parseLocationId(locationData['id']);
    if (locationId == null) return;

    final initial = _formatCoordinates(locationData['latitude'], locationData['longitude']);
    final fallback = '55.751669743618876, 37.6164092387259';
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLocation: initial == 'Координаты не указаны' ? fallback : initial,
        ),
      ),
    );

    if (result == null) return;

    final parts = result.split(',');
    if (parts.length != 2) {
      _showSnack('Некорректные координаты');
      return;
    }

    final lat = double.tryParse(parts[0].trim());
    final lon = double.tryParse(parts[1].trim());
    if (lat == null || lon == null) {
      _showSnack('Некорректные координаты');
      return;
    }

    try {
      await ApiService.updateWardrobeLocation(
        userId: userId!,
        locationId: locationId,
        latitude: lat,
        longitude: lon,
      );
      _showSnack('Координаты места обновлены');
      await _loadLocations(userId!);
    } catch (e) {
      _showSnack('Не удалось обновить координаты: $e');
    }
  }

  Widget _buildPersonalLocationCard(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Личные координаты', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            location,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final result = await Navigator.push<String>(
                context,
                MaterialPageRoute(
                  builder: (context) => LocationPickerScreen(initialLocation: location),
                ),
              );
              if (result != null) {
                setState(() => location = result);
                await updateLocation(result);
              }
            },
            icon: const Icon(Icons.place),
            label: const Text('Выбрать на карте'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedLocationCard(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final data = _currentLocation();
    if (data == null) {
      return const SizedBox.shrink();
    }

    final coordinates = _formatCoordinates(data['latitude'], data['longitude']);
    final name = data['name']?.toString() ?? 'Без названия';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Координаты: $coordinates', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _renameLocation(data),
                  icon: const Icon(Icons.edit),
                  label: const Text('Переименовать'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _editLocationCoordinates(data),
                  icon: const Icon(Icons.place_outlined),
                  label: const Text('Изменить точку'),
                ),
              ),
            ],
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
          decoration: InputDecoration(border: const OutlineInputBorder(), labelText: title),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onEdit(controller.text);
              }
              Navigator.pop(context);
              if (title.contains('API')) updateKeys();
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

  Widget buildOption(IconData icon, String title, String value, VoidCallback onTap) {
    final isApiKey = title.contains('API');
    final displayedValue = isApiKey ? shortenKey(value) : value;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      height: 72,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 28, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  displayedValue,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.edit),
            color: colorScheme.onSecondaryContainer,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dropdownItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Личные данные аккаунта'),
      ),
      ...locations.map((loc) {
        final id = _parseLocationId(loc['id']);
        if (id == null) return null;
        return DropdownMenuItem<int?>(
          value: id,
          child: Text(loc['name']?.toString() ?? 'Без названия'),
        );
      }).whereType<DropdownMenuItem<int?>>(),
    ];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Дом',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: isLocationsLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<int?>(
                            value: selectedWardrobeLocationId,
                            decoration: const InputDecoration(
                              labelText: 'Выбранное место',
                              border: OutlineInputBorder(),
                            ),
                            items: dropdownItems,
                            onChanged: (value) => _onLocationSelected(value),
                          ),
                          const SizedBox(height: 16),
                          if (selectedWardrobeLocationId == null)
                            _buildPersonalLocationCard(colorScheme)
                          else
                            _buildSelectedLocationCard(colorScheme),
                          const SizedBox(height: 24),
                          Text('API-ключи', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 12),
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
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }
}
