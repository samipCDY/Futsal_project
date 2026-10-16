import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/notification_model.dart';
import '../services/api_exception.dart';
import '../services/notifications_api.dart';
import '../utils/time_format.dart';

/// Everything under the bell, newest first. Opening it marks all as read.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel>? _notifications;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final notifications = await NotificationsApi.fetch();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _error = null;
      });
      // Keep the unread dots on this screen; the bell clears straight away.
      if (notifications.any((n) => !n.isRead)) await NotificationsApi.markAllRead();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = _notifications;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Notifications', style: AppTextStyles.subheading),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (notifications == null && _error != null)
              Column(
                children: [
                  const SizedBox(height: 40),
                  Text(_error!, style: AppTextStyles.body, textAlign: TextAlign.center),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              )
            else if (notifications == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (notifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Column(
                  children: [
                    Icon(Icons.notifications_none, size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 8),
                    Text('No notifications yet.', style: AppTextStyles.body),
                  ],
                ),
              )
            else
              for (final notification in notifications) ...[
                _NotificationTile(notification: notification),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final (icon, colour) = switch (notification.kind) {
      'booking' => (Icons.event_available, AppColors.primaryGreen),
      'cancellation' => (Icons.currency_exchange, AppColors.dangerText),
      'maintenance' => (Icons.construction, AppColors.statusPendingText),
      'event' => (Icons.emoji_events_outlined, AppColors.accentOrange),
      'announcement' => (Icons.campaign_outlined, AppColors.darkGreen),
      'review' => (Icons.star_outline_rounded, AppColors.rating),
      _ => (Icons.verified_outlined, AppColors.primaryGreen),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: notification.isRead ? AppColors.surface : colour.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: notification.isRead ? AppColors.divider : colour.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colour.withValues(alpha: 0.15),
            child: Icon(icon, color: colour, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(notification.title,
                          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    Text(formatAgo(notification.createdAt), style: AppTextStyles.caption),
                  ],
                ),
                if (notification.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(notification.body, style: AppTextStyles.body),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
