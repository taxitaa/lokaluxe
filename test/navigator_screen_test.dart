import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:lokaluxe/core/models/map_place_model.dart';
import 'package:lokaluxe/core/services/currency_provider.dart';
import 'package:lokaluxe/core/services/map_places_service.dart';
import 'package:lokaluxe/screens/map/navigator_screen.dart';
import 'package:lokaluxe/screens/map/qibla_compass_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test(
      'Loads curated places and generates surrounding places for any location',
      () async {
        final userLoc = const LatLng(-6.2000, 106.8166);
        final places = await MapPlacesService.getPlaces(userLocation: userLoc);

        expect(places.isNotEmpty, isTrue);

        // Verify category coverage exists
        final hasRestaurant = places.any(
          (p) => p.category == PlaceCategory.restaurants,
        );
        final hasHotel = places.any((p) => p.category == PlaceCategory.hotel);
        final hasAmusement = places.any(
          (p) => p.category == PlaceCategory.amusement,
        );
        final hasPark = places.any((p) => p.category == PlaceCategory.park);
        final hasPool = places.any((p) => p.category == PlaceCategory.pool);

        expect(hasRestaurant, isTrue);
        expect(hasHotel, isTrue);
        expect(hasAmusement, isTrue);
        expect(hasPark, isTrue);
        expect(hasPool, isTrue);
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

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CurrencyProvider>.value(
              value: currencyProvider,
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
      expect(find.text('Menjelajahi Jakarta'), findsOneWidget);
      expect(find.text('Tempat di sekitar Jakarta'), findsOneWidget);
      expect(find.text('Jelajahi sekitar'), findsNothing);
      expect(find.text('Lokasi kamu'), findsNothing);
      expect(find.text('Ketuk untuk mendeteksi lokasi'), findsNothing);
      expect(find.text('Akses Lokasi Diperlukan'), findsNothing);

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
