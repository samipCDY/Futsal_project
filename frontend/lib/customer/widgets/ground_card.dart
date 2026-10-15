import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';

class GroundCard extends StatelessWidget {
  final GroundModel ground;

  /// Distance from the user, when their location is known.
  final double? distanceKm;
  final VoidCallback? onBookNow;
  final VoidCallback? onTap;
  final VoidCallback? onFavouriteTap;

  const GroundCard({
    super.key,
    required this.ground,
    this.distanceKm,
    this.onBookNow,
    this.onTap,
    this.onFavouriteTap,
  });

  String get _locationLine {
    final km = distanceKm;
    if (km == null) return ground.area;
    // Rough city travel time, ~20 km/h.
    final minutes = (km * 3).ceil().clamp(1, 999);
    return '${ground.area} · ${km.toStringAsFixed(1)} km · $minutes min away';
  }

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
            _GroundImage(ground: ground, onFavouriteTap: onFavouriteTap),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ground.name,
                    style: AppTextStyles.subheading.copyWith(fontSize: 17),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _locationLine,
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.divider),
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
  final VoidCallback? onFavouriteTap;

  const _GroundImage({required this.ground, this.onFavouriteTap});

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
          if (onFavouriteTap != null)
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: onFavouriteTap,
                tooltip: ground.isFavourite ? 'Remove from favourites' : 'Save to favourites',
                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                icon: Icon(
                  ground.isFavourite ? Icons.favorite : Icons.favorite_border,
                  color: ground.isFavourite ? Colors.red : AppColors.textSecondary,
                ),
              ),
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
