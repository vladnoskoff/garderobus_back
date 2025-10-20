import 'dart:math' as math;

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

  Future<void> _openFilterSheet() async {
    final categories = _availableCategories;
    final seasons = _availableSeasons;
    String? tempCategory = _selectedCategoryFilter;
    String? tempSeason = _selectedSeasonFilter;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final theme = Theme.of(context);
              final colorScheme = theme.colorScheme;
              final labelStyle = theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Фильтры гардероба',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Сужайте подборку по категориям и сезонам.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (categories.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      value: tempCategory,
                      decoration: InputDecoration(
                        labelText: 'Категория',
                        labelStyle: labelStyle,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: colorScheme.surfaceVariant.withOpacity(
                          theme.brightness == Brightness.dark ? 0.3 : 0.6,
                        ),
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
                  if (categories.isNotEmpty && seasons.isNotEmpty)
                    const SizedBox(height: 16),
                  if (seasons.isNotEmpty)
                    DropdownButtonFormField<String?>(
                      value: tempSeason,
                      decoration: InputDecoration(
                        labelText: 'Сезон',
                        labelStyle: labelStyle,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: colorScheme.surfaceVariant.withOpacity(
                          theme.brightness == Brightness.dark ? 0.3 : 0.6,
                        ),
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
                  if (categories.isEmpty && seasons.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(
                          theme.brightness == Brightness.dark ? 0.35 : 0.8,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Фильтры появятся, когда вы добавите вещи с категориями и сезонами.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
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
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
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
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _resetFilters() {
    setState(() {
      _selectedCategoryFilter = null;
      _selectedSeasonFilter = null;
      clothes = _filterClothes(_allClothes);
    });
  }

  Future<void> confirmAndDeleteClothes(int clothesId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить вещь'),
        content: const Text('Вы уверены, что хотите удалить эту вещь?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
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

  Future<void> _openClothesDetails(Clothes item) async {
    final deleted = await showClothesDetailSheet(context, item);
    if (deleted == true) {
      await fetchClothes();
    }
  }

  Widget _buildWardrobeHeader(
    BuildContext context,
    List<DropdownMenuItem<int?>> locationItems,
    bool filtersAreActive,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final totalCount = clothes.length;
    final activeFiltersCount = [
      if (_selectedCategoryFilter != null) _selectedCategoryFilter,
      if (_selectedSeasonFilter != null) _selectedSeasonFilter,
    ].length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(brightness == Brightness.dark ? 0.4 : 0.85),
            colorScheme.surfaceVariant.withOpacity(brightness == Brightness.dark ? 0.3 : 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.checkroom_outlined,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  totalCount > 0
                      ? 'Всего вещей: $totalCount'
                      : 'Добавьте первую вещь в гардероб',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            value: selectedLocationId,
            decoration: InputDecoration(
              labelText: 'Локация гардероба',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
              filled: true,
              fillColor: colorScheme.surface.withOpacity(brightness == Brightness.dark ? 0.35 : 0.9),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Все локации'),
              ),
              ...locationItems,
            ],
            onChanged: isLocationsLoading ? null : (value) => _onLocationChanged(value),
          ),
          const SizedBox(height: 16),
          if (isLocationsLoading) const LinearProgressIndicator(minHeight: 2),
          if (isLocationsLoading) const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: navigateToAddClothes,
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить вещь'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _openFilterSheet,
                  icon: const Icon(Icons.tune_rounded),
                  label: Text(
                    activeFiltersCount > 0
                        ? 'Фильтры • $activeFiltersCount'
                        : 'Фильтры',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _openHistory,
            icon: const Icon(Icons.history),
            label: const Text('История нарядов'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSummary(ColorScheme colorScheme) {
    final theme = Theme.of(context);
    final chips = <Widget>[];
    if (_selectedCategoryFilter != null) {
      chips.add(_buildFilterChip(
        label: 'Категория: ${_selectedCategoryFilter!}',
        onDeleted: () {
          setState(() {
            _selectedCategoryFilter = null;
            clothes = _filterClothes(_allClothes);
          });
        },
        colorScheme: colorScheme,
      ));
    }
    if (_selectedSeasonFilter != null) {
      chips.add(_buildFilterChip(
        label: 'Сезон: ${_selectedSeasonFilter!}',
        onDeleted: () {
          setState(() {
            _selectedSeasonFilter = null;
            clothes = _filterClothes(_allClothes);
          });
        },
        colorScheme: colorScheme,
      ));
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(
          Theme.of(context).brightness == Brightness.dark ? 0.35 : 0.65,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Активные фильтры',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: chips,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('Сбросить фильтры'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onDeleted,
    required ColorScheme colorScheme,
  }) {
    return Chip(
      label: Text(label),
      onDeleted: onDeleted,
      deleteIcon: const Icon(Icons.close, size: 18),
      labelStyle: TextStyle(
        color: colorScheme.onSecondaryContainer,
      ),
      backgroundColor: colorScheme.secondaryContainer.withOpacity(0.8),
    );
  }

  Widget _buildClothesCard(Clothes item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final temperatureText = _temperatureRangeText(item);
    final materialText = item.material?.trim();
    final careText = item.careInstructions?.trim();
    final description = item.promptDescription?.trim();

    final chips = <Widget>[
      _buildMetadataChip(Icons.category_outlined, item.category),
      _buildMetadataChip(Icons.style_outlined, item.season),
      if (item.color.trim().isNotEmpty)
        _buildMetadataChip(Icons.palette_outlined, item.color.trim()),
      if (temperatureText != null)
        _buildMetadataChip(Icons.thermostat, temperatureText),
      if (materialText != null && materialText.isNotEmpty)
        _buildMetadataChip(Icons.texture, materialText),
      if (careText != null && careText.isNotEmpty)
        _buildMetadataChip(Icons.local_laundry_service_outlined, careText),
    ];

    return InkWell(
      onTap: () => _openClothesDetails(item),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.surfaceVariant.withOpacity(brightness == Brightness.dark ? 0.45 : 0.85),
              colorScheme.surfaceVariant.withOpacity(brightness == Brightness.dark ? 0.3 : 0.6),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.15)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: colorScheme.surfaceVariant.withOpacity(0.35),
                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? Image.network(
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
                        : Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 42,
                              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                            ),
                          ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      tooltip: 'Удалить',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => confirmAndDeleteClothes(item.id),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.35),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: chips,
                  ),
                  if (description != null && description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataChip(IconData icon, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(
          theme.brightness == Brightness.dark ? 0.45 : 0.75,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtersAreActive = _selectedCategoryFilter != null || _selectedSeasonFilter != null;

    final locationDropdownItems = wardrobeLocations
        .whereType<Map<String, dynamic>>()
        .map((location) {
          final id = _extractLocationId(location['id']);
          final name = location['name']?.toString() ?? (id != null ? 'Локация #$id' : null);
          if (id == null || name == null) {
            return null;
          }
          return DropdownMenuItem<int?>(
            value: id,
            child: Text(name),
          );
        })
        .whereType<DropdownMenuItem<int?>>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('Гардероб${!isLoading ? ' ${clothes.length}' : ''}'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final targetWidth = math.min(constraints.maxWidth, 980.0);
            final horizontalPadding = math.max(20.0, (constraints.maxWidth - targetWidth) / 2);

            return RefreshIndicator(
              onRefresh: fetchClothes,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildWardrobeHeader(context, locationDropdownItems, filtersAreActive),
                          if (filtersAreActive) ...[
                            const SizedBox(height: 20),
                            _buildFilterSummary(colorScheme),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (isLoading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else if (clothes.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'В этом гардеробе пока нет вещей. Добавьте новые элементы, чтобы увидеть их здесь.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        24,
                        horizontalPadding,
                        24 + MediaQuery.of(context).padding.bottom,
                      ),
                      sliver: SliverGrid(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = clothes[index];
                            return _buildClothesCard(item);
                          },
                          childCount: clothes.length,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: constraints.maxWidth >= 1200
                              ? 4
                              : constraints.maxWidth >= 900
                                  ? 3
                                  : 2,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.68,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
