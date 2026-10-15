import '../models/ground_model.dart';

/// Shared placeholder data until the backend exists. Home tab and Map tab
/// both read from this so they show the same grounds.
const mockGrounds = [
  GroundModel(
    id: 'g1',
    name: 'Kathmandu Futsal Arena',
    area: 'Baneshwor',
    distanceKm: 0.8,
    minutesAway: 4,
    rating: 4.6,
    reviewCount: 128,
    pricePerHour: 1400,
    imageUrl: '',
    badgeLabel: 'Free bibs + water',
    latitude: 27.6939,
    longitude: 85.3336,
  ),
  GroundModel(
    id: 'g2',
    name: 'New Baneshwor Futsal Hub',
    area: 'Shantinagar',
    distanceKm: 1.5,
    minutesAway: 7,
    rating: 4.3,
    reviewCount: 86,
    pricePerHour: 1200,
    imageUrl: '',
    badgeLabel: 'Tournament Sat',
    latitude: 27.6923,
    longitude: 85.3346,
  ),
];
