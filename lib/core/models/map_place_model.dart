import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

enum PlaceCategory {
  all('all', 'Semua', 'All'),
  amusement('amusement', 'Wahana & Hiburan', 'Amusement'),
  hotel('hotel', 'Hotel & Resort', 'Hotel'),
  park('park', 'Taman & Alam', 'Park'),
  restaurants('restaurants', 'Restoran & Kuliner', 'Restaurants'),
  pool('pool', 'Kolam & Waterpark', 'Pool');

  final String key;
  final String labelId;
  final String labelEn;

  const PlaceCategory(this.key, this.labelId, this.labelEn);

  static PlaceCategory fromString(String? val) {
    if (val == null) return PlaceCategory.all;
    final lower = val.toLowerCase().trim();
    if (lower.contains('resto') ||
        lower.contains('kuliner') ||
        lower.contains('makan') ||
        lower.contains('cafe') ||
        lower.contains('kafe') ||
        lower.contains('restaurant')) {
      return PlaceCategory.restaurants;
    }
    if (lower.contains('hotel') ||
        lower.contains('resort') ||
        lower.contains('villa') ||
        lower.contains('penginapan')) {
      return PlaceCategory.hotel;
    }
    if (lower.contains('amuse') ||
        lower.contains('wahana') ||
        lower.contains('tematik') ||
        lower.contains('lampion') ||
        lower.contains('hiburan') ||
        lower.contains('bermain')) {
      return PlaceCategory.amusement;
    }
    if (lower.contains('pool') ||
        lower.contains('kolam') ||
        lower.contains('waterpark') ||
        lower.contains('tirta') ||
        lower.contains('pemandian')) {
      return PlaceCategory.pool;
    }
    if (lower.contains('park') ||
        lower.contains('taman') ||
        lower.contains('alam') ||
        lower.contains('hutan') ||
        lower.contains('pantai') ||
        lower.contains('gunung') ||
        lower.contains('bukit') ||
        lower.contains('lembah')) {
      return PlaceCategory.park;
    }
    return PlaceCategory.amusement;
  }
}

class MapPlace {
  final String id;
  final String name;
  final PlaceCategory category;
  final double latitude;
  final double longitude;
  final double rating;
  final int reviewCount;
  final double? price;
  final String? priceDisplay;
  final String address;
  final String city;
  final String imageUrl;
  final String? description;
  final String? openHours;
  final String? googleMapsUri;
  final List<String> tags;
  bool isFavorite;

  MapPlace({
    required this.id,
    required this.name,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewCount,
    this.price,
    this.priceDisplay,
    required this.address,
    required this.city,
    required this.imageUrl,
    this.description,
    this.openHours,
    this.googleMapsUri,
    this.tags = const [],
    this.isFavorite = false,
  });

  LatLng get coordinates => LatLng(latitude, longitude);

  /// Menghitung jarak ke lokasi pengguna dalam meter (Haversine Formula)
  double distanceTo(LatLng target) {
    const double earthRadius = 6371000; // meter
    final double dLat = _deg2rad(latitude - target.latitude);
    final double dLon = _deg2rad(longitude - target.longitude);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(target.latitude)) *
            math.cos(_deg2rad(latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  /// Menampilkan teks jarak yang rapi (misal: "450 m" atau "2.4 km")
  String formattedDistanceTo(LatLng target) {
    final double meters = distanceTo(target);
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final double km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  static double _deg2rad(double deg) => deg * (math.pi / 180.0);

  MapPlace copyWith({
    String? id,
    String? name,
    PlaceCategory? category,
    double? latitude,
    double? longitude,
    double? rating,
    int? reviewCount,
    double? price,
    String? priceDisplay,
    String? address,
    String? city,
    String? imageUrl,
    String? description,
    String? openHours,
    String? googleMapsUri,
    List<String>? tags,
    bool? isFavorite,
  }) {
    return MapPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      price: price ?? this.price,
      priceDisplay: priceDisplay ?? this.priceDisplay,
      address: address ?? this.address,
      city: city ?? this.city,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      openHours: openHours ?? this.openHours,
      googleMapsUri: googleMapsUri ?? this.googleMapsUri,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
