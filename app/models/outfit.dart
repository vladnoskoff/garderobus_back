class Outfit {
  final int id;
  final int userId;
  final int weatherId;
  final List<int> clothingIds;
  final DateTime createdAt;
  final int? rating;

  Outfit({
    required this.id,
    required this.userId,
    required this.weatherId,
    required this.clothingIds,
    required this.createdAt,
    this.rating,
  });

  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id'],
      userId: json['user_id'],
      weatherId: json['weather_id'],
      clothingIds: List<int>.from(json['clothing_ids']),
      createdAt: DateTime.parse(json['created_at']),
      rating: json['rating'],
    );
  }
}
