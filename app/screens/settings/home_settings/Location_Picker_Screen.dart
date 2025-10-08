import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LocationPickerScreen extends StatefulWidget {
  final String initialLocation;

  const LocationPickerScreen({
    super.key,
    required this.initialLocation,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late final MapController _mapController;
  late LatLng _selectedLocation;
  double _currentZoom = 13;

  static const LatLng _moscowFallback =
      LatLng(55.751669743618876, 37.6164092387259);

  LatLng _parseInitialLocation() {
    final parts = widget.initialLocation.split(',');
    if (parts.length != 2) {
      return _moscowFallback;
    }

    final lat = double.tryParse(parts[0].trim());
    final lon = double.tryParse(parts[1].trim());
    if (lat == null || lon == null) {
      return _moscowFallback;
    }

    return LatLng(lat, lon);
  }

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _selectedLocation = _parseInitialLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Выбор координат")),
      body: Stack(
        children: [
          FlutterMap(
            key: ValueKey(_selectedLocation),
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLocation,
              initialZoom: _currentZoom,
              onTap: (tapPosition, point) {
                setState(() => _selectedLocation = point);
                _mapController.move(point, _currentZoom);
              },
              onPositionChanged: (position, hasGesture) {
                _currentZoom = position.zoom;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                tileProvider: NetworkTileProvider(
                  headers: const {
                    'User-Agent':
                        'CHKAF/1.0 (contact@noksovsteam.ru, ru.noksovsteam.chkaf)',
                  },
                ),
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _selectedLocation,
                    width: 40,
                    height: 40,
                    child:
                        const Icon(Icons.location_on, size: 40, color: Colors.red),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 90,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Выбранные координаты',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_selectedLocation.latitude.toStringAsFixed(6)}, '
                    '${_selectedLocation.longitude.toStringAsFixed(6)}',
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Нажмите на карту, чтобы изменить точку.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.check),
        onPressed: () {
          final loc =
              '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}';
          Navigator.pop(context, loc); // ВАЖНО
        },
      ),
    );
  }
}
