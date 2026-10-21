import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/location_model.dart';
import 'currency_provider.dart';
import 'timezone_service.dart';

/// Provider untuk manajemen lokasi aktif pengguna.
///
/// Bertanggung jawab:
/// 1. Menyimpan & memuat lokasi aktif (persistent via SharedPreferences)
/// 2. Mengorkestrasi perubahan mata uang & zona waktu otomatis saat lokasi berubah
/// 3. Mengaktifkan bahasa UI yang sesuai via [LocalizationProvider]
/// 4. Menyediakan informasi lokasi ke seluruh widget tree (Provider pattern)
///
/// Currency and time-zone settings are derived from the selected location.
class LocationProvider extends ChangeNotifier {
  LocationModel _currentLocation = LocationDatabase.defaultLocation;
  static const String _locationPrefKey = 'selected_location_id';
  final CurrencyProvider _currencyProvider;
  Future<void>? _initialization;
  bool _hasSavedLocation = false;

  LocationProvider(this._currencyProvider);

  LocationModel get currentLocation => _currentLocation;
  String get effectiveCurrency => _currentLocation.currency;
  String get activeTimezone => _currentLocation.timezone;
  int get timezoneOffsetHours =>
      TimeZoneService.getOffsetHours(_currentLocation.timezone);
  DateTime get localNow =>
      TimeZoneService.getLocalTime(_currentLocation.timezone);
  bool get isIndonesiaRegion => _currentLocation.isIndonesia;
  bool get hasSavedLocation => _hasSavedLocation;

  Future<void> initialize() =>
      _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString(_locationPrefKey);
      if (savedId != null) {
        final found = LocationDatabase.findById(savedId);
        if (found != null) {
          _currentLocation = found;
          _hasSavedLocation = true;
          debugPrint('[LocationProvider] Location loaded: ${found.displayName}');
        }
      }
    } catch (e) {
      debugPrint('[LocationProvider] Could not load saved location: $e');
    }

    await _currencyProvider.initialize();
    await _syncAll(_currentLocation, notify: false);
  }

  Future<void> changeLocation(LocationModel location) async {
    if (_currentLocation.id == location.id && _hasSavedLocation) return;

    _currentLocation = location;
    await _saveLocationPreference(location.id);
    _hasSavedLocation = true;
    await _syncAll(location);

    debugPrint('[LocationProvider] Location changed: ${location.displayName} '
        '| Currency: $effectiveCurrency | Time zone: ${location.timezone}');
  }

  Future<void> _syncAll(LocationModel location, {bool notify = true}) async {
    await _syncCurrency(location);
    if (notify) notifyListeners();
  }

  Future<void> _syncCurrency(LocationModel location) async {
    await _currencyProvider.changeCurrency(location.currency);
  }

  Future<void> _saveLocationPreference(String locationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_locationPrefKey, locationId);
    } catch (e) {
      debugPrint('[LocationProvider] Could not save location: $e');
    }
  }
}
