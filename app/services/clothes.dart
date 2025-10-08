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
  });

  factory Clothes.fromJson(Map<String, dynamic> json) {
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
    );
  }
}
