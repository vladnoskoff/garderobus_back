import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/api_service.dart';
import '../services/clothes.dart';
import '../widgets/rounded_back_button.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pressureValue = weather?["pressure"];
    final pressureMm = pressureValue is num ? (pressureValue * 0.75006).round() : null;
    final isWeatherLoading = weather == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Гардероб 26'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: Alignment.topCenter,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLocationSection(context),
                    const SizedBox(height: 20),
                    _buildWeatherSection(
                      context,
                      isLoading: isWeatherLoading,
                      pressureMm: pressureMm,
                    ),
                    if (((weather?['forecast']) as List<dynamic>?)?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 20),
                      _buildForecastSection(context),
                    ],
                    const SizedBox(height: 20),
                    _buildMannequinSection(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLocationSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final locationItems = <DropdownMenuItem<int?>>[
      const DropdownMenuItem<int?>(
        value: null,
        child: Text('Использовать личные координаты'),
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
          child: Text('$name$subtitle'),
        );
      }).whereType<DropdownMenuItem<int?>>(),
    ];

    return _buildHomeCard(
      context,
      accentColor: colorScheme.primary,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardIcon(colorScheme.primary, Icons.home_work_outlined),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Дом и места',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Выберите гардероб для погоды и рекомендаций.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HomeScreenSettings(),
                  ),
                );
              },
              icon: const Icon(Icons.tune),
              label: const Text('Управлять'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (isLocationsLoading)
          const LinearProgressIndicator()
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(18),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: selectedLocationId,
                isExpanded: true,
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colorScheme.primary,
                ),
                style: theme.textTheme.titleMedium,
                borderRadius: BorderRadius.circular(18),
                items: locationItems,
                onChanged: (value) => _handleLocationChange(value),
              ),
            ),
          ),
        if (!isLocationsLoading && wardrobeLocations.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Добавьте адрес в настройках, чтобы выбрать конкретный гардероб.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
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

    final humidity = weather?['humidity'];
    final wind = (weather?['wind_speed'] as num?)?.toDouble();
    final temperature = weather?['temperature'];

    return _buildHomeCard(
      context,
      accentColor: colorScheme.primary,
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
          ],
        ),
        const SizedBox(height: 20),
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
                          temperature != null ? '$temperature°C' : '—',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
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
                          ? Image.network(
                              weatherIconUrl!,
                              width: 72,
                              height: 72,
                              errorBuilder: (_, __, ___) => Icon(
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
                const SizedBox(height: 20),
                Text(
                  weatherComment!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildForecastSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final forecastDays = (weather?['forecast'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((day) => day.map((key, value) => MapEntry(key.toString(), value)))
        .toList(growable: false);

    return _buildHomeCard(
      context,
      accentColor: colorScheme.secondary,
      children: [
        Row(
          children: [
            _buildCardIcon(colorScheme.secondary, Icons.calendar_month_outlined),
            const SizedBox(width: 16),
            Text(
              'Прогноз на 3 дня',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          children: forecastDays
              .map((day) => _buildForecastTile(context, day))
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildForecastTile(BuildContext context, Map<String, dynamic> day) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final date = day['date']?.toString() ?? '';
    final temp = day['temp'];
    final iconCode = day['icon']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              date,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            temp != null ? '$temp°C' : '—',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          if (iconCode != null && iconCode.isNotEmpty)
            Image.network(
              'http://openweathermap.org/img/wn/$iconCode@2x.png',
              width: 40,
              height: 40,
              errorBuilder: (_, __, ___) => Icon(
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
          const Center(child: CircularProgressIndicator())
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

  Widget _buildHomeCard(
    BuildContext context, {
    required Color accentColor,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            baseColor.withOpacity(0.75),
            baseColor,
            accentColor.withOpacity(0.22),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
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
