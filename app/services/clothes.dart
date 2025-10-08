class Clothes {
  final int id;
  final int userId;
  final String name;
  final String category;
  final String season;
  final String color;
  final String? material;
  final String? imageUrl;
  final DateTime createdAt;
  final int? locationId;
  final String? promptDescription;
  final String? careInstructions;
  final int? temperatureMin;
  final int? temperatureMax;

  Clothes({
    required this.id,
    required this.userId,
    required this.name,
    required this.category,
    required this.season,
    required this.color,
    this.material,
    this.imageUrl,
    required this.createdAt,
    this.locationId,
    this.promptDescription,
    this.careInstructions,
    this.temperatureMin,
    this.temperatureMax,
  });

  factory Clothes.fromJson(Map<String, dynamic> json) {
    int? _parseInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.round();
      if (value is num) return value.toInt();
      if (value is String && value.trim().isNotEmpty) {
        return int.tryParse(value.trim());
      }
      return null;
    }

    Map<String, dynamic>? _parseMetadata(dynamic value) {
      if (value is Map<String, dynamic>) return value;
      if (value is Map) {
        return value.map((key, val) => MapEntry(key.toString(), val));
      }
      return null;
    }

    final metadata = _parseMetadata(json['ai_metadata']);
    int? minTemperature = _parseInt(json['temperature_min']);
    int? maxTemperature = _parseInt(json['temperature_max']);

    if (metadata != null) {
      final tempRange = metadata['temp_c_range'];
      if (tempRange is List && tempRange.isNotEmpty) {
        minTemperature ??= _parseInt(tempRange.first);
        if (tempRange.length > 1) {
          maxTemperature ??= _parseInt(tempRange[1]);
        } else {
          maxTemperature ??= minTemperature;
        }
      }
    }

    return Clothes(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      category: json['category'],
      season: json['season'],
      color: json['color'],
      material: json['material'],
      imageUrl: json['image_url'],
      createdAt: DateTime.parse(json['created_at']),
      locationId: json['location_id'] is int
          ? json['location_id'] as int
          : int.tryParse(json['location_id']?.toString() ?? ''),
      promptDescription: json['prompt_description']?.toString(),
      careInstructions: json['care_instructions']?.toString(),
      temperatureMin: minTemperature,
      temperatureMax: maxTemperature,
    );
  }
}
