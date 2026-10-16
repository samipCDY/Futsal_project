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

/// Zoom in (+) and out (−) stacked in one card, like most map apps.
class MapZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  const MapZoomControls({super.key, required this.onZoomIn, required this.onZoomOut});

  @override
  Widget build(BuildContext context) {
    Widget half(IconData icon, String tooltip, VoidCallback onTap, BorderRadius radius) => Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: AppColors.textPrimary)),
          ),
        );
    return Material(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          half(Icons.add, 'Zoom in', onZoomIn, const BorderRadius.vertical(top: Radius.circular(12))),
          SizedBox(width: 28, child: Divider(height: 1, color: AppColors.divider)),
          half(Icons.remove, 'Zoom out', onZoomOut, const BorderRadius.vertical(bottom: Radius.circular(12))),
        ],
      ),
    );
  }
}
