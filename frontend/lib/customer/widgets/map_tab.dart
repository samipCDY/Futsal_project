import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../../core/services/location_service.dart';
import '../screens/ground_booking_screen.dart';
import 'ground_search_bar.dart';
import 'map_ground_pin.dart';
import 'map_controls.dart';

/// Yango/inDrive-style location picker: a pin fixed at the screen centre
/// while the map pans underneath it. Confirming reads whatever coordinate
/// is under the pin and sorts grounds by real distance from that point.
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  final _mapController = MapController();
  LatLng? _myLocation;
  bool _hasCenteredOnMyLocation = false;

  LatLng? _pinnedCenter;
  List<GroundModel>? _nearbyGrounds;
  List<GroundModel>? _grounds;

  @override
  void initState() {
    super.initState();
    _initLocation();
    _loadGrounds();
  }

  Future<void> _loadGrounds() async {
    try {
      final grounds = await FutsalApi.fetchGrounds();
      if (mounted) setState(() => _grounds = grounds);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _initLocation() async {
    final location = await LocationService.current();
    if (!mounted || location == null) return;
    setState(() => _myLocation = location);
    if (!_hasCenteredOnMyLocation) {
      _hasCenteredOnMyLocation = true;
      _mapController.move(location, _mapController.camera.zoom);
    }
  }

  Future<void> _goToMyLocation() async {
    if (_myLocation == null) {
      await _initLocation();
    }
    if (_myLocation == null) return;
    _mapController.move(_myLocation!, _mapController.camera.zoom);
  }

  void _zoomBy(double delta) {
    _mapController.move(_mapController.camera.center, _mapController.camera.zoom + delta);
  }

  Future<void> _confirmLocation() async {
    if (_grounds == null) await _loadGrounds();
    if (!mounted || _grounds == null) return;
    final center = _mapController.camera.center;
    final sorted = [..._grounds!]..sort((a, b) =>
        LocationService.kmBetween(center, a.location).compareTo(LocationService.kmBetween(center, b.location)));
    setState(() {
      _pinnedCenter = center;
      _nearbyGrounds = sorted;
    });
  }

  void _changeLocation() => setState(() => _nearbyGrounds = null);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LocationService.fallback,
            initialZoom: 15,
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && _nearbyGrounds != null) _changeLocation();
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.futsal_app',
            ),
            if (_myLocation != null)
              MarkerLayer(
                markers: [
                  Marker(point: _myLocation!, width: 22, height: 22, child: const MyLocationDot()),
                ],
              ),
            const RichAttributionWidget(
              alignment: AttributionAlignment.bottomLeft,
              attributions: [TextSourceAttribution('OpenStreetMap contributors')],
            ),
          ],
        ),
        const IgnorePointer(child: Center(child: _CenterPin())),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: GroundSearchBar(hintText: 'Search this area...', onFilterTap: () {}),
            ),
          ),
        ),
        Positioned(
          left: 16,
          top: 120,
          child: Column(
            children: [
              MapZoomControls(
                onZoomIn: () => _zoomBy(1),
                onZoomOut: () => _zoomBy(-1),
              ),
              const SizedBox(height: 20),
              const MapControlButton(icon: Icons.layers_outlined),
            ],
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MapControlButton(icon: Icons.my_location, onTap: _goToMyLocation),
                  const SizedBox(height: 12),
                  if (_nearbyGrounds == null)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _confirmLocation,
                        icon: const Icon(Icons.check_circle_outline, size: 18),
                        label: const Text('Confirm this location', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    )
                  else
                    _NearbyGroundsPanel(
                      grounds: _nearbyGrounds!,
                      pinnedCenter: _pinnedCenter!,
                      onChangeLocation: _changeLocation,
                      onBookNow: (ground) => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => GroundBookingScreen(ground: ground)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 44, color: AppColors.darkGreen),
          Container(
            width: 8,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0x40000000),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyGroundsPanel extends StatelessWidget {
  final List<GroundModel> grounds;
  final LatLng pinnedCenter;
  final VoidCallback onChangeLocation;
  final ValueChanged<GroundModel> onBookNow;

  const _NearbyGroundsPanel({
    required this.grounds,
    required this.pinnedCenter,
    required this.onChangeLocation,
    required this.onBookNow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${grounds.length} grounds near this spot',
                    style: AppTextStyles.subheading.copyWith(fontSize: 15),
                  ),
                ),
                TextButton(onPressed: onChangeLocation, child: const Text('Change location')),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.divider),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              itemCount: grounds.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final ground = grounds[index];
                final km = LocationService.kmBetween(pinnedCenter, ground.location);
                return _NearbyGroundTile(ground: ground, distanceKm: km, onBookNow: () => onBookNow(ground));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NearbyGroundTile extends StatelessWidget {
  final GroundModel ground;
  final double distanceKm;
  final VoidCallback? onBookNow;

  const _NearbyGroundTile({required this.ground, required this.distanceKm, this.onBookNow});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryGreen.withValues(alpha: 0.85), AppColors.darkGreen],
              ),
            ),
            child: const Icon(Icons.sports_soccer, color: Colors.white70, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ground.name, style: AppTextStyles.subheading.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text('${ground.area} · ${distanceKm.toStringAsFixed(1)} km', style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Rs ${ground.pricePerHour.toStringAsFixed(0)}/hr', style: AppTextStyles.price.copyWith(fontSize: 13)),
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 28)),
                onPressed: onBookNow,
                child: const Text('Book now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
