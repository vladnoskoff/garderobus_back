import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../services/api_service.dart';
import '../home_settings/Location_Picker_Screen.dart';

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
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

      setState(() {
        _userId = parsedId;
        _locations = locations;
        _homeCoordinates = user['location']?.toString();
      });
    } catch (e) {
      _showError('Не удалось загрузить данные: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatCoordinates(dynamic latitude, dynamic longitude) {
    if (latitude == null || longitude == null) {
      return 'Координаты не указаны';
    }
    final lat = (latitude as num).toDouble();
    final lon = (longitude as num).toDouble();
    return '${lat.toStringAsFixed(6)}, ${lon.toStringAsFixed(6)}';
  }

  Future<void> _refreshLocations() async {
    if (_userId == null) return;
    try {
      final locations = await ApiService.getWardrobeLocations(_userId!);
      setState(() => _locations = locations);
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
        setState(() => _homeCoordinates = result);
        ScaffoldMessenger.of(context).showSnackBar(
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
    final initialLatitude = location?['latitude'] != null
        ? (location!['latitude'] as num).toDouble()
        : null;
    final initialLongitude = location?['longitude'] != null
        ? (location!['longitude'] as num).toDouble()
        : null;

    final nameController = TextEditingController(text: initialName);
    double? latitude = initialLatitude;
    double? longitude = initialLongitude;

    String? coordinatesDisplay =
        latitude != null && longitude != null ? '$latitude, $longitude' : null;

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
                              coordinatesDisplay = '$lat, $lon';
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

                      if (isEdit) {
                        await ApiService.updateWardrobeLocation(
                          userId: _userId!,
                          locationId: location!['id'] as int,
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

  Future<void> _deleteLocation(int locationId) async {
    if (_userId == null) return;
    try {
      await ApiService.deleteWardrobeLocation(userId: _userId!, locationId: locationId);
      await _refreshLocations();
    } catch (e) {
      _showError('Не удалось удалить локацию: $e');
    }
  }

  Widget _buildHomeCard() {
    final coordinatesText =
        (_homeCoordinates != null && _homeCoordinates!.trim().isNotEmpty)
            ? _homeCoordinates!
            : 'Координаты не указаны';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF62DEFA),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Домашние координаты',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            coordinatesText,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _pickHomeCoordinates,
              icon: const Icon(Icons.edit_location_alt),
              label: const Text('Изменить'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTile(Map<String, dynamic> location) {
    final coords = _formatCoordinates(location['latitude'], location['longitude']);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF62DEFA),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.location_on, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location['name']?.toString() ?? 'Без названия',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  coords,
                  style: const TextStyle(color: Colors.black87, fontSize: 14),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.black),
            onPressed: () => _showLocationDialog(location: location),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () => _deleteLocation(location['id'] as int),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Места'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshLocations,
              child: ListView(
                padding: const EdgeInsets.all(16),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildHomeCard(),
                  if (_locations.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: const Text('Локации гардероба пока не добавлены'),
                    )
                  else
                    ..._locations.map((loc) => _buildLocationTile(loc as Map<String, dynamic>)),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLocationDialog(),
        backgroundColor: const Color(0xFFCFDDE0),
        child: const Icon(
          Icons.add,
          color: Colors.black,
        ),
      ),
    );
  }
}
