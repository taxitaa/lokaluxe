import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';

/// Provider global untuk manajemen bahasa UI aplikasi.
///
/// Logika otomatis:
///   Lokasi Indonesia  → AppStrings.id (Bahasa Indonesia)
///   Lokasi lainnya    → AppStrings.en (English)
///
/// Bahasa dapat juga di-override secara manual oleh pengguna.
/// Pilihan manual disimpan ke SharedPreferences agar persisten.
class LocalizationProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  AppStrings _strings = AppStrings.id;
  bool _isManualOverride = false; // true jika user memilih bahasa manual

  static const String _langPrefKey = 'selected_language';
  static const String _manualOverrideKey = 'lang_manual_override';

  // ── Getters ────────────────────────────────────────────────────────────────

  /// String bundle yang aktif (id atau en)
  AppStrings get strings => _strings;

  /// Kode bahasa aktif: 'id' atau 'en'
  String get langCode => _strings.langCode;

  /// True jika bahasa sedang English
  bool get isEnglish => _strings.langCode == 'en';

  /// True jika user sudah override bahasa secara manual
  bool get isManualOverride => _isManualOverride;

  // ── Inisialisasi ───────────────────────────────────────────────────────────

  /// Muat preferensi bahasa tersimpan dari SharedPreferences.
  /// Jika user pernah override, gunakan pilihan manual tersebut.
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isManual = prefs.getBool(_manualOverrideKey) ?? false;
      if (isManual) {
        final saved = prefs.getString(_langPrefKey);
        if (saved == 'en') {
          _strings = AppStrings.en;
        } else {
          _strings = AppStrings.id;
        }
        _isManualOverride = true;
        debugPrint('[LocalizationProvider] Override manual: $saved');
      }
      // Jika tidak ada override manual, tunggu auto-detect dari lokasi
    } catch (e) {
      debugPrint('[LocalizationProvider] Gagal memuat preferensi bahasa: $e');
    }
  }

  // ── API Publik ─────────────────────────────────────────────────────────────

  /// Mengubah bahasa secara OTOMATIS berdasarkan region lokasi.
  ///
  /// Dipanggil oleh [LocationProvider] setiap kali lokasi berubah.
  /// Tidak akan override jika user sudah memilih bahasa secara manual.
  ///
  /// [isIndonesia] true jika lokasi aktif berada di Indonesia
  void autoSetFromLocation(bool isIndonesia) {
    if (_isManualOverride) return; // hormati pilihan manual user
    final newStrings = isIndonesia ? AppStrings.id : AppStrings.en;
    if (newStrings.langCode == _strings.langCode) return;
    _strings = newStrings;
    notifyListeners();
    debugPrint('[LocalizationProvider] Auto bahasa: ${_strings.langCode}');
  }

  /// Mengubah bahasa secara MANUAL (dipanggil dari UI pengaturan).
  ///
  /// Setelah dipanggil, auto-detect dari lokasi tidak akan override lagi
  /// kecuali [clearManualOverride] dipanggil.
  Future<void> setLanguage(String langCode) async {
    final newStrings = langCode == 'en' ? AppStrings.en : AppStrings.id;
    if (newStrings.langCode == _strings.langCode && _isManualOverride) return;

    _strings = newStrings;
    _isManualOverride = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_langPrefKey, langCode);
      await prefs.setBool(_manualOverrideKey, true);
    } catch (e) {
      debugPrint('[LocalizationProvider] Gagal simpan preferensi bahasa: $e');
    }

    notifyListeners();
    debugPrint('[LocalizationProvider] Manual bahasa: $langCode');
  }

  /// Menghapus override manual — bahasa kembali mengikuti lokasi.
  Future<void> clearManualOverride() async {
    _isManualOverride = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_manualOverrideKey, false);
    } catch (e) {
      debugPrint('[LocalizationProvider] Gagal hapus override: $e');
    }
    notifyListeners();
  }
}

// ─── Extension Helper ──────────────────────────────────────────────────────

/// Akses [AppStrings] dari mana saja dalam widget tree.
///
/// Penggunaan: `context.strings.home`  atau  `context.s.hotels`
extension LocalizationContext on BuildContext {
  /// Mengambil [AppStrings] aktif dari [LocalizationProvider].
  /// Widget yang memanggil ini TIDAK otomatis rebuild saat bahasa berubah;
  /// gunakan [Consumer<LocalizationProvider>] atau [context.watchStrings]
  /// untuk reaktivitas penuh.
  AppStrings get strings {
    try {
      // ignore: invalid_use_of_protected_member
      return (getElementForInheritedWidgetOfExactType<
                  _LocalizationInheritedWidget>()
              ?.widget as _LocalizationInheritedWidget?)
          ?.strings ?? AppStrings.id;
    } catch (_) {
      return AppStrings.id;
    }
  }

  /// Shorthand: `context.s.hotels`
  AppStrings get s => strings;
}

/// Widget InheritedWidget untuk propagasi [AppStrings] tanpa Provider overhead.
/// Dibungkus secara otomatis di dalam [LocalizationScope].
class _LocalizationInheritedWidget extends InheritedWidget {
  final AppStrings strings;
  const _LocalizationInheritedWidget({
    required this.strings,
    required super.child,
  });

  @override
  bool updateShouldNotify(_LocalizationInheritedWidget old) =>
      strings.langCode != old.strings.langCode;
}

/// Wrapper widget yang menyebarkan [AppStrings] ke seluruh widget tree.
///
/// Tempatkan di root app (di dalam [MultiProvider]) agar semua widget
/// dapat mengakses string lokalisasi via `context.strings`.
///
/// Contoh penggunaan di main.dart:
/// ```dart
/// Consumer<LocalizationProvider>(
///   builder: (_, locProv, child) => LocalizationScope(
///     strings: locProv.strings,
///     child: child!,
///   ),
///   child: MaterialApp(...),
/// )
/// ```
class LocalizationScope extends StatelessWidget {
  final AppStrings strings;
  final Widget child;

  const LocalizationScope({
    super.key,
    required this.strings,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _LocalizationInheritedWidget(strings: strings, child: child);
  }
}
