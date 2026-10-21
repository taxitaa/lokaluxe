import 'package:flutter_test/flutter_test.dart';
import 'package:lokaluxe/core/services/timezone_service.dart';

void main() {
  group('TimeZoneService daylight saving time', () {
    test('formats dates using the initialized default locale', () {
      expect(
        TimeZoneService.formatDate(DateTime.utc(2026, 10, 21)),
        'Wednesday, 21 October 2026',
      );
    });

    test('uses British and Central European summer offsets', () {
      final summer = DateTime.utc(2026, 6, 1, 12);

      expect(TimeZoneService.getOffsetHours('LONDON', now: summer), 1);
      expect(TimeZoneService.getOffsetHours('CET', now: summer), 2);
      expect(TimeZoneService.getZoneInfo('CET', now: summer).code, 'CEST');
    });

    test('uses US daylight offsets only during daylight time', () {
      final summer = DateTime.utc(2026, 7, 1, 12);
      final winter = DateTime.utc(2026, 1, 1, 12);

      expect(TimeZoneService.getOffsetHours('EST', now: summer), -4);
      expect(TimeZoneService.getOffsetHours('PST', now: summer), -7);
      expect(TimeZoneService.getOffsetHours('EST', now: winter), -5);
      expect(TimeZoneService.getOffsetHours('PST', now: winter), -8);
    });

    test('uses Australian daylight time across the southern summer', () {
      final summer = DateTime.utc(2026, 1, 1, 12);
      final winter = DateTime.utc(2026, 7, 1, 12);

      expect(TimeZoneService.getOffsetHours('AEST', now: summer), 11);
      expect(TimeZoneService.getZoneInfo('AEST', now: summer).code, 'AEDT');
      expect(TimeZoneService.getOffsetHours('AEDT', now: winter), 10);
      expect(TimeZoneService.getZoneInfo('AEDT', now: winter).code, 'AEST');
    });

    test('applies US daylight transitions at the correct UTC instants', () {
      expect(
        TimeZoneService.getOffsetHours(
          'EST',
          now: DateTime.utc(2026, 3, 8, 6, 59),
        ),
        -5,
      );
      expect(
        TimeZoneService.getOffsetHours(
          'EST',
          now: DateTime.utc(2026, 3, 8, 7),
        ),
        -4,
      );
      expect(
        TimeZoneService.getOffsetHours(
          'PST',
          now: DateTime.utc(2026, 11, 1, 9),
        ),
        -8,
      );
    });
  });
}
