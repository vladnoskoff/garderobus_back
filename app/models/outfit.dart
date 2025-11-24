class Outfit {
  final int id;
  final int userId;
  final int weatherId;
  final List<int> clothingIds;
  final DateTime createdAt;
  final int? rating;
  final bool isPending;

  Outfit({
    required this.id,
    required this.userId,
    required this.weatherId,
    required this.clothingIds,
    required this.createdAt,
    this.rating,
    this.isPending = false,
  });

  factory Outfit.fromJson(Map<String, dynamic> json) {
    return Outfit(
      id: json['id'],
      userId: json['user_id'],
      weatherId: json['weather_id'],
      clothingIds: List<int>.from(json['clothing_ids']),
      createdAt: DateTime.parse(json['created_at']),
      rating: json['rating'],
      isPending: json['is_pending'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'weather_id': weatherId,
      'clothing_ids': clothingIds,
      'created_at': createdAt.toIso8601String(),
      'rating': rating,
      'is_pending': isPending,
    };
  }

  Outfit copyWith({
    int? rating,
    bool? isPending,
    List<int>? clothingIds,
  }) {
    return Outfit(
      id: id,
      userId: userId,
      weatherId: weatherId,
      clothingIds: clothingIds ?? this.clothingIds,
      createdAt: createdAt,
      rating: rating ?? this.rating,
      isPending: isPending ?? this.isPending,
    );
  }
}
