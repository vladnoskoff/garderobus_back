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

      final response = await ApiService.getOutfitHistory(
        userId,
        locationId: widget.locationId,
      );
      if (!mounted) return;
      setState(() {
        _history = response
            .whereType<Map<String, dynamic>>()
            .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
            .toList();
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

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return const Center(
        child: Text(
          'История нарядов пуста. Создайте новые рекомендации, чтобы они появились здесь.',
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
          final item = _history[index];
          final title = item['title'] ?? item['name'] ?? 'Наряд ${index + 1}';
          final description = item['description'] ?? item['summary'] ?? 'Описание отсутствует';
          final createdAt = _formatDate(item['created_at'] ?? item['createdAt'] ?? item['date']);
          final rating = item['rating'];
          final imageUrl = item['image_url'] ?? item['imageUrl'];
          final locationName = item['location_name'] ?? item['locationName'];

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
                        createdAt,
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
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
                  if (locationName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Локация: $locationName',
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                  if (rating != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(rating.toString()),
                      ],
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
                          'Показаны наряды для выбранной локации.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    Expanded(child: _buildHistoryList()),
                  ],
                ),
    );
  }
}
