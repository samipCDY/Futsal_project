import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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

/// Google map of every ground, each a drop-shaped pin (orange when closed
/// for maintenance today). Tapping a pin opens its details like a place in
/// Google Maps; the search bar finds grounds by name or area.
class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => MapTabState();
}

class MapTabState extends State<MapTab> {
  static const _sheetSize = 0.45;

  GoogleMapController? _map;
  List<GroundModel>? _grounds;
  String? _selectedId;
  LatLng? _myLocation;
  bool _locationAllowed = false;
  StreamSubscription<LatLng>? _locationUpdates;
  MapType _mapType = MapType.normal;

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  Map<PinKind, BitmapDescriptor> _pins = {};
  String _pinsKey = '';

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadPins(); // again when the theme (pin colours) or screen density changes
  }

  @override
  void dispose() {
    FutsalApi.favouritesChanged.removeListener(_loadGrounds);
    FutsalApi.reviewsChanged.removeListener(_loadGrounds);
    _locationUpdates?.cancel();
    _search.dispose();
    _searchFocus.dispose();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _loadPins() async {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final key = '$ratio-${Theme.of(context).brightness}';
    if (key == _pinsKey) return;
    _pinsKey = key;
    final pins = {for (final kind in PinKind.values) kind: await GroundPins.icon(kind, ratio)};
    if (mounted) setState(() => _pins = pins);
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
    setState(() {
      _myLocation = location;
      _locationAllowed = true;
    });
    if (firstFix && _selectedId == null) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(location, 14));
    }
    // Keep distances right as the customer moves; the blue dot moves by itself.
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
    _map?.animateCamera(CameraUpdate.newLatLngZoom(location, 15));
  }

  /// Opens [ground]'s details and moves the map so its pin sits above them.
  /// Other tabs call this too, e.g. Home's map preview.
  void showGround(GroundModel ground) {
    _searchFocus.unfocus();
    setState(() => _selectedId = ground.id);
    _map?.animateCamera(CameraUpdate.newLatLngZoom(ground.location, 16));
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
    final grounds = [...?_grounds];
    final from = _myLocation ?? LocationService.fallback;
    grounds.sort((a, b) => LocationService.kmBetween(from, a.location).compareTo(LocationService.kmBetween(from, b.location)));
    return grounds;
  }

  List<GroundModel> get _searchResults {
    final words = _query.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return const [];
    return _nearestFirst
        .where((g) => words.every('${g.name} ${g.area} ${g.address}'.toLowerCase().contains))
        .take(6)
        .toList();
  }

  Set<Marker> _markers() {
    if (_pins.isEmpty) return const {};
    final now = DateTime.now();
    return {
      for (final ground in _grounds ?? const <GroundModel>[])
        Marker(
          markerId: MarkerId(ground.id),
          position: ground.location,
          icon: _pins[ground.id == _selectedId
              ? PinKind.selected
              : ground.closureOn(now) != null
                  ? PinKind.closed
                  : PinKind.open]!,
          zIndexInt: ground.id == _selectedId ? 1 : 0,
          consumeTapEvents: true,
          onTap: () => showGround(ground),
        ),
    };
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
    final screenHeight = MediaQuery.sizeOf(context).height;
    final showResults = _searchFocus.hasFocus && _query.isNotEmpty;

    return Stack(
      fit: StackFit.expand,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _myLocation ?? LocationService.fallback, zoom: 13),
          onMapCreated: (controller) => _map = controller,
          style: mapStyleFor(context),
          mapType: _mapType,
          markers: _markers(),
          myLocationEnabled: _locationAllowed,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: true,
          // Keep Google's logo and the compass clear of our panels.
          padding: EdgeInsets.only(
            top: MediaQuery.paddingOf(context).top + 70,
            bottom: selected != null ? screenHeight * _sheetSize : 140,
          ),
          onTap: (_) {
            _searchFocus.unfocus();
            if (_selectedId != null) _closeGround();
          },
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
                  if (showResults) _SearchResults(results: _searchResults, distanceTo: _distanceTo, onTap: showGround),
                ],
              ),
            ),
          ),
        ),
        if (!showResults)
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 80,
            child: Column(
              children: [
                MapControlButton(
                  icon: _mapType == MapType.normal ? Icons.satellite_alt_outlined : Icons.map_outlined,
                  tooltip: _mapType == MapType.normal ? 'Satellite view' : 'Map view',
                  onTap: () => setState(
                      () => _mapType = _mapType == MapType.normal ? MapType.hybrid : MapType.normal),
                ),
                const SizedBox(height: 10),
                MapControlButton(icon: Icons.my_location, tooltip: 'My location', onTap: _goToMyLocation),
              ],
            ),
          ),
        if (selected == null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: _NearbyStrip(
              grounds: _nearestFirst,
              loading: _grounds == null,
              distanceTo: _distanceTo,
              onTap: showGround,
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
