import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';
import '../../services/clothes.dart';
import 'add_clothes_screen.dart';
import 'clothes_detail_screen.dart';
import 'outfit_history_screen.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  _WardrobeScreenState createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  final storage = const FlutterSecureStorage();
  List<Clothes> clothes = [];
  bool isLoading = true;
  bool isLocationsLoading = false;
  int? _userId;
  int? selectedLocationId;
  List<dynamic> wardrobeLocations = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    final userIdValue = await storage.read(key: 'user_id');
    if (!mounted) return;

    if (userIdValue == null) {
      setState(() {
        isLoading = false;
        _error = 'Пользователь не найден';
      });
      return;
    }

    final parsedId = int.tryParse(userIdValue);
    if (parsedId == null) {
      setState(() {
        isLoading = false;
        _error = 'Некорректный идентификатор пользователя';
      });
      return;
    }

    setState(() {
      _userId = parsedId;
    });

    await _loadLocations();
    await fetchClothes();
  }

  Future<void> _loadLocations() async {
    if (_userId == null) return;
    setState(() {
      isLocationsLoading = true;
    });
    try {
      final locations = await ApiService.getWardrobeLocations(_userId!);
      final storedLocationIdString = await storage.read(key: 'selected_location_id');
      int? storedLocationId = storedLocationIdString != null
          ? int.tryParse(storedLocationIdString)
          : null;

      int? resolvedLocationId = storedLocationId;
      final mappedLocations = locations.whereType<Map<String, dynamic>>().toList();
      final hasStored = resolvedLocationId != null &&
          mappedLocations.any((loc) => _extractLocationId(loc['id']) == resolvedLocationId);

      if (!hasStored) {
        resolvedLocationId = null;
      }

      resolvedLocationId ??=
          mappedLocations.isNotEmpty ? _extractLocationId(mappedLocations.first['id']) : null;

      setState(() {
        wardrobeLocations = locations;
        selectedLocationId = resolvedLocationId;
      });

      if (resolvedLocationId != storedLocationId) {
        await _persistSelectedLocation(resolvedLocationId);
      }
    } catch (e) {
      setState(() {
        _error = 'Не удалось загрузить локации: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLocationsLoading = false;
        });
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

  Future<void> fetchClothes() async {
    if (_userId == null) return;
    if (mounted) {
      setState(() {
        isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await ApiService.getUserClothes(
        _userId!,
        locationId: selectedLocationId,
      );
      if (!mounted) return;
      setState(() {
        clothes = response
            .whereType<Map<String, dynamic>>()
            .map((json) => Clothes.fromJson(json))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _error = 'Ошибка при загрузке одежды: $e';
        clothes = [];
      });
    }
  }

  Future<void> confirmAndDeleteClothes(int clothesId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить вещь'),
        content: Text('Вы уверены, что хотите удалить эту вещь?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService.deleteClothes(clothesId);
      await fetchClothes();
    }
  }

  void navigateToAddClothes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddClothesScreen(
          initialLocationId: selectedLocationId,
        ),
      ),
    ).then((_) => fetchClothes());
  }

  Future<void> _onLocationChanged(int? newLocationId) async {
    setState(() {
      selectedLocationId = newLocationId;
    });
    await _persistSelectedLocation(newLocationId);
    await fetchClothes();
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OutfitHistoryScreen(
          locationId: selectedLocationId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationDropdownItems = wardrobeLocations
        .whereType<Map<String, dynamic>>()
        .map((loc) {
          final parsedId = _extractLocationId(loc['id']);
          if (parsedId == null) {
            return null;
          }
          final name = loc['name']?.toString() ?? 'Без названия';
          return DropdownMenuItem<int?>(
            value: parsedId,
            child: Text(name),
          );
        })
        .whereType<DropdownMenuItem<int?>>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Гардеробус'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'История нарядов',
            onPressed: _openHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          if (isLocationsLoading) const LinearProgressIndicator(),
          if (wardrobeLocations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: DropdownButtonFormField<int?>(
                value: selectedLocationId,
                decoration: const InputDecoration(
                  labelText: 'Локация гардероба',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Без привязки'),
                  ),
                  ...locationDropdownItems,
                ],
                onChanged: (value) {
                  _onLocationChanged(value);
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: navigateToAddClothes,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.add,
                    color: Colors.black,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : clothes.isEmpty
                        ? const Center(
                            child: Text(
                              'В этом гардеробе пока нет вещей.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: GridView.builder(
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1.2,
                              ),
                              itemCount: clothes.length,
                              itemBuilder: (context, index) {
                                final item = clothes[index];
                                return GestureDetector(
                                  onTap: () async {
                                    final deleted = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ClothesDetailScreen(clothes: item),
                                      ),
                                    );
                                    if (deleted == true) {
                                      await fetchClothes();
                                    }
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF62DEFA),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Stack(
                                      children: [
                                        Positioned(
                                          left: 12,
                                          top: 18,
                                          right: 35,
                                          child: Container(
                                            height: 127,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(15),
                                              image: item.imageUrl != null
                                                  ? DecorationImage(
                                                      image: NetworkImage(item.imageUrl!),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : null,
                                            ),
                                            child: item.imageUrl == null
                                                ? const Center(
                                                    child: Icon(
                                                      Icons.image_not_supported,
                                                      color: Colors.white70,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        Positioned(
                                          right: 8,
                                          top: 8,
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFCFDDE0),
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: const Icon(
                                              Icons.edit,
                                              color: Colors.black,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          right: 8,
                                          bottom: 8,
                                          child: GestureDetector(
                                            onTap: () => confirmAndDeleteClothes(item.id),
                                            child: Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFF0D0D),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                              child: const Icon(
                                                Icons.delete,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
}

  int? _extractLocationId(dynamic rawId) {
    if (rawId is int) return rawId;
    if (rawId is String) {
      return int.tryParse(rawId);
    }
    if (rawId != null) {
      return int.tryParse(rawId.toString());
    }
    return null;
  }
}
