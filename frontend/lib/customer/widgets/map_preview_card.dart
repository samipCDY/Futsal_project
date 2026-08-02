import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Static map-style preview with a "Map view" button. Wire up a real map
/// SDK (Google Maps / Mapbox) behind [onMapViewTap] later.
class MapPreviewCard extends StatelessWidget {
  final VoidCallback? onMapViewTap;

  const MapPreviewCard({super.key, this.onMapViewTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 170,
        decoration: const BoxDecoration(color: Color(0xFFDCE6DD)),
        child: Stack(
          children: [
            CustomPaint(size: Size.infinite, painter: _MapGridPainter()),
            Positioned(
              left: 16,
              bottom: 16,
              child: ElevatedButton.icon(
                onPressed: onMapViewTap,
                icon: const Icon(Icons.map_outlined, size: 18, color: AppColors.textPrimary),
                label: const Text('Map view', style: TextStyle(color: AppColors.textPrimary)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    const step = 24.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final pinPaint = Paint()..color = AppColors.primaryGreen;
    final pins = [
      Offset(size.width * 0.3, size.height * 0.4),
      Offset(size.width * 0.55, size.height * 0.25),
      Offset(size.width * 0.7, size.height * 0.6),
      Offset(size.width * 0.4, size.height * 0.75),
    ];
    for (final p in pins) {
      canvas.drawCircle(p, 5, pinPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
