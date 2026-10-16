import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/notification_bell.dart';
import '../../core/widgets/profile_avatar.dart';

class LocationHeader extends StatelessWidget {
  final String initials;
  final String photoUrl;
  final String locationLabel;
  final VoidCallback? onLocationTap;

  const LocationHeader({
    super.key,
    required this.initials,
    this.photoUrl = '',
    required this.locationLabel,
    this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileAvatar(photoUrl: photoUrl, initials: initials, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onLocationTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR LOCATION',
                  style: AppTextStyles.caption.copyWith(
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      locationLabel,
                      style: AppTextStyles.subheading.copyWith(color: AppColors.primaryGreen),
                    ),
                    Icon(Icons.keyboard_arrow_down, color: AppColors.primaryGreen, size: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
        const NotificationBell(),
      ],
    );
  }
}
