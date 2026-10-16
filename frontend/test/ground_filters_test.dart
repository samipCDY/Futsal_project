import 'package:flutter_test/flutter_test.dart';
import 'package:futsal_app/core/models/ground_model.dart';
import 'package:futsal_app/customer/widgets/ground_filters.dart';

GroundModel _ground(String name, double price, {double? rating, int reviews = 0, bool saved = false}) => GroundModel(
      id: name,
      name: name,
      area: 'Bharatpur',
      address: '',
      morningPrice: price,
      dayPrice: price,
      eveningPrice: price + 500,
      imageUrl: '',
      latitude: 27.68,
      longitude: 84.43,
      rating: rating,
      reviewCount: reviews,
      isFavourite: saved,
    );

void main() {
  final cheap = _ground('Cheap', 800, rating: 3.5, reviews: 4);
  final top = _ground('Top', 1500, rating: 4.8, reviews: 20, saved: true);
  final unrated = _ground('Unrated', 1200);
  final km = {'Cheap': 6.0, 'Top': 1.5, 'Unrated': 12.0};
  double? distance(GroundModel g) => km[g.id];
  final evening = DateTime(2026, 10, 16, 18);

  List<String> names(List<GroundModel> grounds) => [for (final g in grounds) g.name];

  test('sorts by distance, rating, price and name', () {
    final grounds = [unrated, cheap, top];
    GroundSort.nearest.apply(grounds, distance);
    expect(names(grounds), ['Top', 'Cheap', 'Unrated']);
    GroundSort.rating.apply(grounds, distance);
    expect(names(grounds), ['Top', 'Cheap', 'Unrated']);
    GroundSort.priceLow.apply(grounds, distance);
    expect(names(grounds), ['Cheap', 'Unrated', 'Top']);
    GroundSort.priceHigh.apply(grounds, distance);
    expect(names(grounds), ['Top', 'Unrated', 'Cheap']);
    GroundSort.name.apply(grounds, distance);
    expect(names(grounds), ['Cheap', 'Top', 'Unrated']);
  });

  test('filters by price, distance, rating, open now and saved', () {
    List<String> keep(GroundFilters f) =>
        names([cheap, top, unrated].where((g) => f.matches(g, distanceKm: distance(g), now: evening)).toList());
    expect(keep(GroundFilters.none), ['Cheap', 'Top', 'Unrated']);
    expect(keep(const GroundFilters(maxPrice: 1000)), ['Cheap']);
    expect(keep(const GroundFilters(withinKm: 5)), ['Top']);
    expect(keep(const GroundFilters(minRating: 4)), ['Top']);
    expect(keep(const GroundFilters(savedOnly: true)), ['Top']);
    expect(keep(const GroundFilters(openNow: true)), ['Cheap', 'Top', 'Unrated']);
    expect([cheap].where((g) => const GroundFilters(openNow: true).matches(g, now: DateTime(2026, 10, 16, 23))),
        isEmpty);
    expect(const GroundFilters(maxPrice: 1000, openNow: true).activeCount, 2);
  });
}
