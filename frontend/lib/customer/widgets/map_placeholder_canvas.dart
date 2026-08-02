import 'package:flutter/material.dart';

/// Stand-in for a real map surface until google_maps_flutter is wired up.
/// Draws terrain-ish shading, a couple of roads, and a route line so the
/// pins/overlays built against it look right without a live map SDK.
class MapPlaceholderCanvas extends StatelessWidget {
  final Offset routeStart;
  final Offset routeEnd;

  const MapPlaceholderCanvas({
    super.key,
    required this.routeStart,
    required this.routeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _MapPainter(routeStart: routeStart, routeEnd: routeEnd),
    );
  }
}

class _MapPainter extends CustomPainter {
  final Offset routeStart;
  final Offset routeEnd;

  _MapPainter({required this.routeStart, required this.routeEnd});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFE9EEE9));

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, size.height * 0.35), Offset(size.width, size.height * 0.42), roadPaint);
    canvas.drawLine(Offset(size.width * 0.25, 0), Offset(size.width * 0.55, size.height), roadPaint);

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final start = Offset(routeStart.dx * size.width, routeStart.dy * size.height);
    final end = Offset(routeEnd.dx * size.width, routeEnd.dy * size.height);
    final control = Offset(end.dx, start.dy);
    final routePath = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    canvas.drawPath(
      routePath,
      Paint()
        ..color = const Color(0xFF3B82F6)
        ..strokeWidth = 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.routeStart != routeStart || oldDelegate.routeEnd != routeEnd;
}
