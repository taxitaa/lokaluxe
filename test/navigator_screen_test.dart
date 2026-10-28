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

      // Distance from exact same point should be 0 m
      final sameLoc = LatLng(-6.1754, 106.8272);
      expect(place.distanceTo(sameLoc).round(), 0);
      expect(place.formattedDistanceTo(sameLoc), '0 m');

      // Distance from ~1 km away
      final nearbyLoc = LatLng(-6.1844, 106.8272);
      final dist = place.distanceTo(nearbyLoc);
      expect(dist, greaterThan(800));
      expect(dist, lessThan(1200));
    });

    test('Parses nearby node, way and relation results by category', () async {
      final location = const LatLng(-6.2, 106.8);
      String? sentQuery;
      final places = await MapPlacesService.searchNearbyPlaces(
        userLocation: location,
        radiusMeters: 5000,
        forceRefresh: true,
        client: MockClient((request) async {
          sentQuery = Uri.splitQueryString(request.body)['data'];
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

      expect(sentQuery, contains('around:5000,-6.200000,106.800000'));
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
          radiusMeters: 5000,
          forceRefresh: true,
          client: MockClient((_) async => httpResponse({'elements': []})),
        );

        expect(places, isEmpty);
      },
    );

    test('Requests only tags for the selected category', () async {
      String? sentQuery;
      await MapPlacesService.searchNearbyPlaces(
        userLocation: const LatLng(7.1234, 110.1234),
        radiusMeters: 5000,
        category: PlaceCategory.amusement,
        forceRefresh: true,
        client: MockClient((request) async {
          sentQuery = Uri.splitQueryString(request.body)['data'];
          return httpResponse({'elements': []});
        }),
      );

      expect(sentQuery, contains('"tourism"~"^(attraction'));
      expect(sentQuery, isNot(contains('"amenity"~"restaurant')));
    });

    test(
      'Reports rate limiting after trying both Overpass endpoints',
      () async {
        final requestedHosts = <String>[];
        await expectLater(
          MapPlacesService.searchNearbyPlaces(
            userLocation: const LatLng(3.4567, 4.5678),
            radiusMeters: 5000,
            forceRefresh: true,
            client: MockClient((request) async {
              requestedHosts.add(request.url.host);
              return http.Response('rate limited', 429);
            }),
          ),
          throwsA(
            isA<MapPlacesSearchException>().having(
              (error) => error.kind,
              'kind',
              MapPlacesFailureKind.rateLimited,
            ),
          ),
        );

        expect(requestedHosts.toSet(), hasLength(2));
      },
    );

    test('Google Maps URL format matches user specification', () {
      const lat = -6.1953;
      const lon = 106.8231;
      final expectedUrl =
          'https://www.google.com/maps/search/?api=1&query=$lat%2C$lon';
      final generatedUri = MapPlacesService.googleMapsSearchUri(
        latitude: lat,
        longitude: lon,
      );

      expect(generatedUri.toString(), expectedUrl);
      expect(generatedUri!.queryParameters['api'], '1');
      expect(generatedUri.queryParameters['query'], '$lat,$lon');
    });

    test('Falls back to place name and address without coordinates', () {
      final generatedUri = MapPlacesService.googleMapsSearchUri(
        placeName: 'Taman Wisata',
        address: 'Bandung',
      );

      expect(generatedUri?.queryParameters['query'], 'Taman Wisata, Bandung');
    });

    test('Rejects empty or invalid Google Maps places', () {
      expect(MapPlacesService.googleMapsSearchUri(), isNull);
      expect(
        MapPlacesService.googleMapsSearchUri(
          placeName: 'Taman Wisata',
          latitude: 200,
          longitude: 300,
        )?.queryParameters['query'],
        'Taman Wisata',
      );
    });
  });

  group('NavigatorScreen Widget Tests', () {
    testWidgets('Renders the nearby map navigator and expandable search', (
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

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Mendeteksi lokasi perangkat'), findsOneWidget);
      expect(find.text('Menjelajahi Jakarta'), findsNothing);
      expect(find.text('Tempat di sekitar Jakarta'), findsNothing);

      // Verify the horizontal category chips
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Hiburan'), findsOneWidget);
      expect(find.text('Hotel'), findsOneWidget);
      expect(find.text('Taman'), findsOneWidget);
      expect(find.text('Kuliner'), findsOneWidget);
      expect(find.text('Kolam'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Borobudur');
      await tester.pump();
      expect(find.text('Borobudur'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });
  });
}
