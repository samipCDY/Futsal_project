import 'package:flutter/material.dart';

/// Central color palette for the app. Keep all raw color values here so
/// screens/widgets never hardcode a Color(0x...) directly.
class AppColors {
  AppColors._();

  static const Color primaryGreen = Color(0xFF1B5E3C);
  static const Color darkGreen = Color(0xFF14432B);
  static const Color accentOrange = Color(0xFFB5651D);

  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);

  static const Color rating = Color(0xFFF2A93B);
  static const Color badgeGreenBg = Color(0xFF1B5E3C);
  static const Color badgeOrangeBg = Color(0xFF9C4A1A);

  static const Color bottomNavBackground = Colors.white;
  static const Color bottomNavActive = primaryGreen;
  static const Color bottomNavInactive = Color(0xFF9CA3AF);

  static const Color divider = Color(0xFFE5E7EB);

  // Booking status colors
  static const Color statusConfirmedBg = Color(0xFFDCF3E4);
  static const Color statusConfirmedText = Color(0xFF1B5E3C);
  static const Color statusPendingBg = Color(0xFFFCE9C4);
  static const Color statusPendingText = Color(0xFF9C6B1A);
  static const Color statusCompletedBg = Color(0xFFE5E7EB);
  static const Color statusCompletedText = Color(0xFF4B5563);

  static const Color refChipBg = Color(0xFFDCEAFB);
  static const Color refChipText = Color(0xFF25636E);

  static const Color khaltiPurple = Color(0xFF5C2D91);

  static const Color infoBannerBg = Color(0xFFDCEAFB);
  static const Color infoBannerText = Color(0xFF2563EB);

  static const Color dangerBg = Color(0xFFFCE4E4);
  static const Color dangerText = Color(0xFFDC2626);

  static const Color completedCardBg = Color(0xFFE9F0FD);
}
