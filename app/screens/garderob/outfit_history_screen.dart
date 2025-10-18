import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/api_service.dart';

class OutfitHistoryScreen extends StatefulWidget {
  final int? locationId;

  const OutfitHistoryScreen({super.key, this.locationId});

  @override
  State<OutfitHistoryScreen> createState() => _OutfitHistoryScreenState();
}

class _OutfitHistoryScreenState extends State<OutfitHistoryScreen> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userIdString = await _storage.read(key: 'user_id');
      if (userIdString == null) {
        setState(() {
          _error = 'Пользователь не найден';
          _isLoading = false;
        });
        return;
      }

      final userId = int.tryParse(userIdString);
      if (userId == null) {
        setState(() {
          _error = 'Некорректный идентификатор пользователя';
          _isLoading = false;
        });
        return;
      }

      final outfitHistory = await ApiService.getOutfitHistory(
        userId,
        locationId: widget.locationId,
      );

      final mannequinHistory = await ApiService.getMannequinHistory(
        userId,
        locationId: widget.locationId,
        limit: 20,
      );

      final combined = <Map<String, dynamic>>[];

      void addEntry(String type, Map<String, dynamic> data) {
        final normalized = data.map(
          (key, value) => MapEntry(key.toString(), value),
        );
        combined.add({
          'entryType': type,
          'data': Map<String, dynamic>.from(normalized),
          'createdAt': _parseDateTime(
            normalized['created_at'] ??
                normalized['createdAt'] ??
                normalized['date'],
          ),
        });
      }

      for (final outfit in outfitHistory) {
        addEntry('outfit', outfit);
      }

      for (final mannequin in mannequinHistory) {
        addEntry('mannequin', mannequin);
      }

      combined.sort((a, b) {
        final dateA = a['createdAt'] as DateTime?;
        final dateB = b['createdAt'] as DateTime?;
        if (dateA == null && dateB == null) {
          return 0;
        }
        if (dateA == null) {
          return 1;
        }
        if (dateB == null) {
          return -1;
        }
        return dateB.compareTo(dateA);
      });

      if (!mounted) return;
      setState(() {
        _history = combined;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Не удалось загрузить историю: $e';
      });
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Неизвестная дата';
    if (value is DateTime) {
      return '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed != null) {
      return '${parsed.day.toString().padLeft(2, '0')}.${parsed.month.toString().padLeft(2, '0')}.${parsed.year}';
    }
    return value.toString();
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed;
    }
    if (value is int) {
      try {
        if (value > 1000000000000) {
          return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
        }
        return DateTime.fromMillisecondsSinceEpoch(value * 1000).toLocal();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return const Center(
        child: Text(
          'История рекомендаций пуста. Создайте новый наряд или сгенерируйте манекен, чтобы увидеть его здесь.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final entry = _history[index];
          final entryType = entry['entryType'] as String? ?? 'outfit';
          final rawData = entry['data'] is Map
              ? Map<String, dynamic>.from(
                  (entry['data'] as Map).map(
                    (key, value) => MapEntry(key.toString(), value),
                  ),
                )
              : <String, dynamic>{};
          final createdAtValue = entry['createdAt'] ??
              rawData['created_at'] ??
              rawData['createdAt'] ??
              rawData['date'];
          final createdAtText = _formatDate(createdAtValue);
          final imageUrl = rawData['image_url'] ?? rawData['imageUrl'];
          final weather = (rawData['weather'] is Map)
              ? Map<String, dynamic>.from(rawData['weather'] as Map)
              : null;
          final locationName = rawData['location_name'] ?? rawData['locationName'];
          String? locationDisplay = locationName?.toString();
          if (locationDisplay == null && entryType == 'mannequin') {
            final locationId = rawData['location_id'] ?? rawData['locationId'];
            if (locationId != null) {
              locationDisplay = 'Локация #$locationId';
            }
          }
          final items = <Map<String, dynamic>>[];
          if (rawData['items'] is List) {
            for (final element in rawData['items'] as List) {
              if (element is Map) {
                items.add(
                  Map<String, dynamic>.from(
                    element.map((key, value) => MapEntry(key.toString(), value)),
                  ),
                );
              }
            }
          }
          final description = _resolveDescription(entryType, rawData, items);
          final title = _resolveTitle(
            entryType,
            rawData,
            index,
            createdAtText,
          );
          final rating = entryType == 'outfit' ? rawData['rating'] : null;

          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title.toString(),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        createdAtText,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildEntryBadge(entryType),
                  const SizedBox(height: 12),
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl.toString(),
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          height: 180,
                          color: Colors.black12,
                          alignment: Alignment.center,
                          child: const Text('Не удалось загрузить изображение'),
                        ),
                      ),
                    ),
                  if (imageUrl != null) const SizedBox(height: 12),
                  Text(
                    description.toString(),
                    style: const TextStyle(fontSize: 14),
                  ),
                  if (weather != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.wb_sunny, size: 18, color: Colors.orangeAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${weather['temperature']}°C — ${weather['condition']}',
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (locationDisplay != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 18, color: Colors.teal),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            locationDisplay,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (rating != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(rating.toString()),
                      ],
                    ),
                  ],
                  if (items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Состав наряда',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: items.map(_buildClothingChip).toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemCount: _history.length,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('История нарядов'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (widget.locationId != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        decoration: BoxDecoration(
                          color: const Color(0xFF62DEFA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Показаны рекомендации для выбранной локации.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    Expanded(child: _buildHistoryList()),
                  ],
                ),
    );
  }

  String _resolveTitle(
    String entryType,
    Map<String, dynamic> data,
    int index,
    String createdAtText,
  ) {
    final rawTitle = data['title'] ?? data['name'];
    if (rawTitle is String && rawTitle.trim().isNotEmpty) {
      return rawTitle;
    }

    if (entryType == 'mannequin') {
      if (createdAtText.isNotEmpty && createdAtText != 'Неизвестная дата') {
        return 'Манекен от $createdAtText';
      }
      return 'Манекен ${index + 1}';
    }

    return 'Наряд ${index + 1}';
  }

  String _resolveDescription(
    String entryType,
    Map<String, dynamic> data,
    List<Map<String, dynamic>> items,
  ) {
    final rawDescription = data['description'] ?? data['summary'];
    if (rawDescription is String && rawDescription.trim().isNotEmpty) {
      return rawDescription;
    }

    final itemNames = items
        .map((item) => item['name'] ?? item['category'])
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (itemNames.isNotEmpty) {
      return 'Состав: ${itemNames.join(', ')}';
    }

    if (entryType == 'mannequin') {
      return 'Сгенерированный манекен.';
    }

    return 'Описание отсутствует';
  }

  Widget _buildEntryBadge(String entryType) {
    final bool isMannequin = entryType == 'mannequin';
    final Color backgroundColor = isMannequin
        ? const Color(0xFFE6F4EA)
        : const Color(0xFFE5F3FF);
    final Color textColor = isMannequin
        ? const Color(0xFF1B5E20)
        : const Color(0xFF0D47A1);
    final String label = isMannequin ? 'AI манекен' : 'Рекомендация';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildClothingChip(Map<String, dynamic> item) {
    final category = item['category'];
    final name = item['name'];
    final color = item['color'];
    final season = item['season'];
    final subtitle = [
      if (color != null && color.toString().trim().isNotEmpty) color,
      if (season != null && season.toString().trim().isNotEmpty) season,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name?.toString() ?? category?.toString() ?? 'Без названия',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (category != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                category.toString(),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ),
          if (subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Colors.black45),
              ),
            ),
        ],
      ),
    );
  }
}
