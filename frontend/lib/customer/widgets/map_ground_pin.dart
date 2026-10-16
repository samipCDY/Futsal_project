import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/ground_model.dart';

/// Pin sizes. The tip of the drop sits exactly on the ground's location.
const pinWidth = 38.0;
const pinHeight = 50.0;
const selectedPinScale = 1.3;

/// An upside-down water drop marking a ground: green with a ball when open,
/// orange with a cone when closed for maintenance today, bigger and darker
/// when [selected].
class GroundDropPin extends StatelessWidget {
  final bool closed;
  final bool selected;

  const GroundDropPin({super.key, this.closed = false, this.selected = false});

  @override
  Widget build(BuildContext context) {
    final fill = selected
        ? AppColors.darkGreen
        : closed
            ? AppColors.accentOrange
            : AppColors.primaryGreen;
    final scale = selected ? selectedPinScale : 1.0;
    final width = pinWidth * scale;
    final height = pinHeight * scale;
    final headRadius = width / 2 - 3;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _DropPainter(fill),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 3 + headRadius * 0.38),
            child: Container(
              width: headRadius * 1.24,
              height: headRadius * 1.24,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Icon(closed ? Icons.construction : Icons.sports_soccer, size: headRadius * 1.0, color: fill),
            ),
          ),
        ),
      ),
    );
  }
}

class _DropPainter extends CustomPainter {
  final Color fill;

  const _DropPainter(this.fill);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final r = size.width / 2 - 3; // room for the white edge
    final cy = r + 3;
    final tip = size.height - 2;
    final drop = Path()
      ..moveTo(cx, tip)
      ..cubicTo(cx - r * 0.35, tip - r * 0.9, cx - r, cy + r * 0.8, cx - r, cy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r), math.pi, math.pi, false)
      ..cubicTo(cx + r, cy + r * 0.8, cx + r * 0.35, tip - r * 0.9, cx, tip)
      ..close();
    canvas.drawShadow(drop, Colors.black, 3, false);
    canvas.drawPath(drop, Paint()..color = fill);
    canvas.drawPath(
      drop,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_DropPainter old) => old.fill != fill;
}

/// A map marker for [ground] whose tip points at its location.
Marker groundMarker(GroundModel ground, {bool selected = false, VoidCallback? onTap}) {
  final scale = selected ? selectedPinScale : 1.0;
  final closed = ground.closureOn(DateTime.now()) != null;
  return Marker(
    key: ValueKey('${ground.id}-$selected'),
    point: ground.location,
    width: pinWidth * scale,
    height: pinHeight * scale,
    alignment: Alignment.topCenter, // the widget sits above the point
    child: GestureDetector(
      onTap: onTap,
      child: Semantics(
        button: onTap != null,
        label: '${ground.name}${closed ? ', closed today' : ''}',
        child: GroundDropPin(closed: closed, selected: selected),
      ),
    ),
  );
}

/// The user's own position on the map.
class MyLocationDot extends StatelessWidget {
  const MyLocationDot({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Color(0xFF3B82F6),
          shape: BoxShape.circle,
          border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
        ),
      ),
    );
  }
}

/// OpenStreetMap tiles. In dark mode they're recoloured dark (one filter
/// over the whole layer, which is cheaper than one per tile). Tiles are
/// cached on the phone, so places seen before load instantly.
Widget osmTiles(BuildContext context) {
  final tiles = TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'com.example.futsal_app',
    maxNativeZoom: 19,
  );
  return Theme.of(context).brightness == Brightness.dark ? darkModeTilesContainerBuilder(context, tiles) : tiles;
}

/// OpenStreetMap's licence asks for this credit on every map.
const osmAttribution = RichAttributionWidget(
  alignment: AttributionAlignment.bottomLeft,
  attributions: [TextSourceAttribution('OpenStreetMap contributors')],
);
