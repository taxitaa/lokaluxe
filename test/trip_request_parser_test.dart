import 'package:flutter_test/flutter_test.dart';
import 'package:lokaluxe/core/services/trip_request_parser.dart';

void main() {
  group('parseTripRequest', () {
    test('parses all required itinerary details from labeled input', () {
      final request = parseTripRequest(
        'Tujuan: Bali; tanggal mulai: 01/11/2026; durasi: 3 hari; '
        'jumlah orang: 2; budget: Rp5.000.000',
      );

      expect(request.destination, 'Bali');
      expect(request.startDate, DateTime(2026, 11, 1));
      expect(request.durationDays, 3);
      expect(request.travelerCount, 2);
      expect(request.budget, 5000000);
      expect(request.missingFields, isEmpty);
    });

    test('parses destination, date, and a compact budget', () {
      final request = parseTripRequest(
        'Mau ke Yogyakarta tanggal 24 Okt 2026, 2 hari, 4 orang, budget 2,5 juta',
      );

      expect(request.destination, 'Yogyakarta');
      expect(request.startDate, DateTime(2026, 10, 24));
      expect(request.durationDays, 2);
      expect(request.travelerCount, 4);
      expect(request.budget, 2500000);
    });

    test('keeps missing information explicit', () {
      final request = parseTripRequest('Tujuan: Lombok; durasi: 3 hari');

      expect(request.missingFields, [
        'tanggal mulai',
        'jumlah orang',
        'total budget',
      ]);
    });
  });
}
