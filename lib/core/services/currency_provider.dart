import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'currency_service.dart';

/// Provider state management untuk konversi mata uang di seluruh aplikasi.
///
/// Menggunakan ChangeNotifier (Provider pattern) sehingga widget-widget
/// yang menggunakan harga dapat rebuild otomatis saat mata uang berubah.
class CurrencyProvider extends ChangeNotifier {
  // Mata uang aktif saat ini (default IDR)
  String _selectedCurrency = 'IDR';

  // Kurs yang sudah diambil dari API / cache
  Map<String, double> _rates = {};

  // Status loading saat mengambil data kurs
  bool _isLoading = false;

  // Pesan error jika ada kegagalan
  String? _errorMessage;

  // Waktu terakhir kurs berhasil di-update
  DateTime? _lastFetchTime;

  // Kunci SharedPreferences untuk menyimpan pilihan mata uang user
  static const String _currencyPrefKey = 'selected_currency';
  Future<void>? _initialization;

  // Getter
  String get selectedCurrency => _selectedCurrency;
  Map<String, double> get rates => _rates;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastFetchTime => _lastFetchTime;

  /// Menginisialisasi provider: muat preferensi & ambil kurs
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    await _loadSavedCurrency();
    unawaited(refreshRates());
  }

  /// Memuat pilihan mata uang yang tersimpan dari SharedPreferences
  Future<void> _loadSavedCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_currencyPrefKey);
      if (saved != null && CurrencyService.currencySymbols.containsKey(saved)) {
        _selectedCurrency = saved;
      }
    } catch (e) {
      debugPrint('[CurrencyProvider] Gagal memuat preferensi: $e');
    }
  }

  /// Menyimpan pilihan mata uang ke SharedPreferences
  Future<void> _saveCurrencyPreference(String currency) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currencyPrefKey, currency);
    } catch (e) {
      debugPrint('[CurrencyProvider] Gagal menyimpan preferensi: $e');
    }
  }

  /// Mengubah mata uang aktif dan memperbarui semua harga di UI
  ///
  /// [currency] kode mata uang baru (IDR/USD/EUR/JPY)
  Future<void> changeCurrency(String currency) async {
    if (_selectedCurrency == currency) return;
    _selectedCurrency = currency;
    await _saveCurrencyPreference(currency);
    notifyListeners(); // Trigger rebuild semua widget yang mendengarkan
  }

  /// Memperbarui kurs dari API atau cache
  ///
  /// [forceRefresh] paksa ambil dari API meski cache masih valid
  Future<void> refreshRates({bool forceRefresh = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _rates = await CurrencyService.fetchRates(forceRefresh: forceRefresh);
      _lastFetchTime = await CurrencyService.getLastFetchTime() ?? DateTime.now();
      _errorMessage = null;
      debugPrint('[CurrencyProvider] Kurs berhasil diperbarui: $_rates');
    } catch (e) {
      _errorMessage = 'Gagal memperbarui kurs. Menggunakan data offline.';
      debugPrint('[CurrencyProvider] Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mengkonversi nilai IDR ke mata uang yang sedang dipilih
  ///
  /// [amountIDR] jumlah dalam Rupiah
  /// Mengembalikan nilai yang sudah dikonversi dalam format string siap tampil
  String convertAndFormat(double amountIDR) {
    final converted = CurrencyService.convert(
      amountIDR: amountIDR,
      targetCurrency: _selectedCurrency,
      rates: _rates,
    );
    return CurrencyService.formatAmount(converted, _selectedCurrency);
  }

  /// Mengkonversi tanpa format (nilai mentah)
  double convertRaw(double amountIDR) {
    return CurrencyService.convert(
      amountIDR: amountIDR,
      targetCurrency: _selectedCurrency,
      rates: _rates,
    );
  }

  /// Mendapatkan simbol mata uang aktif (misal: "Rp", "$", "€")
  String get currencySymbol =>
      CurrencyService.currencySymbols[_selectedCurrency] ?? '';

  /// Mendapatkan nama lengkap mata uang aktif
  String get currencyName =>
      CurrencyService.currencyNames[_selectedCurrency] ?? _selectedCurrency;

  /// Mendapatkan emoji bendera mata uang aktif
  String get currencyFlag =>
      CurrencyService.currencyFlags[_selectedCurrency] ?? '';
}
