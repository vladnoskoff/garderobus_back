import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/clothes.dart';

class ClothesDetailScreen extends StatefulWidget {
  final Clothes clothes;

  const ClothesDetailScreen({Key? key, required this.clothes}) : super(key: key);

  @override
  State<ClothesDetailScreen> createState() => _ClothesDetailScreenState();
}

class _ClothesDetailScreenState extends State<ClothesDetailScreen> {
  late Clothes _clothes;
  late final PageController _pageController;
  int _currentPage = 0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _clothes = widget.clothes;
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить вещь?'),
        content: const Text('Вы действительно хотите удалить эту вещь из гардероба?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        await ApiService.deleteClothes(_clothes.id);
        if (!mounted) return;
        Navigator.pop(context, true);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить вещь: $e')),
        );
      }
    }
  }

  Future<void> _editDetails() async {
    final descriptionController = TextEditingController(text: _clothes.promptDescription ?? '');
    final careController = TextEditingController(text: _clothes.careInstructions ?? '');
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Редактирование информации'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    hintText: 'Добавьте заметки или описание вещи',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: careController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Рекомендации по уходу',
                    hintText: 'Например, стирка при 30°C',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop({
                  'description': descriptionController.text.trim(),
                  'care': careController.text.trim(),
                });
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    descriptionController.dispose();
    careController.dispose();

    if (result == null) {
      return;
    }

    final newDescription = result['description'] ?? '';
    final newCare = result['care'] ?? '';
    final currentDescription = _clothes.promptDescription?.trim() ?? '';
    final currentCare = _clothes.careInstructions?.trim() ?? '';

    if (newDescription == currentDescription && newCare == currentCare) {
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final updated = await ApiService.updateClothes(
        clothesId: _clothes.id,
        promptDescription: newDescription,
        careInstructions: newCare,
      );
      if (!mounted) return;
      setState(() {
        _clothes = updated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Информация обновлена')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить данные: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildGallery(ColorScheme colorScheme) {
    final gallery = _clothes.imageGallery;
    if (gallery.isEmpty) {
      return Container(
        height: 320,
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported,
          size: 56,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return SizedBox(
      height: 360,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: gallery.length,
              itemBuilder: (context, index) {
                final url = gallery[index];
                return Container(
                  color: colorScheme.surfaceVariant,
                  alignment: Alignment.center,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    alignment: Alignment.center,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.broken_image_outlined,
                      size: 56,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          ),
          if (gallery.length > 1)
            Positioned(
              bottom: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(gallery.length, (index) {
                  final bool isActive = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isActive ? 16 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final careText = _clothes.careInstructions?.trim();
    final description = _clothes.promptDescription?.trim();
    final material = _clothes.material?.trim();
    final temperatureMin = _clothes.temperatureMin;
    final temperatureMax = _clothes.temperatureMax;
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

    final created = _clothes.createdAt.toLocal();
    final createdText =
        '${created.day.toString().padLeft(2, '0')}.${created.month.toString().padLeft(2, '0')}.${created.year} '
        '${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Гардеробус'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _isProcessing ? null : _editDetails,
            tooltip: 'Редактировать',
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _isProcessing ? null : _confirmDelete,
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildGallery(colorScheme),
              const SizedBox(height: 16),
              Text(
                _clothes.name,
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _InfoChip(icon: Icons.checkroom, label: _clothes.category),
                  _InfoChip(icon: Icons.calendar_month_outlined, label: _clothes.season),
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
                'Цвет: ${_clothes.color}',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Добавлено: $createdText',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          if (_isProcessing)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
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
