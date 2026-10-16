import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/services/api_exception.dart';
import '../../core/services/futsal_api.dart';
import '../../core/services/location_service.dart';
import '../screens/ground_booking_screen.dart';
import 'location_header.dart';
import 'ground_search_bar.dart';
import 'map_preview_card.dart';
import 'ground_card.dart';
import 'ground_filters.dart';

class HomeTab extends StatefulWidget {
  /// Switches to the Map tab.
  final VoidCallback? onOpenMap;

  const HomeTab({super.key, this.onOpenMap});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<GroundModel>? _grounds;
  String? _error;
  LatLng? _myLocation;
  String? _placeName;
  bool _locating = false;
  String _query = '';
  GroundFilters _filters = GroundFilters.none;
  GroundSort _sort = GroundSort.nearest;

  @override
  void initState() {
    super.initState();
    _load();
    _locate();
    FutsalApi.favouritesChanged.addListener(_load);
    FutsalApi.reviewsChanged.addListener(_load);
  }

  @override
  void dispose() {
    FutsalApi.favouritesChanged.removeListener(_load);
    FutsalApi.reviewsChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final grounds = await FutsalApi.fetchGrounds();
      if (mounted) setState(() => _grounds = grounds);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Finds where the customer is and the town's name. Tapping the location
  /// at the top runs it again, e.g. after travelling.
  Future<void> _locate({bool tapped = false}) async {
    if (_locating) return;
    setState(() => _locating = true);
    final location = await LocationService.current();
    final name = location == null ? null : await LocationService.placeName(location);
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (location != null) _myLocation = location;
      _placeName = name;
    });
    if (location == null && tapped) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Turn on location and allow it for Futsal Finder to find grounds near you.')),
      );
    }
  }

  String get _locationLabel {
    if (_locating && _placeName == null) return 'Finding you...';
    if (_myLocation == null) return 'Location off · tap to retry';
    return _placeName ?? 'Near you';
  }

  /// Nearest needs a location; without one, best rated comes first.
  GroundSort get _effectiveSort =>
      _sort == GroundSort.nearest && _myLocation == null ? GroundSort.rating : _sort;

  Future<void> _openFilters() async {
    final filters =
        await showGroundFiltersSheet(context, current: _filters, hasLocation: _myLocation != null);
    if (filters != null && mounted) setState(() => _filters = filters);
  }

  double? _distanceTo(GroundModel ground) =>
      _myLocation == null ? null : LocationService.kmBetween(_myLocation!, ground.location);

  void _replace(GroundModel ground) {
    setState(() => _grounds = [for (final g in _grounds!) g.id == ground.id ? ground : g]);
  }

  /// Flips the heart straight away, then saves; flips it back if that fails.
  Future<void> _toggleFavourite(GroundModel ground) async {
    final favourite = !ground.isFavourite;
    _replace(ground.copyWith(isFavourite: favourite));
    try {
      await FutsalApi.setFavourite(ground.id, favourite);
    } on ApiException catch (e) {
      if (!mounted) return;
      _replace(ground);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openBooking(GroundModel ground) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => GroundBookingScreen(ground: ground)));
  }

  /// Grounds whose name, area or address contains every word typed.
  bool _matches(GroundModel ground) {
    final text = '${ground.name} ${ground.area} ${ground.address}'.toLowerCase();
    return _query.toLowerCase().split(RegExp(r'\s+')).every(text.contains);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final grounds = [...?_grounds]
        .where((g) => _matches(g) && _filters.matches(g, distanceKm: _distanceTo(g), now: now))
        .toList();
    final sort = _effectiveSort;
    sort.apply(grounds, _distanceTo);

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_load(), _locate()]);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            LocationHeader(
              initials: context.watch<ProfileProvider>().profile?.initials ?? '',
              photoUrl: context.watch<ProfileProvider>().profile?.avatarUrl ?? '',
              locationLabel: _locationLabel,
              onLocationTap: () => _locate(tapped: true),
            ),
            const SizedBox(height: 16),
            GroundSearchBar(
              hintText: 'Search by ground name or area...',
              onChanged: (text) => setState(() => _query = text.trim()),
              onFilterTap: _openFilters,
              activeFilters: _filters.activeCount,
            ),
            const SizedBox(height: 16),
            MapPreviewCard(grounds: _grounds ?? const [], myLocation: _myLocation, onMapViewTap: widget.onOpenMap),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(sort == GroundSort.nearest ? 'Grounds near you' : 'Grounds',
                      style: AppTextStyles.heading),
                ),
                PopupMenuButton<GroundSort>(
                  tooltip: 'Sort',
                  initialValue: sort,
                  onSelected: (choice) => setState(() => _sort = choice),
                  itemBuilder: (_) => [
                    for (final option in GroundSort.values)
                      PopupMenuItem(
                        value: option,
                        enabled: option != GroundSort.nearest || _myLocation != null,
                        child: Text(option == GroundSort.nearest && _myLocation == null
                            ? 'Nearest (turn on location)'
                            : option.label),
                      ),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text('Sort: ${sort.label}', style: AppTextStyles.body),
                        const SizedBox(width: 4),
                        Icon(Icons.sort, size: 18, color: AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_filters.activeCount > 0 && _grounds != null)
              Row(
                children: [
                  Text('${grounds.length} of ${_grounds!.length} grounds match your filters',
                      style: AppTextStyles.caption),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _filters = GroundFilters.none),
                    child: const Text('Clear filters'),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            if (_error != null)
              _Message(text: _error!, onRetry: _load)
            else if (_grounds == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (grounds.isEmpty)
              _Message(
                  text: _query.isNotEmpty
                      ? 'No ground matches "$_query". Try another name or area.'
                      : _filters.activeCount > 0
                          ? 'No ground matches your filters. Try loosening them.'
                          : 'No grounds listed yet. Check back soon!')
            else
              for (final ground in grounds) ...[
                GroundCard(
                  ground: ground,
                  distanceKm: _distanceTo(ground),
                  onTap: () => _openBooking(ground),
                  onBookNow: () => _openBooking(ground),
                  onFavouriteTap: () => _toggleFavourite(ground),
                ),
                const SizedBox(height: 16),
              ],
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;

  const _Message({required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Text(text, style: AppTextStyles.body, textAlign: TextAlign.center),
          if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
