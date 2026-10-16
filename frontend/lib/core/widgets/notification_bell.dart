import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../screens/notifications_screen.dart';
import '../services/futsal_api.dart';
import '../services/notifications_api.dart';

/// The bell with a red dot when something new arrived. Checks again when it
/// appears, after any booking change, and when coming back from the list.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  @override
  void initState() {
    super.initState();
    NotificationsApi.refreshUnread();
    FutsalApi.bookingsChanged.addListener(NotificationsApi.refreshUnread);
  }

  @override
  void dispose() {
    FutsalApi.bookingsChanged.removeListener(NotificationsApi.refreshUnread);
    super.dispose();
  }

  Future<void> _open() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
    NotificationsApi.refreshUnread();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationsApi.unread,
      builder: (context, unread, _) => IconButton(
        onPressed: _open,
        tooltip: unread == 0 ? 'Notifications' : '$unread new notifications',
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 9 ? '9+' : '$unread'),
          child: Icon(unread > 0 ? Icons.notifications : Icons.notifications_none, color: AppColors.primaryGreen),
        ),
      ),
    );
  }
}
