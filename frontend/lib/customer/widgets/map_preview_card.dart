import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/ground_model.dart';
import '../../core/services/location_service.dart';
import 'map_ground_pin.dart';

/// A small, still map of the grounds around the customer. Tapping it (or
/// "Map view") opens the full Map tab.
class MapPreviewCard extends StatelessWidget {
  final List<GroundModel> grounds;
  final LatLng? myLocation;
  final VoidCallback? onMapViewTap;

  const MapPreviewCard({super.key, this.grounds = const [], this.myLocation, this.onMapViewTap});

  @override
  Widget build(BuildContext context) {
    final center = myLocation ?? LocationService.fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 170,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.mapPreviewBg,
                child: FlutterMap(
                  // A new map when the location arrives, so it centres there.
                  key: ValueKey(center),
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 12.5,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    osmTiles(context),
                    MarkerLayer(markers: [
                      if (myLocation != null)
                        Marker(point: myLocation!, width: 22, height: 22, child: const MyLocationDot()),
                      for (final ground in grounds) groundMarker(ground),
                    ]),
                  ],
                ),
              ),
            ),
            // Catches taps so the whole card opens the Map tab.
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onMapViewTap),
            ),
            Positioned(
              left: 8,
              bottom: 4,
              child: Text('© OpenStreetMap',
                  style: TextStyle(fontSize: 9, color: AppColors.textSecondary.withValues(alpha: 0.9))),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: ElevatedButton.icon(
                onPressed: onMapViewTap,
                icon: Icon(Icons.map_outlined, size: 18, color: AppColors.textPrimary),
                label: Text('Map view', style: TextStyle(color: AppColors.textPrimary)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
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
