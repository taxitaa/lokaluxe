import 'dart:convert';

class TripItineraryDay {
  final int dayNumber;
  final String title;
  final List<String> activities;

  const TripItineraryDay({
    required this.dayNumber,
    required this.title,
    required this.activities,
  });

  Map<String, Object> toMap() => {
    'dayNumber': dayNumber,
    'title': title,
    'activities': jsonEncode(activities),
  };

  factory TripItineraryDay.fromMap(Map<String, Object?> map) {
    final decoded = jsonDecode(map['activities'] as String);
    if (decoded is! List || decoded.any((item) => item is! String)) {
      throw const FormatException('Data aktivitas itinerary tidak valid.');
    }
    return TripItineraryDay(
      dayNumber: (map['dayNumber'] as num).toInt(),
      title: map['title'] as String,
      activities: decoded.cast<String>(),
    );
  }
}
