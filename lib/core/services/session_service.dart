import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionData {
  final int userId;
  final String email;
  final String fullName;
  final DateTime createdAt;
  final DateTime expiresAt;

  SessionData({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.createdAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'email': email,
    'fullName': fullName,
    'createdAt': createdAt.toIso8601String(),
    'expiresAt': expiresAt.toIso8601String(),
  };

  factory SessionData.fromJson(Map<String, dynamic> json) => SessionData(
    userId: (json['userId'] as num?)?.toInt() ?? 0,
    email: (json['email'] ?? '') as String,
    fullName: (json['fullName'] ?? '') as String,
    createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    expiresAt:
        DateTime.tryParse(json['expiresAt'] ?? '') ??
        DateTime.now().add(const Duration(days: 30)),
  );
}

class SessionService {
  static const Duration inactivityTimeout = Duration(minutes: 5);

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _keySessionToken = 'lokaluxe_session_token';
  static const String _keySupabaseAccountEmail = 'lokaluxe_supabase_account_email';
  static const String _keySupabaseUserId = 'lokaluxe_supabase_user_id';
  static const String _keySupabaseAccessToken = 'lokaluxe_supabase_access_token';
  static const String _keySupabaseRefreshToken = 'lokaluxe_supabase_refresh_token';
  static const String _keyBiometricEnabled = 'lokaluxe_biometric_enabled';
  static const String _keyFingerprintEnabled = 'lokaluxe_fingerprint_enabled';
  static const String _keyFaceIdEnabled = 'lokaluxe_faceid_enabled';
  static const String _keySecurityPin = 'lokaluxe_security_pin';
  static const String _keyLastEmail = 'lokaluxe_last_email';
  static const String _keyBiometricAccountEmail =
      'lokaluxe_biometric_account_email';

  /// Menyimpan token sesi aman ke Keystore/Keychain
  static Future<void> saveSession({
    required int userId,
    required String email,
    required String fullName,
    Duration validDuration = const Duration(days: 30),
  }) async {
    final now = DateTime.now();
    final session = SessionData(
      userId: userId,
      email: email,
      fullName: fullName,
      createdAt: now,
      expiresAt: now.add(validDuration),
    );

    final tokenString = jsonEncode(session.toJson());
    await _storage.write(key: _keySessionToken, value: tokenString);
    await _storage.write(key: _keyLastEmail, value: email);
  }

  /// Memeriksa apakah ada sesi aktif dan belum kedaluwarsa
  static Future<bool> isSessionActive() async {
    final session = await getSessionData();
    if (session == null) return false;
    if (session.isExpired) {
      await clearSession();
      return false;
    }
    return true;
  }

  /// Memperbarui batas waktu sesi setelah ada aktivitas pengguna
  static Future<bool> refreshSession() async {
    final session = await getSessionData();
    if (session == null) return false;
    if (session.isExpired) {
      await clearSession();
      return false;
    }

    final refreshedSession = SessionData(
      userId: session.userId,
      email: session.email,
      fullName: session.fullName,
      createdAt: session.createdAt,
      expiresAt: DateTime.now().add(inactivityTimeout),
    );
    await _storage.write(
      key: _keySessionToken,
      value: jsonEncode(refreshedSession.toJson()),
    );
    return true;
  }

  /// Mengambil data sesi aktif
  static Future<SessionData?> getSessionData() async {
    final raw = await _storage.read(key: _keySessionToken);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SessionData.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Menghapus token sesi secara aman saat logout
  static Future<void> clearSession() async {
    await _storage.delete(key: _keySessionToken);
    await clearSupabaseTokens();
  }

  static Future<void> saveSupabaseTokens({
    required String accountEmail,
    required String userId,
    required String accessToken,
    String? refreshToken,
  }) async {
    await _storage.write(
      key: _keySupabaseAccountEmail,
      value: accountEmail.trim().toLowerCase(),
    );
    await _storage.write(key: _keySupabaseUserId, value: userId);
    await _storage.write(key: _keySupabaseAccessToken, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _keySupabaseRefreshToken, value: refreshToken);
    }
  }

  static Future<String?> getSupabaseAccessToken(String accountEmail) async {
    final savedEmail = await _storage.read(key: _keySupabaseAccountEmail);
    if (savedEmail != accountEmail.trim().toLowerCase()) return null;
    return _storage.read(key: _keySupabaseAccessToken);
  }

  static Future<String?> getSupabaseUserId(String accountEmail) async {
    final savedEmail = await _storage.read(key: _keySupabaseAccountEmail);
    if (savedEmail != accountEmail.trim().toLowerCase()) return null;
    return _storage.read(key: _keySupabaseUserId);
  }

  static Future<String?> getSupabaseRefreshToken(String accountEmail) async {
    final savedEmail = await _storage.read(key: _keySupabaseAccountEmail);
    if (savedEmail != accountEmail.trim().toLowerCase()) return null;
    return _storage.read(key: _keySupabaseRefreshToken);
  }

  static Future<void> clearSupabaseTokens() async {
    await _storage.delete(key: _keySupabaseAccountEmail);
    await _storage.delete(key: _keySupabaseUserId);
    await _storage.delete(key: _keySupabaseAccessToken);
    await _storage.delete(key: _keySupabaseRefreshToken);
  }

  /// Mengatur preferensi biometrik pengguna
  static Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _keyBiometricEnabled,
      value: enabled ? 'true' : 'false',
    );
  }

  /// Memeriksa apakah biometrik telah diaktifkan untuk akun lokal ini
  static Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _keyBiometricEnabled);
    return val == 'true';
  }

  /// Mengatur preferensi sidik jari
  static Future<void> setFingerprintEnabled(bool enabled) async {
    await _storage.write(
      key: _keyFingerprintEnabled,
      value: enabled ? 'true' : 'false',
    );
    if (enabled) {
      await setBiometricEnabled(true);
    }
  }

  /// Memeriksa apakah sidik jari aktif
  static Future<bool> isFingerprintEnabled() async {
    final val = await _storage.read(key: _keyFingerprintEnabled);
    if (val != null) return val == 'true';
    return await isBiometricEnabled();
  }

  /// Mengatur preferensi Face ID
  static Future<void> setFaceIdEnabled(bool enabled) async {
    await _storage.write(
      key: _keyFaceIdEnabled,
      value: enabled ? 'true' : 'false',
    );
    if (enabled) {
      await setBiometricEnabled(true);
    }
  }

  /// Memeriksa apakah Face ID aktif
  static Future<bool> isFaceIdEnabled() async {
    final val = await _storage.read(key: _keyFaceIdEnabled);
    if (val != null) return val == 'true';
    return await isBiometricEnabled();
  }

  /// Menyimpan PIN keamanan pengguna
  static Future<void> setSecurityPin(String pin) async {
    await _storage.write(key: _keySecurityPin, value: pin);
  }

  /// Mengambil PIN keamanan yang tersimpan
  static Future<String?> getSecurityPin() async {
    return await _storage.read(key: _keySecurityPin);
  }

  /// Memvalidasi PIN keamanan
  static Future<bool> verifySecurityPin(String pin) async {
    final savedPin = await getSecurityPin();
    if (savedPin == null || savedPin.isEmpty) return false;
    return savedPin == pin;
  }

  /// Mengambil email akun terakhir yang berhasil login
  static Future<String?> getLastLoggedInEmail() async {
    return await _storage.read(key: _keyLastEmail);
  }

  /// Menyimpan akun yang dipilih untuk login biometrik cepat
  static Future<void> setBiometricAccountEmail(String email) async {
    await _storage.write(
      key: _keyBiometricAccountEmail,
      value: email.trim().toLowerCase(),
    );
  }

  /// Mengambil akun yang terhubung dengan login biometrik cepat
  static Future<String?> getBiometricAccountEmail() async {
    return await _storage.read(key: _keyBiometricAccountEmail);
  }

  /// Menghapus akun login biometrik cepat jika tidak lagi diaktifkan
  static Future<void> clearBiometricAccountEmail() async {
    await _storage.delete(key: _keyBiometricAccountEmail);
  }
}
