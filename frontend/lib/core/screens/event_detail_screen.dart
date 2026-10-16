import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_text_styles.dart';
import '../models/event_model.dart';
import '../utils/launcher.dart';
import '../widgets/event_card.dart';
import '../widgets/photo_gallery.dart';

/// Everything about one event. There's no sign-up form: customers read the
/// details and call the organiser to register.
class EventDetailScreen extends StatelessWidget {
  final EventModel event;

  const EventDetailScreen({super.key, required this.event});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: event.contactPhone));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied ${event.contactPhone}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhone = event.contactPhone.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Event', style: AppTextStyles.subheading),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (event.imageUrl.isNotEmpty) ...[
            GestureDetector(
              onTap: () => openPhotoViewer(context, [event.imageUrl], 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: event.imageUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(event.title, style: AppTextStyles.heading.copyWith(fontSize: 22)),
          if (event.isExpired) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.statusCompletedBg, borderRadius: BorderRadius.circular(10)),
              child: Text('This event is over.', style: TextStyle(color: AppColors.statusCompletedText)),
            ),
          ],
          const SizedBox(height: 12),
          _Row(icon: Icons.schedule, text: eventWhen(event)),
          _Row(icon: Icons.location_on_outlined, text: '${event.groundName}, ${event.groundArea}'),
          const SizedBox(height: 12),
          Divider(color: AppColors.divider),
          const SizedBox(height: 8),
          Text('Details', style: AppTextStyles.subheading),
          const SizedBox(height: 8),
          Text(
            event.description.isEmpty ? 'Call the organiser for the details.' : event.description,
            style: AppTextStyles.body.copyWith(height: 1.45),
          ),
          if (!event.isExpired && hasPhone) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.infoBannerBg, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How to register', style: AppTextStyles.subheading.copyWith(color: AppColors.infoBannerText)),
                  const SizedBox(height: 4),
                  Text('Call the organiser and tell them your team name. They\'ll explain the entry fee and rules.',
                      style: TextStyle(color: AppColors.infoBannerText)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 18, color: AppColors.infoBannerText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SelectableText(event.contactPhone,
                            style: TextStyle(
                                color: AppColors.infoBannerText, fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                      IconButton(
                        tooltip: 'Copy number',
                        onPressed: () => _copy(context),
                        icon: Icon(Icons.copy, size: 18, color: AppColors.infoBannerText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: event.isExpired || !hasPhone
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton.icon(
                  onPressed: () => callNumber(context, event.contactPhone),
                  icon: const Icon(Icons.call),
                  label: const Text('Call to register', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Row({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primaryGreen),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
