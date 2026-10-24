import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum TripReminderResult { scheduled, permissionRequested, unsupported }

class TripReminderService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.lokaluxe/trip_reminders',
  );

  static Future<TripReminderResult> schedule({
    required int tripId,
    required String destination,
    required DateTime startDate,
  }) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return TripReminderResult.unsupported;
    }

    final result = await _channel.invokeMethod<String>(
      'scheduleTripReminders',
      {
        'tripId': tripId,
        'destination': destination,
        'startDateMillis': DateTime(
          startDate.year,
          startDate.month,
          startDate.day,
        ).millisecondsSinceEpoch,
      },
    );
    return switch (result) {
      'scheduled' => TripReminderResult.scheduled,
      'permission_requested' => TripReminderResult.permissionRequested,
      _ => throw StateError('Status pengingat tidak dikenal: $result'),
    };
  }
}
