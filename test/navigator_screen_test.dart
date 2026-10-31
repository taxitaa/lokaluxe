import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:lokaluxe/core/models/map_place_model.dart';
import 'package:lokaluxe/core/services/currency_provider.dart';
import 'package:lokaluxe/core/services/localization_provider.dart';
import 'package:lokaluxe/core/services/map_places_service.dart';
import 'package:lokaluxe/screens/map/navigator_screen.dart';
import 'package:lokaluxe/screens/map/qibla_compass_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  http.Response httpResponse(Object body) => http.Response(
    jsonEncode(body),
    200,
    headers: const {'content-type': 'application/json'},
  );

  group('Bearing, CompassDirection & RouteInfo Tests', () {
    test('Calculates bearing and 8 cardinal directions accurately', () {
      final origin = const LatLng(-6.2000, 106.8000);

      // Directly North
      final northTarget = const LatLng(-6.1000, 106.8000);
      final bearingNorth = calculateBearing(origin, northTarget);
      expect(CompassDirection.fromBearing(bearingNorth), CompassDirection.north);
      expect(CompassDirection.fromBearing(bearingNorth).labelId, 'Utara');
      expect(CompassDirection.fromBearing(bearingNorth).labelEn, 'North');

      // Northeast
      final neTarget = const LatLng(-6.1000, 106.9000);
      final bearingNE = calculateBearing(origin, neTarget);
      expect(CompassDirection.fromBearing(bearingNE), CompassDirection.northEast);
      expect(CompassDirection.fromBearing(bearingNE).labelId, 'Timur Laut');
      expect(CompassDirection.fromBearing(bearingNE).labelEn, 'Northeast');

      // East
      final eastTarget = const LatLng(-6.2000, 106.9000);
      final bearingEast = calculateBearing(origin, eastTarget);
      expect(CompassDirection.fromBearing(bearingEast), CompassDirection.east);
      expect(CompassDirection.fromBearing(bearingEast).labelId, 'Timur');

      // Southeast
      final seTarget = const LatLng(-6.3000, 106.9000);
      final bearingSE = calculateBearing(origin, seTarget);
      expect(CompassDirection.fromBearing(bearingSE), CompassDirection.southEast);
      expect(CompassDirection.fromBearing(bearingSE).labelId, 'Tenggara');

      // South
      final southTarget = const LatLng(-6.3000, 106.8000);
      final bearingSouth = calculateBearing(origin, southTarget);
      expect(CompassDirection.fromBearing(bearingSouth), CompassDirection.south);
      expect(CompassDirection.fromBearing(bearingSouth).labelId, 'Selatan');

      // Southwest
      final swTarget = const LatLng(-6.3000, 106.7000);
      final bearingSW = calculateBearing(origin, swTarget);
      expect(CompassDirection.fromBearing(bearingSW), CompassDirection.southWest);
      expect(CompassDirection.fromBearing(bearingSW).labelId, 'Barat Daya');

      // West
      final westTarget = const LatLng(-6.2000, 106.7000);
      final bearingWest = calculateBearing(origin, westTarget);
      expect(CompassDirection.fromBearing(bearingWest), CompassDirection.west);
      expect(CompassDirection.fromBearing(bearingWest).labelId, 'Barat');

      // Northwest
      final nwTarget = const LatLng(-6.1000, 106.7000);
      final bearingNW = calculateBearing(origin, nwTarget);
      expect(CompassDirection.fromBearing(bearingNW), CompassDirection.northWest);
      expect(CompassDirection.fromBearing(bearingNW).labelId, 'Barat Laut');
    });

    test('RouteInfo calculates distance, bearing and estimates correctly', () {
      final origin = const LatLng(-6.1754, 106.8272); // Monas
      final dest = MapPlace(
        id: 'place_1',
        name: 'Resto Sunda',
        category: PlaceCategory.restaurants,
        latitude: -6.1800,
        longitude: 106.8300,
        rating: 4.7,
        reviewCount: 150,
        address: 'Jl. Merdeka',
        city: 'Jakarta',
        imageUrl: '',
      );

      final route = RouteInfo.fromLocations(origin: origin, destination: dest);

      expect(route.distanceMeters, greaterThan(400));
      expect(route.distanceMeters, lessThan(800));
      expect(route.bearingDegrees, greaterThan(130));
      expect(route.bearingDegrees, lessThan(170));
      expect(route.direction, CompassDirection.southEast);
      expect(route.direction.labelId, 'Tenggara');
      expect(route.estimatedWalkingMinutes, greaterThan(0));
      expect(route.estimatedDrivingMinutes, greaterThan(0));
    });
  });

  group('MapPlace Model & MapPlacesService Tests', () {
    test('Calculates the Qibla bearing from Jakarta', () {
      final bearing = calculateQiblaBearing(const LatLng(-6.1953, 106.8231));

      expect(bearing, greaterThan(290));
      expect(bearing, lessThan(300));
    });

    test('Calculates Haversine distance correctly', () {
      final place = MapPlace(
        id: 'test_1',
        name: 'Monas Jakarta',
        category: PlaceCategory.amusement,
        latitude: -6.1754,
        longitude: 106.8272,
        rating: 4.8,
        reviewCount: 500,
        address: 'Gambir',
        city: 'Jakarta Pusat',
        imageUrl: '',
      );

      final sameLoc = const LatLng(-6.1754, 106.8272);
      expect(place.distanceTo(sameLoc).round(), 0);
      expect(place.formattedDistanceTo(sameLoc), '0 m');

      final nearbyLoc = const LatLng(-6.1844, 106.8272);
      final dist = place.distanceTo(nearbyLoc);
      expect(dist, greaterThan(800));
      expect(dist, lessThan(1200));
    });

    test('Parses nearby node, way and relation results by category', () async {
      final location = const LatLng(-6.2, 106.8);
      String? sentQuery;
      final places = await MapPlacesService.searchNearbyPlaces(
        userLocation: location,
        radiusMeters: 3000,
        forceRefresh: true,
        client: MockClient((request) async {
          sentQuery = request.url.queryParameters['data'];
          return httpResponse({
            'elements': [
              {
                'type': 'node',
                'id': 100,
                'lat': -6.201,
                'lon': 106.8,
                'tags': {'name': 'Nearby Cafe', 'amenity': 'cafe'},
              },
              {
                'type': 'way',
                'id': 200,
                'center': {'lat': -6.202, 'lon': 106.8},
                'tags': {'name': 'Nearby Hotel', 'tourism': 'hotel'},
              },
              {
                'type': 'relation',
                'id': 300,
                'center': {'lat': -6.203, 'lon': 106.8},
                'tags': {'name': 'Nearby Park', 'leisure': 'park'},
              },
              {
                'type': 'way',
                'id': 400,
                'center': {'lat': -6.204, 'lon': 106.8},
                'tags': {'name': 'Nearby Museum', 'tourism': 'museum'},
              },
              {
                'type': 'node',
                'id': 101,
                'lat': -6.201,
                'lon': 106.8,
                'tags': {'name': 'Nearby Cafe', 'amenity': 'cafe'},
              },
            ],
          });
        }),
      );

      expect(sentQuery, contains('around:3000,-6.200000,106.800000'));
      expect(places, hasLength(4));
      expect(
        places.map((place) => place.category),
        containsAll([
          PlaceCategory.restaurants,
          PlaceCategory.hotel,
          PlaceCategory.park,
          PlaceCategory.amusement,
        ]),
      );
      expect(
        places.map((place) => place.distanceTo(location)).toList(),
        orderedEquals(
          places.map((place) => place.distanceTo(location)).toList()..sort(),
        ),
      );
    });

    test(
      'Returns an empty list for a successful empty Overpass response',
      () async {
        final places = await MapPlacesService.searchNearbyPlaces(
          userLocation: const LatLng(1.2345, 2.3456),
          radiusMeters: 3000,
          forceRefresh: true,
          client: MockClient((_) async => httpResponse({'elements': []})),
        );

        expect(places, isEmpty);
      },
    );

    test('Requests a combined multi-category Overpass query for any tab', () async {
      String? sentQuery;
      await MapPlacesService.searchNearbyPlaces(
        userLocation: const LatLng(7.1234, 110.1234),
        radiusMeters: 3000,
        category: PlaceCategory.amusement,
        forceRefresh: true,
        client: MockClient((request) async {
          sentQuery = request.url.queryParameters['data'];
          return httpResponse({'elements': []});
        }),
      );

      // Query gabungan: satu fetch memuat SEMUA kategori, kategori dipisah
      // di sisi aplikasi (_filterByCategory) sehingga berpindah tab tidak
      // menembak Overpass berulang.
      expect(sentQuery, contains('"tourism"~"^(hotel'));
      expect(sentQuery, contains('"amenity"~"^(restaurant'));
      expect(sentQuery, contains('"leisure"~"^(park'));
    });

    test('Filters the combined area cache by the selected category', () async {
      // Fetch gabungan sekali untuk area ini...
      await MapPlacesService.searchNearbyPlaces(
        userLocation: const LatLng(-6.2, 106.8),
        radiusMeters: 3000,
        category: PlaceCategory.all,
        forceRefresh: true,
        client: MockClient((request) async {
          return httpResponse({
            'elements': [
              {
                'type': 'node',
                'id': 100,
                'lat': -6.201,
                'lon': 106.8,
                'tags': {'name': 'Nearby Cafe', 'amenity': 'cafe'},
              },
              {
                'type': 'way',
                'id': 200,
                'center': {'lat': -6.202, 'lon': 106.8},
                'tags': {'name': 'Nearby Hotel', 'tourism': 'hotel'},
              },
            ],
          });
        }),
      );

      // ...lalu setiap tab HARUS terfilter dari cache TANPA request baru
      // (mock tidak dipasang ulang — jika request terjadi, mockClient
      // tidak ada sehingga HTTP nyata dipanggil dan test gagal timeouts;
      // lebih aman: verify hasil filter langsung).
      final hotelsOnly = await MapPlacesService.searchNearbyPlaces(
        userLocation: const LatLng(-6.2, 106.8),
        radiusMeters: 3000,
        category: PlaceCategory.hotel,
      );
      expect(hotelsOnly, hasLength(1));
      expect(hotelsOnly.single.name, 'Nearby Hotel');
      expect(hotelsOnly.single.category, PlaceCategory.hotel);

      final culinaryOnly = await MapPlacesService.searchNearbyPlaces(
        userLocation: const LatLng(-6.2, 106.8),
        radiusMeters: 3000,
        category: PlaceCategory.restaurants,
      );
      expect(culinaryOnly, hasLength(1));
      expect(culinaryOnly.single.name, 'Nearby Cafe');

      final all = await MapPlacesService.searchNearbyPlaces(
        userLocation: const LatLng(-6.2, 106.8),
        radiusMeters: 3000,
        category: PlaceCategory.all,
      );
      expect(all, hasLength(2));
    });

    test(
      'Tries multiple Overpass endpoints sequentially on failure and throws exception without dummy fallback',
      () async {
        final requestedHosts = <String>[];
        bool threwException = false;
        try {
          await MapPlacesService.searchNearbyPlaces(
            userLocation: const LatLng(3.4567, 4.5678),
            radiusMeters: 3000,
            forceRefresh: true,
            client: MockClient((request) async {
              requestedHosts.add(request.url.host);
              return http.Response('rate limited', 429);
            }),
          );
        } on MapPlacesSearchException {
          threwException = true;
        }

        expect(requestedHosts.toSet().length, greaterThanOrEqualTo(2));
        expect(threwException, isTrue);
      },
    );

    test('Generates correct Google Maps search URL with latitude and longitude', () {
      final uri = MapPlacesService.googleMapsSearchUri(
        latitude: -7.6079,
        longitude: 110.2038,
      );

      expect(uri, isNotNull);
      expect(uri.toString(), 'https://www.google.com/maps/search/?api=1&query=-7.6079%2C110.2038');
    });
  });

  group('NavigatorScreen Widget Tests', () {
    testWidgets('Renders the nearby map navigator, GPS bar, and category chips', (
      WidgetTester tester,
    ) async {
      final currencyProvider = CurrencyProvider();
      final localizationProvider = LocalizationProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CurrencyProvider>.value(
              value: currencyProvider,
            ),
            ChangeNotifierProvider<LocalizationProvider>.value(
              value: localizationProvider,
            ),
          ],
          child: const MaterialApp(
            home: NavigatorScreen(initialTarget: LatLng(-6.1953, 106.8231)),
          ),
        ),
      );

      // Verify header title
      expect(find.text('LokaLuxe Navigator'), findsOneWidget);

      // Verify Search TextField
      expect(find.byType(TextField), findsOneWidget);

      // Verify GPS bar
      expect(find.text('Koordinat GPS Riil'), findsOneWidget);

      // Verify the 5 horizontal category chips (Semua, Hiburan, Hotel, Taman, Kuliner)
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Hiburan'), findsOneWidget);
      expect(find.text('Hotel'), findsOneWidget);
      expect(find.text('Taman'), findsOneWidget);
      expect(find.text('Kuliner'), findsOneWidget);

      // Verify compass button in AppBar remains present
      expect(find.byIcon(Icons.explore_rounded), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Borobudur');
      await tester.pump();
      expect(find.text('Borobudur'), findsOneWidget);
    });
  });
}
