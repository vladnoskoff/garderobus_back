import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../services/api_service.dart';
import '../home_settings/Location_Picker_Screen.dart';

Future<void> showPlacesSettingsSheet(BuildContext context) async {
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
        child: PlacesSettingsSheet(sheetContext: sheetContext),
      );
    },
  );
}

class PlacesSettingsSheet extends StatefulWidget {
  const PlacesSettingsSheet({required this.sheetContext, super.key});

  final BuildContext sheetContext;

  @override
  State<PlacesSettingsSheet> createState() => _PlacesSettingsSheetState();
}

class _PlacesSettingsSheetState extends State<PlacesSettingsSheet> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  int? _userId;
  List<dynamic> _locations = [];
  bool _isLoading = false;
  String? _homeCoordinates;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    try {
      final idString = await _storage.read(key: 'user_id');
      if (idString == null) return;
      final parsedId = int.tryParse(idString);
      if (parsedId == null) return;

      final user = await ApiService.getUser(parsedId);
      final locations = await ApiService.getWardrobeLocations(parsedId);
      final mappedLocations =
          locations.whereType<Map<String, dynamic>>().toList(growable: false);

      if (!mounted) return;
      setState(() {
        _userId = parsedId;
        _locations = mappedLocations;
        _homeCoordinates = user['location']?.toString();
      });
    } catch (e) {
      _showError('Не удалось загрузить данные: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(widget.sheetContext).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
    if (latitude == null || longitude == null) {
      return 'Координаты не указаны';
    }
    final lat = _parseCoordinate(latitude);
    final lon = _parseCoordinate(longitude);
    if (lat == null || lon == null) {
      return 'Координаты не указаны';
    }
    return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
  }

  Future<void> _refreshLocations() async {
    if (_userId == null) return;
    try {
      final locations = await ApiService.getWardrobeLocations(_userId!);
      if (!mounted) return;
      setState(() =>
          _locations = locations.whereType<Map<String, dynamic>>().toList());
    } catch (e) {
      _showError('Ошибка обновления списка: $e');
    }
  }

  Future<void> _pickHomeCoordinates() async {
    if (_userId == null) return;

    final initial =
        (_homeCoordinates != null && _homeCoordinates!.trim().isNotEmpty)
            ? _homeCoordinates!
            : '55.751669743618876, 37.6164092387259';

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(initialLocation: initial),
      ),
    );

    if (result != null) {
      try {
        await ApiService.updateLocation(_userId!, result);
        if (!mounted) return;
        setState(() => _homeCoordinates = result);
        ScaffoldMessenger.of(widget.sheetContext).showSnackBar(
          const SnackBar(content: Text('Домашние координаты обновлены')),
        );
      } catch (e) {
        _showError('Не удалось сохранить координаты: $e');
      }
    }
  }

  Future<String?> _pickCoordinates({String? initial}) async {
    final start = (initial != null && initial.trim().isNotEmpty)
        ? initial
        : '55.751669743618876, 37.6164092387259';
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(initialLocation: start),
      ),
    );
  }

  Future<void> _showLocationDialog({Map<String, dynamic>? location}) async {
    if (_userId == null) return;

    final isEdit = location != null;
    final initialName = location?['name']?.toString() ?? '';
    final initialLatitude = _parseCoordinate(location?['latitude']);
    final initialLongitude = _parseCoordinate(location?['longitude']);

    final nameController = TextEditingController(text: initialName);
    double? latitude = initialLatitude;
    double? longitude = initialLongitude;

    String? coordinatesDisplay = latitude != null && longitude != null
        ? '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
        : null;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(isEdit ? 'Редактировать локацию' : 'Добавить локацию'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Название места'),
                  ),
                  const SizedBox(height: 16),
                  if (coordinatesDisplay != null)
                    Text(
                      'Координаты: $coordinatesDisplay',
                      style: const TextStyle(fontSize: 14),
                    )
                  else
                    const Text('Координаты не выбраны'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final initial = coordinatesDisplay ?? '';
                      final result = await _pickCoordinates(initial: initial);
                      if (result != null) {
                        final parts = result.split(',');
                        if (parts.length == 2) {
                          final lat = double.tryParse(parts[0].trim());
                          final lon = double.tryParse(parts[1].trim());
                          if (lat != null && lon != null) {
                            setStateDialog(() {
                              latitude = lat;
                              longitude = lon;
                              coordinatesDisplay =
                                  '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
                            });
                          }
                        }
                      }
                    },
                    icon: const Icon(Icons.location_on_outlined),
                    label: Text(coordinatesDisplay == null
                        ? 'Выбрать координаты'
                        : 'Изменить координаты'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      _showError('Введите название локации');
                      return;
                    }

                    try {
                      final hasNameChanged = name != initialName;
                      final hasLatitudeChanged = latitude != initialLatitude;
                      final hasLongitudeChanged = longitude != initialLongitude;

                      if (isEdit && !hasNameChanged && !hasLatitudeChanged && !hasLongitudeChanged) {
                        Navigator.pop(context);
                        return;
                      }

                      if (!isEdit && (latitude == null || longitude == null)) {
                        _showError('Выберите координаты на карте');
                        return;
                      }

                      if (isEdit) {
                        final locationId = _parseLocationId(location?['id']);
                        if (locationId == null) {
                          _showError('Некорректная локация');
                          return;
                        }
                        await ApiService.updateWardrobeLocation(
                          userId: _userId!,
                          locationId: locationId,
                          name: name,
                          latitude: latitude,
                          longitude: longitude,
                        );
                      } else {
                        await ApiService.createWardrobeLocation(
                          userId: _userId!,
                          name: name,
                          latitude: latitude,
                          longitude: longitude,
                        );
                      }
                      if (mounted) Navigator.pop(context);
                      await _refreshLocations();
                    } catch (e) {
                      _showError('Не удалось сохранить локацию: $e');
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

  Future<void> _deleteLocation(dynamic locationId) async {
    if (_userId == null) return;
    try {
      final parsedId = _parseLocationId(locationId);
      if (parsedId == null) {
        _showError('Некорректная локация');
        return;
      }
      await ApiService.deleteWardrobeLocation(userId: _userId!, locationId: parsedId);
      await _refreshLocations();
    } catch (e) {
      _showError('Не удалось удалить локацию: $e');
    }
  }

  Widget _buildHomeCard(ColorScheme colorScheme, TextTheme textTheme) {
    final coordinatesText =
        (_homeCoordinates != null && _homeCoordinates!.trim().isNotEmpty)
            ? _homeCoordinates!
            : 'Координаты не указаны';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Домашние координаты',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            coordinatesText,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _pickHomeCoordinates,
              icon: const Icon(Icons.edit_location_alt),
              label: const Text('Изменить'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile(
    Map<String, dynamic> location,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final coords = _formatCoordinates(location['latitude'], location['longitude']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.onSecondaryContainer.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.location_on, color: colorScheme.onSecondaryContainer),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location['name']?.toString() ?? 'Без названия',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  coords,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSecondaryContainer.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            color: colorScheme.onSecondaryContainer,
            onPressed: () => _showLocationDialog(location: location),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            color: colorScheme.error,
            onPressed: () => _deleteLocation(location['id']),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

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
                    'Места',
                    style: textTheme.titleLarge?.copyWith(
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
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHomeCard(colorScheme, textTheme),
                          if (_locations.isEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              alignment: Alignment.center,
                              child: const Text('Локации гардероба пока не добавлены'),
                            )
                          else
                            ..._locations
                                .whereType<Map<String, dynamic>>()
                                .map((location) => _buildLocationTile(
                                      location,
                                      colorScheme,
                                      textTheme,
                                    )),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _showLocationDialog(),
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить место'),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                Navigator.of(context).maybePop();
              },
              child: const Text('Готово'),
            ),
          ],
        ),
      ),
    );
  }
}
