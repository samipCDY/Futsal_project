/// A message under the bell, e.g. "Booking confirmed".
class NotificationModel {
  final String id;
  final String kind; // booking, cancellation, maintenance, event, ground
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
        id: json['id'].toString(),
        kind: json['kind'] as String,
        title: json['title'] as String,
        body: json['body'] as String? ?? '',
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
