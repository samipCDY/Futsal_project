/// A customer's star rating and comment for a ground.
class ReviewModel {
  final String id;
  final int rating;
  final String comment;
  final String customerName;
  final String customerPhoto;
  final DateTime updatedAt;

  const ReviewModel({
    required this.id,
    required this.rating,
    required this.comment,
    required this.customerName,
    required this.customerPhoto,
    required this.updatedAt,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) => ReviewModel(
        id: json['id'].toString(),
        rating: json['rating'] as int,
        comment: json['comment'] as String? ?? '',
        customerName: json['customer_name'] as String? ?? '',
        customerPhoto: json['customer_photo'] as String? ?? '',
        updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  String get initials {
    final parts = customerName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    return (parts.first[0] + (parts.length > 1 ? parts.last[0] : '')).toUpperCase();
  }
}

/// Everything the reviews section of a ground shows.
class GroundReviews {
  final double? rating;
  final int reviewCount;

  /// How many reviews gave each number of stars, 5 down to 1.
  final Map<int, int> stars;
  final ReviewModel? myReview;
  final bool canReview;
  final List<ReviewModel> reviews;

  const GroundReviews({
    required this.rating,
    required this.reviewCount,
    required this.stars,
    required this.myReview,
    required this.canReview,
    required this.reviews,
  });

  factory GroundReviews.fromJson(Map<String, dynamic> json) {
    final mine = json['my_review'];
    return GroundReviews(
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: json['review_count'] as int? ?? 0,
      stars: {
        for (final entry in (json['stars'] as Map<String, dynamic>? ?? {}).entries)
          int.parse(entry.key): entry.value as int,
      },
      myReview: mine == null ? null : ReviewModel.fromJson(mine as Map<String, dynamic>),
      canReview: json['can_review'] as bool? ?? false,
      reviews: [
        for (final review in json['reviews'] as List? ?? []) ReviewModel.fromJson(review as Map<String, dynamic>),
      ],
    );
  }
}
