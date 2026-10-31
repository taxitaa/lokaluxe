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
  /// Daftar endpoint publik Overpass API — DIURUTKAN berdasarkan hasil uji
  /// langsung (2026-10): maps.mail.ru & overpass-api.de sukses memproses query
  /// gabungan area 3 km (400 elemen, ~25 dtk via GET). Mirror overpass.osm.ch
  /// DIHAPUS karena terbukti membalas HTTP 200 dengan 0 elemen palsu untuk
  /// area Indonesia, dan overpass.osm.jp/private.coffee sering tidak
  /// responsif — mirror bermasalah di depan hanya menambah latensi.
  static const _overpassEndpoints = [
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
  ];

  /// Mirror terbukti sukses (maps.mail.ru ~25 dtk untuk area 3 km): dua kali
  /// timeout berurutan dianggap kegagalan mirror dan dipindah ke mirror lain.
  static const _requestTimeout = Duration(seconds: 30);
  static const _cacheDuration = Duration(minutes: 5);
  static const _maxResponseElements = 400;
  static final http.Client _httpClient = http.Client();

  /// Cache hasil pencarian per AREA (koordinat + radius), berisi SEMUA kategori
  /// sekaligus (satu query gabungan). Tab mana pun memfilter dari cache ini di
  /// sisi aplikasi sehingga berpindah tab TIDAK memicu request baru.
  static final Map<String, _NearbyPlacesCache> _nearbyCache = {};

  /// Permintaan Overpass yang sedang berjalan per area (dedupe in-flight):
  /// mencegah request ganda ketika pengguna berpindah tab / lokasi cepat.
  static final Map<String, Future<List<MapPlace>>> _inflightRequests = {};

  /// Jumlah mirror minimal yang harus setuju "0 elemen" sebelum hasil kosong
  /// dipercaya. Beberapa mirror (mis. overpass.osm.ch) membalas HTTP 200
  /// dengan 0 elemen palsu untuk data yang belum lengkap — jika langsung
  /// diterima, SEMUA tab LBS menampilkan "0 tempat" meski tempat ada.
  static const _minMirrorsForEmptyResult = 2;

  /// Kursor endpoint bergilir: mendistribusikan beban antar mirror sehingga
  /// satu server tidak selalu dipukul lebih dulu (menghindari rate-limit).
  static int _endpointCursor = 0;

  /// Mengambil tempat sekitar (LBS) MURNI dari OpenStreetMap.
  /// Strategi: 1) Overpass API (tercepat & paling lengkap); 2) jika seluruh
  /// endpoint Overpass gagal (timeout/rate limit), fallback ke Nominatim
  /// area search per kategori — tetap data nyata OSM, tanpa data dummy.
  /// Hasil terakhir yang sukses diingat per kategori: jika jaringan buruk,
  /// hasil sebelumnya langsung ditampilkan agar UI tetap responsif.
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
    } on MapPlacesSearchException catch (error) {
      debugPrint(
        '[MapPlacesService] Overpass gagal, fallback ke Nominatim: $error',
      );
      // Jangan fallback ke Nominatim untuk kegagalan yang bukan jaringan/
      // server (mis. argumen tidak valid) — langsung lempar.
      if (error.kind == MapPlacesFailureKind.invalidRequest) rethrow;
      try {
        final fallback = await fetchPlacesViaNominatim(
          userLocation: userLocation,
          radiusMeters: radiusMeters,
          category: category,
          forceRefresh: forceRefresh,
        );
        if (fallback.isNotEmpty) return fallback;
      } catch (fallbackError) {
        debugPrint(
          '[MapPlacesService] Fallback Nominatim juga gagal: $fallbackError',
        );
      }

      // Last resort: kembalikan hasil sukses terakhir untuk kategori ini
      // agar UI tidak bolong (masih data nyata, hanya sedikit lebih tua).
      final stale = _lastGoodByCategory[category];
      if (stale != null && stale.isNotEmpty) return stale;

      rethrow;
    }
  }

  /// Hasil sukses terakhir per kategori — jaring pengaman saat jaringan
  /// buruk agar tempat tetap tampil instan (tanpa data dummy).
  static final Map<PlaceCategory, List<MapPlace>> _lastGoodByCategory = {};

  /// Kata kunci pencarian Nominatim per kategori LBS aplikasi.
  /// Memakai kata tunggal (bentuk dasar) karena Nominatim free-text search
  /// jauh lebih akurat dengan bentuk tunggal: "restaurant" bukan "restaurants".
  static const _nominatimCategoryQueries = <PlaceCategory, List<String>>{
    PlaceCategory.hotel: ['hotel', 'penginapan', 'guest house'],
    PlaceCategory.restaurants: [
      'restaurant',
      'restoran',
      'cafe',
      'kafe',
      'bakery',
      'warung makan',
      'food court',
    ],
    PlaceCategory.park: [
      'park',
      'taman',
      'garden',
      'kebun',
      'forest',
      'playground',
    ],
    PlaceCategory.amusement: [
      'museum',
      'theme park',
      'water park',
      'zoo',
      'monument',
      'castle',
      'candi',
      'art gallery',
      'tempat wisata',
      'taman hiburan',
    ],
    PlaceCategory.pool: ['swimming pool', 'water park', 'kolam renang'],
  };

  /// Radius dalam derajat koordinat (perkiraan) dari meter untuk viewbox.
  static double _metersToDegrees(int meters) => meters / 111320.0;

  /// Fallback LBS via Nominatim area-bounded search (masih data nyata OSM).
  /// Mengembalikan daftar kosong jika Nominatim juga gagal.
  static Future<List<MapPlace>> fetchPlacesViaNominatim({
    required LatLng userLocation,
    int radiusMeters = 3000,
    PlaceCategory category = PlaceCategory.all,
    bool forceRefresh = false,
    http.Client? client,
  }) async {
    final delta = _metersToDegrees(radiusMeters);
    final categories = category == PlaceCategory.all
        ? _nominatimCategoryQueries.keys.toList()
        : [category];

    final cacheKey = 'nominatim:${category.key}:$radiusMeters:'
        '${userLocation.latitude.toStringAsFixed(3)}:'
        '${userLocation.longitude.toStringAsFixed(3)}';
    final cached = _nearbyCache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheDuration) {
      return List<MapPlace>.unmodifiable(cached.places);
    }

    final results = <MapPlace>[];
    final seenIdentity = <String>{};
    final requestClient = client ?? _httpClient;

    // PENTING: urutan viewbox Nominatim adalah <lon1>,<lat1>,<lon2>,<lat2>
    // (bukan lat dulu!). Urutan salah membuat Nominatim balas HTTP 400,
    // sehingga fallback Nominatim selalu gagal total.
    final viewbox =
        '${(userLocation.longitude - delta).toStringAsFixed(5)},'
        '${(userLocation.latitude - delta).toStringAsFixed(5)},'
        '${(userLocation.longitude + delta).toStringAsFixed(5)},'
        '${(userLocation.latitude + delta).toStringAsFixed(5)}';

    for (final cat in categories) {
      for (final keyword in _nominatimCategoryQueries[cat] ?? const []) {
        final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
          'q': keyword,
          'format': 'jsonv2',
          'limit': '40',
          'addressdetails': '1',
          'viewbox': viewbox,
          'bounded': '1',
        });
        try {
          final response = await requestClient
              .get(
                uri,
                headers: const {
                  'Accept': 'application/json',
                  'User-Agent':
                      'LokaLuxe-MobileApp/1.0 (OSM Nominatim Nearby)',
                },
              )
              .timeout(_requestTimeout);
          if (response.statusCode < 200 || response.statusCode >= 300) {
            continue;
          }
          final decoded = jsonDecode(response.body);
          if (decoded is! List) continue;

          for (final raw in decoded) {
            if (raw is! Map) continue;
            final item = Map<String, dynamic>.from(raw);
            final lat = double.tryParse(item['lat']?.toString() ?? '');
            final lon = double.tryParse(item['lon']?.toString() ?? '');
            if (lat == null || lon == null) continue;

            final name =
                (item['name'] ?? item['display_name'] ?? '').toString();
            final shortName = name.split(',').first.trim();
            if (shortName.isEmpty) continue;

            final identity = '${shortName.toLowerCase()}_'
                '${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';
            if (!seenIdentity.add(identity)) continue;

            final displayName = item['display_name']?.toString() ?? '';
            final addressParts = displayName
                .split(',')
                .skip(1)
                .map((p) => p.trim())
                .where((p) => p.isNotEmpty)
                .toList();

            results.add(
              MapPlace(
                id: 'nominatim_${item['place_id'] ?? identity}',
                name: shortName,
                category:
                    _categoryFromNominatimItem(item) ?? cat,
                latitude: lat,
                longitude: lon,
                rating: 0,
                reviewCount: 0,
                address: addressParts.isNotEmpty
                    ? addressParts.take(2).join(', ')
                    : '',
                city: addressParts.isNotEmpty
                    ? addressParts[addressParts.length - 1]
                    : '',
                imageUrl: '',
                tags: ['nominatim', 'lbs', cat.key],
              ),
            );
          }
        } catch (_) {
          continue;
        }
      }
    }

    results.sort(
      (a, b) => a
          .distanceTo(userLocation)
          .compareTo(b.distanceTo(userLocation)),
    );

    if (results.isNotEmpty) {
      _nearbyCache[cacheKey] = _NearbyPlacesCache(
        places: List<MapPlace>.unmodifiable(results),
        fetchedAt: DateTime.now(),
      );
    }
    return results;
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
      throw const MapPlacesSearchException(
        MapPlacesFailureKind.invalidRequest,
        details: 'Koordinat lokasi atau radius pencarian tidak valid.',
      );
    }

    // SATU cache per AREA (koordinat + radius) untuk SEMUA kategori.
    final cacheKey = [
      userLocation.latitude.toStringAsFixed(3),
      userLocation.longitude.toStringAsFixed(3),
      radiusMeters,
    ].join(':');

    final cached = _nearbyCache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheDuration) {
      return _filterByCategory(cached.places, category, userLocation);
    }

    // Dedupe in-flight: jika pengguna berpindah tab cepat-cepat, jangan
    // menembak Overpass berulang — tunggu request yang sedang berjalan.
    final inflight = _inflightRequests[cacheKey];
    if (inflight != null) {
      final places = await inflight;
      return _filterByCategory(places, category, userLocation);
    }

    final Future<List<MapPlace>> request = _fetchPlacesFromOverpass(
      cacheKey: cacheKey,
      userLocation: userLocation,
      radiusMeters: radiusMeters,
      client: client,
      endpointOverride: endpointOverride,
    );
    _inflightRequests[cacheKey] = request;
    try {
      final places = await request;
      return _filterByCategory(places, category, userLocation);
    } finally {
      _inflightRequests.remove(cacheKey);
    }
  }

  /// Memfilter hasil area gabungan per kategori LBS di sisi aplikasi.
  static List<MapPlace> _filterByCategory(
    List<MapPlace> places,
    PlaceCategory category,
    LatLng userLocation,
  ) {
    final filtered = category == PlaceCategory.all
        ? places.toList()
        : places.where((place) => place.category == category).toList();
    filtered.sort(
      (a, b) => a
          .distanceTo(userLocation)
          .compareTo(b.distanceTo(userLocation)),
    );
    if (filtered.isNotEmpty) {
      _lastGoodByCategory[category] = filtered;
    }
    return List<MapPlace>.unmodifiable(filtered);
  }

  /// Mengambil SEMUA kategori dalam SATU query Overpass gabungan, lalu
  /// menyimpannya sebagai cache area. Endpoint dicoba BERURUTAN mulai dari
  /// mirror bergilir (bukan paralel) agar tidak memicu rate-limit Overpass.
  static Future<List<MapPlace>> _fetchPlacesFromOverpass({
    required String cacheKey,
    required LatLng userLocation,
    required int radiusMeters,
    http.Client? client,
    Uri? endpointOverride,
  }) async {
    final endpoints = endpointOverride == null
        ? _overpassEndpoints.map(Uri.parse).toList(growable: false)
        : [endpointOverride];
    final query = _buildOverpassQuery(userLocation, radiusMeters);
    final requestClient = client ?? _httpClient;
    MapPlacesSearchException? firstError;
    var emptyResultMirrors = 0;

    for (var offset = 0; offset < endpoints.length; offset++) {
      final endpoint = endpoints[(_endpointCursor + offset) % endpoints.length];

      try {
        debugPrint(
          '[MapPlacesService] Menghubungi Overpass API: ${endpoint.host}',
        );
        // GET (bukan POST): mirror maps.mail.ru terbukti gagal/mengembalikan
        // hasil rusak lewat POST form-encoded, tetapi sukses lewat GET.
        final uri = endpoint.replace(
          queryParameters: {'data': query},
        );
        final response = await requestClient
            .get(
              uri,
              headers: const {
                'Accept': 'application/json',
                'User-Agent':
                    'LokaLuxe-MobileApp/1.0 (OSM Overpass Search; contact: lokaluxe@lokaluxe.app)',
              },
            )
            .timeout(_requestTimeout);

        // Server menolak (406) / rate limited (429) / sibuk (503/504) →
        // tandai gagal; lanjut ke mirror berikutnya secara berurutan.
        if (response.statusCode == 406 ||
            response.statusCode == 429 ||
            response.statusCode == 503 ||
            response.statusCode == 504) {
          firstError ??= MapPlacesSearchException(
            response.statusCode == 429
                ? MapPlacesFailureKind.rateLimited
                : MapPlacesFailureKind.server,
            statusCode: response.statusCode,
            details:
                'Server ${endpoint.host} menolak/sibuk (HTTP ${response.statusCode}).',
          );
          continue;
        }

        if (response.statusCode < 200 || response.statusCode >= 300) {
          firstError ??= MapPlacesSearchException(
            MapPlacesFailureKind.server,
            statusCode: response.statusCode,
            details: 'HTTP ${response.statusCode} dari ${endpoint.host}',
          );
          continue;
        }

        final decoded = _decodeResponse(response);
        final rawElements = decoded['elements'];
        if (rawElements is! List) {
          firstError ??= const MapPlacesSearchException(
            MapPlacesFailureKind.invalidResponse,
            details: 'Respons Overpass tidak memiliki array elements.',
          );
          continue;
        }

        // Hasil 0 elemen dari SATU mirror tidak langsung dipercaya: beberapa
        // mirror publik membalas HTTP 200 + 0 elemen palsu (data belum
        // lengkap). Coba mirror lain; "kosong" baru sah jika >= 2 mirror
        // sepakat, atau jika hanya ada satu endpoint yang tersedia.
        if (rawElements.isEmpty &&
            endpoints.length > 1 &&
            emptyResultMirrors + 1 < _minMirrorsForEmptyResult) {
          emptyResultMirrors++;
          debugPrint(
            '[MapPlacesService] ${endpoint.host} mengembalikan 0 elemen '
            '(diduga data tidak lengkap) — mencoba mirror lain.',
          );
          firstError ??= MapPlacesSearchException(
            MapPlacesFailureKind.suspectedIncomplete,
            details: '${endpoint.host} mengembalikan hasil kosong yang mencurigakan.',
          );
          continue;
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

        debugPrint(
          '[MapPlacesService] Sukses memuat ${places.length} tempat nyata dari ${endpoint.host}',
        );

        // Simpan hasil GABUNGAN seluruh kategori dalam cache area.
        _nearbyCache[cacheKey] = _NearbyPlacesCache(
          places: List<MapPlace>.unmodifiable(places),
          fetchedAt: DateTime.now(),
        );

        // Geser kursor endpoint agar request berikutnya mulai dari mirror lain.
        _endpointCursor = (_endpointCursor + offset + 1) % endpoints.length;
        return places;
      } on TimeoutException catch (error) {
        debugPrint('[MapPlacesService] Timeout pada ${endpoint.host}: ${error.message}');
        firstError ??= MapPlacesSearchException(
          MapPlacesFailureKind.timeout,
          details: 'Koneksi ke ${endpoint.host} mengalami batas waktu (timeout).',
        );
      } on SocketException catch (error) {
        debugPrint('[MapPlacesService] SocketException pada ${endpoint.host}: ${error.message}');
        firstError ??= MapPlacesSearchException(
          MapPlacesFailureKind.network,
          details: error.message,
        );
      } on http.ClientException catch (error) {
        debugPrint('[MapPlacesService] ClientException pada ${endpoint.host}: ${error.message}');
        firstError ??= MapPlacesSearchException(
          MapPlacesFailureKind.network,
          details: error.message,
        );
      } on MapPlacesSearchException catch (error) {
        firstError ??= error;
      } catch (error) {
        debugPrint('[MapPlacesService] Kesalahan tidak terduga pada ${endpoint.host}: $error');
        firstError ??= MapPlacesSearchException(
          MapPlacesFailureKind.server,
          details: error.toString(),
        );
      }
    }

    // Jika seluruh Overpass endpoints gagal, lempar exception murni tanpa fallback dummy/lokal
    throw firstError ??
        const MapPlacesSearchException(
          MapPlacesFailureKind.server,
          details: 'Gagal terhubung ke seluruh endpoint publik OpenStreetMap Overpass API.',
        );
  }

  /// Membangun query Overpass QL gabungan (SEMUA kategori LBS aplikasi dalam
  /// satu permintaan) dengan batasan radius. Kategori dipisahkan di sisi
  /// aplikasi lewat [_filterByCategory] sehingga satu fetch melayani kelima
  /// tab dan tidak ada request berulang saat berpindah tab.
  static String _buildOverpassQuery(
    LatLng location,
    int radiusMeters,
  ) {
    const tags = {
      'tourism':
          'hotel|motel|guest_house|hostel|apartment|resort|camp_site|attraction|museum|theme_park|zoo|aquarium|viewpoint|artwork|gallery',
      'amenity':
          'restaurant|cafe|fast_food|food_court|ice_cream|pub|bar|biergarten|public_bath|swimming_area',
      'leisure':
          'park|water_park|swimming_pool|garden|nature_reserve|playground|sports_centre|amusement_arcade|escape_game|horse_riding',
      'shop': 'bakery|convenience|deli|greengrocer|seafood',
      'landuse': 'recreation_ground|village_green|forest',
      'natural': 'beach|peak|waterfall|wood|scrub|hot_spring|spring',
      'historic': 'monument|memorial|castle|ruins|fort',
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
    return '[out:json][timeout:10];($selectors);out center tags $_maxResponseElements;';
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
    final shop = tags['shop']?.toString();
    final natural = tags['natural']?.toString();
    final historic = tags['historic']?.toString();

    if (tourism == 'hotel' ||
        tourism == 'motel' ||
        tourism == 'guest_house' ||
        tourism == 'hostel' ||
        tourism == 'apartment' ||
        tourism == 'resort' ||
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
          'biergarten',
        }.contains(amenity)) {
      return PlaceCategory.restaurants;
    }
    if (shop != null &&
        const {
          'bakery',
          'deli',
          'convenience',
          'seafood',
          'greengrocer',
        }.contains(shop)) {
      return PlaceCategory.restaurants;
    }
    if (leisure == 'swimming_pool' ||
        leisure == 'water_park' ||
        amenity == 'public_bath' ||
        amenity == 'swimming_area' ||
        natural == 'hot_spring' ||
        natural == 'spring') {
      return PlaceCategory.pool;
    }
    if (leisure == 'park' ||
        leisure == 'garden' ||
        leisure == 'nature_reserve' ||
        leisure == 'playground' ||
        leisure == 'sports_centre' ||
        tags['landuse'] == 'recreation_ground' ||
        tags['landuse'] == 'village_green' ||
        tags['landuse'] == 'forest' ||
        natural == 'beach' ||
        natural == 'peak' ||
        natural == 'waterfall' ||
        natural == 'wood' ||
        natural == 'scrub') {
      return PlaceCategory.park;
    }
    if (tourism == 'attraction' ||
        tourism == 'museum' ||
        tourism == 'theme_park' ||
        tourism == 'zoo' ||
        tourism == 'aquarium' ||
        tourism == 'viewpoint' ||
        tourism == 'artwork' ||
        tourism == 'gallery' ||
        leisure == 'amusement_arcade' ||
        leisure == 'escape_game' ||
        leisure == 'horse_riding' ||
        historic == 'monument' ||
        historic == 'memorial' ||
        historic == 'castle' ||
        historic == 'ruins' ||
        historic == 'fort') {
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

  // ---------------------------------------------------------------------------
  // RUTE JALAN NYATA (STREET-LEVEL) VIA OSRM (OpenStreetMap Routing Machine)
  // Menghasilkan polyline rute persis mengikuti jalan — bukan garis lurus
  // maupun rangkaian jalan kasar dari Overpass.
  // ---------------------------------------------------------------------------

  /// Daftar server OSRM publik untuk fallback berurutan
  static const _osrmEndpoints = [
    'https://router.project-osrm.org/route/v1/driving/',
    'https://routing.openstreetmap.de/routed-car/route/v1/driving/',
  ];

  /// Mengambil rute mengikuti jalan nyata dari OSRM.
  /// Mengembalikan daftar titik dari [origin] ke [destination]. Jika OSRM
  /// gagal, daftar kosong dikembalikan sehingga pemanggil dapat memakai
  /// garis lurus sebagai fallback.
  static Future<List<LatLng>> fetchDrivingRoutePolyline({
    required LatLng origin,
    required LatLng destination,
    http.Client? client,
  }) async {
    final coordinates =
        '${origin.longitude.toStringAsFixed(6)},${origin.latitude.toStringAsFixed(6)};'
        '${destination.longitude.toStringAsFixed(6)},${destination.latitude.toStringAsFixed(6)}';

    final requestClient = client ?? _httpClient;
    for (final base in _osrmEndpoints) {
      try {
        final uri = Uri.parse('$base$coordinates')
            .replace(queryParameters: {
          'overview': 'full',
          'geometries': 'polyline',
          'steps': 'false',
        });
        final response = await requestClient.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': 'LokaLuxe-MobileApp/1.0 (OSRM Route)',
          },
        ).timeout(_requestTimeout);
        if (response.statusCode < 200 || response.statusCode >= 300) continue;

        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) continue;
        final code = decoded['code']?.toString();
        if (code != 'Ok') continue;

        final routes = decoded['routes'];
        if (routes is! List || routes.isEmpty) continue;
        final route = routes.first;
        if (route is! Map) continue;

        final geometry = route['geometry'];
        if (geometry is! String || geometry.isEmpty) continue;

        final points = _decodePolyline(geometry);
        if (points.length < 2) continue;
        return points;
      } on TimeoutException {
        continue;
      } catch (_) {
        continue;
      }
    }
    return const [];
  }

  /// Dekoder polyline encoding Google/OSRM (precision 1e5)
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lon = 0;

    while (index < encoded.length) {
      final resultLat = _decodePolylineValue(encoded, index);
      lat += resultLat.value;
      index = resultLat.nextIndex;

      final resultLon = _decodePolylineValue(encoded, index);
      lon += resultLon.value;
      index = resultLon.nextIndex;

      points.add(LatLng(lat / 1e5, lon / 1e5));
    }
    return points;
  }

  static ({int value, int nextIndex}) _decodePolylineValue(
    String encoded,
    int startIndex,
  ) {
    var index = startIndex;
    var shift = 0;
    var result = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    final value = result & 1 != 0 ? ~(result >> 1) : (result >> 1);
    return (value: value, nextIndex: index);
  }

  // ---------------------------------------------------------------------------
  // PENCARIAN TEMPAT BERDASARKAN TEKS (NOMINATIM / OPENSTREETMAP SEARCH API)
  // Dipakai search bar navigator: mencari tempat nyata di sekitar lokasi
  // pengguna (amusement, hotel, park, kuliner, dll), bukan sekadar memfilter
  // hasil yang sudah ada.
  // ---------------------------------------------------------------------------

  /// Kategori LBS yang bisa dicari lewat search bar beserta kata kunci
  /// OSM-nya (untuk pemetaan query → kategori MapPlace).
  static const _searchKeywordCategory = <PlaceCategory, List<String>>{
    PlaceCategory.restaurants: [
      'restaurant', 'restoran', 'rumah makan', 'warung', 'cafe', 'kafe',
      'kuliner', 'makan', 'food', 'coffee', 'bakery', 'bar',
    ],
    PlaceCategory.hotel: [
      'hotel', 'penginapan', 'motel', 'guest house', 'hostel', 'villa',
      'resort', 'lodging', 'inn',
    ],
    PlaceCategory.park: [
      'park', 'taman', 'garden', 'kebun', 'hutan', 'forest', 'alam',
      'nature', 'beach', 'pantai', 'gunung', 'mountain',
    ],
    PlaceCategory.amusement: [
      'amusement', 'hiburan', 'wahana', 'museum', 'attraction', 'atraksi',
      'zoo', 'kebun binatang', 'waterpark', 'theme park', 'gallery',
      'galeri', 'monumen', 'candi', 'tempat wisata', 'wisata',
    ],
    PlaceCategory.pool: [
      'pool', 'kolam', 'waterpark', 'water park', 'pemandian', 'spring',
    ],
  };

  /// Mencari tempat berdasarkan teks pencarian umum (ala Google Maps).
  /// Strategi dua mesin pencari OSM DIPACU PARALEL — hasil valid pertama
  /// langsung dipakai (responsif seperti Google Maps):
  ///   1) Nominatim (resmi OSM) — bebas mencari nama tempat, alamat, jalan,
  ///      kota, POI apa pun; viewbox dipakai hanya sebagai bias prioritas
  ///      hasil terdekat (bounded=0) sehingga hasil global tetap muncul.
  ///   2) Photon (Komoot) berlomba bersamaan; hasilnya dipakai jika lebih
  ///      dulu datang ATAU Nominatim gagal/kosong. Keduanya data OSM nyata.
  static Future<List<MapPlace>> searchPlacesByText({
    required String query,
    required LatLng userLocation,
    int limit = 30,
    http.Client? client,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final nominatimFuture = _searchPlacesByTextNominatim(
      query: trimmed,
      userLocation: userLocation,
      limit: limit,
      client: client,
    );
    final photonFuture = _searchPlacesByTextPhoton(
      query: trimmed,
      userLocation: userLocation,
      limit: limit,
      client: client,
    );

    // Ambil respons valid pertama dari salah satu geocoder.
    final pending = <Future<List<MapPlace>>>[nominatimFuture, photonFuture];
    final futures = List.of(pending);
    while (futures.isNotEmpty) {
      final winner = await Future.any(futures.map((f) async {
        final r = await f;
        return (future: f, result: r);
      }));
      futures.remove(winner.future);
      if (winner.result.isNotEmpty) return winner.result;
    }
    return const [];
  }

  static Future<List<MapPlace>> _searchPlacesByTextNominatim({
    required String query,
    required LatLng userLocation,
    int limit = 30,
    http.Client? client,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final viewboxHalfDegrees = 0.04; // bias area ~radius 3-4 km, tidak membatasi
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '$limit',
      'addressdetails': '1',
      // PENTING: urutan viewbox Nominatim = lon1,lat1,lon2,lat2 (bukan lat
      // dulu!). Urutan salah membuat Nominatim balas HTTP 400.
      'viewbox':
          '${(userLocation.longitude - viewboxHalfDegrees).toStringAsFixed(5)},'
          '${(userLocation.latitude - viewboxHalfDegrees).toStringAsFixed(5)},'
          '${(userLocation.longitude + viewboxHalfDegrees).toStringAsFixed(5)},'
          '${(userLocation.latitude + viewboxHalfDegrees).toStringAsFixed(5)}',
      'bounded': '0',
    });

    final requestClient = client ?? _httpClient;
    try {
      final response = await requestClient.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'LokaLuxe-MobileApp/1.0 (OSM Nominatim Nearby Search)',
        },
      ).timeout(_requestTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];

      final places = <MapPlace>[];
      final seenIdentity = <String>{};
      for (final raw in decoded) {
        if (raw is! Map) continue;
        final item = Map<String, dynamic>.from(raw);
        final lat = double.tryParse(item['lat']?.toString() ?? '');
        final lon = double.tryParse(item['lon']?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final name = (item['name'] ??
                item['display_name'] ??
                '')
            .toString();
        final shortName = name.split(',').first.trim();
        if (shortName.isEmpty) continue;

        final category =
            _categoryFromNominatimItem(item) ?? PlaceCategory.amusement;

        final identity = '${shortName.toLowerCase()}_'
            '${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';
        if (!seenIdentity.add(identity)) continue;

        final displayName = item['display_name']?.toString() ?? '';
        final addressParts = displayName
            .split(',')
            .skip(1)
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();

        places.add(
          MapPlace(
            id: 'nominatim_${item['place_id'] ?? identity}',
            name: shortName,
            category: category,
            latitude: lat,
            longitude: lon,
            rating: 0,
            reviewCount: 0,
            address:
                addressParts.isNotEmpty ? addressParts.take(2).join(', ') : '',
            city: addressParts.isNotEmpty
                ? addressParts[addressParts.length - 1]
                : '',
            imageUrl: '',
            tags: const ['nominatim', 'search'],
          ),
        );
      }

      places.sort(
        (a, b) => a.distanceTo(userLocation).compareTo(b.distanceTo(userLocation)),
      );
      return places;
    } catch (error) {
      debugPrint('[MapPlacesService] Nominatim search gagal: $error');
      return const [];
    }
  }

  /// Pencarian teks via Photon (Komoot) — geocoder berbasis data OSM.
  /// Dipakai sebagai fallback ketika Nominatim gagal/kosong.
  static Future<List<MapPlace>> _searchPlacesByTextPhoton({
    required String query,
    required LatLng userLocation,
    int limit = 30,
    http.Client? client,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.https('photon.komoot.io', '/api', {
      'q': trimmed,
      'lat': userLocation.latitude.toStringAsFixed(5),
      'lon': userLocation.longitude.toStringAsFixed(5),
      'limit': '$limit',
      'lang': 'id',
    });
    final requestClient = client ?? _httpClient;
    try {
      final response = await requestClient.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'User-Agent': 'LokaLuxe-MobileApp/1.0 (Photon Fallback Search)',
        },
      ).timeout(_requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return const [];
      final features = decoded['features'];
      if (features is! List) return const [];

      final places = <MapPlace>[];
      final seenIdentity = <String>{};
      for (final raw in features) {
        if (raw is! Map) continue;
        final feature = Map<String, dynamic>.from(raw);
        final geometry = feature['geometry'];
        final props = feature['properties'];
        if (geometry is! Map || props is! Map) continue;
        final coords = geometry['coordinates'];
        if (coords is! List || coords.length < 2) continue;
        final lon = double.tryParse(coords[0]?.toString() ?? '');
        final lat = double.tryParse(coords[1]?.toString() ?? '');
        if (lat == null || lon == null) continue;

        final p = Map<String, dynamic>.from(props);
        final name = (p['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final identity =
            '${name.toLowerCase()}_${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';
        if (!seenIdentity.add(identity)) continue;

        final addressParts = [
          p['street'],
          p['housenumber'],
          p['district'],
          p['city'],
          p['state'],
          p['country'],
        ]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();

        places.add(
          MapPlace(
            id: 'photon_${p['osm_id'] ?? identity}',
            name: name,
            category: _categoryFromNominatimItem({
              ...p,
              'class': p['osm_key']?.toString() ?? '',
              'type': p['osm_value']?.toString() ?? '',
              'display_name': addressParts.join(', '),
            }) ??
                PlaceCategory.amusement,
            latitude: lat,
            longitude: lon,
            rating: 0,
            reviewCount: 0,
            address: addressParts.isNotEmpty
                ? addressParts.take(2).join(', ')
                : '',
            city: (p['city'] ?? p['state'] ?? '').toString(),
            imageUrl: '',
            tags: const ['photon', 'search'],
          ),
        );
      }

      places.sort(
        (a, b) =>
            a.distanceTo(userLocation).compareTo(b.distanceTo(userLocation)),
      );
      return places;
    } catch (error) {
      debugPrint('[MapPlacesService] Photon search gagal: $error');
      return const [];
    }
  }

  /// Memetakan hasil Nominatim ke kategori LBS aplikasi berdasarkan
  /// osm_type/osm_class/category dan teks nama.
  static PlaceCategory? _categoryFromNominatimItem(Map<String, dynamic> item) {
    final osmType = item['osm_type']?.toString().toLowerCase();
    final osmClass = item['class']?.toString().toLowerCase();
    final osmValue = item['type']?.toString().toLowerCase() ?? '';
    final categoryText = item['category']?.toString().toLowerCase() ?? '';
    final nameText =
        '${item['name'] ?? ''} ${item['display_name'] ?? ''}'.toLowerCase();

    PlaceCategory? fromKeywords(List<String> keywords, PlaceCategory category) {
      for (final keyword in keywords) {
        if (nameText.contains(keyword) ||
            osmValue.contains(keyword.replaceAll(' ', '_')) ||
            categoryText.contains(keyword)) {
          return category;
        }
      }
      return null;
    }

    if (osmClass == 'tourism') {
      if (['hotel', 'motel', 'guest_house', 'hostel', 'apartment', 'resort']
          .contains(osmValue)) {
        return PlaceCategory.hotel;
      }
      if ([
        'attraction',
        'museum',
        'theme_park',
        'zoo',
        'aquarium',
        'viewpoint',
        'artwork',
        'gallery',
      ].contains(osmValue)) {
        return PlaceCategory.amusement;
      }
    }
    if (osmClass == 'amenity') {
      if ([
        'restaurant',
        'cafe',
        'fast_food',
        'food_court',
        'pub',
        'bar',
        'ice_cream',
        'biergarten',
      ].contains(osmValue)) {
        return PlaceCategory.restaurants;
      }
      if (['public_bath', 'swimming_area'].contains(osmValue)) {
        return PlaceCategory.pool;
      }
    }
    if (osmClass == 'leisure') {
      if (['swimming_pool', 'water_park'].contains(osmValue)) {
        return PlaceCategory.pool;
      }
      if ([
        'park',
        'garden',
        'nature_reserve',
        'playground',
        'sports_centre',
      ].contains(osmValue)) {
        return PlaceCategory.park;
      }
      if (['amusement_arcade', 'escape_game', 'horse_riding']
          .contains(osmValue)) {
        return PlaceCategory.amusement;
      }
    }
    if (osmClass == 'natural' &&
        ['beach', 'peak', 'waterfall', 'spring', 'hot_spring'].contains(osmValue)) {
      return osmValue == 'hot_spring' || osmValue == 'spring'
          ? PlaceCategory.pool
          : PlaceCategory.park;
    }
    if (osmClass == 'historic' || osmType == 'way' && osmClass == 'building') {
      return PlaceCategory.amusement;
    }

    // Fallback: cocokkan dengan kata kunci kategori pada nama hasil
    for (final entry in _searchKeywordCategory.entries) {
      final match = fromKeywords(entry.value, entry.key);
      if (match != null) return match;
    }
    return null;
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

  /// Mirror membalas HTTP 200 dengan 0 elemen yang mencurigakan (data
  /// tidak lengkap) — bukan hasil kosong yang sah.
  suspectedIncomplete,
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
