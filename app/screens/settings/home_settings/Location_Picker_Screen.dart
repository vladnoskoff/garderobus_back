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
  late LatLng selectedLocation;

  @override
  void initState() {
    super.initState();
    final parts = widget.initialLocation.split(',');
    if (parts.length == 2) {
      selectedLocation = LatLng(
        double.parse(parts[0]),
        double.parse(parts[1]),
      );
    } else {
      selectedLocation = LatLng(55.751669743618876, 37.6164092387259); // Москва по умолчанию
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Выбор координат")),
      body: FlutterMap(
        options: MapOptions(
          center: selectedLocation,
          zoom: 13,
          onTap: (tapPosition, point) {
            setState(() => selectedLocation = point);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: 'com.example.app',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: selectedLocation,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_on, size: 40, color: Colors.red),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.check),
        onPressed: () {
          final loc = '${selectedLocation.latitude}, ${selectedLocation.longitude}';
          Navigator.pop(context, loc); // ВАЖНО
        },
      ),
    );
  }
}
