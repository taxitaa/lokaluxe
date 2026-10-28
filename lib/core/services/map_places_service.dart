import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/map_place_model.dart';

class MapPlacesService {
  static const _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];
  static const _requestTimeout = Duration(seconds: 25);
  static const _cacheDuration = Duration(minutes: 2);
  static final http.Client _httpClient = http.Client();
  static final Map<String, _NearbyPlacesCache> _nearbyCache = {};

  static Future<List<MapPlace>> searchNearbyPlaces({
    required LatLng userLocation,
    required int radiusMeters,
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

    for (final endpoint in endpoints) {
      try {
        final response = await requestClient
            .post(
              endpoint,
              headers: const {
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/json',
                'User-Agent': 'LokaLuxe/1.0 (nearby places search)',
              },
              body: {'data': query},
            )
            .timeout(_requestTimeout);

        debugPrint(
          '[MapPlacesService] Overpass HTTP ${response.statusCode} '
          'from ${endpoint.host}',
        );
        if (response.statusCode == 429 || response.statusCode == 503) {
          lastError = MapPlacesSearchException(
            MapPlacesFailureKind.rateLimited,
            statusCode: response.statusCode,
          );
          continue;
        }
        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = MapPlacesSearchException(
            MapPlacesFailureKind.server,
            statusCode: response.statusCode,
          );
          continue;
        }

        final decoded = _decodeResponse(response);
        final rawElements = decoded['elements'];
        if (rawElements is! List) {
          throw const MapPlacesSearchException(
            MapPlacesFailureKind.invalidResponse,
            details: 'Overpass response must contain an elements array.',
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
        _nearbyCache[cacheKey] = _NearbyPlacesCache(
          places: List<MapPlace>.unmodifiable(places),
          fetchedAt: DateTime.now(),
        );
        debugPrint(
          '[MapPlacesService] Parsed ${places.length} unique OSM places.',
        );
        return places;
      } on TimeoutException catch (error) {
        lastError = MapPlacesSearchException(
          MapPlacesFailureKind.timeout,
          details: error.message,
        );
      } on http.ClientException catch (error) {
        lastError = MapPlacesSearchException(
          MapPlacesFailureKind.network,
          details: error.message,
        );
      } on MapPlacesSearchException catch (error) {
        lastError = error;
        if (error.kind == MapPlacesFailureKind.invalidResponse) rethrow;
      }
    }

    throw lastError ??
        const MapPlacesSearchException(MapPlacesFailureKind.server);
  }

  static String _buildOverpassQuery(
    LatLng location,
    int radiusMeters,
    PlaceCategory category,
  ) {
    final tags = switch (category) {
      PlaceCategory.all => const {
        'tourism': 'hotel|motel|guest_house|hostel|attraction|museum|theme_park|zoo|aquarium|viewpoint|camp_site',
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
        'landuse': 'recreation_ground',
      },
      PlaceCategory.amusement => const {
        'tourism': 'attraction|museum|theme_park|zoo|aquarium|viewpoint',
        'leisure': 'water_park',
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
    return '[out:json][timeout:20];($selectors);out center tags;';
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
      details: 'Overpass response must be a JSON object.',
    );
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
      address: addressParts.join(', '),
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
        tags['landuse'] == 'recreation_ground') {
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

  static Future<bool> openInGoogleMaps(
    double latitude,
    double longitude, {
    String? placeId,
    String? googleMapsUri,
  }) => openPlaceInGoogleMaps(
    latitude: latitude,
    longitude: longitude,
    placeId: placeId,
    googleMapsUri: googleMapsUri,
  );

  static Future<bool> openPlaceInGoogleMaps({
    String? placeName,
    String? address,
    double? latitude,
    double? longitude,
    String? placeId,
    String? googleMapsUri,
  }) async {
    final uri = googleMapsSearchUri(
      placeName: placeName,
      address: address,
      latitude: latitude,
      longitude: longitude,
      placeId: placeId,
      googleMapsUri: googleMapsUri,
    );
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('[MapPlacesService] Could not open map link: $error');
      return false;
    }
  }

  static Uri? googleMapsSearchUri({
    String? placeName,
    String? address,
    double? latitude,
    double? longitude,
    String? placeId,
    String? googleMapsUri,
  }) {
    final mapsUri = Uri.tryParse(googleMapsUri ?? '');
    if (mapsUri != null &&
        mapsUri.scheme == 'https' &&
        (mapsUri.host == 'maps.google.com' ||
            mapsUri.host == 'www.google.com' ||
            mapsUri.host == 'google.com')) {
      return mapsUri;
    }
    if (placeId != null && placeId.trim().isNotEmpty) {
      return Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': placeName?.trim().isNotEmpty == true
            ? placeName!.trim()
            : 'Place',
        'query_place_id': placeId,
      });
    }
    final validCoordinates =
        latitude != null &&
        longitude != null &&
        latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
    final query = validCoordinates
        ? '$latitude,$longitude'
        : [
            placeName,
            address,
          ].where((part) => part != null && part.trim().isNotEmpty).join(', ');
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
      'MapPlacesSearchException(kind: $kind, status: $statusCode, '
      'details: $details)';
}

class _NearbyPlacesCache {
  final List<MapPlace> places;
  final DateTime fetchedAt;

  const _NearbyPlacesCache({required this.places, required this.fetchedAt});
}
