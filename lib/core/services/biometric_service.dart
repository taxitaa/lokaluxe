import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../database/db_helper.dart';
import 'session_service.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Memeriksa apakah perangkat mendukung autentikasi biometrik
  static Future<bool> isBiometricSupported() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return isSupported && canCheck;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Mengambil daftar biometrik yang tersedia di perangkat
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Cek ketersediaan sensor sidik jari
  static Future<bool> hasFingerprint() async {
    final list = await getAvailableBiometrics();
    return list.contains(BiometricType.fingerprint) ||
        list.contains(BiometricType.strong);
  }

  /// Cek ketersediaan sensor Face ID / Wajah
  static Future<bool> hasFaceId() async {
    final list = await getAvailableBiometrics();
    return list.contains(BiometricType.face) ||
        list.contains(BiometricType.strong);
  }

  /// Mengembalikan label yang sesuai berdasarkan biometrik yang tersedia
  static Future<String> getBiometricLabel() async {
    try {
      final biometrics = await getAvailableBiometrics();
      final hasFp = biometrics.contains(BiometricType.fingerprint);
      final hasFace = biometrics.contains(BiometricType.face);

      if (hasFp && hasFace) return 'Sidik Jari & Face ID';
      if (hasFace) return 'Face ID';
      if (hasFp) return 'Sidik Jari';
      return 'Biometrik';
    } catch (_) {
      return 'Biometrik';
    }
  }

  /// Menjalankan prompt autentikasi biometrik umum
  static Future<bool> authenticate({
    String reason = 'Pindai biometrik Anda untuk verifikasi identitas di LokaLuxe',
  }) async {
    try {
      final isSupported = await isBiometricSupported();
      if (!isSupported) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Menjalankan prompt autentikasi khusus Sidik Jari
  static Future<bool> authenticateWithFingerprint({
    String reason = 'Letakkan jari Anda pada sensor sidik jari perangkat untuk masuk ke LokaLuxe',
  }) async {
    return await authenticate(reason: reason);
  }

  /// Menjalankan prompt autentikasi khusus Face ID
  static Future<bool> authenticateWithFaceId({
    String reason = 'Arahkan wajah Anda ke kamera depan untuk masuk dengan Face ID',
  }) async {
    return await authenticate(reason: reason);
  }

  /// Menyimpan preferensi biometrik umum ke SQLite DAN Secure Storage (dual persistence)
  static Future<void> saveUserBiometricPreference(
    int userId,
    bool enabled,
  ) async {
    await Future.wait([
      DBHelper.updateUserBiometric(userId, enabled),
      SessionService.setBiometricEnabled(enabled),
      SessionService.setFingerprintEnabled(enabled),
      SessionService.setFaceIdEnabled(enabled),
    ]);
  }

  /// Menyimpan preferensi Sidik Jari
  static Future<void> saveFingerprintPreference(
    int userId,
    bool enabled,
  ) async {
    await Future.wait([
      DBHelper.updateUserBiometricSettings(userId, fingerprintEnabled: enabled),
      SessionService.setFingerprintEnabled(enabled),
    ]);
  }

  /// Menyimpan preferensi Face ID
  static Future<void> saveFaceIdPreference(
    int userId,
    bool enabled,
  ) async {
    await Future.wait([
      DBHelper.updateUserBiometricSettings(userId, faceIdEnabled: enabled),
      SessionService.setFaceIdEnabled(enabled),
    ]);
  }

  /// Menyimpan PIN keamanan
  static Future<void> saveSecurityPin(
    int userId,
    String pin,
  ) async {
    await Future.wait([
      DBHelper.updateUserBiometricSettings(userId, securityPin: pin),
      SessionService.setSecurityPin(pin),
    ]);
  }

  /// Mengambil pengaturan keamanan lengkap user
  static Future<Map<String, dynamic>> getUserSecuritySettings(int userId) async {
    try {
      final dbSettings = await DBHelper.getUserSecuritySettings(userId);
      final secPin = await SessionService.getSecurityPin();

      final fp = dbSettings['fingerprintEnabled'] == true;
      final face = dbSettings['faceIdEnabled'] == true;
      final bio = (dbSettings['biometricEnabled'] == true) || fp || face;

      return {
        'biometricEnabled': bio,
        'fingerprintEnabled': fp,
        'faceIdEnabled': face,
        'securityPin': dbSettings['securityPin'] ?? secPin,
      };
    } catch (_) {
      return {
        'biometricEnabled': false,
        'fingerprintEnabled': false,
        'faceIdEnabled': false,
        'securityPin': await SessionService.getSecurityPin(),
      };
    }
  }

  /// Mengambil status biometrik dari SQLite (primary), fallback ke Secure Storage
  static Future<bool> getUserBiometricPreference(int userId) async {
    try {
      return await DBHelper.getUserBiometricStatus(userId);
    } catch (_) {
      return await SessionService.isBiometricEnabled();
    }
  }
}
