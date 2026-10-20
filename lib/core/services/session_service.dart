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
        expiresAt: DateTime.tryParse(json['expiresAt'] ?? '') ??
            DateTime.now().add(const Duration(days: 30)),
      );
}

class SessionService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _keySessionToken = 'lokaluxe_session_token';
  static const String _keyBiometricEnabled = 'lokaluxe_biometric_enabled';
  static const String _keyLastEmail = 'lokaluxe_last_email';

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

  /// Mengambil email akun terakhir yang berhasil login
  static Future<String?> getLastLoggedInEmail() async {
    return await _storage.read(key: _keyLastEmail);
  }
}
