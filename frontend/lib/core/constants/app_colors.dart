import 'package:flutter/material.dart';

/// Central color palette for the app. Keep all raw color values here so
/// screens/widgets never hardcode a Color(0x...) directly.
///
/// Every color has a light and a dark version (see [AppPalette]).
/// `PaletteScope` switches between them to match the active theme, so
/// widgets just use `AppColors.surface` etc. and follow light/dark mode.
class AppColors {
  AppColors._();

  static AppPalette _palette = AppPalette.light;

  /// Only `PaletteScope` should call this.
  static void usePalette(AppPalette palette) => _palette = palette;

  static Color get primaryGreen => _palette.primaryGreen;
  static Color get darkGreen => _palette.darkGreen;
  static Color get accentOrange => _palette.accentOrange;

  static Color get background => _palette.background;
  static Color get surface => _palette.surface;

  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;

  static Color get rating => _palette.rating;
  static Color get badgeGreenBg => _palette.badgeGreenBg;
  static Color get badgeOrangeBg => _palette.badgeOrangeBg;

  static Color get bottomNavBackground => _palette.surface;
  static Color get bottomNavActive => _palette.primaryGreen;
  static Color get bottomNavInactive => _palette.bottomNavInactive;

  static Color get divider => _palette.divider;

  // Booking status colors
  static Color get statusConfirmedBg => _palette.statusConfirmedBg;
  static Color get statusConfirmedText => _palette.statusConfirmedText;
  static Color get statusPendingBg => _palette.statusPendingBg;
  static Color get statusPendingText => _palette.statusPendingText;
  static Color get statusCompletedBg => _palette.statusCompletedBg;
  static Color get statusCompletedText => _palette.statusCompletedText;

  static Color get refChipBg => _palette.refChipBg;
  static Color get refChipText => _palette.refChipText;

  static Color get khaltiPurple => _palette.khaltiPurple;

  static Color get infoBannerBg => _palette.infoBannerBg;
  static Color get infoBannerText => _palette.infoBannerText;

  static Color get dangerBg => _palette.dangerBg;
  static Color get dangerText => _palette.dangerText;

  static Color get completedCardBg => _palette.completedCardBg;

  /// Soft fill behind text fields and footers.
  static Color get subtleFill => _palette.subtleFill;
  static Color get mapPreviewBg => _palette.mapPreviewBg;
}

class AppPalette {
  final Color primaryGreen;
  final Color darkGreen;
  final Color accentOrange;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color rating;
  final Color badgeGreenBg;
  final Color badgeOrangeBg;
  final Color bottomNavInactive;
  final Color divider;
  final Color statusConfirmedBg;
  final Color statusConfirmedText;
  final Color statusPendingBg;
  final Color statusPendingText;
  final Color statusCompletedBg;
  final Color statusCompletedText;
  final Color refChipBg;
  final Color refChipText;
  final Color khaltiPurple;
  final Color infoBannerBg;
  final Color infoBannerText;
  final Color dangerBg;
  final Color dangerText;
  final Color completedCardBg;
  final Color subtleFill;
  final Color mapPreviewBg;

  const AppPalette({
    required this.primaryGreen,
    required this.darkGreen,
    required this.accentOrange,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.rating,
    required this.badgeGreenBg,
    required this.badgeOrangeBg,
    required this.bottomNavInactive,
    required this.divider,
    required this.statusConfirmedBg,
    required this.statusConfirmedText,
    required this.statusPendingBg,
    required this.statusPendingText,
    required this.statusCompletedBg,
    required this.statusCompletedText,
    required this.refChipBg,
    required this.refChipText,
    required this.khaltiPurple,
    required this.infoBannerBg,
    required this.infoBannerText,
    required this.dangerBg,
    required this.dangerText,
    required this.completedCardBg,
    required this.subtleFill,
    required this.mapPreviewBg,
  });

  static const light = AppPalette(
    primaryGreen: Color(0xFF1B5E3C),
    darkGreen: Color(0xFF14432B),
    accentOrange: Color(0xFFB5651D),
    background: Color(0xFFF7F8FA),
    surface: Colors.white,
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF6B7280),
    rating: Color(0xFFF2A93B),
    badgeGreenBg: Color(0xFF1B5E3C),
    badgeOrangeBg: Color(0xFF9C4A1A),
    bottomNavInactive: Color(0xFF9CA3AF),
    divider: Color(0xFFE5E7EB),
    statusConfirmedBg: Color(0xFFDCF3E4),
    statusConfirmedText: Color(0xFF1B5E3C),
    statusPendingBg: Color(0xFFFCE9C4),
    statusPendingText: Color(0xFF9C6B1A),
    statusCompletedBg: Color(0xFFE5E7EB),
    statusCompletedText: Color(0xFF4B5563),
    refChipBg: Color(0xFFDCEAFB),
    refChipText: Color(0xFF25636E),
    khaltiPurple: Color(0xFF5C2D91),
    infoBannerBg: Color(0xFFDCEAFB),
    infoBannerText: Color(0xFF2563EB),
    dangerBg: Color(0xFFFCE4E4),
    dangerText: Color(0xFFDC2626),
    completedCardBg: Color(0xFFE9F0FD),
    subtleFill: Color(0xFFEFF3EF),
    mapPreviewBg: Color(0xFFDCE6DD),
  );

  /// Near-black backgrounds with light text. The green is brightened so it
  /// stays readable on dark surfaces and still carries white button text.
  static const dark = AppPalette(
    primaryGreen: Color(0xFF2A8F59),
    darkGreen: Color(0xFF1F6B44),
    accentOrange: Color(0xFFD9853B),
    background: Color(0xFF121212),
    surface: Color(0xFF1E1E1E),
    textPrimary: Color(0xFFF1F1F1),
    textSecondary: Color(0xFFA0A6B0),
    rating: Color(0xFFF2A93B),
    badgeGreenBg: Color(0xFF1B5E3C),
    badgeOrangeBg: Color(0xFF9C4A1A),
    bottomNavInactive: Color(0xFF7C828C),
    divider: Color(0xFF2E2E2E),
    statusConfirmedBg: Color(0xFF1E3A2B),
    statusConfirmedText: Color(0xFF7DD3A0),
    statusPendingBg: Color(0xFF3D2F12),
    statusPendingText: Color(0xFFF2C46B),
    statusCompletedBg: Color(0xFF2E2E2E),
    statusCompletedText: Color(0xFFC4C8CF),
    refChipBg: Color(0xFF1E3348),
    refChipText: Color(0xFF8CC4D0),
    khaltiPurple: Color(0xFF7B4BC0),
    infoBannerBg: Color(0xFF1E2A3D),
    infoBannerText: Color(0xFF8AB4F8),
    dangerBg: Color(0xFF3B1E1E),
    dangerText: Color(0xFFF87171),
    completedCardBg: Color(0xFF1A2233),
    subtleFill: Color(0xFF2A2A2A),
    mapPreviewBg: Color(0xFF1F2A22),
  );
}
