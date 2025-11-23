import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/clothes.dart';
import '../../services/image_cache_service.dart';
import '../../widgets/skeletons.dart';

Future<bool?> showClothesDetailSheet(BuildContext context, Clothes clothes) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _ClothesDetailSheet(clothes: clothes),
  );
}

class _ClothesDetailSheet extends StatefulWidget {
  const _ClothesDetailSheet({required this.clothes});

  final Clothes clothes;

  @override
  State<_ClothesDetailSheet> createState() => _ClothesDetailSheetState();
}

class _ClothesDetailSheetState extends State<_ClothesDetailSheet> {
  late Clothes _clothes;
  late final PageController _pageController;
  final ScrollController _scrollController = ScrollController();
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
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    if (_isProcessing) return;

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
        Navigator.of(context).pop(true);
      } catch (error) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить вещь: $error')),
        );
      }
    }
  }

  Future<void> _editDetails() async {
    final descriptionController =
        TextEditingController(text: _clothes.promptDescription?.trim() ?? '');
    final careController = TextEditingController(text: _clothes.careInstructions?.trim() ?? '');

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

    if (result == null) return;

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
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Информация обновлена')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось обновить данные: $error')),
      );
    }
  }

  Widget _buildGallery(ColorScheme colorScheme) {
    final gallery = _clothes.imageGallery;
    if (gallery.isEmpty) {
      return Container(
        height: 260,
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported,
          size: 52,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: gallery.length,
              itemBuilder: (context, index) {
                final url = gallery[index];
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.6),
                  ),
                  child: ImageCacheService.cached(
                    url,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    placeholder: const ShimmerSkeleton(
                      height: double.infinity,
                      width: double.infinity,
                      borderRadius: 0,
                    ),
                    errorWidget: Icon(
                      Icons.broken_image_outlined,
                      size: 56,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    borderRadius: 0,
                  ),
                );
              },
            ),
          ),
          if (gallery.length > 1)
            Positioned(
              bottom: 14,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(gallery.length, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 16 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: isActive
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: highlight
            ? LinearGradient(
                colors: [
                  colorScheme.primary.withOpacity(0.18),
                  colorScheme.secondaryContainer.withOpacity(0.22),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: highlight ? null : colorScheme.surfaceVariant.withOpacity(0.6),
        border: Border.all(
          color: colorScheme.outlineVariant.withOpacity(0.25),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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

    return FractionallySizedBox(
      heightFactor: 0.94,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.surface,
                    colorScheme.surfaceVariant.withOpacity(0.45),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Container(
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _clothes.name,
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Редактировать',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: _isProcessing ? null : _editDetails,
                          ),
                          IconButton(
                            tooltip: 'Удалить',
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                            onPressed: _isProcessing ? null : _confirmDelete,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                          color: colorScheme.surface,
                        ),
                        child: CustomScrollView(
                          controller: _scrollController,
                          slivers: [
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                              sliver: SliverToBoxAdapter(
                                child: _buildGallery(colorScheme),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                              sliver: SliverToBoxAdapter(
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    _buildInfoChip(
                                      icon: Icons.checkroom_outlined,
                                      label: _clothes.category,
                                      highlight: true,
                                    ),
                                    _buildInfoChip(
                                      icon: Icons.calendar_month_outlined,
                                      label: _clothes.season,
                                    ),
                                    if (temperatureRange != null)
                                      _buildInfoChip(
                                        icon: Icons.device_thermostat,
                                        label: temperatureRange,
                                      ),
                                    if (material != null && material.isNotEmpty)
                                      _buildInfoChip(
                                        icon: Icons.texture,
                                        label: material,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (description != null && description.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                                sliver: SliverToBoxAdapter(
                                  child: _DetailSection(
                                    title: 'Описание',
                                    body: description,
                                  ),
                                ),
                              ),
                            if (careText != null && careText.isNotEmpty)
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                                sliver: SliverToBoxAdapter(
                                  child: _DetailSection(
                                    title: 'Рекомендации по уходу',
                                    body: careText,
                                  ),
                                ),
                              ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                              sliver: SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _DetailRow(
                                      icon: Icons.palette_outlined,
                                      label: 'Цвет',
                                      value: _clothes.color,
                                    ),
                                    const SizedBox(height: 12),
                                    _DetailRow(
                                      icon: Icons.schedule_outlined,
                                      label: 'Добавлено',
                                      value: createdText,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isProcessing)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.secondaryContainer.withOpacity(0.24),
            colorScheme.surfaceVariant.withOpacity(0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.surfaceVariant.withOpacity(0.35),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
