import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/api_service.dart';
import '../../services/clothes.dart';
import '../../services/image_cache_service.dart';
import '../../services/network_service.dart';
import '../../services/startup_service.dart';
import '../../services/sync_service.dart';
import '../../services/state_restoration_service.dart';
import '../../widgets/skeletons.dart';
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
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initialise();
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

    final restored = await StateRestorationService.restoreWardrobeFilters();
    final restoredCategory = restored.$1;
    final restoredSeason = restored.$2;
    if (!mounted) return;
    setState(() {
      _selectedCategoryFilter = restoredCategory;
      _selectedSeasonFilter = restoredSeason;
      clothes = _filterClothes(_allClothes);
    });
  }

  Future<void> _loadLocations() async {
    if (_userId == null) return;
    setState(() {
      isLocationsLoading = true;
    });
    try {
      final cachedLocations = await StartupService.getCachedLocations(_userId!);
      if (cachedLocations.isNotEmpty && mounted) {
        setState(() {
          wardrobeLocations = cachedLocations;
          selectedLocationId ??= _extractLocationId(cachedLocations.first['id']);
        });
      }

      final locations = await ApiService.getWardrobeLocations(_userId!);
      await StartupService.cacheLocations(_userId!, locations);
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

  Widget _buildStatusBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkService.isOnline,
      builder: (context, isOnline, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: SyncService.instance.isSyncing,
          builder: (context, isSyncing, __) {
            if (isOnline && !isSyncing) return const SizedBox.shrink();

            final background = isOnline
                ? colorScheme.tertiaryContainer
                : colorScheme.errorContainer;
            final foreground = isOnline
                ? colorScheme.onTertiaryContainer
                : colorScheme.onErrorContainer;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(isOnline ? Icons.sync : Icons.cloud_off, color: foreground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isOnline
                          ? 'Синхронизация очереди действий'
                          : 'Офлайн-режим: новые изменения помечены как ожидающие',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
      final parsed = await ApiService.getUserClothes(
        _userId!,
        locationId: selectedLocationId,
      );
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
                            StateRestorationService.persistWardrobeFilters();
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
                            StateRestorationService.persistWardrobeFilters(
                              category: tempCategory,
                              season: tempSeason,
                            );
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
    StateRestorationService.persistWardrobeFilters();
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

    final baseSurface = colorScheme.surfaceVariant.withOpacity(
      brightness == Brightness.dark ? 0.32 : 0.7,
    );
    final buttonPadding = const EdgeInsets.symmetric(vertical: 10);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withOpacity(brightness == Brightness.dark ? 0.35 : 0.75),
            baseSurface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.18)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.checkroom_outlined,
                color: colorScheme.onPrimaryContainer,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Гардероб',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      totalCount > 0
                          ? 'Всего вещей: $totalCount'
                          : 'Добавьте первую вещь в гардероб',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimaryContainer.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _openHistory,
                icon: const Icon(Icons.history),
                tooltip: 'История нарядов',
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.onPrimaryContainer,
                  backgroundColor: colorScheme.onPrimaryContainer.withOpacity(0.12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int?>(
            value: selectedLocationId,
            decoration: InputDecoration(
              labelText: 'Локация гардероба',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              filled: true,
              fillColor: colorScheme.surface.withOpacity(brightness == Brightness.dark ? 0.33 : 0.92),
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
          if (isLocationsLoading) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: navigateToAddClothes,
                  style: FilledButton.styleFrom(padding: buttonPadding),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить вещь'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _openFilterSheet,
                  style: FilledButton.styleFrom(padding: buttonPadding),
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

  Widget _buildWardrobeSkeleton() {
    return SafeArea(
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        itemBuilder: (_, __) => const ListTileSkeleton(),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemCount: 6,
      ),
    );
  }

  Widget _buildClothesCard(Clothes item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final brightness = theme.brightness;
    final category = item.category.trim();
    final season = item.season.trim();

    final chips = <Widget>[
      if (category.isNotEmpty)
        _buildMetadataChip(Icons.category_outlined, category),
      if (season.isNotEmpty)
        _buildMetadataChip(Icons.style_outlined, season),
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
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: colorScheme.surfaceVariant.withOpacity(0.25),
                    child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                        ? ImageCacheService.cached(
                            item.imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: const ShimmerSkeleton(
                              height: double.infinity,
                              width: double.infinity,
                              borderRadius: 0,
                            ),
                            errorWidget: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: colorScheme.onSurfaceVariant,
                                size: 40,
                              ),
                            ),
                          borderRadius: 0,
                        )
                        : Center(
                            child: Icon(
                              Icons.image_outlined,
                              size: 42,
                              color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                            ),
                          ),
                  ),
                  if (item.isPending)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule, size: 16, color: colorScheme.onErrorContainer),
                            const SizedBox(width: 6),
                            Text(
                              'PENDING',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onErrorContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: chips,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(
          theme.brightness == Brightness.dark ? 0.45 : 0.75,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSecondaryContainer),
          const SizedBox(width: 5),
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
      body: FutureBuilder<void>(
        future: _initializationFuture,
        builder: (context, snapshot) {
          final isStartupLoading = snapshot.connectionState != ConnectionState.done;

          if (isStartupLoading && clothes.isEmpty) {
            return _buildWardrobeSkeleton();
          }

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final targetWidth = math.min(constraints.maxWidth, 980.0);
                final horizontalPadding =
                    math.max(20.0, (constraints.maxWidth - targetWidth) / 2);

                return RefreshIndicator(
                  onRefresh: fetchClothes,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding:
                            EdgeInsets.fromLTRB(horizontalPadding, 24, horizontalPadding, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildWardrobeHeader(context, locationDropdownItems, filtersAreActive),
                              const SizedBox(height: 12),
                              _buildStatusBanner(),
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
                              childAspectRatio: 0.65,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
