import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/widgets/profile_avatar.dart';

class LocationHeader extends StatelessWidget {
  final String initials;
  final String photoUrl;
  final String locationLabel;
  final bool hasNotification;
  final VoidCallback? onLocationTap;
  final VoidCallback? onNotificationTap;

  const LocationHeader({
    super.key,
    required this.initials,
    this.photoUrl = '',
    required this.locationLabel,
    this.hasNotification = false,
    this.onLocationTap,
    this.onNotificationTap,
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
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              onPressed: onNotificationTap,
              icon: Icon(Icons.notifications_none, color: AppColors.primaryGreen),
            ),
            if (hasNotification)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
