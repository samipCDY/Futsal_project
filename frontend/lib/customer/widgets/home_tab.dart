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
  String _query = '';

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

  Future<void> _locate() async {
    final location = await LocationService.current();
    if (mounted && location != null) setState(() => _myLocation = location);
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
    final grounds = [...?_grounds].where(_matches).toList();
    if (_myLocation != null) {
      grounds.sort((a, b) => _distanceTo(a)!.compareTo(_distanceTo(b)!));
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            LocationHeader(
              initials: context.watch<ProfileProvider>().profile?.initials ?? '',
              photoUrl: context.watch<ProfileProvider>().profile?.avatarUrl ?? '',
              locationLabel: 'Baneshwor, Kathmandu',
            ),
            const SizedBox(height: 16),
            GroundSearchBar(
              hintText: 'Search by ground name or area...',
              onChanged: (text) => setState(() => _query = text.trim()),
            ),
            const SizedBox(height: 16),
            MapPreviewCard(grounds: _grounds ?? const [], myLocation: _myLocation, onMapViewTap: widget.onOpenMap),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_myLocation == null ? 'Grounds' : 'Grounds near you', style: AppTextStyles.heading),
                if (_myLocation != null)
                  Row(
                    children: [
                      Text('Sort: Nearest', style: AppTextStyles.body),
                      const SizedBox(width: 4),
                      Icon(Icons.sort, size: 18, color: AppColors.textSecondary),
                    ],
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
              _Message(text: _query.isEmpty
                  ? 'No grounds listed yet. Check back soon!'
                  : 'No ground matches "$_query". Try another name or area.')
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
