import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/ground_model.dart';
import '../../core/services/location_service.dart';
import 'map_ground_pin.dart';

/// A small, still Google map of the grounds around the customer. Tapping it
/// (or "Map view") opens the full Map tab.
class MapPreviewCard extends StatefulWidget {
  final List<GroundModel> grounds;
  final LatLng? myLocation;
  final VoidCallback? onMapViewTap;

  const MapPreviewCard({super.key, this.grounds = const [], this.myLocation, this.onMapViewTap});

  @override
  State<MapPreviewCard> createState() => _MapPreviewCardState();
}

class _MapPreviewCardState extends State<MapPreviewCard> {
  Map<PinKind, BitmapDescriptor> _pins = {};
  String _pinsKey = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPins();
  }

  Future<void> _loadPins() async {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final key = '$ratio-${Theme.of(context).brightness}';
    if (key == _pinsKey) return;
    _pinsKey = key;
    final pins = {
      PinKind.open: await GroundPins.icon(PinKind.open, ratio),
      PinKind.closed: await GroundPins.icon(PinKind.closed, ratio),
    };
    if (mounted) setState(() => _pins = pins);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final center = widget.myLocation ?? LocationService.fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 170,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                color: AppColors.mapPreviewBg,
                child: GoogleMap(
                  // A new map when the location arrives, so it centres there.
                  key: ValueKey(center),
                  initialCameraPosition: CameraPosition(target: center, zoom: 12.5),
                  liteModeEnabled: true,
                  style: mapStyleFor(context),
                  markers: _pins.isEmpty
                      ? const {}
                      : {
                          for (final ground in widget.grounds)
                            Marker(
                              markerId: MarkerId(ground.id),
                              position: ground.location,
                              icon: _pins[ground.closureOn(now) == null ? PinKind.open : PinKind.closed]!,
                            ),
                        },
                  myLocationEnabled: widget.myLocation != null,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  tiltGesturesEnabled: false,
                ),
              ),
            ),
            // Catches taps so they open the Map tab instead of Google Maps.
            Positioned.fill(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onMapViewTap),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: ElevatedButton.icon(
                onPressed: widget.onMapViewTap,
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
