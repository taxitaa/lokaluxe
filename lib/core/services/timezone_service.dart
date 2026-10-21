import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Model untuk merepresentasikan satu zona waktu
class TimeZoneInfo {
  final String code;        // Kode zona, misal: "WIB", "JST", "CET"
  final String name;        // Nama lengkap
  final String offset;      // Offset UTC, misal: "+07:00"
  final int offsetHours;    // Offset dalam jam dari UTC
  final String flag;        // Emoji bendera
  final String location;    // Deskripsi lokasi
  final DateTime localTime; // Waktu lokal saat ini di zona ini

  const TimeZoneInfo({
    required this.code,
    required this.name,
    required this.offset,
    required this.offsetHours,
    required this.flag,
    required this.location,
    required this.localTime,
  });
}

/// Conversion and display helpers for Indonesian and international time zones.
///
/// Mendukung zona waktu:
/// - Indonesia : WIB (UTC+7), WITA (UTC+8), WIT (UTC+9)
/// - Jepang    : JST (UTC+9)
/// - Eropa     : CET (UTC+1), EET (UTC+2), GMT/BST (UK)
/// - Asia      : SGT (UTC+8), MYT (UTC+8), KST (UTC+9), GST (UTC+4)
/// - Amerika   : EST (UTC-5), PST (UTC-8)
/// - Pasifik   : AEST (UTC+10)
class TimeZoneService {
  // ─── Tabel offset UTC dalam jam untuk setiap kode zona ─────────────────────
  static const Map<String, int> _zoneOffsets = {
    // Indonesia
    'WIB':  7,   // Waktu Indonesia Barat
    'WITA': 8,   // Waktu Indonesia Tengah
    'WIT':  9,   // Waktu Indonesia Timur

    // Inggris (musim dingin; BST ditangani secara dinamis)
    'GMT':  0,
    'BST':  1,   // British Summer Time

    // Jepang
    'JST':  9,   // Japan Standard Time

    // Eropa
    'CET':  1,   // Central European Time (Paris, Berlin, Roma, dll.)
    'CEST': 2,   // Central European Summer Time
    'EET':  2,   // Eastern European Time (Athena, dll.)

    // Asia Tenggara / Timur Tengah
    'SGT':  8,   // Singapore Time
    'MYT':  8,   // Malaysia Time
    'KST':  9,   // Korea Standard Time
    'GST':  4,   // Gulf Standard Time (Dubai)

    // Amerika
    'EST':  -5,  // Eastern Standard Time (New York)
    'EDT':  -4,  // Eastern Daylight Time
    'PST':  -8,  // Pacific Standard Time (Los Angeles)
    'PDT':  -7,  // Pacific Daylight Time

    // Australia
    'AEST': 10,  // Australian Eastern Standard Time
    'AEDT': 11,  // Australian Eastern Daylight Time
  };

  static const Map<String, String> _zoneNames = {
    'WIB':  'Western Indonesia Time',
    'WITA': 'Central Indonesia Time',
    'WIT':  'Eastern Indonesia Time',
    'GMT':  'Greenwich Mean Time',
    'BST':  'British Summer Time',
    'JST':  'Japan Standard Time',
    'CET':  'Central European Time',
    'CEST': 'Central European Summer Time',
    'EET':  'Eastern European Time',
    'EEST': 'Eastern European Summer Time',
    'SGT':  'Singapore Time',
    'MYT':  'Malaysia Time',
    'KST':  'Korea Standard Time',
    'GST':  'Gulf Standard Time',
    'EST':  'Eastern Standard Time',
    'EDT':  'Eastern Daylight Time',
    'PST':  'Pacific Standard Time',
    'PDT':  'Pacific Daylight Time',
    'AEST': 'Australian Eastern Standard Time',
    'AEDT': 'Australian Eastern Daylight Time',
  };

  static const Map<String, String> _zoneFlags = {
    'WIB':  '🇮🇩',
    'WITA': '🇮🇩',
    'WIT':  '🇮🇩',
    'GMT':  '🇬🇧',
    'BST':  '🇬🇧',
    'JST':  '🇯🇵',
    'CET':  '🇪🇺',
    'CEST': '🇪🇺',
    'EET':  '🇬🇷',
    'EEST': '🇬🇷',
    'SGT':  '🇸🇬',
    'MYT':  '🇲🇾',
    'KST':  '🇰🇷',
    'GST':  '🇦🇪',
    'EST':  '🇺🇸',
    'EDT':  '🇺🇸',
    'PST':  '🇺🇸',
    'PDT':  '🇺🇸',
    'AEST': '🇦🇺',
  };

  static const Map<String, String> _zoneLocations = {
    'WIB':  'Jakarta, Medan, Bandung, Surabaya',
    'WITA': 'Bali, Makassar, Balikpapan',
    'WIT':  'Jayapura, Ambon, Sorong',
    'GMT':  'London (GMT, Nov–Mar)',
    'BST':  'London (BST, Apr–Oct)',
    'JST':  'Tokyo, Osaka, Kyoto',
    'CET':  'Paris, Berlin, Roma, Madrid, Amsterdam',
    'CEST': 'Paris, Berlin, Rome (summer)',
    'EET':  'Athens, Ankara',
    'EEST': 'Athens (summer time)',
    'SGT':  'Singapura',
    'MYT':  'Kuala Lumpur',
    'KST':  'Seoul, Busan',
    'GST':  'Dubai, Abu Dhabi',
    'EST':  'New York, Washington D.C.',
    'EDT':  'New York, Washington D.C.',
    'PST':  'Los Angeles, San Francisco',
    'PDT':  'Los Angeles, San Francisco',
    'AEST': 'Sydney, Melbourne',
    'AEDT': 'Sydney, Melbourne',
  };

  // ─── Logika BST (British Summer Time) ──────────────────────────────────────

  /// Determines whether London is currently observing British Summer Time.
  ///
  /// BST berlaku dari Minggu terakhir Maret (01:00 UTC) hingga
  /// Minggu terakhir Oktober (01:00 UTC).
  static bool _isUkBST(DateTime utcNow) {
    final year = utcNow.year;
    final bstStart = DateTime.utc(year, 3, _lastSundayOf(year, 3), 1);
    final bstEnd   = DateTime.utc(year, 10, _lastSundayOf(year, 10), 1);
    return utcNow.isAfter(bstStart) && utcNow.isBefore(bstEnd);
  }

  static bool _isEuropeanSummerTime(DateTime utcNow) {
    final start = DateTime.utc(
      utcNow.year,
      3,
      _lastSundayOf(utcNow.year, 3),
      1,
    );
    final end = DateTime.utc(
      utcNow.year,
      10,
      _lastSundayOf(utcNow.year, 10),
      1,
    );
    return !utcNow.isBefore(start) && utcNow.isBefore(end);
  }

  /// Mencari tanggal hari Minggu terakhir dalam [month] di [year]
  static int _lastSundayOf(int year, int month) {
    final lastDay = DateTime.utc(year, month + 1, 0);
    int day = lastDay.day;
    while (DateTime.utc(year, month, day).weekday != DateTime.sunday) {
      day--;
    }
    return day;
  }

  static int _nthSundayOf(int year, int month, int occurrence) {
    final firstDay = DateTime.utc(year, month, 1);
    final daysToSunday = (DateTime.sunday - firstDay.weekday + 7) % 7;
    return 1 + daysToSunday + (occurrence - 1) * 7;
  }

  static bool _isUsDaylightTime(DateTime utcNow, int standardOffset) {
    final year = utcNow.year;
    final startUtc = DateTime.utc(
      year,
      3,
      _nthSundayOf(year, 3, 2),
      2 - standardOffset,
    );
    final endUtc = DateTime.utc(
      year,
      11,
      _nthSundayOf(year, 11, 1),
      2 - standardOffset - 1,
    );
    return !utcNow.isBefore(startUtc) && utcNow.isBefore(endUtc);
  }

  static bool _isAustralianEasternDaylightTime(DateTime utcNow) {
    final year = utcNow.year;
    final daylightStarts = DateTime.utc(
      year,
      10,
      _nthSundayOf(year, 10, 1),
    ).subtract(const Duration(hours: 8));
    final daylightEnds = DateTime.utc(
      year,
      4,
      _nthSundayOf(year, 4, 1),
    ).subtract(const Duration(hours: 8));
    return !utcNow.isBefore(daylightStarts) || utcNow.isBefore(daylightEnds);
  }

  // ─── API Publik ─────────────────────────────────────────────────────────────

  /// Mendapatkan waktu lokal saat ini untuk kode zona tertentu.
  ///
  /// [zoneCode] contoh: "WIB", "JST", "CET", "GMT", "LONDON"
  /// Nilai "LONDON" akan otomatis memilih GMT atau BST berdasarkan tanggal.
  static DateTime getLocalTime(String zoneCode, {DateTime? now}) {
    final utcNow = (now ?? DateTime.now()).toUtc();

    if (zoneCode.toUpperCase() == 'LONDON') {
      final offset = _isUkBST(utcNow) ? 1 : 0;
      return utcNow.add(Duration(hours: offset));
    }

    final zone = zoneCode.toUpperCase();
    final offset = _getOffsetForZone(zone, utcNow);
    return utcNow.add(Duration(hours: offset));
  }

  /// Mendapatkan offset UTC (dalam jam) untuk kode zona tertentu.
  ///
  /// Mengembalikan 0 jika kode tidak dikenali.
  static int getOffsetHours(String zoneCode, {DateTime? now}) {
    return _getOffsetForZone(
      zoneCode,
      (now ?? DateTime.now()).toUtc(),
    );
  }

  /// Mendapatkan info lengkap zona waktu London (otomatis GMT atau BST).
  static TimeZoneInfo getLondonInfo({DateTime? now}) {
    final utcNow = (now ?? DateTime.now()).toUtc();
    final isBST  = _isUkBST(utcNow);
    final code   = isBST ? 'BST' : 'GMT';
    final offset = isBST ? 1 : 0;

    return TimeZoneInfo(
      code:        code,
      name:        _zoneNames[code]!,
      offset:      isBST ? '+01:00' : '+00:00',
      offsetHours: offset,
      flag:        '🇬🇧',
      location:    'London, Manchester, Edinburgh',
      localTime:   utcNow.add(Duration(hours: offset)),
    );
  }

  /// Mendapatkan [TimeZoneInfo] untuk kode zona mana pun.
  ///
  /// Gunakan ini saat ingin menampilkan info zona waktu suatu lokasi
  /// berdasarkan data dari [LocationModel.timezone].
  static TimeZoneInfo getZoneInfo(String zoneCode, {DateTime? now}) {
    final code = zoneCode.toUpperCase();

    if (code == 'LONDON') return getLondonInfo(now: now);

    final utcNow   = (now ?? DateTime.now()).toUtc();
    var effectiveCode = code;
    var offset = _getOffsetForZone(code, utcNow);
    if (code == 'CET' || code == 'CEST') {
      final summer = _isEuropeanSummerTime(utcNow);
      effectiveCode = summer ? 'CEST' : 'CET';
      offset = summer ? 2 : 1;
    } else if (code == 'EET' || code == 'EEST') {
      final summer = _isEuropeanSummerTime(utcNow);
      effectiveCode = summer ? 'EEST' : 'EET';
      offset = summer ? 3 : 2;
    } else if (code == 'EST' || code == 'EDT') {
      final summer = _isUsDaylightTime(utcNow, -5);
      effectiveCode = summer ? 'EDT' : 'EST';
      offset = summer ? -4 : -5;
    } else if (code == 'PST' || code == 'PDT') {
      final summer = _isUsDaylightTime(utcNow, -8);
      effectiveCode = summer ? 'PDT' : 'PST';
      offset = summer ? -7 : -8;
    } else if (code == 'AEST' || code == 'AEDT') {
      final summer = _isAustralianEasternDaylightTime(utcNow);
      effectiveCode = summer ? 'AEDT' : 'AEST';
      offset = summer ? 11 : 10;
    }
    final sign     = offset >= 0 ? '+' : '-';
    final absOff   = offset.abs();
    final offsetStr = '$sign${absOff.toString().padLeft(2, '0')}:00';

    return TimeZoneInfo(
      code:        effectiveCode,
      name:        _zoneNames[effectiveCode] ?? effectiveCode,
      offset:      offsetStr,
      offsetHours: offset,
      flag:        _zoneFlags[effectiveCode] ?? '🌍',
      location:    _zoneLocations[effectiveCode] ?? '',
      localTime:   utcNow.add(Duration(hours: offset)),
    );
  }

  /// Mendapatkan daftar semua zona waktu relevan untuk panel Finance Hub.
  ///
  /// Mencakup zona Indonesia, London, Tokyo, dan zona Euro (CET).
  static List<TimeZoneInfo> getAllZones({DateTime? now}) {
    final utcNow = (now ?? DateTime.now()).toUtc();
    final londonInfo = getLondonInfo(now: utcNow);
    final zones = <TimeZoneInfo>[];

    // Zona Indonesia
    for (final code in ['WIB', 'WITA', 'WIT']) {
      final offset = _zoneOffsets[code]!;
      zones.add(TimeZoneInfo(
        code:        code,
        name:        _zoneNames[code]!,
        offset:      '+0$offset:00',
        offsetHours: offset,
        flag:        _zoneFlags[code]!,
        location:    _zoneLocations[code]!,
        localTime:   utcNow.add(Duration(hours: offset)),
      ));
    }

    // London (dinamis GMT/BST)
    zones.add(londonInfo);

    // Tokyo (JST UTC+9)
    zones.add(getZoneInfo('JST', now: utcNow));

    // Paris/Berlin (CET UTC+1)
    zones.add(getZoneInfo('CET', now: utcNow));

    return zones;
  }

  /// Memformat DateTime menjadi string waktu HH:mm:ss
  static String formatTime(DateTime dt) => DateFormat('HH:mm:ss').format(dt);

  /// Memformat DateTime menjadi string waktu singkat HH:mm
  static String formatTimeShort(DateTime dt) => DateFormat('HH:mm').format(dt);

  /// Memformat DateTime menjadi string tanggal lengkap dengan hari.
  /// Formats a date in English, for example "Wednesday, 21 October 2026".
  static String formatDate(DateTime dt) =>
      DateFormat('EEEE, d MMMM yyyy').format(dt);

  /// Mengkonversi waktu dari satu zona ke zona lain.
  ///
  /// [sourceTime] waktu di zona asal
  /// [fromZone] kode zona asal, misal "WIB"
  /// [toZone] kode zona tujuan, misal "JST"
  static DateTime convertBetweenZones({
    required DateTime sourceTime,
    required String fromZone,
    required String toZone,
  }) {
    final sourceUtcDate = DateTime.utc(
      sourceTime.year,
      sourceTime.month,
      sourceTime.day,
      sourceTime.hour,
      sourceTime.minute,
      sourceTime.second,
      sourceTime.millisecond,
      sourceTime.microsecond,
    );
    final fromOffset = _getOffsetForZone(fromZone, sourceUtcDate);
    final utc = sourceTime.subtract(Duration(hours: fromOffset));
    final utcDate = DateTime.utc(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
      utc.millisecond,
      utc.microsecond,
    );
    final toOffset = _getOffsetForZone(toZone, utcDate);
    return utc.add(Duration(hours: toOffset));
  }

  // ─── Helper Privat ──────────────────────────────────────────────────────────

  static int _getOffsetForZone(String zone, DateTime utcNow) {
    final code = zone.toUpperCase();
    if (code == 'LONDON') {
      return _isUkBST(utcNow) ? 1 : 0;
    }
    if (code == 'CET' || code == 'CEST') {
      return _isEuropeanSummerTime(utcNow) ? 2 : 1;
    }
    if (code == 'EET' || code == 'EEST') {
      return _isEuropeanSummerTime(utcNow) ? 3 : 2;
    }
    if (code == 'EST' || code == 'EDT') {
      return _isUsDaylightTime(utcNow, -5) ? -4 : -5;
    }
    if (code == 'PST' || code == 'PDT') {
      return _isUsDaylightTime(utcNow, -8) ? -7 : -8;
    }
    if (code == 'AEST' || code == 'AEDT') {
      return _isAustralianEasternDaylightTime(utcNow) ? 11 : 10;
    }
    return _zoneOffsets[code] ?? 0;
  }

  /// Debug: cetak semua zona saat ini ke konsol
  static void debugPrintZones() {
    final zones = getAllZones();
    for (final z in zones) {
      debugPrint('[TimeZone] ${z.code}: ${formatTime(z.localTime)} (${z.offset})');
    }
  }
}
