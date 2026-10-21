import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';
import 'currency_provider.dart';

/// Provider untuk manajemen lokasi aktif pengguna.
///
/// Bertanggung jawab:
/// 1. Menyimpan & memuat lokasi aktif (persistent via SharedPreferences)
/// 2. Mengorkestrasi perubahan mata uang & zona waktu otomatis saat lokasi berubah
/// 3. Menyediakan informasi lokasi ke seluruh widget tree (Provider pattern)
///
/// Hierarki logika pemilihan mata uang:
///   Indonesia  → IDR (otomatis)
///   Jepang     → JPY (otomatis)
///   Zona Euro  → EUR (otomatis)
///   Lainnya    → USD atau IDR (user pilih via [otherRegionCurrency])
class LocationProvider extends ChangeNotifier {
  // ── Lokasi aktif saat ini ─────────────────────────────────────────────────
  LocationModel _currentLocation = LocationDatabase.defaultLocation;

  // ── Fallback currency untuk region "other" (USD atau IDR) ────────────────
  // Default ke USD; user bisa toggle ke IDR via UI
  String _otherRegionCurrency = 'USD';

  // ── Key SharedPreferences ─────────────────────────────────────────────────
  static const String _locationPrefKey = 'selected_location_id';
  static const String _otherCurrencyPrefKey = 'other_region_currency';

  // ── Referensi ke CurrencyProvider agar bisa trigger perubahan mata uang ──
  final CurrencyProvider _currencyProvider;

  LocationProvider(this._currencyProvider);

  // ─── Getters ──────────────────────────────────────────────────────────────

  /// Lokasi yang sedang aktif dipilih pengguna
  LocationModel get currentLocation => _currentLocation;

  /// Fallback currency untuk negara "other" (USD / IDR)
  String get otherRegionCurrency => _otherRegionCurrency;

  /// Mata uang efektif berdasarkan lokasi + setting fallback
  String get effectiveCurrency {
    if (_currentLocation.isOtherRegion) return _otherRegionCurrency;
    return _currentLocation.currency;
  }

  /// Zona waktu aktif berdasarkan lokasi yang dipilih
  String get activeTimezone => _currentLocation.timezone;

  /// Offset UTC dalam jam
  int get timezoneOffsetHours => _currentLocation.timezoneOffset;

  /// Waktu lokal saat ini berdasarkan lokasi aktif
  DateTime get localNow =>
      DateTime.now().toUtc().add(Duration(hours: _currentLocation.timezoneOffset));

  /// True jika lokasi aktif termasuk Indonesia
  bool get isIndonesiaRegion => _currentLocation.isIndonesia;

  /// True jika lokasi aktif termasuk negara "other" (perlu selector USD/IDR)
  bool get needsCurrencySelector => _currentLocation.isOtherRegion;

  // ─── Inisialisasi ─────────────────────────────────────────────────────────

  /// Memuat lokasi & preferensi tersimpan, lalu sinkronkan mata uang.
  ///
  /// Harus dipanggil sekali saat aplikasi pertama kali startup.
  Future<void> initialize() async {
    await _loadSavedLocation();
    // Sinkronkan mata uang dengan lokasi yang sudah dimuat
    await _syncCurrencyWithLocation(_currentLocation, notify: false);
  }

  /// Memuat ID lokasi yang tersimpan dari SharedPreferences
  Future<void> _loadSavedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_locationPrefKey);
      final savedOtherCurrency = prefs.getString(_otherCurrencyPrefKey);

      if (savedOtherCurrency != null &&
          (savedOtherCurrency == 'USD' || savedOtherCurrency == 'IDR')) {
        _otherRegionCurrency = savedOtherCurrency;
      }

      if (savedId != null) {
        final found = LocationDatabase.findById(savedId);
        if (found != null) {
          _currentLocation = found;
          debugPrint('[LocationProvider] Lokasi dimuat: ${found.displayName}');
        }
      }
    } catch (e) {
      debugPrint('[LocationProvider] Gagal memuat lokasi tersimpan: $e');
    }
  }

  // ─── Aksi Publik ──────────────────────────────────────────────────────────

  /// Mengubah lokasi aktif dan otomatis menyesuaikan mata uang & timezone.
  ///
  /// [location] lokasi baru yang dipilih pengguna
  ///
  /// Logika mata uang:
  /// - Indonesia → IDR
  /// - Jepang    → JPY
  /// - Zona Euro → EUR
  /// - Lainnya   → [otherRegionCurrency] (USD atau IDR, bisa diubah user)
  Future<void> changeLocation(LocationModel location) async {
    if (_currentLocation.id == location.id) return;

    _currentLocation = location;
    await _saveLocationPreference(location.id);
    await _syncCurrencyWithLocation(location);

    debugPrint('[LocationProvider] Lokasi diubah: ${location.displayName} '
        '| Currency: ${effectiveCurrency} | TZ: ${location.timezone} UTC+${location.timezoneOffset}');
  }

  /// Mengubah fallback currency untuk region "other" (USD ↔ IDR).
  ///
  /// Hanya berlaku jika lokasi aktif adalah region "other".
  /// Setelah diubah, CurrencyProvider akan ikut terupdate.
  Future<void> changeOtherRegionCurrency(String currency) async {
    assert(currency == 'USD' || currency == 'IDR',
        'otherRegionCurrency hanya boleh USD atau IDR');
    if (_otherRegionCurrency == currency) return;

    _otherRegionCurrency = currency;
    await _saveOtherCurrencyPreference(currency);

    // Jika lokasi aktif memang "other", update CurrencyProvider
    if (_currentLocation.isOtherRegion) {
      await _currencyProvider.changeCurrency(currency);
    }

    notifyListeners();
    debugPrint('[LocationProvider] Fallback currency diubah ke: $currency');
  }

  // ─── Helper Privat ────────────────────────────────────────────────────────

  /// Sinkronkan CurrencyProvider dengan mata uang yang sesuai lokasi.
  ///
  /// [notify] jika false, tidak akan memanggil notifyListeners()
  /// (digunakan saat inisialisasi agar tidak trigger rebuild ganda)
  Future<void> _syncCurrencyWithLocation(
    LocationModel location, {
    bool notify = true,
  }) async {
    String targetCurrency;

    if (location.isIndonesia) {
      targetCurrency = 'IDR';
    } else if (location.isJapan) {
      targetCurrency = 'JPY';
    } else if (location.isEurozone) {
      targetCurrency = 'EUR';
    } else {
      // Region "other": gunakan preferensi user (USD atau IDR)
      targetCurrency = _otherRegionCurrency;
    }

    // Update CurrencyProvider (tidak perlu await penuh karena hanya preference)
    await _currencyProvider.changeCurrency(targetCurrency);

    if (notify) notifyListeners();
  }

  /// Menyimpan ID lokasi ke SharedPreferences
  Future<void> _saveLocationPreference(String locationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_locationPrefKey, locationId);
    } catch (e) {
      debugPrint('[LocationProvider] Gagal menyimpan lokasi: $e');
    }
  }

  /// Menyimpan preferensi fallback currency ke SharedPreferences
  Future<void> _saveOtherCurrencyPreference(String currency) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_otherCurrencyPrefKey, currency);
    } catch (e) {
      debugPrint('[LocationProvider] Gagal menyimpan preferensi currency: $e');
    }
  }
}
