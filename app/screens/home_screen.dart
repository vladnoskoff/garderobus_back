import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/api_service.dart';
import '../services/clothes.dart';
import '../services/image_cache_service.dart';
import '../services/network_service.dart';
import '../services/startup_service.dart';
import '../services/sync_service.dart';
import '../widgets/rounded_back_button.dart';
import '../widgets/skeletons.dart';
import '../l10n/l10n_extensions.dart';
import 'garderob/clothes_detail_screen.dart';
import 'settings/home_settings/home_screen_settings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _MannequinItemChip extends StatelessWidget {
  const _MannequinItemChip({
    required this.name,
    this.category,
    this.onTap,
  });

  final String name;
  final String? category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (category != null && category!.isNotEmpty)
              Text(
                category!,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: colorScheme.onSecondaryContainer.withOpacity(0.7),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MannequinRefreshButton extends StatelessWidget {
  const _MannequinRefreshButton({
    required this.onPressed,
    required this.isLoading,
    this.foregroundColor,
    this.backgroundColor,
  });

  final VoidCallback onPressed;
  final bool isLoading;
  final Color? foregroundColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedForeground = foregroundColor ?? colorScheme.onSecondaryContainer;
    final resolvedBackground =
        backgroundColor ?? resolvedForeground.withOpacity(0.1);
    final refreshLabel = context.l10n.homeRefreshMannequin;

    return Semantics(
      button: true,
      enabled: !isLoading,
      label: refreshLabel,
      child: Tooltip(
        message: refreshLabel,
        child: Material(
          color: resolvedBackground,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isLoading ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: isLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(resolvedForeground),
                      ),
                    )
                  : Icon(
                      Icons.autorenew,
                      color: resolvedForeground,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MannequinImageViewer extends StatelessWidget {
  const _MannequinImageViewer({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        leading: const RoundedBackButton(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          context.l10n.getString('home_mannequin_preview'),
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Hero(
            tag: imageUrl,
            child: ImageCacheService.cached(
              imageUrl,
              fit: BoxFit.contain,
              borderRadius: 0,
              placeholder: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeScreenState extends State<HomeScreen> {
  AppLocalizations get l10n => context.l10n;
  Map<String, dynamic>? weather;
  List<Map<String, dynamic>> mannequins = [];
  String? weatherComment;
  String? weatherIconUrl;
  final storage = const FlutterSecureStorage();
  int? userId;
  List<dynamic> wardrobeLocations = [];
  int? selectedLocationId;
  bool isLocationsLoading = false;
  bool isMannequinsLoading = false;
  double mannequinProgress = 0;
  String mannequinStatusKey = 'home_outfit_preparing';
  String get mannequinStatusText => l10n.getString(mannequinStatusKey);
  String? mannequinsError;
  Timer? _weatherTimer;
  late Future<void> _initialLoadFuture;

  @override
  void initState() {
    super.initState();
    _initialLoadFuture = _initializeHome();

    _weatherTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        fetchWeather();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeHome() async {
    await _loadUserId();
    if (userId == null) return;

    setState(() {
      isLocationsLoading = true;
      isMannequinsLoading = true;
    });

    try {
      await checkInitialSettings();
      final preferredLocationId = await _readStoredLocationId();
      final startup = await StartupService.loadHomeStartup(
        userId: userId!,
        preferredLocationId: preferredLocationId,
      );

      if (!mounted) return;
      setState(() {
        wardrobeLocations = startup.locations;
        selectedLocationId = startup.selectedLocationId;
        weather = startup.weather;
        weatherIconUrl = startup.weather != null
            ? "https://openweathermap.org/img/wn/${startup.weather!['icon']}@2x.png"
            : null;
        weatherComment = startup.weather != null
            ? generateWeatherComment(startup.weather!)
            : null;
        mannequins = startup.mannequins;
      });
      await _persistSelectedLocation(startup.selectedLocationId);
    } catch (e) {
      debugPrint('Ошибка инициализации: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLocationsLoading = false;
          isMannequinsLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserId() async {
    final idString = await storage.read(key: 'user_id');
    if (idString != null) {
      setState(() {
        userId = int.tryParse(idString);
      });
    }
  }

  Future<int?> _readStoredLocationId() async {
    final storedLocationIdString = await storage.read(key: 'selected_location_id');
    return storedLocationIdString != null ? int.tryParse(storedLocationIdString) : null;
  }

  Future<void> _loadLocations() async {
    if (userId == null) return;
    setState(() => isLocationsLoading = true);
    try {
      final cachedLocations = await StartupService.getCachedLocations(userId!);
      if (cachedLocations.isNotEmpty && mounted) {
        setState(() {
          wardrobeLocations = cachedLocations;
          selectedLocationId ??= _deriveDefaultLocation(cachedLocations);
        });
      }

      final locations = await ApiService.getWardrobeLocations(userId!);
      await StartupService.cacheLocations(userId!, locations);
      final storedLocationId = await _readStoredLocationId();
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
      await _refreshDashboardBatch(preferredLocationId: resolvedLocationId);
    } catch (e) {
      debugPrint('Ошибка загрузки локаций: $e');
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
    await _refreshDashboardBatch(preferredLocationId: value);
  }

  Future<void> _refreshDashboardBatch({int? preferredLocationId}) async {
    if (userId == null) return;
    setState(() {
      isMannequinsLoading = true;
      mannequinsError = null;
    });
    try {
      final bundle = await StartupService.loadDashboardData(
        userId: userId!,
        locationId: preferredLocationId ?? _locationIdForRequests(),
        knownLocations: wardrobeLocations,
      );

      if (!mounted) return;
      setState(() {
        wardrobeLocations = bundle.locations;
        selectedLocationId = bundle.selectedLocationId ?? preferredLocationId;
        weather = bundle.weather;
        weatherIconUrl = bundle.weather != null
            ? "https://openweathermap.org/img/wn/${bundle.weather!['icon']}@2x.png"
            : null;
        weatherComment = bundle.weather != null
            ? generateWeatherComment(bundle.weather!)
            : null;
        mannequins = bundle.mannequins;
      });
      await _persistSelectedLocation(selectedLocationId);
    } catch (e) {
      debugPrint('Ошибка пакетного обновления: $e');
      if (mounted) {
        setState(() {
          mannequinsError = l10n.getString('home_mannequins_update_failed');
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

  int? _locationIdForRequests() {
    if (selectedLocationId == null) {
      return null;
    }
    final selectedLocation = _findLocationById(selectedLocationId);
    if (selectedLocation == null) {
      return null;
    }
    if (selectedLocation['latitude'] == null || selectedLocation['longitude'] == null) {
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
      final location = user['location'];
      final hasLocation = location != null && location.toString().trim().isNotEmpty;

      if (!hasLocation) {
        await ApiService.updateLocation(userId!, ApiService.defaultHomeCoordinates);
      }
    } catch (e) {
      debugPrint('Ошибка проверки настроек: $e');
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
      debugPrint('Ошибка при получении погоды: $e');
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
      debugPrint('Ошибка при получении манекенов: $e');
      if (mounted) {
        setState(() {
          mannequins = [];
          mannequinsError =
              l10n.getString('home_mannequin_history_load_failed');
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
        mannequinProgress = 0.05;
        mannequinStatusKey = 'home_mannequin_generation_starting';
      });

      final locationIdForRequest = _locationIdForRequests();
      final mannequin = await ApiService.generateMannequin(
        userId!,
        locationId: locationIdForRequest,
        onProgress: (progress, status) {
          if (!mounted) return;
          setState(() {
            mannequinProgress = progress;
            mannequinStatusKey = _resolveMannequinStatusKey(status);
          });
        },
      );

      if (!mounted) return;
      setState(() {
        mannequins = [mannequin];
        mannequinProgress = 1;
        mannequinStatusKey = 'home_outfit_ready';
      });
    } catch (e) {
      debugPrint('Ошибка при генерации манекена: $e');
      if (!mounted) return;
      setState(() {
        mannequinsError = l10n.getString('home_mannequin_create_failed');
        mannequinStatusKey = 'home_mannequin_error_label';
        mannequinProgress = 0;
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
      return l10n.getString('home_recommendation_default');
    }

    String recommendation;
    if (temp < -10) {
      recommendation = l10n.getString('home_recommendation_extreme_cold');
    } else if (temp < 0) {
      recommendation = l10n.getString('home_recommendation_very_cold');
    } else if (temp < 10) {
      recommendation = l10n.getString('home_recommendation_cool');
    } else if (temp < 18) {
      recommendation = l10n.getString('home_recommendation_light_cool');
    } else if (temp < 25) {
      recommendation = l10n.getString('home_recommendation_comfortable');
    } else {
      recommendation = l10n.getString('home_recommendation_hot');
    }

    if (condition.contains('дожд') || condition.contains('rain')) {
      recommendation += ' ${l10n.getString('home_recommendation_rain_add')}';
    } else if (condition.contains('снег') || condition.contains('snow')) {
      recommendation += ' ${l10n.getString('home_recommendation_snow_add')}';
    }

    if (wind >= 8) {
      recommendation += ' ${l10n.getString('home_recommendation_wind_add')}';
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
      margin: const EdgeInsets.symmetric(vertical: 4),
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
          AspectRatio(
            aspectRatio: 3 / 4,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Material(
                color: colorScheme.surfaceVariant,
                child: InkWell(
                  onTap: imageUrl != null && imageUrl.isNotEmpty
                      ? () => _openMannequinImage(context, imageUrl)
                      : null,
                    child: Center(
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Hero(
                              tag: imageUrl,
                              child: ImageCacheService.cached(
                                imageUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                placeholder: const ShimmerSkeleton(
                                  height: double.infinity,
                                  width: double.infinity,
                                  borderRadius: 0,
                                ),
                                errorWidget: Icon(
                                  Icons.broken_image_outlined,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 40,
                                ),
                                borderRadius: 0,
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Манекен',
                  style: theme.textTheme.titleMedium,
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: items.take(4).map((item) {
                      final name = item['name']?.toString() ?? 'Вещь';
                      final category = item['category']?.toString();
                      return _MannequinItemChip(
                        name: name,
                        category: category,
                        onTap: () => _handleMannequinItemTap(context, item),
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

  Future<void> _handleMannequinItemTap(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final rawId = item['id'];
    final clothesId = rawId is int
        ? rawId
        : rawId is String
            ? int.tryParse(rawId)
            : int.tryParse(rawId?.toString() ?? '');

    if (clothesId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось определить вещь для просмотра.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final Clothes clothes = await ApiService.getClothesById(clothesId);
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      await showClothesDetailSheet(context, clothes);
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось открыть вещь: $error')),
      );
    }
  }

  void _openMannequinImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _MannequinImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  Widget _buildStatusBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<bool>(
      valueListenable: NetworkService.isOnline,
      builder: (context, isOnline, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: SyncService.instance.isSyncing,
          builder: (context, isSyncing, __) {
            if (isOnline && !isSyncing) {
              return const SizedBox.shrink();
            }

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
                  Icon(
                    isOnline ? Icons.sync : Icons.wifi_off,
                    color: foreground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isOnline
                          ? 'Идет синхронизация локальных данных'
                          : 'Вы офлайн — изменения будут отправлены при появлении связи',
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

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    // Fix text rendering on the home screen by disabling oversized dynamic text
    // scaling that caused words to wrap vertically on some devices.
    final clampedTextScaler = const TextScaler.linear(1.0);


    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: clampedTextScaler),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Гардероб 26'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Настройки',
              onPressed: () {
                showHomeSettingsSheet(context);
              },
            ),
          ],
        ),
        body: FutureBuilder<void>(
          future: _initialLoadFuture,
          builder: (context, snapshot) {
            final isStartupLoading = snapshot.connectionState != ConnectionState.done;
            final pressureValue = weather?["pressure"];
            final pressureMm =
                pressureValue is num ? (pressureValue * 0.75006).round() : null;
            final isWeatherLoading = isStartupLoading || weather == null;

            return LayoutBuilder(
              builder: (context, constraints) {
                if (isStartupLoading && mannequins.isEmpty && wardrobeLocations.isEmpty) {
                  return _buildHomeSkeleton(context);
                }

                return Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildStatusBanner(context),
                          const SizedBox(height: 12),
                          _buildLocationSection(context),
                          const SizedBox(height: 20),
                          _buildWeatherSection(
                            context,
                            isLoading: isWeatherLoading,
                            pressureMm: pressureMm,
                          ),
                          const SizedBox(height: 20),
                          _buildMannequinSection(context),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final locationItems = <DropdownMenuItem<int?>>[
      DropdownMenuItem<int?>(
        value: null,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Text('Использовать личные координаты'),
        ),
      ),
      ...wardrobeLocations.whereType<Map<String, dynamic>>().map((map) {
        final name = map['name']?.toString() ?? 'Без названия';
        final hasCoords = map['latitude'] != null && map['longitude'] != null;
        final subtitle = hasCoords ? '' : ' (нет координат)';
        final parsedId = _parseLocationId(map['id']);
        if (parsedId == null) {
          return null;
        }
        return DropdownMenuItem<int?>(
          value: parsedId,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('$name$subtitle'),
          ),
        );
      }).whereType<DropdownMenuItem<int?>>(),
    ];

    return _buildHomeCard(
      context,
      accentColor: colorScheme.primary,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 400;

            final description = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Дом и места',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Выберите гардероб для погоды и рекомендаций.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );

            final actionButton = FilledButton.tonalIcon(
              onPressed: () => showHomeSettingsSheet(context),
              icon: const Icon(Icons.tune),
              label: const Text('Управлять'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCardIcon(colorScheme.primary, Icons.home_work_outlined),
                      const SizedBox(width: 12),
                      Expanded(child: description),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: actionButton,
                  ),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildCardIcon(colorScheme.primary, Icons.home_work_outlined),
                const SizedBox(width: 16),
                Expanded(child: description),
                const SizedBox(width: 12),
                actionButton,
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (isLocationsLoading)
          const LinearProgressIndicator()
        else if (wardrobeLocations.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: selectedLocationId,
                  isExpanded: true,
                  alignment: AlignmentDirectional.centerStart,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.primary,
                  ),
                  style: theme.textTheme.titleSmall,
                  borderRadius: BorderRadius.circular(18),
                  items: locationItems,
                  onChanged: (value) => _handleLocationChange(value),
                ),
              ),
            ),
          )
        else
          _buildEmptyState(
            context,
            'Добавьте адрес в настройках, чтобы выбрать конкретный гардероб.',
          ),
      ],
    );
  }

  Widget _buildWeatherSection(
    BuildContext context, {
    required bool isLoading,
    required int? pressureMm,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final weatherData = weather;
    final humidity = weatherData?['humidity'];
    final wind = (weatherData?['wind_speed'] as num?)?.toDouble();
    final temperature = weatherData?['temperature'];
    final hasDetails = !isLoading && weatherData != null;

    return _buildHomeCard(
      context,
      accentColor: colorScheme.primary,
      onTap: hasDetails ? () => _showWeatherDetailsSheet(context, pressureMm) : null,
      children: [
        Row(
          children: [
            _buildCardIcon(colorScheme.primary, Icons.cloud_outlined),
            const SizedBox(width: 16),
            Text(
              'Погода сейчас',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (hasDetails)
              Icon(
                Icons.keyboard_arrow_up,
                color: colorScheme.primary,
              ),
          ],
        ),
        const SizedBox(height: 14),
        if (isLoading)
          const SizedBox(
            height: 140,
            child: Center(child: CircularProgressIndicator()),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          temperature != null ? '${_formatTemperature(temperature)}°C' : '—',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 20,
                          runSpacing: 12,
                          children: [
                            if (humidity != null)
                              _buildWeatherMetric(
                                context,
                                label: 'Влажность',
                                value: '$humidity%',
                              ),
                            if (pressureMm != null)
                              _buildWeatherMetric(
                                context,
                                label: 'Давление',
                                value: '$pressureMm мм рт. ст.',
                              ),
                            if (wind != null)
                              _buildWeatherMetric(
                                context,
                                label: 'Ветер',
                                value: '${wind.toStringAsFixed(1)} м/с',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        color: colorScheme.surface.withOpacity(0.6),
                        padding: const EdgeInsets.all(12),
                        child: weatherIconUrl != null && weatherIconUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: weatherIconUrl!,
                                width: 72,
                                height: 72,
                                placeholder: (_, __) => const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                errorWidget: (_, __, ___) => Icon(
                                  Icons.cloud,
                                  size: 48,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              )
                            : Icon(
                                Icons.cloud,
                                size: 48,
                                color: colorScheme.onSurfaceVariant,
                              ),
                      ),
                    ),
                ],
              ),
              if (weatherComment != null) ...[
                const SizedBox(height: 14),
                Text(
                  weatherComment!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (hasDetails) ...[
                const SizedBox(height: 12),
                Text(
                  'Нажмите, чтобы посмотреть подробный прогноз и погоду на неделю',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Future<void> _showWeatherDetailsSheet(BuildContext context, int? pressureMm) async {
    final weatherData = weather;
    if (weatherData == null) {
      return;
    }

    final humidity = weatherData['humidity'];
    final wind = (weatherData['wind_speed'] as num?)?.toDouble();
    final temperature = weatherData['temperature'];
    final feelsLike = weatherData['feels_like'];
    final description = weatherData['description']?.toString();
    final forecastDays = (weatherData['forecast'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((day) => day.map((key, value) => MapEntry(key.toString(), value)))
        .take(7)
        .toList(growable: false);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        final brightness = theme.brightness;
        final bottomPadding = MediaQuery.of(sheetContext).padding.bottom;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.92,
          minChildSize: 0.4,
          builder: (context, controller) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                gradient: LinearGradient(
                  colors: [
                    colorScheme.surfaceVariant.withOpacity(brightness == Brightness.dark ? 0.65 : 0.95),
                    colorScheme.surface.withOpacity(brightness == Brightness.dark ? 0.92 : 1),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.2)),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 12, 24, 20 + bottomPadding),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCardIcon(colorScheme.primary, Icons.cloud_outlined),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Прогноз погоды',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (description != null && description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  description,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close),
                          tooltip: 'Закрыть',
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Expanded(
                      child: ListView(
                        controller: controller,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      temperature != null
                                          ? '${_formatTemperature(temperature)}°C'
                                          : '—',
                                      style: theme.textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (feelsLike != null) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Ощущается как ${_formatTemperature(feelsLike)}°C',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
        if (weatherIconUrl != null && weatherIconUrl!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: CachedNetworkImage(
              imageUrl: weatherIconUrl!,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (_, __, ___) => Icon(
                Icons.cloud,
                size: 54,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
                                Icon(
                                  Icons.cloud,
                                  size: 54,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 20,
                            runSpacing: 12,
                            children: [
                              if (humidity != null)
                                _buildWeatherMetric(
                                  context,
                                  label: 'Влажность',
                                  value: '$humidity%',
                                ),
                              if (pressureMm != null)
                                _buildWeatherMetric(
                                  context,
                                  label: 'Давление',
                                  value: '$pressureMm мм рт. ст.',
                                ),
                              if (wind != null)
                                _buildWeatherMetric(
                                  context,
                                  label: 'Ветер',
                                  value: '${wind.toStringAsFixed(1)} м/с',
                                ),
                            ],
                          ),
                          if (weatherComment != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              weatherComment!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          if (forecastDays.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              'Прогноз на неделю',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...forecastDays.map((day) => _buildForecastTile(context, day)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildForecastTile(BuildContext context, Map<String, dynamic> day) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final date = day['date']?.toString() ?? '';
    final temp = day['temp'];
    final iconCode = day['icon']?.toString();
    final description = day['description']?.toString();
    final formattedTemp = temp != null ? '${_formatTemperature(temp)}°C' : '—';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date,
                  style: theme.textTheme.bodyMedium,
                ),
                if (description != null && description.isNotEmpty)
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            formattedTemp,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          if (iconCode != null && iconCode.isNotEmpty)
            CachedNetworkImage(
              imageUrl: 'http://openweathermap.org/img/wn/$iconCode@2x.png',
              width: 40,
              height: 40,
              placeholder: (_, __) => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (_, __, ___) => Icon(
                Icons.cloud,
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            Icon(
              Icons.cloud,
              color: colorScheme.onSurfaceVariant,
            ),
        ],
      ),
    );
  }

  Widget _buildMannequinSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = colorScheme.tertiary;

    return _buildHomeCard(
      context,
      accentColor: accent,
      children: [
        Row(
          children: [
            _buildCardIcon(accent, Icons.checkroom_outlined),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Образ дня',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _MannequinRefreshButton(
              onPressed: _generateMannequin,
              isLoading: isMannequinsLoading,
              foregroundColor: accent,
              backgroundColor: accent.withOpacity(0.14),
            ),
          ],
        ),
        if (weatherComment != null) ...[
          const SizedBox(height: 12),
          Text(
            weatherComment!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (isMannequinsLoading)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(
                value: mannequinProgress > 0 && mannequinProgress < 1
                    ? mannequinProgress
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                '${(mannequinProgress * 100).clamp(0, 100).round()}% — $mannequinStatusText',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          )
        else if (mannequins.isEmpty)
          _buildEmptyState(
            context,
            mannequinsError ??
                'Нажмите «Обновить», чтобы ИИ подобрал образ под вашу погоду и гардероб.',
          )
        else
          _buildMannequinCard(
            context,
            mannequins.first,
          ),
      ],
    );
  }

  Widget _buildWeatherMetric(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatTemperature(dynamic value) {
    if (value == null) {
      return '';
    }
    if (value is num) {
      final isWhole = value % 1 == 0;
      return isWhole ? value.toInt().toString() : value.toStringAsFixed(1);
    }
    final parsed = num.tryParse(value.toString());
    if (parsed != null) {
      final isWhole = parsed % 1 == 0;
      return isWhole ? parsed.toInt().toString() : parsed.toStringAsFixed(1);
    }
    return value.toString();
  }

  String _resolveMannequinStatusKey(String status) {
    switch (status) {
      case 'started':
        return 'home_outfit_collecting_items';
      case 'pending':
      case 'queued':
        return 'home_outfit_queued';
      case 'progress':
        return 'home_outfit_rendering';
      case 'success':
        return 'home_outfit_ready';
      case 'failure':
        return 'home_outfit_error';
      default:
        return 'home_outfit_preparing';
    }
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: colorScheme.surface.withOpacity(0.75),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildHomeSkeleton(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              HomeCardSkeleton(lines: 2, hasMedia: false),
              SizedBox(height: 20),
              HomeCardSkeleton(lines: 3),
              SizedBox(height: 20),
              HomeCardSkeleton(lines: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeCard(
    BuildContext context, {
    required Color accentColor,
    required List<Widget> children,
    VoidCallback? onTap,
    EdgeInsetsGeometry? padding,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceVariant;
    final borderRadius = BorderRadius.circular(26);
    final resolvedPadding = padding ?? const EdgeInsets.symmetric(horizontal: 18, vertical: 18);

    final decoration = BoxDecoration(
      borderRadius: borderRadius,
      gradient: LinearGradient(
        colors: [
          baseColor.withOpacity(0.7),
          baseColor,
          accentColor.withOpacity(0.18),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );

    final content = Padding(
      padding: resolvedPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: Ink(
          decoration: decoration,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: onTap,
            child: content,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: decoration,
      child: content,
    );
  }

  Widget _buildCardIcon(Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        icon,
        color: color,
        size: 24,
      ),
    );
  }
}
