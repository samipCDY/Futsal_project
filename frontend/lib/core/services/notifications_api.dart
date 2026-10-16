import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import 'api_client.dart';

/// The messages under the bell.
class NotificationsApi {
  /// How many are unread, for the red dot on the bell.
  static final unread = ValueNotifier<int>(0);

  static Future<List<NotificationModel>> fetch() async {
    final data = await ApiClient.get('/notifications/') as Map<String, dynamic>;
    unread.value = data['unread'] as int;
    return (data['results'] as List)
        .map((json) => NotificationModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Refreshes only the unread count; failures just keep the old count.
  static Future<void> refreshUnread() async {
    try {
      await fetch();
    } on Exception {
      // the bell simply keeps its last state
    }
  }

  static Future<void> markAllRead() async {
    await ApiClient.post('/notifications/read/');
    unread.value = 0;
  }
}
