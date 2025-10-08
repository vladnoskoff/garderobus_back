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
        title: Text('Гардеробус'),
        actions: [
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: clothes.imageUrl != null && clothes.imageUrl!.isNotEmpty
                ? Image.network(
                    clothes.imageUrl!,
                    fit: BoxFit.cover,
                    height: 320,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 320,
                      color: const Color(0xFFE0E0E0),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: Colors.black45,
                      ),
                    ),
                  )
                : Container(
                    height: 320,
                    color: const Color(0xFFE0E0E0),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 48,
                      color: Colors.black45,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          Text(
            clothes.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
            const Text(
              'Описание',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 15),
            ),
          ],
          if (careText != null && careText.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Рекомендации по уходу',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              careText,
              style: const TextStyle(fontSize: 15),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Цвет: ${clothes.color}',
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            'Добавлено: $createdText',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Colors.black87),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
 