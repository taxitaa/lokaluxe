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

/// Service untuk konversi dan pengecekan zona waktu Indonesia & internasional.
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
    'PST':  -8,  // Pacific Standard Time (Los Angeles)

    // Australia
    'AEST': 10,  // Australian Eastern Standard Time
  };

  static const Map<String, String> _zoneNames = {
    'WIB':  'Waktu Indonesia Barat',
    'WITA': 'Waktu Indonesia Tengah',
    'WIT':  'Waktu Indonesia Timur',
    'GMT':  'Greenwich Mean Time',
    'BST':  'British Summer Time',
    'JST':  'Japan Standard Time',
    'CET':  'Central European Time',
    'CEST': 'Central European Summer Time',
    'EET':  'Eastern European Time',
    'SGT':  'Singapore Time',
    'MYT':  'Malaysia Time',
    'KST':  'Korea Standard Time',
    'GST':  'Gulf Standard Time',
    'EST':  'Eastern Standard Time',
    'PST':  'Pacific Standard Time',
    'AEST': 'Australian Eastern Standard Time',
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
    'SGT':  '🇸🇬',
    'MYT':  '🇲🇾',
    'KST':  '🇰🇷',
    'GST':  '🇦🇪',
    'EST':  '🇺🇸',
    'PST':  '🇺🇸',
    'AEST': '🇦🇺',
  };

  static const Map<String, String> _zoneLocations = {
    'WIB':  'Jakarta, Medan, Bandung, Surabaya',
    'WITA': 'Bali, Makassar, Balikpapan',
    'WIT':  'Jayapura, Ambon, Sorong',
    'GMT':  'London (GMT, Nov–Mar)',
    'BST':  'London (BST, Apr–Okt)',
    'JST':  'Tokyo, Osaka, Kyoto',
    'CET':  'Paris, Berlin, Roma, Madrid, Amsterdam',
    'CEST': 'Paris, Berlin, Roma (musim panas)',
    'EET':  'Athena, Ankara',
    'SGT':  'Singapura',
    'MYT':  'Kuala Lumpur',
    'KST':  'Seoul, Busan',
    'GST':  'Dubai, Abu Dhabi',
    'EST':  'New York, Washington D.C.',
    'PST':  'Los Angeles, San Francisco',
    'AEST': 'Sydney, Melbourne',
  };

  // ─── Logika BST (British Summer Time) ──────────────────────────────────────

  /// Menentukan apakah saat ini London sedang menggunakan BST.
  ///
  /// BST berlaku dari Minggu terakhir Maret (01:00 UTC) hingga
  /// Minggu terakhir Oktober (01:00 UTC).
  static bool _isUkBST(DateTime utcNow) {
    final year = utcNow.year;
    final bstStart = DateTime.utc(year, 3, _lastSundayOf(year, 3), 1);
    final bstEnd   = DateTime.utc(year, 10, _lastSundayOf(year, 10), 1);
    return utcNow.isAfter(bstStart) && utcNow.isBefore(bstEnd);
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

  // ─── API Publik ─────────────────────────────────────────────────────────────

  /// Mendapatkan waktu lokal saat ini untuk kode zona tertentu.
  ///
  /// [zoneCode] contoh: "WIB", "JST", "CET", "GMT", "LONDON"
  /// Nilai "LONDON" akan otomatis memilih GMT atau BST berdasarkan tanggal.
  static DateTime getLocalTime(String zoneCode) {
    final utcNow = DateTime.now().toUtc();

    if (zoneCode.toUpperCase() == 'LONDON') {
      final offset = _isUkBST(utcNow) ? 1 : 0;
      return utcNow.add(Duration(hours: offset));
    }

    final offset = _zoneOffsets[zoneCode.toUpperCase()] ?? 0;
    return utcNow.add(Duration(hours: offset));
  }

  /// Mendapatkan offset UTC (dalam jam) untuk kode zona tertentu.
  ///
  /// Mengembalikan 0 jika kode tidak dikenali.
  static int getOffsetHours(String zoneCode) {
    return _getOffsetForZone(zoneCode);
  }

  /// Mendapatkan info lengkap zona waktu London (otomatis GMT atau BST).
  static TimeZoneInfo getLondonInfo() {
    final utcNow = DateTime.now().toUtc();
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
      localTime:   DateTime.now().toUtc().add(Duration(hours: offset)),
    );
  }

  /// Mendapatkan [TimeZoneInfo] untuk kode zona mana pun.
  ///
  /// Gunakan ini saat ingin menampilkan info zona waktu suatu lokasi
  /// berdasarkan data dari [LocationModel.timezone].
  static TimeZoneInfo getZoneInfo(String zoneCode) {
    final code = zoneCode.toUpperCase();

    if (code == 'LONDON') return getLondonInfo();

    final offset   = _zoneOffsets[code] ?? 0;
    final utcNow   = DateTime.now().toUtc();
    final sign     = offset >= 0 ? '+' : '-';
    final absOff   = offset.abs();
    final offsetStr = '$sign${absOff.toString().padLeft(2, '0')}:00';

    return TimeZoneInfo(
      code:        code,
      name:        _zoneNames[code] ?? code,
      offset:      offsetStr,
      offsetHours: offset,
      flag:        _zoneFlags[code] ?? '🌍',
      location:    _zoneLocations[code] ?? '',
      localTime:   utcNow.add(Duration(hours: offset)),
    );
  }

  /// Mendapatkan daftar semua zona waktu relevan untuk panel Finance Hub.
  ///
  /// Mencakup zona Indonesia, London, Tokyo, dan zona Euro (CET).
  static List<TimeZoneInfo> getAllZones() {
    final utcNow = DateTime.now().toUtc();
    final londonInfo = getLondonInfo();
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
    zones.add(getZoneInfo('JST'));

    // Paris/Berlin (CET UTC+1)
    zones.add(getZoneInfo('CET'));

    return zones;
  }

  /// Memformat DateTime menjadi string waktu HH:mm:ss
  static String formatTime(DateTime dt) => DateFormat('HH:mm:ss').format(dt);

  /// Memformat DateTime menjadi string waktu singkat HH:mm
  static String formatTimeShort(DateTime dt) => DateFormat('HH:mm').format(dt);

  /// Memformat DateTime menjadi string tanggal lengkap dengan hari.
  /// Contoh: "Selasa, 21 Oktober 2026"
  static String formatDate(DateTime dt) {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    const days = [
      '', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu',
    ];
    return '${days[dt.weekday]}, ${dt.day} ${months[dt.month]} ${dt.year}';
  }

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
    final fromOffset = _getOffsetForZone(fromZone);
    final toOffset   = _getOffsetForZone(toZone);
    final utc = sourceTime.subtract(Duration(hours: fromOffset));
    return utc.add(Duration(hours: toOffset));
  }

  // ─── Helper Privat ──────────────────────────────────────────────────────────

  static int _getOffsetForZone(String zone) {
    if (zone.toUpperCase() == 'LONDON') {
      return _isUkBST(DateTime.now().toUtc()) ? 1 : 0;
    }
    return _zoneOffsets[zone.toUpperCase()] ?? 0;
  }

  /// Debug: cetak semua zona saat ini ke konsol
  static void debugPrintZones() {
    final zones = getAllZones();
    for (final z in zones) {
      debugPrint('[TimeZone] ${z.code}: ${formatTime(z.localTime)} (${z.offset})');
    }
  }
}
