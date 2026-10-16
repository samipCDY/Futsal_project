import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/location_service.dart';
import '../../customer/widgets/map_ground_pin.dart';

/// Move the map until the pin sits on the ground's entrance, then confirm.
/// Pops with the chosen [LatLng].
class LocationPickerScreen extends StatefulWidget {
  final LatLng? initial;

  const LocationPickerScreen({super.key, this.initial});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _map;
  late LatLng _center = widget.initial ?? LocationService.fallback;
  // Satellite helps owners spot their pitch from above.
  MapType _mapType = MapType.hybrid;

  @override
  void initState() {
    super.initState();
    // New ground: start where the owner is standing, likely at the ground.
    if (widget.initial == null) _goToMyLocation();
  }

  Future<void> _goToMyLocation() async {
    final location = await LocationService.current();
    if (!mounted) return;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't get your location. Move the map to the ground instead.")),
      );
      return;
    }
    _map?.animateCamera(CameraUpdate.newLatLngZoom(location, 18));
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Ground location', style: AppTextStyles.subheading),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 17),
            onMapCreated: (controller) => _map = controller,
            onCameraMove: (camera) => _center = camera.target,
            mapType: _mapType,
            style: _mapType == MapType.normal ? mapStyleFor(context) : null,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding: const EdgeInsets.only(top: 70, bottom: 130),
          ),
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -22),
                child: Icon(Icons.location_on, size: 44, color: AppColors.darkGreen),
              ),
            ),
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: Text('Move the map so the pin is on your ground.', style: AppTextStyles.body),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'map-type',
                    tooltip: _mapType == MapType.normal ? 'Satellite view' : 'Map view',
                    onPressed: () => setState(
                        () => _mapType = _mapType == MapType.normal ? MapType.hybrid : MapType.normal),
                    backgroundColor: AppColors.surface,
                    child: Icon(_mapType == MapType.normal ? Icons.satellite_alt_outlined : Icons.map_outlined,
                        color: AppColors.primaryGreen),
                  ),
                  const SizedBox(height: 8),
                  FloatingActionButton.small(
                    heroTag: 'my-location',
                    onPressed: _goToMyLocation,
                    backgroundColor: AppColors.surface,
                    child: Icon(Icons.my_location, color: AppColors.primaryGreen),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, _center),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Use this location', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
