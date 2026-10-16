import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_colors.dart';

/// How a ground's pin looks on the map.
enum PinKind { open, closed, selected }

/// Draws the upside-down water-drop pins for grounds: green with a ball when
/// open, orange with a cone when closed for maintenance today, and bigger
/// and darker for the one being looked at. Each look is drawn once and
/// reused.
class GroundPins {
  GroundPins._();

  static final _cache = <String, BitmapDescriptor>{};

  static Future<BitmapDescriptor> icon(PinKind kind, double pixelRatio) async {
    final (fill, glyph, scale) = switch (kind) {
      PinKind.open => (AppColors.primaryGreen, Icons.sports_soccer, 1.0),
      PinKind.closed => (AppColors.accentOrange, Icons.construction, 1.0),
      PinKind.selected => (AppColors.darkGreen, Icons.sports_soccer, 1.3),
    };
    final key = '${kind.name}-${fill.toARGB32()}-$pixelRatio';
    return _cache[key] ??= await _draw(fill, glyph, scale, pixelRatio);
  }

  static Future<BitmapDescriptor> _draw(Color fill, IconData glyph, double scale, double pixelRatio) async {
    final width = 38.0 * scale;
    final height = 50.0 * scale;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);

    final cx = width / 2;
    final r = width / 2 - 3; // room for the white edge
    final cy = r + 3;
    final tip = height - 2;
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
    canvas.drawCircle(Offset(cx, cy), r * 0.62, Paint()..color = Colors.white);

    final iconSize = r * 1.0;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(glyph.codePoint),
        style: TextStyle(fontFamily: glyph.fontFamily, package: glyph.fontPackage, fontSize: iconSize, color: fill),
      ),
    )..layout();
    painter.paint(canvas, Offset(cx - painter.width / 2, cy - painter.height / 2));

    final image =
        await recorder.endRecording().toImage((width * pixelRatio).ceil(), (height * pixelRatio).ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: pixelRatio);
  }
}

/// Google's dark map colours, for when the app is in dark mode.
const darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#181818"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#373737"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
  {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
]
''';

/// The map style for the current theme (null = Google's normal colours).
String? mapStyleFor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? darkMapStyle : null;
