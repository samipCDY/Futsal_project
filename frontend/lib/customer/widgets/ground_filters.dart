import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/models/ground_model.dart';

/// How the Home list is ordered.
enum GroundSort {
  nearest('Nearest'),
  rating('Top rated'),
  priceLow('Price: low to high'),
  priceHigh('Price: high to low'),
  name('Name (A–Z)');

  final String label;

  const GroundSort(this.label);

  /// Puts [grounds] in this order. [distanceTo] is null without a location.
  void apply(List<GroundModel> grounds, double? Function(GroundModel) distanceTo) {
    int byName(GroundModel a, GroundModel b) => a.name.toLowerCase().compareTo(b.name.toLowerCase());
    switch (this) {
      case GroundSort.nearest:
        grounds.sort((a, b) => (distanceTo(a) ?? double.infinity).compareTo(distanceTo(b) ?? double.infinity));
      case GroundSort.rating:
        // Best first; unrated last; more reviews wins a tie.
        grounds.sort((a, b) {
          final byStars = (b.rating ?? 0).compareTo(a.rating ?? 0);
          return byStars != 0 ? byStars : b.reviewCount.compareTo(a.reviewCount);
        });
      case GroundSort.priceLow:
        grounds.sort((a, b) {
          final byPrice = a.priceFrom.compareTo(b.priceFrom);
          return byPrice != 0 ? byPrice : byName(a, b);
        });
      case GroundSort.priceHigh:
        grounds.sort((a, b) {
          final byPrice = b.priceFrom.compareTo(a.priceFrom);
          return byPrice != 0 ? byPrice : byName(a, b);
        });
      case GroundSort.name:
        grounds.sort(byName);
    }
  }
}

/// What the customer narrowed the Home list to. Prices compare against a
/// ground's cheapest hourly rate.
class GroundFilters {
  final double? maxPrice;
  final double? withinKm;
  final double minRating; // 0 = any
  final bool openNow;
  final bool savedOnly;

  const GroundFilters({this.maxPrice, this.withinKm, this.minRating = 0, this.openNow = false, this.savedOnly = false});

  static const none = GroundFilters();

  /// For the badge on the filter button.
  int get activeCount =>
      [maxPrice != null, withinKm != null, minRating > 0, openNow, savedOnly].where((on) => on).length;

  bool matches(GroundModel ground, {double? distanceKm, required DateTime now}) {
    if (maxPrice != null && ground.priceFrom > maxPrice!) return false;
    if (withinKm != null && (distanceKm == null || distanceKm > withinKm!)) return false;
    if (minRating > 0 && (ground.rating ?? 0) < minRating) return false;
    if (openNow && !ground.openStatus(now).$1) return false;
    if (savedOnly && !ground.isFavourite) return false;
    return true;
  }
}

/// The filter sheet. Returns the new filters, or null if dismissed.
Future<GroundFilters?> showGroundFiltersSheet(
  BuildContext context, {
  required GroundFilters current,
  required bool hasLocation,
}) {
  return showModalBottomSheet<GroundFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _FiltersSheet(initial: current, hasLocation: hasLocation),
  );
}

class _FiltersSheet extends StatefulWidget {
  final GroundFilters initial;
  final bool hasLocation;

  const _FiltersSheet({required this.initial, required this.hasLocation});

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late double? _maxPrice = widget.initial.maxPrice;
  late double? _withinKm = widget.initial.withinKm;
  late double _minRating = widget.initial.minRating;
  late bool _openNow = widget.initial.openNow;
  late bool _savedOnly = widget.initial.savedOnly;

  static const _prices = [null, 1000.0, 1500.0, 2000.0, 3000.0];
  static const _distances = [null, 2.0, 5.0, 10.0, 25.0];
  static const _ratings = [0.0, 3.0, 4.0, 4.5];

  Widget _choices<T>(String title, List<T> options, T selected, String Function(T) label, ValueChanged<T>? onPick,
      {String? note}) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
          if (note != null) Text(note, style: AppTextStyles.caption),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in options)
                ChoiceChip(
                  label: Text(label(option)),
                  selected: option == selected,
                  onSelected: onPick == null ? null : (_) => setState(() => onPick(option)),
                  selectedColor: AppColors.primaryGreen.withValues(alpha: 0.18),
                  side: BorderSide(color: option == selected ? AppColors.primaryGreen : AppColors.divider),
                  showCheckmark: false,
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: Text('Filter grounds', style: AppTextStyles.subheading)),
                TextButton(
                  onPressed: () => Navigator.pop(context, GroundFilters.none),
                  child: const Text('Clear all'),
                ),
              ],
            ),
            _choices<double?>('Price per hour', _prices, _maxPrice,
                (price) => price == null ? 'Any' : 'Up to Rs ${price.toStringAsFixed(0)}', (p) => _maxPrice = p,
                note: 'Using each ground\'s cheapest rate.'),
            _choices<double?>(
              'Distance',
              _distances,
              _withinKm,
              (km) => km == null ? 'Any' : 'Within ${km.toStringAsFixed(0)} km',
              widget.hasLocation ? (km) => _withinKm = km : null,
              note: widget.hasLocation ? null : 'Turn on location to filter by distance.',
            ),
            _choices<double>('Rating', _ratings, _minRating,
                (stars) => stars == 0 ? 'Any' : '${stars.toString().replaceAll('.0', '')}★ & up', (s) => _minRating = s),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Open now', style: AppTextStyles.body),
              subtitle: Text('Hide grounds that are closed or under maintenance', style: AppTextStyles.caption),
              value: _openNow,
              onChanged: (on) => setState(() => _openNow = on),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Saved grounds only', style: AppTextStyles.body),
              value: _savedOnly,
              onChanged: (on) => setState(() => _savedOnly = on),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  GroundFilters(
                    maxPrice: _maxPrice,
                    withinKm: widget.hasLocation ? _withinKm : null,
                    minRating: _minRating,
                    openNow: _openNow,
                    savedOnly: _savedOnly,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Show grounds', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
