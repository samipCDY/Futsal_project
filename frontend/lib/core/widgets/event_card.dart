import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/event_model.dart';
import '../utils/time_format.dart';

/// One event: poster, title, where and when, and an "Expired" or "Draft"
/// label. Owners get their edit/publish buttons through [actions].
class EventCard extends StatelessWidget {
  final EventModel event;
  final Widget? actions;

  /// Hide the ground's name when the card is already on that ground's page.
  final bool showGround;

  const EventCard({super.key, required this.event, this.actions, this.showGround = true});

  String get _when {
    final end = event.endsAt;
    if (end == null) return formatDateTime(event.startsAt);
    final sameDay = end.year == event.startsAt.year && end.month == event.startsAt.month && end.day == event.startsAt.day;
    return sameDay
        ? '${formatDateTime(event.startsAt)} – ${formatClockOf(end)}'
        : '${formatDateTime(event.startsAt)} – ${formatDateTime(end)}';
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: event.isExpired ? 0.6 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: event.imageUrl,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.emoji_events_outlined, color: AppColors.accentOrange, size: 20),
                      const SizedBox(width: 6),
                      Expanded(child: Text(event.title, style: AppTextStyles.subheading.copyWith(fontSize: 16))),
                      if (event.isExpired)
                        _Label(text: 'EXPIRED', background: AppColors.statusCompletedBg,
                            foreground: AppColors.statusCompletedText)
                      else if (!event.isPublished)
                        _Label(text: 'DRAFT', background: AppColors.statusPendingBg,
                            foreground: AppColors.statusPendingText),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(icon: Icons.schedule, text: _when),
                  if (showGround)
                    _InfoRow(icon: Icons.location_on_outlined, text: '${event.groundName}, ${event.groundArea}'),
                  if (event.description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(event.description, style: AppTextStyles.body),
                  ],
                  if (actions != null) ...[
                    const SizedBox(height: 8),
                    actions!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: AppTextStyles.caption)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const _Label({required this.text, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}
