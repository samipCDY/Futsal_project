import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../../core/services/location_service.dart';
import '../../core/utils/money.dart';
import '../screens/ground_booking_screen.dart';
import 'ground_place_sheet.dart';
import 'ground_reviews.dart';
import 'map_controls.dart';
import 'map_ground_pin.dart';

const _minZoom = 4.0;
const _maxZoom = 19.0;

/// OpenStreetMap of every ground, each a drop-shaped pin (orange when closed
/// for maintenance today). Tapping a pin opens its details like a place in
/// Google Maps; the search bar finds grounds by name or area.
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> with SingleTickerProviderStateMixin {
  static const _sheetSize = 0.45;

  final _map = MapController();
  late final _flight = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  List<GroundModel>? _grounds;
  String? _selectedId;
  LatLng? _myLocation;
  StreamSubscription<LatLng>? _locationUpdates;

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadGrounds();
    _startLocation();
    FutsalApi.favouritesChanged.addListener(_loadGrounds);
    FutsalApi.reviewsChanged.addListener(_loadGrounds);
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    FutsalApi.favouritesChanged.removeListener(_loadGrounds);
    FutsalApi.reviewsChanged.removeListener(_loadGrounds);
    _locationUpdates?.cancel();
    _flight.dispose();
    _search.dispose();
    _searchFocus.dispose();
    _map.dispose();
    super.dispose();
  }

  Future<void> _loadGrounds() async {
    try {
      final grounds = await FutsalApi.fetchGrounds();
      if (mounted) setState(() => _grounds = grounds);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _startLocation() async {
    final location = await LocationService.current();
    if (!mounted || location == null) return;
    final firstFix = _myLocation == null;
    setState(() => _myLocation = location);
    if (firstFix && _selectedId == null) _flyTo(location, 14);
    // Keep the blue dot and distances right as the customer moves.
    _locationUpdates ??= LocationService.watch().listen((location) {
      if (mounted) setState(() => _myLocation = location);
    });
  }

  Future<void> _goToMyLocation() async {
    if (_myLocation == null) await _startLocation();
    final location = _myLocation;
    if (location == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turn on location and allow it for Futsal Finder to see where you are.')),
        );
      }
      return;
    }
    _flyTo(location, 15);
  }

  /// Glides the map to [target] at [zoom]. [coveredBottom] is how many
  /// pixels at the bottom are hidden (by the details sheet), so the target
  /// lands in the middle of what's still visible.
  void _flyTo(LatLng target, double zoom, {double coveredBottom = 0}) {
    final camera = _map.camera;
    final endZoom = zoom.clamp(_minZoom, _maxZoom).toDouble();
    var endCenter = target;
    if (coveredBottom > 0) {
      final point = camera.crs.latLngToOffset(target, endZoom);
      endCenter = camera.crs.offsetToLatLng(point + Offset(0, coveredBottom / 2), endZoom);
    }
    final start = camera.center;
    final startZoom = camera.zoom;
    final curve = CurvedAnimation(parent: _flight, curve: Curves.easeInOutCubic);
    void step() {
      final t = curve.value;
      _map.move(
        LatLng(start.latitude + (endCenter.latitude - start.latitude) * t,
            start.longitude + (endCenter.longitude - start.longitude) * t),
        startZoom + (endZoom - startZoom) * t,
      );
    }

    _flight
      ..stop()
      ..reset();
    _flight.addListener(step);
    _flight.forward().whenCompleteOrCancel(() {
      _flight.removeListener(step);
      curve.dispose();
    });
  }

  void _zoomBy(double delta) => _flyTo(_map.camera.center, _map.camera.zoom + delta);

  /// Opens [ground]'s details and glides the map so its pin sits above them.
  void _showGround(GroundModel ground) {
    _searchFocus.unfocus();
    setState(() => _selectedId = ground.id);
    final zoom = _map.camera.zoom < 15 ? 16.0 : _map.camera.zoom;
    _flyTo(ground.location, zoom, coveredBottom: MediaQuery.sizeOf(context).height * _sheetSize);
  }

  void _closeGround() => setState(() => _selectedId = null);

  GroundModel? get _selected {
    for (final ground in _grounds ?? const <GroundModel>[]) {
      if (ground.id == _selectedId) return ground;
    }
    return null;
  }

  double? _distanceTo(GroundModel ground) =>
      _myLocation == null ? null : LocationService.kmBetween(_myLocation!, ground.location);

  List<GroundModel> get _nearestFirst {
    final from = _myLocation ?? LocationService.fallback;
    return [...?_grounds]
      ..sort((a, b) => LocationService.kmBetween(from, a.location).compareTo(LocationService.kmBetween(from, b.location)));
  }

  List<GroundModel> get _searchResults {
    final words = _query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    return _nearestFirst
        .where((g) => words.every('${g.name} ${g.area} ${g.address}'.toLowerCase().contains))
        .take(6)
        .toList();
  }

  List<Marker> _markers() {
    final grounds = [...?_grounds]
      // The selected pin is drawn last so it's on top.
      ..sort((a, b) => (a.id == _selectedId ? 1 : 0) - (b.id == _selectedId ? 1 : 0));
    return [
      if (_myLocation != null)
        Marker(point: _myLocation!, width: 22, height: 22, child: const MyLocationDot()),
      for (final ground in grounds)
        groundMarker(ground, selected: ground.id == _selectedId, onTap: () => _showGround(ground)),
    ];
  }

  Future<void> _toggleFavourite(GroundModel ground) async {
    try {
      await FutsalApi.setFavourite(ground.id, !ground.isFavourite);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _book(GroundModel ground) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GroundBookingScreen(ground: ground)));
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final topInset = MediaQuery.paddingOf(context).top;
    final showResults = _searchFocus.hasFocus && _query.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _myLocation ?? LocationService.fallback,
            initialZoom: 13,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
            // No twisting the map by accident; north stays up.
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
            onPositionChanged: (_, hasGesture) {
              if (hasGesture && _flight.isAnimating) _flight.stop();
            },
            onTap: (_, __) {
              _searchFocus.unfocus();
              if (_selectedId != null) _closeGround();
            },
          ),
          children: [
            osmTiles(context),
            MarkerLayer(markers: _markers()),
            osmAttribution,
          ],
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  _SearchField(
                    controller: _search,
                    focusNode: _searchFocus,
                    onChanged: (text) => setState(() => _query = text.trim()),
                    onClear: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
                  if (showResults) _SearchResults(results: _searchResults, distanceTo: _distanceTo, onTap: _showGround),
                ],
              ),
            ),
          ),
        ),
        if (!showResults) ...[
          Positioned(
            left: 16,
            top: topInset + 80,
            child: MapZoomControls(onZoomIn: () => _zoomBy(1), onZoomOut: () => _zoomBy(-1)),
          ),
          Positioned(
            right: 16,
            top: topInset + 80,
            child: MapControlButton(icon: Icons.my_location, tooltip: 'My location', onTap: _goToMyLocation),
          ),
        ],
        if (selected == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: _NearbyStrip(
              grounds: _nearestFirst,
              loading: _grounds == null,
              distanceTo: _distanceTo,
              onTap: _showGround,
            ),
          )
        else
          DraggableScrollableSheet(
            key: ValueKey(selected.id),
            initialChildSize: _sheetSize,
            minChildSize: 0.25,
            maxChildSize: 0.95,
            snap: true,
            snapSizes: const [_sheetSize],
            builder: (context, scrollController) => GroundPlaceSheet(
              ground: selected,
              distanceKm: _distanceTo(selected),
              scrollController: scrollController,
              onClose: _closeGround,
              onBook: () => _book(selected),
              onFavourite: () => _toggleFavourite(selected),
            ),
          ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(28),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          hintText: 'Search grounds or areas',
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: Icon(Icons.close, color: AppColors.textSecondary),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<GroundModel> results;
  final double? Function(GroundModel) distanceTo;
  final ValueChanged<GroundModel> onTap;

  const _SearchResults({required this.results, required this.distanceTo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: results.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No grounds match that.', style: AppTextStyles.body),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final ground in results)
                  ListTile(
                    onTap: () => onTap(ground),
                    leading: Icon(Icons.location_on, color: AppColors.primaryGreen),
                    title: Text(ground.name, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [ground.area, if (distanceTo(ground) != null) '${distanceTo(ground)!.toStringAsFixed(1)} km']
                          .join(' · '),
                      style: AppTextStyles.caption,
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Grounds nearest first, as cards you swipe through at the bottom of the map.
class _NearbyStrip extends StatelessWidget {
  final List<GroundModel> grounds;
  final bool loading;
  final double? Function(GroundModel) distanceTo;
  final ValueChanged<GroundModel> onTap;

  const _NearbyStrip({required this.grounds, required this.loading, required this.distanceTo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (loading || grounds.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
          child: Text(loading ? 'Finding grounds...' : 'No grounds listed yet.', style: AppTextStyles.body),
        ),
      );
    }
    final now = DateTime.now();
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: grounds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final ground = grounds[index];
          final (isOpen, _) = ground.openStatus(now);
          final km = distanceTo(ground);
          return Material(
            color: AppColors.surface,
            elevation: 4,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => onTap(ground),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 250,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ground.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.subheading.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    RatingLine(rating: ground.rating, count: ground.reviewCount),
                    const Spacer(),
                    Row(
                      children: [
                        Text(
                          isOpen ? 'Open' : 'Closed',
                          style: AppTextStyles.caption.copyWith(
                            color: isOpen ? AppColors.statusConfirmedText : AppColors.dangerText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            [' · ${ground.area}', if (km != null) '${km.toStringAsFixed(1)} km'].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                        ),
                        Text('${formatRupees(ground.priceFrom)}+', style: AppTextStyles.price.copyWith(fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
