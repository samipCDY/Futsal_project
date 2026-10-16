/// A tournament or other event a ground owner posts.
class EventModel {
  final String id;
  final String groundId;
  final String groundName;
  final String groundArea;
  final String title;
  final String description;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String imageUrl;
  final bool isPublished;
  final bool isExpired;
  final bool isMine;

  const EventModel({
    required this.id,
    required this.groundId,
    required this.groundName,
    required this.groundArea,
    required this.title,
    required this.description,
    required this.startsAt,
    this.endsAt,
    this.imageUrl = '',
    required this.isPublished,
    required this.isExpired,
    required this.isMine,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) => EventModel(
        id: json['id'].toString(),
        groundId: json['ground'].toString(),
        groundName: json['ground_name'] as String? ?? '',
        groundArea: json['ground_area'] as String? ?? '',
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
        endsAt: json['ends_at'] == null ? null : DateTime.parse(json['ends_at'] as String).toLocal(),
        imageUrl: json['image_url'] as String? ?? '',
        isPublished: json['is_published'] as bool? ?? true,
        isExpired: json['is_expired'] as bool? ?? false,
        isMine: json['is_mine'] as bool? ?? false,
      );
}
