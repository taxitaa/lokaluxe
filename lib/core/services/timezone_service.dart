import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Model untuk merepresentasikan satu zona waktu
class TimeZoneInfo {
  final String code;        // Kode zona, misal: "WIB"
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

/// Service untuk konversi dan pengecekan zona waktu Indonesia & internasional
///
/// Mendukung: WIB (UTC+7), WITA (UTC+8), WIT (UTC+9), London GMT/BST
class TimeZoneService {
  // Definisi zona waktu statis (offset UTC dalam jam)
  static const Map<String, int> _zoneOffsets = {
    'WIB': 7,    // Waktu Indonesia Barat (Jawa, Sumatera, Kalimantan Barat & Tengah)
    'WITA': 8,   // Waktu Indonesia Tengah (Bali, NTT, NTB, Kalimantan Timur & Selatan, Sulawesi)
    'WIT': 9,    // Waktu Indonesia Timur (Papua, Maluku)
    'GMT': 0,    // London GMT (musim dingin)
    'BST': 1,    // British Summer Time (musim panas, aktif Maret-Oktober)
  };

  static const Map<String, String> _zoneNames = {
    'WIB': 'Waktu Indonesia Barat',
    'WITA': 'Waktu Indonesia Tengah',
    'WIT': 'Waktu Indonesia Timur',
    'GMT': 'Greenwich Mean Time',
    'BST': 'British Summer Time',
  };

  static const Map<String, String> _zoneFlags = {
    'WIB': '🇮🇩',
    'WITA': '🇮🇩',
    'WIT': '🇮🇩',
    'GMT': '🇬🇧',
    'BST': '🇬🇧',
  };

  static const Map<String, String> _zoneLocations = {
    'WIB': 'Jakarta, Medan, Bandung, Surabaya',
    'WITA': 'Bali, Makassar, Balikpapan',
    'WIT': 'Jayapura, Ambon, Sorong',
    'GMT': 'London (GMT, Nov–Mar)',
    'BST': 'London (BST, Apr–Okt)',
  };

  /// Menentukan apakah saat ini London sedang menggunakan BST (British Summer Time)
  ///
  /// BST berlaku dari hari Minggu terakhir Maret hingga hari Minggu terakhir Oktober
  static bool _isUkBST(DateTime utcNow) {
    final year = utcNow.year;

    // Cari hari Minggu terakhir di bulan Maret (awal BST) pukul 01:00 UTC
    final lastSundayMarch = _lastSundayOf(year, 3);
    final bstStart = DateTime.utc(year, 3, lastSundayMarch, 1, 0, 0);

    // Cari hari Minggu terakhir di bulan Oktober (akhir BST) pukul 01:00 UTC
    final lastSundayOctober = _lastSundayOf(year, 10);
    final bstEnd = DateTime.utc(year, 10, lastSundayOctober, 1, 0, 0);

    return utcNow.isAfter(bstStart) && utcNow.isBefore(bstEnd);
  }

  /// Mencari tanggal hari Minggu terakhir dalam [month] di [year]
  static int _lastSundayOf(int year, int month) {
    // Mulai dari hari terakhir bulan, mundur sampai Minggu (weekday == 7)
    final lastDay = DateTime.utc(year, month + 1, 0); // hari terakhir bulan ini
    int day = lastDay.day;
    while (DateTime.utc(year, month, day).weekday != DateTime.sunday) {
      day--;
    }
    return day;
  }

  /// Mendapatkan waktu lokal saat ini untuk zona tertentu berdasarkan UTC
  ///
  /// [zoneCode] kode zona: WIB / WITA / WIT / GMT / BST / London
  static DateTime getLocalTime(String zoneCode) {
    final utcNow = DateTime.now().toUtc();

    // "London" secara otomatis memilih GMT atau BST
    if (zoneCode.toUpperCase() == 'LONDON') {
      final isBST = _isUkBST(utcNow);
      final offset = isBST ? 1 : 0;
      return utcNow.add(Duration(hours: offset));
    }

    final offset = _zoneOffsets[zoneCode.toUpperCase()] ?? 0;
    return utcNow.add(Duration(hours: offset));
  }

  /// Mendapatkan info lengkap zona waktu London (otomatis GMT atau BST)
  static TimeZoneInfo getLondonInfo() {
    final utcNow = DateTime.now().toUtc();
    final isBST = _isUkBST(utcNow);
    final code = isBST ? 'BST' : 'GMT';
    final offset = isBST ? 1 : 0;
    final localTime = utcNow.add(Duration(hours: offset));

    return TimeZoneInfo(
      code: code,
      name: _zoneNames[code]!,
      offset: isBST ? '+01:00' : '+00:00',
      offsetHours: offset,
      flag: '🇬🇧',
      location: 'London, Manchester, Edinburgh',
      localTime: localTime,
    );
  }

  /// Mendapatkan daftar semua zona waktu yang relevan dengan info lengkap
  static List<TimeZoneInfo> getAllZones() {
    final utcNow = DateTime.now().toUtc();
    final londonInfo = getLondonInfo();

    final List<TimeZoneInfo> zones = [];

    // Zona Indonesia
    for (final code in ['WIB', 'WITA', 'WIT']) {
      final offset = _zoneOffsets[code]!;
      zones.add(TimeZoneInfo(
        code: code,
        name: _zoneNames[code]!,
        offset: '+0${offset}:00',
        offsetHours: offset,
        flag: _zoneFlags[code]!,
        location: _zoneLocations[code]!,
        localTime: utcNow.add(Duration(hours: offset)),
      ));
    }

    // Tambahkan London
    zones.add(londonInfo);

    return zones;
  }

  /// Memformat DateTime menjadi string waktu HH:mm:ss
  static String formatTime(DateTime dt) {
    return DateFormat('HH:mm:ss').format(dt);
  }

  /// Memformat DateTime menjadi string tanggal lengkap dengan hari
  /// Contoh: "Selasa, 21 Oktober 2026"
  static String formatDate(DateTime dt) {
    const months = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    const days = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

    return '${days[dt.weekday]}, ${dt.day} ${months[dt.month]} ${dt.year}';
  }

  /// Mengkonversi waktu dari satu zona ke zona lain
  ///
  /// [sourceTime] waktu sumber
  /// [fromZone] kode zona asal
  /// [toZone] kode zona tujuan
  static DateTime convertBetweenZones({
    required DateTime sourceTime,
    required String fromZone,
    required String toZone,
  }) {
    // Ubah ke UTC dulu, lalu tambahkan offset tujuan
    final fromOffset = _getOffsetForZone(fromZone);
    final toOffset = _getOffsetForZone(toZone);

    final utc = sourceTime.subtract(Duration(hours: fromOffset));
    return utc.add(Duration(hours: toOffset));
  }

  /// Helper: mendapatkan offset jam untuk zona tertentu
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
