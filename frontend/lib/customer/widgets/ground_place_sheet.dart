import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';
import '../../core/utils/money.dart';
import '../../core/utils/time_format.dart';
import '../../core/widgets/photo_gallery.dart';
import 'ground_reviews.dart';

/// Opens Google Maps with driving directions to a ground.
Future<void> openDirections(BuildContext context, double latitude, double longitude) async {
  final uri = Uri.parse('https://www.google.com/maps/dir/?api=1'
      '&destination=$latitude,$longitude&travelmode=driving');
  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Couldn't open Google Maps.")));
  }
}

/// Everything about one ground, like a place in Google Maps: rating, open
/// or closed (and why), buttons, photo, rates, hours, address and reviews.
/// Lives in a sheet the customer drags up; [scrollController] comes from it.
class GroundPlaceSheet extends StatelessWidget {
  final GroundModel ground;
  final double? distanceKm;
  final ScrollController scrollController;
  final VoidCallback onClose;
  final VoidCallback onBook;
  final VoidCallback onFavourite;

  const GroundPlaceSheet({
    super.key,
    required this.ground,
    required this.distanceKm,
    required this.scrollController,
    required this.onClose,
    required this.onBook,
    required this.onFavourite,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final (isOpen, openText) = ground.openStatus(now);
    final km = distanceKm;

    return Material(
      color: AppColors.surface,
      elevation: 12,
      shadowColor: Colors.black45,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text(ground.name, style: AppTextStyles.heading.copyWith(fontSize: 22))),
              IconButton(
                tooltip: 'Close',
                onPressed: onClose,
                style: IconButton.styleFrom(backgroundColor: AppColors.subtleFill),
                icon: Icon(Icons.close, size: 20, color: AppColors.textPrimary),
              ),
            ],
          ),
          RatingLine(rating: ground.rating, count: ground.reviewCount),
          const SizedBox(height: 4),
          Text(
            ['Futsal ground', ground.area, if (km != null) '${km.toStringAsFixed(1)} km'].join(' · '),
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: isOpen ? 'Open' : 'Closed',
                style: TextStyle(
                  color: isOpen ? AppColors.statusConfirmedText : AppColors.dangerText,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(text: ' · $openText'),
            ]),
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: onBook,
                  icon: const Icon(Icons.event_available, size: 18),
                  label: const Text('Book now', style: TextStyle(fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _PillButton(icon: Icons.directions, label: 'Directions', onTap: () => openDirections(context, ground.latitude, ground.longitude)),
              const SizedBox(width: 8),
              _PillButton(
                icon: ground.isFavourite ? Icons.favorite : Icons.favorite_border,
                label: ground.isFavourite ? 'Saved' : 'Save',
                iconColor: ground.isFavourite ? Colors.red : null,
                onTap: onFavourite,
              ),
            ],
          ),
          if (ground.maintenance.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final period in ground.maintenance) _ClosureBanner(period: period),
          ],
          const SizedBox(height: 14),
          PhotoCarousel(photos: ground.photos, height: 190),
          const SizedBox(height: 16),
          Text('Hourly rates', style: AppTextStyles.subheading),
          const SizedBox(height: 8),
          _RateRow(label: 'Morning', hours: 'before ${formatClock('$dayStartsHour:00')}', price: ground.morningPrice),
          _RateRow(
            label: 'Day',
            hours: '${formatClock('$dayStartsHour:00')} – ${formatClock('$eveningStartsHour:00')}',
            price: ground.dayPrice,
          ),
          _RateRow(
            label: 'Evening',
            hours: 'from ${formatClock('$eveningStartsHour:00')}',
            price: ground.eveningPrice,
            isPeak: ground.peakPrice != null && ground.peakPrice == ground.eveningPrice,
          ),
          const SizedBox(height: 8),
          Divider(color: AppColors.divider),
          _InfoRow(
            icon: Icons.location_on_outlined,
            text: ground.address.isEmpty ? ground.area : '${ground.address}, ${ground.area}',
          ),
          _InfoRow(
            icon: Icons.schedule,
            text: 'Open daily ${formatClock(ground.opensAt.substring(0, 5))} – '
                '${formatClock(ground.closesAt.substring(0, 5))}',
          ),
          if (ground.badgeLabel != null) _InfoRow(icon: Icons.check_circle_outline, text: ground.badgeLabel!),
          Divider(color: AppColors.divider),
          const SizedBox(height: 8),
          GroundReviewsSection(groundId: ground.id, groundName: ground.name),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _PillButton({required this.icon, required this.label, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 6),
          side: BorderSide(color: AppColors.divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: iconColor),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ClosureBanner extends StatelessWidget {
  final MaintenancePeriod period;

  const _ClosureBanner({required this.period});

  @override
  Widget build(BuildContext context) {
    final days = period.isOneDay
        ? formatDateDayMonthYear(period.startsOn)
        : '${formatDateDayMonthYear(period.startsOn)} – ${formatDateDayMonthYear(period.endsOn)}';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.statusPendingBg, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.construction, size: 20, color: AppColors.statusPendingText),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: 'Closed for maintenance $days\n', style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(text: period.reason),
              ]),
              style: AppTextStyles.body.copyWith(color: AppColors.statusPendingText),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateRow extends StatelessWidget {
  final String label;
  final String hours;
  final double price;
  final bool isPeak;

  const _RateRow({required this.label, required this.hours, required this.price, this.isPeak = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Expanded(child: Text(hours, style: AppTextStyles.caption)),
          if (isPeak) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: AppColors.badgeOrangeBg, borderRadius: BorderRadius.circular(6)),
              child: const Text('Peak', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
          ],
          Text('${formatRupees(price)}/hr', style: AppTextStyles.price.copyWith(fontSize: 14)),
        ],
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primaryGreen),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}
