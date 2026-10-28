import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

enum PlaceCategory {
  all('all', 'Semua', 'All'),
  amusement('amusement', 'Hiburan', 'Amusement'),
  hotel('hotel', 'Hotel', 'Hotel'),
  park('park', 'Taman', 'Park'),
  restaurants('restaurants', 'Kuliner', 'Culinary'),
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
        lower.contains('restaurant') ||
        lower.contains('food')) {
      return PlaceCategory.restaurants;
    }
    if (lower.contains('hotel') ||
        lower.contains('resort') ||
        lower.contains('villa') ||
        lower.contains('penginapan') ||
        lower.contains('hostel') ||
        lower.contains('lodging')) {
      return PlaceCategory.hotel;
    }
    if (lower.contains('amuse') ||
        lower.contains('wahana') ||
        lower.contains('tematik') ||
        lower.contains('lampion') ||
        lower.contains('hiburan') ||
        lower.contains('bermain') ||
        lower.contains('attraction') ||
        lower.contains('museum') ||
        lower.contains('zoo')) {
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
        lower.contains('lembah') ||
        lower.contains('garden')) {
      return PlaceCategory.park;
    }
    return PlaceCategory.amusement;
  }
}

/// 8 Arah Mata Angin (Cardinal Directions)
enum CompassDirection {
  north('Utara', 'North', 'U', 'N', 0),
  northEast('Timur Laut', 'Northeast', 'TL', 'NE', 45),
  east('Timur', 'East', 'T', 'E', 90),
  southEast('Tenggara', 'Southeast', 'TG', 'SE', 135),
  south('Selatan', 'South', 'S', 'S', 180),
  southWest('Barat Daya', 'Southwest', 'BD', 'SW', 225),
  west('Barat', 'West', 'B', 'W', 270),
  northWest('Barat Laut', 'Northwest', 'BL', 'NW', 315);

  final String labelId;
  final String labelEn;
  final String abbrId;
  final String abbrEn;
  final double angleDegrees;

  const CompassDirection(
    this.labelId,
    this.labelEn,
    this.abbrId,
    this.abbrEn,
    this.angleDegrees,
  );

  String localizedLabel(bool isEnglish) => isEnglish ? labelEn : labelId;
  String localizedAbbr(bool isEnglish) => isEnglish ? abbrEn : abbrId;

  /// Konversi sudut bearing (0 - 360 derajat) ke 8 arah mata angin
  static CompassDirection fromBearing(double bearing) {
    final normalized = (bearing % 360.0 + 360.0) % 360.0;
    if (normalized >= 337.5 || normalized < 22.5) {
      return CompassDirection.north;
    } else if (normalized < 67.5) {
      return CompassDirection.northEast;
    } else if (normalized < 112.5) {
      return CompassDirection.east;
    } else if (normalized < 157.5) {
      return CompassDirection.southEast;
    } else if (normalized < 202.5) {
      return CompassDirection.south;
    } else if (normalized < 247.5) {
      return CompassDirection.southWest;
    } else if (normalized < 292.5) {
      return CompassDirection.west;
    } else {
      return CompassDirection.northWest;
    }
  }
}

/// Menghitung sudut bearing (0 - 360 derajat) dari titik asal ke titik tujuan
double calculateBearing(LatLng from, LatLng to) {
  final double lat1 = from.latitude * (math.pi / 180.0);
  final double lon1 = from.longitude * (math.pi / 180.0);
  final double lat2 = to.latitude * (math.pi / 180.0);
  final double lon2 = to.longitude * (math.pi / 180.0);

  final double dLon = lon2 - lon1;
  final double y = math.sin(dLon) * math.cos(lat2);
  final double x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

  final double radians = math.atan2(y, x);
  final double degrees = radians * (180.0 / math.pi);
  return (degrees + 360.0) % 360.0;
}

/// Informasi Rute Perjalanan Garis Lurus (Bearing & Distance)
class RouteInfo {
  final LatLng origin;
  final MapPlace destination;
  final double distanceMeters;
  final double bearingDegrees;
  final CompassDirection direction;

  RouteInfo({
    required this.origin,
    required this.destination,
    required this.distanceMeters,
    required this.bearingDegrees,
    required this.direction,
  });

  /// Factory untuk membuat RouteInfo secara otomatis dari titik awal dan destinasi
  factory RouteInfo.fromLocations({
    required LatLng origin,
    required MapPlace destination,
  }) {
    final distance = destination.distanceTo(origin);
    final bearing = calculateBearing(origin, destination.coordinates);
    final dir = CompassDirection.fromBearing(bearing);
    return RouteInfo(
      origin: origin,
      destination: destination,
      distanceMeters: distance,
      bearingDegrees: bearing,
      direction: dir,
    );
  }

  /// Teks format jarak (misal: "850 m" atau "2.4 km")
  String formattedDistance() {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    final double km = distanceMeters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  /// Estimasi waktu berjalan kaki (asumsi kecepatan ~80 meter/menit)
  int get estimatedWalkingMinutes => (distanceMeters / 80).ceil().clamp(1, 999);

  /// Estimasi waktu berkendara (asumsi kecepatan rata-rata kota ~400 meter/menit)
  int get estimatedDrivingMinutes =>
      (distanceMeters / 400).ceil().clamp(1, 999);
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

  /// Menghitung sudut bearing dari posisi pengguna ke tempat ini
  double bearingFrom(LatLng userLocation) =>
      calculateBearing(userLocation, coordinates);

  /// Menghitung arah mata angin dari posisi pengguna ke tempat ini
  CompassDirection directionFrom(LatLng userLocation) =>
      CompassDirection.fromBearing(bearingFrom(userLocation));

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
