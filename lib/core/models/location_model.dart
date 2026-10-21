/// Model yang merepresentasikan satu lokasi yang bisa dipilih pengguna.
///
/// Setiap lokasi memiliki relasi dengan:
/// - Mata uang otomatis (misal Indonesia → IDR, Jepang → JPY)
/// - Zona waktu otomatis (misal Tokyo → Asia/Tokyo UTC+9)
/// - Kategori konversi untuk fallback (IDR/EUR/JPY vs "OTHER")
class LocationModel {
  final String id;           // ID unik, misal: "id-jakarta"
  final String city;         // Nama kota
  final String country;      // Nama negara
  final String countryCode;  // ISO 3166-1 alpha-2, misal: "ID"
  final String flag;         // Emoji bendera
  final String currency;     // Kode mata uang default (IDR/JPY/EUR/USD)
  final String timezone;     // Kode timezone, misal: "WIB", "JST", "CET"
  final int timezoneOffset;  // Offset UTC dalam jam, misal: 7 untuk WIB
  final String region;       // Region besar: "indonesia", "japan", "eurozone", "other"

  const LocationModel({
    required this.id,
    required this.city,
    required this.country,
    required this.countryCode,
    required this.flag,
    required this.currency,
    required this.timezone,
    required this.timezoneOffset,
    required this.region,
  });

  /// Apakah lokasi ini menggunakan mata uang IDR (Indonesia)
  bool get isIndonesia => region == 'indonesia';

  /// Apakah lokasi ini menggunakan mata uang JPY (Jepang)
  bool get isJapan => region == 'japan';

  /// Apakah lokasi ini menggunakan mata uang EUR (Zona Euro)
  bool get isEurozone => region == 'eurozone';

  /// Apakah lokasi ini berada di luar 3 kawasan utama (perlu fallback USD/IDR)
  bool get isOtherRegion => region == 'other';

  /// Nama lengkap lokasi: "Jakarta, Indonesia 🇮🇩"
  String get displayName => '$city, $country $flag';

  /// Label singkat: "Jakarta 🇮🇩"
  String get shortLabel => '$city $flag';

  @override
  String toString() => displayName;
}

/// Database lokasi yang tersedia untuk dipilih pengguna.
///
/// Mencakup kota-kota utama dari:
/// - Indonesia (IDR, WIB/WITA/WIT)
/// - Jepang (JPY, JST UTC+9)
/// - Zona Euro (EUR, berbagai offset UTC)
/// - Negara lain (OTHER, fallback USD/IDR)
class LocationDatabase {
  /// Semua lokasi yang tersedia untuk dipilih
  static const List<LocationModel> all = [
    // ─── INDONESIA ────────────────────────────────────────────
    LocationModel(
      id: 'id-jakarta',
      city: 'Jakarta',
      country: 'Indonesia',
      countryCode: 'ID',
      flag: '🇮🇩',
      currency: 'IDR',
      timezone: 'WIB',
      timezoneOffset: 7,
      region: 'indonesia',
    ),
    LocationModel(
      id: 'id-bali',
      city: 'Bali',
      country: 'Indonesia',
      countryCode: 'ID',
      flag: '🇮🇩',
      currency: 'IDR',
      timezone: 'WITA',
      timezoneOffset: 8,
      region: 'indonesia',
    ),
    LocationModel(
      id: 'id-surabaya',
      city: 'Surabaya',
      country: 'Indonesia',
      countryCode: 'ID',
      flag: '🇮🇩',
      currency: 'IDR',
      timezone: 'WIB',
      timezoneOffset: 7,
      region: 'indonesia',
    ),
    LocationModel(
      id: 'id-medan',
      city: 'Medan',
      country: 'Indonesia',
      countryCode: 'ID',
      flag: '🇮🇩',
      currency: 'IDR',
      timezone: 'WIB',
      timezoneOffset: 7,
      region: 'indonesia',
    ),
    LocationModel(
      id: 'id-makassar',
      city: 'Makassar',
      country: 'Indonesia',
      countryCode: 'ID',
      flag: '🇮🇩',
      currency: 'IDR',
      timezone: 'WITA',
      timezoneOffset: 8,
      region: 'indonesia',
    ),
    LocationModel(
      id: 'id-jayapura',
      city: 'Jayapura',
      country: 'Indonesia',
      countryCode: 'ID',
      flag: '🇮🇩',
      currency: 'IDR',
      timezone: 'WIT',
      timezoneOffset: 9,
      region: 'indonesia',
    ),

    // ─── JEPANG ───────────────────────────────────────────────
    LocationModel(
      id: 'jp-tokyo',
      city: 'Tokyo',
      country: 'Jepang',
      countryCode: 'JP',
      flag: '🇯🇵',
      currency: 'JPY',
      timezone: 'JST',
      timezoneOffset: 9,
      region: 'japan',
    ),
    LocationModel(
      id: 'jp-osaka',
      city: 'Osaka',
      country: 'Jepang',
      countryCode: 'JP',
      flag: '🇯🇵',
      currency: 'JPY',
      timezone: 'JST',
      timezoneOffset: 9,
      region: 'japan',
    ),
    LocationModel(
      id: 'jp-kyoto',
      city: 'Kyoto',
      country: 'Jepang',
      countryCode: 'JP',
      flag: '🇯🇵',
      currency: 'JPY',
      timezone: 'JST',
      timezoneOffset: 9,
      region: 'japan',
    ),

    // ─── ZONA EURO ────────────────────────────────────────────
    LocationModel(
      id: 'fr-paris',
      city: 'Paris',
      country: 'Prancis',
      countryCode: 'FR',
      flag: '🇫🇷',
      currency: 'EUR',
      timezone: 'CET',
      timezoneOffset: 1,
      region: 'eurozone',
    ),
    LocationModel(
      id: 'de-berlin',
      city: 'Berlin',
      country: 'Jerman',
      countryCode: 'DE',
      flag: '🇩🇪',
      currency: 'EUR',
      timezone: 'CET',
      timezoneOffset: 1,
      region: 'eurozone',
    ),
    LocationModel(
      id: 'it-rome',
      city: 'Roma',
      country: 'Italia',
      countryCode: 'IT',
      flag: '🇮🇹',
      currency: 'EUR',
      timezone: 'CET',
      timezoneOffset: 1,
      region: 'eurozone',
    ),
    LocationModel(
      id: 'es-madrid',
      city: 'Madrid',
      country: 'Spanyol',
      countryCode: 'ES',
      flag: '🇪🇸',
      currency: 'EUR',
      timezone: 'CET',
      timezoneOffset: 1,
      region: 'eurozone',
    ),
    LocationModel(
      id: 'nl-amsterdam',
      city: 'Amsterdam',
      country: 'Belanda',
      countryCode: 'NL',
      flag: '🇳🇱',
      currency: 'EUR',
      timezone: 'CET',
      timezoneOffset: 1,
      region: 'eurozone',
    ),
    LocationModel(
      id: 'gr-athens',
      city: 'Athena',
      country: 'Yunani',
      countryCode: 'GR',
      flag: '🇬🇷',
      currency: 'EUR',
      timezone: 'EET',
      timezoneOffset: 2,
      region: 'eurozone',
    ),

    // ─── NEGARA LAIN (fallback USD/IDR) ──────────────────────
    LocationModel(
      id: 'gb-london',
      city: 'London',
      country: 'Inggris',
      countryCode: 'GB',
      flag: '🇬🇧',
      currency: 'USD', // Default fallback, user bisa ganti ke IDR
      timezone: 'GMT',
      timezoneOffset: 0,
      region: 'other',
    ),
    LocationModel(
      id: 'au-sydney',
      city: 'Sydney',
      country: 'Australia',
      countryCode: 'AU',
      flag: '🇦🇺',
      currency: 'USD',
      timezone: 'AEST',
      timezoneOffset: 10,
      region: 'other',
    ),
    LocationModel(
      id: 'us-newyork',
      city: 'New York',
      country: 'Amerika Serikat',
      countryCode: 'US',
      flag: '🇺🇸',
      currency: 'USD',
      timezone: 'EST',
      timezoneOffset: -5,
      region: 'other',
    ),
    LocationModel(
      id: 'us-la',
      city: 'Los Angeles',
      country: 'Amerika Serikat',
      countryCode: 'US',
      flag: '🇺🇸',
      currency: 'USD',
      timezone: 'PST',
      timezoneOffset: -8,
      region: 'other',
    ),
    LocationModel(
      id: 'sg-singapore',
      city: 'Singapura',
      country: 'Singapura',
      countryCode: 'SG',
      flag: '🇸🇬',
      currency: 'USD',
      timezone: 'SGT',
      timezoneOffset: 8,
      region: 'other',
    ),
    LocationModel(
      id: 'my-kualalumpur',
      city: 'Kuala Lumpur',
      country: 'Malaysia',
      countryCode: 'MY',
      flag: '🇲🇾',
      currency: 'USD',
      timezone: 'MYT',
      timezoneOffset: 8,
      region: 'other',
    ),
    LocationModel(
      id: 'ae-dubai',
      city: 'Dubai',
      country: 'Uni Emirat Arab',
      countryCode: 'AE',
      flag: '🇦🇪',
      currency: 'USD',
      timezone: 'GST',
      timezoneOffset: 4,
      region: 'other',
    ),
    LocationModel(
      id: 'kr-seoul',
      city: 'Seoul',
      country: 'Korea Selatan',
      countryCode: 'KR',
      flag: '🇰🇷',
      currency: 'USD',
      timezone: 'KST',
      timezoneOffset: 9,
      region: 'other',
    ),
  ];

  /// Mencari lokasi berdasarkan query (city/country/countryCode)
  static List<LocationModel> search(String query) {
    if (query.isEmpty) return all;
    final q = query.toLowerCase();
    return all.where((loc) {
      return loc.city.toLowerCase().contains(q) ||
          loc.country.toLowerCase().contains(q) ||
          loc.countryCode.toLowerCase().contains(q);
    }).toList();
  }

  /// Mendapatkan lokasi default (Jakarta, Indonesia)
  static LocationModel get defaultLocation => all.first;

  /// Mendapatkan lokasi berdasarkan ID
  static LocationModel? findById(String id) {
    try {
      return all.firstWhere((loc) => loc.id == id);
    } catch (_) {
      return null;
    }
  }
}
