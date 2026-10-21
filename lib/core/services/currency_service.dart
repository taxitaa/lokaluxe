import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Model kurs mata uang dari IDR ke mata uang target
class CurrencyRate {
  final String currency;   // Kode mata uang, misal: "USD"
  final double rate;       // Nilai tukar 1 IDR ke mata uang ini
  final DateTime fetchedAt; // Waktu pengambilan data kurs

  const CurrencyRate({
    required this.currency,
    required this.rate,
    required this.fetchedAt,
  });
}

/// Service untuk mengambil, meng-cache, dan mengkonversi mata uang
/// Mendukung IDR -> USD, EUR, JPY dengan fallback offline
class CurrencyService {
  // Key untuk SharedPreferences (cache offline)
  static const String _cacheKey = 'currency_rates_cache';
  static const String _cacheDateKey = 'currency_rates_cache_date';

  // Durasi cache valid: 1 jam agar tidak terlalu sering memanggil API
  static const Duration _cacheDuration = Duration(hours: 1);

  // Kurs fallback statis jika tidak ada koneksi & cache kosong
  static const Map<String, double> _fallbackRates = {
    'USD': 0.000062, // 1 IDR ≈ 0.000062 USD
    'EUR': 0.000057, // 1 IDR ≈ 0.000057 EUR
    'JPY': 0.0094,   // 1 IDR ≈ 0.0094 JPY
  };

  // Simbol & nama lengkap mata uang yang didukung
  static const Map<String, String> currencySymbols = {
    'IDR': 'Rp',
    'USD': '\$',
    'EUR': '€',
    'JPY': '¥',
  };

  static const Map<String, String> currencyNames = {
    'IDR': 'Indonesian Rupiah',
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'JPY': 'Japanese Yen',
  };

  static const Map<String, String> currencyFlags = {
    'IDR': '🇮🇩',
    'USD': '🇺🇸',
    'EUR': '🇪🇺',
    'JPY': '🇯🇵',
  };

  // Cache in-memory agar tidak perlu membaca disk berulang kali
  static Map<String, double>? _inMemoryCache;
  static DateTime? _inMemoryCacheDate;

  /// Mengambil semua kurs mata uang (dari API, cache, atau fallback)
  ///
  /// [forceRefresh] jika true, akan memaksa pengambilan dari API meski cache masih valid
  static Future<Map<String, double>> fetchRates({
    bool forceRefresh = false,
  }) async {
    // 1. Cek in-memory cache (paling cepat)
    if (!forceRefresh &&
        _inMemoryCache != null &&
        _inMemoryCacheDate != null &&
        DateTime.now().difference(_inMemoryCacheDate!) < _cacheDuration) {
      debugPrint('[CurrencyService] Menggunakan cache in-memory');
      return _inMemoryCache!;
    }

    // 2. Cek cache lokal (SharedPreferences)
    if (!forceRefresh) {
      final cached = await _loadFromCache();
      if (cached != null) {
        debugPrint('[CurrencyService] Menggunakan cache lokal');
        _inMemoryCache = cached;
        return cached;
      }
    }

    // 3. Ambil dari API (dengan timeout 10 detik)
    try {
      final rates = await _fetchFromApi();
      await _saveToCache(rates);
      _inMemoryCache = rates;
      _inMemoryCacheDate = DateTime.now();
      debugPrint('[CurrencyService] Kurs berhasil diambil dari API: $rates');
      return rates;
    } catch (e) {
      debugPrint('[CurrencyService] Gagal ambil dari API: $e');

      // 4. Fallback ke cache lama meski expired
      final staleCache = await _loadFromCache(ignoreExpiry: true);
      if (staleCache != null) {
        debugPrint('[CurrencyService] Menggunakan cache lama (expired) sebagai fallback');
        return staleCache;
      }

      // 5. Fallback ke kurs statis bawaan
      debugPrint('[CurrencyService] Menggunakan kurs fallback statis');
      return _fallbackRates;
    }
  }

  /// Mengambil kurs terbaru dari API open.er-api.com (gratis, tanpa API key)
  static Future<Map<String, double>> _fetchFromApi() async {
    // Menggunakan ExchangeRate-API (open endpoint, gratis)
    final uri = Uri.parse('https://open.er-api.com/v6/latest/IDR');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Status HTTP: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['result'] != 'success') {
      throw Exception('Response API tidak sukses: ${data['error-type']}');
    }

    final rates = data['rates'] as Map<String, dynamic>;

    // Ekstrak hanya mata uang yang didukung
    return {
      'USD': (rates['USD'] as num).toDouble(),
      'EUR': (rates['EUR'] as num).toDouble(),
      'JPY': (rates['JPY'] as num).toDouble(),
    };
  }

  /// Menyimpan kurs ke SharedPreferences sebagai cache offline
  static Future<void> _saveToCache(Map<String, double> rates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(rates));
      await prefs.setString(_cacheDateKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[CurrencyService] Gagal menyimpan cache: $e');
    }
  }

  /// Memuat kurs dari cache SharedPreferences
  ///
  /// [ignoreExpiry] jika true, akan memuat data meski sudah expired
  static Future<Map<String, double>?> _loadFromCache({
    bool ignoreExpiry = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_cacheKey);
      final dateStr = prefs.getString(_cacheDateKey);

      if (cached == null || dateStr == null) return null;

      // Periksa apakah cache masih valid
      if (!ignoreExpiry) {
        final cachedDate = DateTime.parse(dateStr);
        if (DateTime.now().difference(cachedDate) > _cacheDuration) {
          return null; // Cache sudah expired
        }
      }

      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (e) {
      debugPrint('[CurrencyService] Gagal membaca cache: $e');
      return null;
    }
  }

  /// Mengkonversi nilai IDR ke mata uang target
  ///
  /// [amountIDR] nilai dalam Rupiah
  /// [targetCurrency] kode mata uang tujuan (USD/EUR/JPY)
  /// [rates] map kurs yang sudah diambil sebelumnya
  static double convert({
    required double amountIDR,
    required String targetCurrency,
    required Map<String, double> rates,
  }) {
    if (targetCurrency == 'IDR') return amountIDR;
    final rate = rates[targetCurrency] ?? _fallbackRates[targetCurrency] ?? 1.0;
    return amountIDR * rate;
  }

  /// Memformat nilai angka sesuai mata uang dengan simbol & desimal yang tepat
  ///
  /// [amount] nilai numerik
  /// [currency] kode mata uang
  static String formatAmount(double amount, String currency) {
    final symbol = currencySymbols[currency] ?? '';
    switch (currency) {
      case 'IDR':
        // Format Rupiah tanpa desimal, dengan pemisah titik ribuan
        return '$symbol ${_formatThousands(amount.round())}';
      case 'JPY':
        // Yen tidak memiliki sen, bulatkan ke bilangan bulat
        return '$symbol ${_formatThousands(amount.round())}';
      case 'USD':
      case 'EUR':
        // Dollar & Euro 2 angka desimal
        return '$symbol ${amount.toStringAsFixed(2)}';
      default:
        return '$symbol ${amount.toStringAsFixed(2)}';
    }
  }

  /// Helper: memformat angka dengan pemisah ribuan (titik untuk IDR/JPY)
  static String _formatThousands(int number) {
    final str = number.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return number < 0 ? '-$buf' : buf.toString();
  }

  /// Mendapatkan waktu terakhir kurs di-cache
  static Future<DateTime?> getLastFetchTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dateStr = prefs.getString(_cacheDateKey);
      if (dateStr == null) return null;
      return DateTime.parse(dateStr);
    } catch (_) {
      return null;
    }
  }

  /// Menghapus semua cache kurs (untuk reset manual)
  static Future<void> clearCache() async {
    _inMemoryCache = null;
    _inMemoryCacheDate = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheDateKey);
    } catch (_) {}
  }
}
