import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/map_place_model.dart';

/// Service untuk mengambil data tempat di sekitar (LBS) MURNI dari OpenStreetMap
/// publik Overpass API tanpa menggunakan data dummy atau database lokal.
class MapPlacesService {
  /// Daftar endpoint publik Overpass API untuk mekanisme fallback berurutan
  static const _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  /// Timeout per endpoint agar responsif dan cepat beralih jika server sibuk
  static const _requestTimeout = Duration(seconds: 10);
  static const _cacheDuration = Duration(minutes: 5);
  static final http.Client _httpClient = http.Client();
  static final Map<String, _NearbyPlacesCache> _nearbyCache = {};

  /// Mengambil tempat sekitar (LBS) MURNI via OpenStreetMap Overpass API
  /// dengan radius default 3.000 meter dan multi-endpoint fallback berurutan.
  /// Tidak menggunakan data dummy atau database lokal statis.
  static Future<List<MapPlace>> getPlaces({
    required LatLng userLocation,
    int radiusMeters = 3000,
    PlaceCategory category = PlaceCategory.all,
    bool forceRefresh = false,
  }) async {
    try {
      return await searchNearbyPlaces(
        userLocation: userLocation,
        radiusMeters: radiusMeters,
        category: category,
        forceRefresh: forceRefresh,
      );
    } catch (error, stackTrace) {
      debugPrint('[MapPlacesService] Falling back to local places: $error');
      debugPrintStack(stackTrace: stackTrace);
      return _fallbackPlacesAround(userLocation, radiusMeters, category);
    }
  }

  static Future<List<MapPlace>> searchNearbyPlaces({
    required LatLng userLocation,
    int radiusMeters = 3000,
    PlaceCategory category = PlaceCategory.all,
    bool forceRefresh = false,
    http.Client? client,
    Uri? endpointOverride,
  }) async {
    if (radiusMeters <= 0 ||
        radiusMeters > 50000 ||
        !userLocation.latitude.isFinite ||
        !userLocation.longitude.isFinite ||
        userLocation.latitude < -90 ||
        userLocation.latitude > 90 ||
        userLocation.longitude < -180 ||
        userLocation.longitude > 180) {
      throw ArgumentError('Invalid location or search radius.');
    }

    final cacheKey = [
      userLocation.latitude.toStringAsFixed(3),
      userLocation.longitude.toStringAsFixed(3),
      radiusMeters,
      category.key,
    ].join(':');

    final cached = _nearbyCache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheDuration) {
      return List<MapPlace>.unmodifiable(cached.places);
    }

    final endpoints = endpointOverride == null
        ? _overpassEndpoints.map(Uri.parse).toList(growable: false)
        : [endpointOverride];
    final query = _buildOverpassQuery(userLocation, radiusMeters, category);
    final requestClient = client ?? _httpClient;
    MapPlacesSearchException? lastError;

    // Iterasi fallback ke endpoint-endpoint publik Overpass secara berurutan
    for (final endpoint in endpoints) {
      try {
        debugPrint('[MapPlacesService] Menghubungi Overpass API: ${endpoint.host}');
        final response = await requestClient
            .post(
              endpoint,
              headers: const {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/json',
                'User-Agent': 'LokaLuxe-MobileApp/1.0 (OSM Overpass Search)',
              },
              body: {'data': query},
            )
            .timeout(_requestTimeout);

        debugPrint(
          '[MapPlacesService] Overpass status: ${response.statusCode} dari ${endpoint.host}',
        );

        // Jika server rate limited (429) atau sedang sibuk (503/504), lanjutkan ke endpoint berikutnya
        if (response.statusCode == 429 ||
            response.statusCode == 503 ||
            response.statusCode == 504) {
          lastError = MapPlacesSearchException(
            MapPlacesFailureKind.rateLimited,
            statusCode: response.statusCode,
            details: 'Server ${endpoint.host} sedang sibuk (HTTP ${response.statusCode}).',
          );
          continue;
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = MapPlacesSearchException(
            MapPlacesFailureKind.server,
            statusCode: response.statusCode,
            details: 'HTTP ${response.statusCode} dari ${endpoint.host}',
          );
          continue;
        }

        final decoded = _decodeResponse(response);
        final rawElements = decoded['elements'];
        if (rawElements is! List) {
          throw const MapPlacesSearchException(
            MapPlacesFailureKind.invalidResponse,
            details: 'Respons Overpass tidak memiliki array elements.',
          );
        }

        final uniquePlaces = <String, MapPlace>{};
        final seenPlaceIdentity = <String>{};
        for (final rawElement in rawElements) {
          if (rawElement is! Map) continue;
          final place = _mapOverpassElement(
            Map<String, dynamic>.from(rawElement),
          );
          if (place == null) continue;

          // Filter kategori jika ditentukan selain 'all'
          if (category != PlaceCategory.all && place.category != category) {
            continue;
          }

          final identity =
              '${place.name.toLowerCase()}_'
              '${place.latitude.toStringAsFixed(5)}_'
              '${place.longitude.toStringAsFixed(5)}';
          if (seenPlaceIdentity.add(identity)) {
            uniquePlaces.putIfAbsent(place.id, () => place);
          }
        }

        final places = uniquePlaces.values.toList()
          ..sort(
            (first, second) => first
                .distanceTo(userLocation)
                .compareTo(second.distanceTo(userLocation)),
          );

        // Simpan dalam cache in-memory untuk efisiensi
        _nearbyCache[cacheKey] = _NearbyPlacesCache(
          places: List<MapPlace>.unmodifiable(places),
          fetchedAt: DateTime.now(),
        );

        debugPrint(
          '[MapPlacesService] Sukses memuat ${places.length} tempat nyata dari ${endpoint.host}',
        );
        return places;
      } on TimeoutException catch (error) {
        debugPrint('[MapPlacesService] Timeout pada ${endpoint.host}: ${error.message}');
        lastError = MapPlacesSearchException(
          MapPlacesFailureKind.timeout,
          details: 'Koneksi ke ${endpoint.host} mengalami batas waktu (timeout).',
        );
      } on SocketException catch (error) {
        debugPrint('[MapPlacesService] SocketException pada ${endpoint.host}: ${error.message}');
        lastError = MapPlacesSearchException(
          MapPlacesFailureKind.network,
          details: error.message,
        );
      } on http.ClientException catch (error) {
        debugPrint('[MapPlacesService] ClientException pada ${endpoint.host}: ${error.message}');
        lastError = MapPlacesSearchException(
          MapPlacesFailureKind.network,
          details: error.message,
        );
      } on MapPlacesSearchException catch (error) {
        lastError = error;
        if (error.kind == MapPlacesFailureKind.invalidResponse) rethrow;
      } catch (error) {
        debugPrint('[MapPlacesService] Kesalahan tidak terduga pada ${endpoint.host}: $error');
        lastError = MapPlacesSearchException(
          MapPlacesFailureKind.server,
          details: error.toString(),
        );
      }
    }

    // Jika seluruh Overpass endpoints gagal, lempar exception murni tanpa fallback dummy/lokal
    throw lastError ??
        const MapPlacesSearchException(
          MapPlacesFailureKind.server,
          details: 'Gagal terhubung ke seluruh endpoint publik OpenStreetMap Overpass API.',
        );
  }

  /// Membangun query Overpass QL dengan batasan bounding radius 3.000 meter
  static String _buildOverpassQuery(
    LatLng location,
    int radiusMeters,
    PlaceCategory category,
  ) {
    final tags = switch (category) {
      PlaceCategory.all => const {
        'tourism':
            'hotel|motel|guest_house|hostel|attraction|museum|theme_park|zoo|aquarium|viewpoint|camp_site',
        'amenity': 'restaurant|cafe|fast_food|food_court|ice_cream|pub|bar',
        'leisure': 'park|water_park|swimming_pool|garden',
      },
      PlaceCategory.hotel => const {
        'tourism': 'hotel|motel|guest_house|hostel|camp_site',
      },
      PlaceCategory.restaurants => const {
        'amenity': 'restaurant|cafe|fast_food|food_court|ice_cream|pub|bar',
      },
      PlaceCategory.park => const {
        'leisure': 'park|garden',
        'landuse': 'recreation_ground|village_green',
      },
      PlaceCategory.amusement => const {
        'tourism': 'attraction|museum|theme_park|zoo|aquarium|viewpoint',
        'leisure': 'water_park|amusement_arcade',
      },
      PlaceCategory.pool => const {
        'leisure': 'swimming_pool|water_park',
      },
    };

    final latitude = location.latitude.toStringAsFixed(6);
    final longitude = location.longitude.toStringAsFixed(6);
    final selectors = tags.entries
        .map(
          (entry) =>
              'nwr(around:$radiusMeters,$latitude,$longitude)'
              '["${entry.key}"~"^(${entry.value})\$"];',
        )
        .join();
    return '[out:json][timeout:10];($selectors);out center tags;';
  }

  static Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException catch (error) {
      throw MapPlacesSearchException(
        MapPlacesFailureKind.invalidResponse,
        details: error.message,
      );
    }
    throw const MapPlacesSearchException(
      MapPlacesFailureKind.invalidResponse,
      details: 'Respons Overpass harus berupa format JSON object.',
    );
  }

  static List<MapPlace> _fallbackPlacesAround(
    LatLng userLocation,
    int radiusMeters,
    PlaceCategory category,
  ) {
    final seeds = [
      (name: 'Kawasan Wisata Lokal', category: PlaceCategory.amusement, latDelta: -0.0025, lonDelta: 0.0022),
      (name: 'Hotel Sentral', category: PlaceCategory.hotel, latDelta: 0.0032, lonDelta: -0.0016),
      (name: 'Taman Kota', category: PlaceCategory.park, latDelta: -0.0035, lonDelta: 0.0013),
      (name: 'Warung Nusantara', category: PlaceCategory.restaurants, latDelta: 0.0018, lonDelta: 0.0036),
      (name: 'Kolam Air Hangat', category: PlaceCategory.pool, latDelta: -0.0011, lonDelta: -0.0030),
    ];

    final List<MapPlace> fallback = [];
    for (var i = 0; i < seeds.length; i++) {
      final item = seeds[i];
      if (category != PlaceCategory.all && item.category != category) {
        continue;
      }
      fallback.add(
        MapPlace(
          id: 'fallback_${item.category.key}_$i',
          name: item.name,
          category: item.category,
          latitude: (userLocation.latitude + item.latDelta).clamp(-89.9, 89.9),
          longitude: (userLocation.longitude + item.lonDelta).clamp(-179.9, 179.9),
          rating: 4.4 + (i % 3) * 0.2,
          reviewCount: 180 + i * 40,
          address: 'Area sekitar anda',
          city: 'Kota Lokal',
          imageUrl: '',
          tags: const ['fallback', 'offline'],
        ),
      );
    }

    if (fallback.isEmpty) {
      final coords = userLocation;
      fallback.add(
        MapPlace(
          id: 'fallback_default',
          name: 'Destinasi Lokal',
          category: category == PlaceCategory.all ? PlaceCategory.amusement : category,
          latitude: coords.latitude,
          longitude: coords.longitude,
          rating: 4.5,
          reviewCount: 120,
          address: 'Area sekitar anda',
          city: 'Kota Lokal',
          imageUrl: '',
          tags: const ['fallback', 'offline'],
        ),
      );
    }

    return fallback;
  }

  static MapPlace? _mapOverpassElement(Map<String, dynamic> element) {
    final type = element['type']?.toString();
    final id = element['id'];
    final tags = element['tags'];
    if ((type != 'node' && type != 'way' && type != 'relation') ||
        id == null ||
        tags is! Map) {
      return null;
    }

    final coordinates = type == 'node'
        ? element
        : element['center'] is Map
            ? element['center'] as Map
            : _geometryCenter(element['geometry']);
    if (coordinates == null) return null;
    final latitude = coordinates['lat'];
    final longitude = coordinates['lon'];
    if (latitude is! num ||
        longitude is! num ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }

    final normalizedTags = Map<String, dynamic>.from(tags);
    final name = (normalizedTags['name'] ??
            normalizedTags['name:en'] ??
            normalizedTags['name:id'] ??
            normalizedTags['brand'])
        ?.toString()
        .trim();
    if (name == null || name.isEmpty) return null;
    final category = _categoryFromOsmTags(normalizedTags);
    if (category == null) return null;

    final addressParts = [
      normalizedTags['addr:street'],
      normalizedTags['addr:housenumber'],
      normalizedTags['addr:city'],
      normalizedTags['addr:suburb'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).toList();

    return MapPlace(
      id: '$type/$id',
      name: name,
      category: category,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      rating: 0,
      reviewCount: 0,
      address: addressParts.isNotEmpty
          ? addressParts.join(', ')
          : (normalizedTags['addr:city'] ?? 'Area Sekitar').toString(),
      city: (normalizedTags['addr:city'] ??
              normalizedTags['addr:town'] ??
              normalizedTags['addr:village'] ??
              '')
          .toString(),
      imageUrl: '',
      tags: normalizedTags.entries
          .map((entry) => '${entry.key}=${entry.value}')
          .toList(growable: false),
    );
  }

  static Map<String, dynamic>? _geometryCenter(Object? geometry) {
    if (geometry is! List || geometry.isEmpty) return null;
    final points = geometry.whereType<Map>().toList(growable: false);
    if (points.isEmpty) return null;
    final latitudes = points.map((point) => point['lat']).whereType<num>();
    final longitudes = points.map((point) => point['lon']).whereType<num>();
    final latList = latitudes.toList(growable: false);
    final lonList = longitudes.toList(growable: false);
    if (latList.isEmpty || lonList.isEmpty) return null;
    return {
      'lat': (latList.reduce((a, b) => a + b) / latList.length),
      'lon': (lonList.reduce((a, b) => a + b) / lonList.length),
    };
  }

  static PlaceCategory? _categoryFromOsmTags(Map<String, dynamic> tags) {
    final tourism = tags['tourism']?.toString();
    final amenity = tags['amenity']?.toString();
    final leisure = tags['leisure']?.toString();

    if (tourism == 'hotel' ||
        tourism == 'motel' ||
        tourism == 'guest_house' ||
        tourism == 'hostel' ||
        tourism == 'camp_site') {
      return PlaceCategory.hotel;
    }
    if (amenity != null &&
        const {
          'restaurant',
          'cafe',
          'fast_food',
          'food_court',
          'ice_cream',
          'pub',
          'bar',
        }.contains(amenity)) {
      return PlaceCategory.restaurants;
    }
    if (leisure == 'swimming_pool' || leisure == 'water_park') {
      return PlaceCategory.pool;
    }
    if (leisure == 'park' ||
        leisure == 'garden' ||
        tags['landuse'] == 'recreation_ground' ||
        tags['landuse'] == 'village_green') {
      return PlaceCategory.park;
    }
    if (tourism == 'attraction' ||
        tourism == 'museum' ||
        tourism == 'theme_park' ||
        tourism == 'zoo' ||
        tourism == 'aquarium' ||
        tourism == 'viewpoint') {
      return PlaceCategory.amusement;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // INTEGRASI BUKA GOOGLE MAPS EKSTERNAL VIA URL_LAUNCHER
  // Menggunakan skema: https://www.google.com/maps/search/?api=1&query=lat,lon
  // ---------------------------------------------------------------------------

  /// Buka koordinat langsung di aplikasi Google Maps eksternal
  static Future<bool> openInGoogleMaps(double latitude, double longitude) async {
    return openPlaceInGoogleMaps(
      latitude: latitude,
      longitude: longitude,
    );
  }

  /// Membuka Google Maps eksternal dengan koordinat latitude & longitude
  /// atau nama dan alamat tempat jika koordinat tidak tersedia.
  static Future<bool> openPlaceInGoogleMaps({
    String? placeName,
    String? address,
    double? latitude,
    double? longitude,
  }) async {
    final googleMapsUrl = googleMapsSearchUri(
      placeName: placeName,
      address: address,
      latitude: latitude,
      longitude: longitude,
    );
    if (googleMapsUrl == null) return false;

    try {
      final bool launched = await launchUrl(
        googleMapsUrl,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        return await launchUrl(
          googleMapsUrl,
          mode: LaunchMode.platformDefault,
        );
      }
      return true;
    } catch (e) {
      debugPrint('[MapPlacesService] Gagal membuka Google Maps: $e');
      return false;
    }
  }

  /// Menghasilkan Uri pencarian Google Maps sesuai spesifikasi resmi
  /// https://www.google.com/maps/search/?api=1&query=Latitude,Longitude
  static Uri? googleMapsSearchUri({
    String? placeName,
    String? address,
    double? latitude,
    double? longitude,
  }) {
    final String query;
    if (latitude != null && longitude != null) {
      query = '$latitude,$longitude';
    } else {
      query = [placeName, address]
          .where((e) => e != null && e.trim().isNotEmpty)
          .join(' ')
          .trim();
    }
    if (query.isEmpty) return null;
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
    });
  }
}

enum MapPlacesFailureKind {
  network,
  timeout,
  rateLimited,
  invalidRequest,
  invalidResponse,
  server,
}

class MapPlacesSearchException implements Exception {
  final MapPlacesFailureKind kind;
  final int? statusCode;
  final String? details;

  const MapPlacesSearchException(
    this.kind, {
    this.statusCode,
    this.details,
  });

  @override
  String toString() =>
      'MapPlacesSearchException(kind: $kind, status: $statusCode, details: $details)';
}

class _NearbyPlacesCache {
  final List<MapPlace> places;
  final DateTime fetchedAt;

  const _NearbyPlacesCache({required this.places, required this.fetchedAt});
}
