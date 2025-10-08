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
  List<Clothes> _allClothes = [];
  bool isLoading = true;
  bool isLocationsLoading = false;
  int? _userId;
  int? selectedLocationId;
  List<dynamic> wardrobeLocations = [];
  String? _error;
  String? _selectedCategoryFilter;
  String? _selectedSeasonFilter;

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
      final parsed = response
          .whereType<Map<String, dynamic>>()
          .map((json) => Clothes.fromJson(json))
          .toList();
      setState(() {
        _allClothes = parsed;
        clothes = _filterClothes(parsed);
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        _error = 'Ошибка при загрузке одежды: $e';
        clothes = [];
        _allClothes = [];
      });
    }
  }

  List<Clothes> _filterClothes(List<Clothes> source) {
    return source.where((item) {
      final categoryMatches = _selectedCategoryFilter == null
          ? true
          : item.category.toLowerCase() == _selectedCategoryFilter!.toLowerCase();
      final seasonMatches = _selectedSeasonFilter == null
          ? true
          : item.season.toLowerCase() == _selectedSeasonFilter!.toLowerCase();
      return categoryMatches && seasonMatches;
    }).toList();
  }

  void _applyFilters() {
    if (!mounted) return;
    setState(() {
      clothes = _filterClothes(_allClothes);
    });
  }

  void _resetFilters() {
    setState(() {
      _selectedCategoryFilter = null;
      _selectedSeasonFilter = null;
      clothes = _filterClothes(_allClothes);
    });
  }

  List<String> get _availableCategories {
    final categories = _allClothes
        .map((item) => item.category.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return categories;
  }

  List<String> get _availableSeasons {
    final values = _allClothes
        .map((item) => item.season.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
    const preferredSeasonOrder = ['Зима', 'Весна', 'Лето', 'Осень'];
    values.sort((a, b) {
      final indexA = preferredSeasonOrder.indexOf(a);
      final indexB = preferredSeasonOrder.indexOf(b);
      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      }
      if (indexA != -1) return -1;
      if (indexB != -1) return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return values;
  }

  Widget _buildActiveFilters() {
    final chips = <Widget>[];
    if (_selectedCategoryFilter != null) {
      chips.add(
        Chip(
          label: Text('Категория: ${_selectedCategoryFilter!}'),
          onDeleted: () {
            setState(() {
              _selectedCategoryFilter = null;
              clothes = _filterClothes(_allClothes);
            });
          },
        ),
      );
    }
    if (_selectedSeasonFilter != null) {
      chips.add(
        Chip(
          label: Text('Сезон: ${_selectedSeasonFilter!}'),
          onDeleted: () {
            setState(() {
              _selectedSeasonFilter = null;
              clothes = _filterClothes(_allClothes);
            });
          },
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }

  void _openFilterSheet() {
    final categories = _availableCategories;
    final seasons = _availableSeasons;
    String? tempCategory = _selectedCategoryFilter;
    String? tempSeason = _selectedSeasonFilter;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Фильтры гардероба',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    if (categories.isEmpty && seasons.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Фильтры появятся, когда будут добавлены вещи с категориями и сезонами.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    if (categories.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        value: tempCategory,
                        decoration: const InputDecoration(
                          labelText: 'Категория',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Все категории'),
                          ),
                          ...categories.map(
                            (category) => DropdownMenuItem<String?>(
                              value: category,
                              child: Text(category),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setModalState(() => tempCategory = value);
                        },
                      ),
                    if (categories.isNotEmpty) const SizedBox(height: 16),
                    if (seasons.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        value: tempSeason,
                        decoration: const InputDecoration(
                          labelText: 'Сезон',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Все сезоны'),
                          ),
                          ...seasons.map(
                            (season) => DropdownMenuItem<String?>(
                              value: season,
                              child: Text(season),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setModalState(() => tempSeason = value);
                        },
                      ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategoryFilter = null;
                              _selectedSeasonFilter = null;
                              clothes = _filterClothes(_allClothes);
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Сбросить'),
                        ),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedCategoryFilter = tempCategory;
                              _selectedSeasonFilter = tempSeason;
                              clothes = _filterClothes(_allClothes);
                            });
                            Navigator.pop(context);
                          },
                          child: const Text('Применить'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
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
      _selectedCategoryFilter = null;
      _selectedSeasonFilter = null;
      clothes = [];
      _allClothes = [];
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

  String? _temperatureRangeText(Clothes item) {
    final min = item.temperatureMin;
    final max = item.temperatureMax;
    if (min == null && max == null) {
      return null;
    }
    if (min != null && max != null) {
      if (min == max) {
        return '$min°C';
      }
      return '$min–$max°C';
    }
    final value = min ?? max;
    return value != null ? '$value°C' : null;
  }

  Widget _buildInfoPill(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textStyle = theme.textTheme.labelSmall?.copyWith(
      color: colorScheme.onSecondaryContainer,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openClothesDetails(Clothes item) async {
    final deleted = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClothesDetailScreen(clothes: item),
      ),
    );
    if (deleted == true) {
      await fetchClothes();
    }
  }

  Widget _buildClothesCard(Clothes item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final temperatureText = _temperatureRangeText(item);
    final careText = item.careInstructions?.trim();
    final materialText = item.material?.trim();
    final description = item.promptDescription?.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openClothesDetails(item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                      if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                        Image.network(
                          item.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: colorScheme.onSurfaceVariant,
                              size: 40,
                            ),
                          ),
                        )
                    else
                      Container(
                        color: colorScheme.surfaceVariant,
                        child: Icon(
                          Icons.image_not_supported,
                          color: colorScheme.onSurfaceVariant,
                          size: 40,
                        ),
                      ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () async {
                            await confirmAndDeleteClothes(item.id);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              Icons.delete,
                              size: 18,
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildInfoPill(context, Icons.checkroom, item.category),
                      _buildInfoPill(context, Icons.calendar_today_outlined, item.season),
                      if (temperatureText != null)
                        _buildInfoPill(context, Icons.device_thermostat, temperatureText),
                      if (materialText != null && materialText.isNotEmpty)
                        _buildInfoPill(context, Icons.texture, materialText),
                    ],
                  ),
                    if (description != null && description.isNotEmpty)
                      const SizedBox(height: 10),
                  if (description != null && description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
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
    final categoryOptions = _availableCategories;
    final seasons = _availableSeasons;
    final filtersAreActive =
        _selectedCategoryFilter != null || _selectedSeasonFilter != null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Гардеробус'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(Icons.filter_list),
                if (filtersAreActive)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Фильтры',
            onPressed: categoryOptions.isEmpty && seasons.isEmpty && _allClothes.isEmpty
                ? null
                : _openFilterSheet,
          ),
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
          if (filtersAreActive) _buildActiveFilters(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: navigateToAddClothes,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.add,
                  color: colorScheme.onPrimaryContainer,
                  size: 32,
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
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.68,
                              ),
                              itemCount: clothes.length,
                              itemBuilder: (context, index) {
                                final item = clothes[index];
                                return _buildClothesCard(item);
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
