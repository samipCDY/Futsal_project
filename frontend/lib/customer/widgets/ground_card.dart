import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';

class GroundCard extends StatelessWidget {
  final GroundModel ground;
  final VoidCallback? onBookNow;
  final VoidCallback? onTap;

  const GroundCard({
    super.key,
    required this.ground,
    this.onBookNow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
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
            _GroundImage(ground: ground),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          ground.name,
                          style: AppTextStyles.subheading.copyWith(fontSize: 17),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RatingPill(rating: ground.rating, reviewCount: ground.reviewCount),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${ground.area} · ${ground.distanceKm} km · ${ground.minutesAway} min away',
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.divider),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Starting from', style: AppTextStyles.caption),
                            RichText(
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Rs ${ground.pricePerHour.toStringAsFixed(0)}',
                                    style: AppTextStyles.price,
                                  ),
                                  TextSpan(text: '/hour', style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: onBookNow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Book now', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroundImage extends StatelessWidget {
  final GroundModel ground;

  const _GroundImage({required this.ground});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryGreen.withValues(alpha: 0.85), AppColors.darkGreen],
              ),
            ),
            child: const Center(
              child: Icon(Icons.sports_soccer, size: 56, color: Colors.white24),
            ),
          ),
          if (ground.badgeLabel != null)
            Positioned(
              top: 10,
              left: 10,
              child: _Badge(label: ground.badgeLabel!),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;

  const _Badge({required this.label});

  bool get _isTournament => label.toLowerCase().contains('tournament');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _isTournament ? AppColors.badgeOrangeBg : AppColors.badgeGreenBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isTournament ? Icons.emoji_events_outlined : Icons.check_circle_outline,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _RatingPill extends StatelessWidget {
  final double rating;
  final int reviewCount;

  const _RatingPill({required this.rating, required this.reviewCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.rating.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 14, color: AppColors.rating),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 3),
          Text(
            '($reviewCount)',
            style: AppTextStyles.caption.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}
