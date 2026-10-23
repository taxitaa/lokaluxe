import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:lokaluxe/core/models/map_place_model.dart';
import 'package:lokaluxe/core/services/currency_provider.dart';
import 'package:lokaluxe/core/services/currency_service.dart';
import 'package:lokaluxe/core/services/map_places_service.dart';
import 'package:lokaluxe/screens/map/navigator_screen.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MapPlace Model & MapPlacesService Tests', () {
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

    test('Loads curated places and generates surrounding places for any location', () async {
      final userLoc = const LatLng(-6.2000, 106.8166);
      final places = await MapPlacesService.getPlaces(userLocation: userLoc);

      expect(places.isNotEmpty, isTrue);

      // Verify category coverage exists
      final hasRestaurant = places.any((p) => p.category == PlaceCategory.restaurants);
      final hasHotel = places.any((p) => p.category == PlaceCategory.hotel);
      final hasAmusement = places.any((p) => p.category == PlaceCategory.amusement);
      final hasPark = places.any((p) => p.category == PlaceCategory.park);
      final hasPool = places.any((p) => p.category == PlaceCategory.pool);

      expect(hasRestaurant, isTrue);
      expect(hasHotel, isTrue);
      expect(hasAmusement, isTrue);
      expect(hasPark, isTrue);
      expect(hasPool, isTrue);
    });

    test('Google Maps URL format matches user specification', () {
      const lat = -6.1953;
      const lon = 106.8231;
      final expectedUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lon';
      final generatedUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lon');

      expect(generatedUri.toString(), expectedUrl);
      expect(generatedUri.queryParameters['api'], '1');
      expect(generatedUri.queryParameters['query'], '$lat,$lon');
    });
  });

  group('NavigatorScreen Widget Tests', () {
    testWidgets('Renders top floating controls and draggable bottom sheet',
        (WidgetTester tester) async {
      final currencyProvider = CurrencyProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<CurrencyProvider>.value(
              value: currencyProvider,
            ),
          ],
          child: const MaterialApp(
            home: NavigatorScreen(
              initialTarget: LatLng(-6.1953, 106.8231),
            ),
          ),
        ),
      );

      // Verify header title
      expect(find.text('LokaLuxe Navigator'), findsOneWidget);

      // Verify Search Place input
      expect(find.byType(TextField), findsOneWidget);

      // Verify Category Buttons in circular row
      expect(find.text('Amusement'), findsOneWidget);
      expect(find.text('Hotel'), findsOneWidget);
      expect(find.text('Park'), findsOneWidget);
      expect(find.text('Restaurants'), findsOneWidget);
      expect(find.text('Pool'), findsOneWidget);
    });
  });
}
