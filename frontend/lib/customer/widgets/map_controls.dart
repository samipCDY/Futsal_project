import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// A round-cornered button floating over the map.
class MapControlButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;

  const MapControlButton({super.key, required this.icon, this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: AppColors.textPrimary)),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
