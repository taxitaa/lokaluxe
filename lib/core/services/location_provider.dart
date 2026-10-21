import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';
import 'currency_provider.dart';
import 'localization_provider.dart';

/// Provider untuk manajemen lokasi aktif pengguna.
///
/// Bertanggung jawab:
/// 1. Menyimpan & memuat lokasi aktif (persistent via SharedPreferences)
/// 2. Mengorkestrasi perubahan mata uang & zona waktu otomatis saat lokasi berubah
/// 3. Mengaktifkan bahasa UI yang sesuai via [LocalizationProvider]
/// 4. Menyediakan informasi lokasi ke seluruh widget tree (Provider pattern)
///
/// Hierarki logika pemilihan mata uang:
///   Indonesia  → IDR (otomatis)
///   Jepang     → JPY (otomatis)
///   Zona Euro  → EUR (otomatis)
///   Lainnya    → USD atau IDR (user pilih via [otherRegionCurrency])
///
/// Hierarki logika bahasa:
///   Indonesia  → Bahasa Indonesia (id)
///   Lainnya    → English (en)
class LocationProvider extends ChangeNotifier {
  // ── Lokasi aktif saat ini ──────────────────────────────────────────────────
  LocationModel _currentLocation = LocationDatabase.defaultLocation;

  // ── Fallback currency untuk region "other" (USD atau IDR) ─────────────────
  String _otherRegionCurrency = 'USD';

  // ── Key SharedPreferences ──────────────────────────────────────────────────
  static const String _locationPrefKey  = 'selected_location_id';
  static const String _otherCurrencyPrefKey = 'other_region_currency';

  // ── Dependencies ───────────────────────────────────────────────────────────
  final CurrencyProvider _currencyProvider;
  final LocalizationProvider _localizationProvider;

  LocationProvider(this._currencyProvider, this._localizationProvider);

  // ─── Getters ───────────────────────────────────────────────────────────────

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
  DateTime get localNow => DateTime.now().toUtc()
      .add(Duration(hours: _currentLocation.timezoneOffset));

  /// True jika lokasi aktif termasuk Indonesia
  bool get isIndonesiaRegion => _currentLocation.isIndonesia;

  /// True jika lokasi aktif termasuk negara "other" (perlu selector USD/IDR)
  bool get needsCurrencySelector => _currentLocation.isOtherRegion;

  // ─── Inisialisasi ──────────────────────────────────────────────────────────

  /// Memuat lokasi & preferensi tersimpan, lalu sinkronkan mata uang & bahasa.
  Future<void> initialize() async {
    await _loadSavedLocation();
    await _syncAll(_currentLocation, notify: false);
  }

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

  // ─── Aksi Publik ───────────────────────────────────────────────────────────

  /// Mengubah lokasi aktif dan otomatis menyesuaikan mata uang,
  /// zona waktu, dan bahasa UI.
  ///
  /// Logika mata uang:
  ///   Indonesia → IDR | Jepang → JPY | Eurozone → EUR | Other → USD/IDR
  /// Logika bahasa:
  ///   Indonesia → id | Other → en
  Future<void> changeLocation(LocationModel location) async {
    if (_currentLocation.id == location.id) return;

    _currentLocation = location;
    await _saveLocationPreference(location.id);
    await _syncAll(location);

    debugPrint('[LocationProvider] Lokasi diubah: ${location.displayName} '
        '| Currency: $effectiveCurrency | TZ: ${location.timezone} '
        'UTC+${location.timezoneOffset}');
  }

  /// Mengubah fallback currency untuk region "other" (USD ↔ IDR).
  Future<void> changeOtherRegionCurrency(String currency) async {
    assert(currency == 'USD' || currency == 'IDR');
    if (_otherRegionCurrency == currency) return;

    _otherRegionCurrency = currency;
    await _saveOtherCurrencyPreference(currency);

    if (_currentLocation.isOtherRegion) {
      await _currencyProvider.changeCurrency(currency);
    }

    notifyListeners();
    debugPrint('[LocationProvider] Fallback currency: $currency');
  }

  // ─── Helper Privat ─────────────────────────────────────────────────────────

  /// Sinkronkan mata uang + bahasa sekaligus untuk lokasi tertentu.
  Future<void> _syncAll(LocationModel location, {bool notify = true}) async {
    await _syncCurrency(location);
    _syncLanguage(location);
    if (notify) notifyListeners();
  }

  /// Sinkronkan CurrencyProvider berdasarkan region lokasi.
  Future<void> _syncCurrency(LocationModel location) async {
    String target;
    if (location.isIndonesia) {
      target = 'IDR';
    } else if (location.isJapan) {
      target = 'JPY';
    } else if (location.isEurozone) {
      target = 'EUR';
    } else {
      target = _otherRegionCurrency;
    }
    await _currencyProvider.changeCurrency(target);
  }

  /// Sinkronkan LocalizationProvider berdasarkan region lokasi.
  void _syncLanguage(LocationModel location) {
    _localizationProvider.autoSetFromLocation(location.isIndonesia);
  }

  Future<void> _saveLocationPreference(String locationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_locationPrefKey, locationId);
    } catch (e) {
      debugPrint('[LocationProvider] Gagal menyimpan lokasi: $e');
    }
  }

  Future<void> _saveOtherCurrencyPreference(String currency) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_otherCurrencyPrefKey, currency);
    } catch (e) {
      debugPrint('[LocationProvider] Gagal menyimpan currency: $e');
    }
  }
}
