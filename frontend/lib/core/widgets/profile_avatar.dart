import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Round profile photo, or the user's initials when there's no photo (or it
/// can't be loaded).
class ProfileAvatar extends StatelessWidget {
  final String photoUrl;
  final String initials;
  final double size;

  const ProfileAvatar({super.key, required this.photoUrl, required this.initials, required this.size});

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      alignment: Alignment.center,
      color: AppColors.primaryGreen.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: TextStyle(fontSize: size * 0.3, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
      ),
    );

    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: photoUrl.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: photoUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}
