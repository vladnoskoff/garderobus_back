import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/clothes.dart';

class ClothesDetailScreen extends StatelessWidget {
  final Clothes clothes;

  const ClothesDetailScreen({Key? key, required this.clothes}) : super(key: key);

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить вещь?'),
        content: Text('Вы действительно хотите удалить эту вещь из гардероба?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ApiService.deleteClothes(clothes.id);
      Navigator.pop(context, true); // Возвращаем значение true, чтобы обновить список
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final careText = clothes.careInstructions?.trim();
    final description = clothes.promptDescription?.trim();
    final material = clothes.material?.trim();
    final temperatureMin = clothes.temperatureMin;
    final temperatureMax = clothes.temperatureMax;
    String? temperatureRange;
    if (temperatureMin != null || temperatureMax != null) {
      if (temperatureMin != null && temperatureMax != null) {
        temperatureRange = temperatureMin == temperatureMax
            ? '$temperatureMin°C'
            : '$temperatureMin–$temperatureMax°C';
      } else {
        final value = temperatureMin ?? temperatureMax;
        temperatureRange = value != null ? '$value°C' : null;
      }
    }
    final created = clothes.createdAt.toLocal();
    final createdText =
        '${created.day.toString().padLeft(2, '0')}.${created.month.toString().padLeft(2, '0')}.${created.year} '
        '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Гардеробус'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: colorScheme.surfaceVariant,
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: clothes.imageUrl != null && clothes.imageUrl!.isNotEmpty
                  ? Image.network(
                      clothes.imageUrl!,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: colorScheme.surfaceVariant,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Container(
                      color: colorScheme.surfaceVariant,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            clothes.name,
            style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InfoChip(icon: Icons.checkroom, label: clothes.category),
              _InfoChip(icon: Icons.calendar_month_outlined, label: clothes.season),
              if (temperatureRange != null)
                _InfoChip(icon: Icons.device_thermostat, label: temperatureRange),
              if (material != null && material.isNotEmpty)
                _InfoChip(icon: Icons.texture, label: material),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Описание',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: textTheme.bodyMedium,
            ),
          ],
          if (careText != null && careText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Рекомендации по уходу',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              careText,
              style: textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Цвет: ${clothes.color}',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Добавлено: $createdText',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
 