import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const MapControlButton({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}

/// Zoom +/- stacked buttons, mirroring standard map UI conventions.
class MapZoomControls extends StatelessWidget {
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  const MapZoomControls({super.key, this.onZoomIn, this.onZoomOut});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MapControlButton(icon: Icons.add, onTap: onZoomIn),
        const SizedBox(height: 8),
        MapControlButton(icon: Icons.remove, onTap: onZoomOut),
      ],
    );
  }
}
