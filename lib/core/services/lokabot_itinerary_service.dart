import '../database/db_helper.dart';
import '../models/trip_itinerary_day_model.dart';

class LokaBotItineraryService {
  static Future<List<TripItineraryDay>> generateDays({
    required String destination,
    required int durationDays,
  }) async {
    final attractions = await DBHelper.getWisata();
    return buildDays(
      destination: destination,
      durationDays: durationDays,
      attractions: attractions,
    );
  }

  static List<TripItineraryDay> buildDays({
    required String destination,
    required int durationDays,
    required List<Map<String, dynamic>> attractions,
  }) {
    final normalizedDestination = destination.trim().toLowerCase();
    if (normalizedDestination.isEmpty ||
        durationDays < 1 ||
        durationDays > 30) {
      throw const FormatException('Tujuan atau durasi itinerary tidak valid.');
    }

    final matchingAttractions = attractions.where((attraction) {
      final city = (attraction['kota_kabupaten'] ?? '')
          .toString()
          .toLowerCase();
      final province = (attraction['provinsi'] ?? '')
          .toString()
          .toLowerCase();
      final name = (attraction['nama_wisata'] ?? '')
          .toString()
          .toLowerCase();
      return _matchesLocation(normalizedDestination, city) ||
          _matchesLocation(normalizedDestination, province) ||
          _matchesLocation(normalizedDestination, name);
    }).toList()..sort(
      (a, b) => (a['nama_wisata'] ?? '').toString().compareTo(
        (b['nama_wisata'] ?? '').toString(),
      ),
    );

    final uniqueAttractions = <Map<String, dynamic>>[];
    final seenNames = <String>{};
    for (final attraction in matchingAttractions) {
      final name = (attraction['nama_wisata'] ?? '').toString().trim();
      if (name.isNotEmpty && seenNames.add(name.toLowerCase())) {
        uniqueAttractions.add(attraction);
      }
    }

    if (uniqueAttractions.isEmpty) {
      throw StateError(
        'Belum ada tempat wisata "$destination" di database lokal. '
        'Coba gunakan nama kota atau provinsi yang tersedia di katalog wisata.',
      );
    }
    if (uniqueAttractions.length < durationDays) {
      throw StateError(
        'Database lokal hanya memiliki ${uniqueAttractions.length} tempat '
        'wisata untuk "$destination". Pilih durasi maksimal '
        '${uniqueAttractions.length} hari atau pilih tujuan yang lebih luas.',
      );
    }

    final selectedCount = uniqueAttractions.length < durationDays * 3
        ? uniqueAttractions.length
        : durationDays * 3;
    final days = <TripItineraryDay>[];
    var currentIndex = 0;
    for (var dayNumber = 1; dayNumber <= durationDays; dayNumber++) {
      final remainingDays = durationDays - dayNumber + 1;
      final remainingAttractions = selectedCount - currentIndex;
      final activitiesToday = (remainingAttractions / remainingDays).ceil();
      final activities = uniqueAttractions
          .skip(currentIndex)
          .take(activitiesToday)
          .map(
            (attraction) =>
                'Kunjungi ${(attraction['nama_wisata'] ?? '').toString().trim()}',
          )
          .toList();
      currentIndex += activitiesToday;

      days.add(
        TripItineraryDay(
          dayNumber: dayNumber,
          title: 'Jelajah $destination - Hari $dayNumber',
          activities: activities,
        ),
      );
    }
    return days;
  }

  static bool _matchesLocation(String destination, String field) {
    if (field.trim().isEmpty) return false;
    return RegExp(
      '\\b${RegExp.escape(destination)}\\b',
    ).hasMatch(field) ||
        RegExp('\\b${RegExp.escape(field.trim())}\\b').hasMatch(destination);
  }
}
