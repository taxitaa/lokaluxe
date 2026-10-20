import 'package:flutter_test/flutter_test.dart';
import 'package:lokaluxe/core/models/user_model.dart';
import 'package:lokaluxe/core/security/password_hasher.dart';
import 'package:lokaluxe/core/services/auth_service.dart';
import 'package:lokaluxe/core/services/session_service.dart';

void main() {
  group('1. PasswordHasher & Cryptography Tests', () {
    test('generateSalt menghasilkan salt unik dan non-empty', () {
      final salt1 = PasswordHasher.generateSalt();
      final salt2 = PasswordHasher.generateSalt();

      expect(salt1, isNotEmpty);
      expect(salt2, isNotEmpty);
      expect(salt1, isNot(equals(salt2)));
    });

    test('hashPassword dan verifyPassword memvalidasi kata sandi dengan benar', () {
      const password = 'MySecureLokaLuxePassword!123';
      final salt = PasswordHasher.generateSalt();

      final hash = PasswordHasher.hashPassword(password, salt);
      expect(hash, isNotEmpty);
      expect(hash, isNot(equals(password)));

      // Verifikasi dengan password benar
      expect(PasswordHasher.verifyPassword(password, hash, salt), isTrue);

      // Verifikasi dengan password salah
      expect(PasswordHasher.verifyPassword('WrongPassword', hash, salt), isFalse);

      // Verifikasi dengan salt salah
      final differentSalt = PasswordHasher.generateSalt();
      expect(PasswordHasher.verifyPassword(password, hash, differentSalt), isFalse);
    });

    test('Dua password sama dengan salt berbeda menghasilkan hash yang berbeda (Rainbow Table Protection)', () {
      const password = 'SamePassword';
      final salt1 = PasswordHasher.generateSalt();
      final salt2 = PasswordHasher.generateSalt();

      final hash1 = PasswordHasher.hashPassword(password, salt1);
      final hash2 = PasswordHasher.hashPassword(password, salt2);

      expect(hash1, isNot(equals(hash2)));
    });
  });

  group('2. UserModel Data Model Tests', () {
    test('UserModel serializes and deserializes accurately', () {
      final user = UserModel(
        id: 1,
        fullName: 'Budi Santoso',
        email: 'budi@lokaluxe.id',
        passwordHash: 'hashed_pwd_abc',
        salt: 'random_salt_xyz',
        currency: 'IDR (Rupiah Indonesia)',
        createdAt: '2026-10-20T10:00:00Z',
      );

      final map = user.toMap();
      expect(map['fullName'], 'Budi Santoso');
      expect(map['email'], 'budi@lokaluxe.id');
      expect(map['passwordHash'], 'hashed_pwd_abc');
      expect(map['salt'], 'random_salt_xyz');

      final reconstructed = UserModel.fromMap(map);
      expect(reconstructed.id, 1);
      expect(reconstructed.fullName, 'Budi Santoso');
      expect(reconstructed.email, 'budi@lokaluxe.id');
      expect(reconstructed.passwordHash, 'hashed_pwd_abc');
      expect(reconstructed.salt, 'random_salt_xyz');
    });
  });

  group('3. SessionData & Token Tests', () {
    test('SessionData detects expiration accurately', () {
      final activeSession = SessionData(
        userId: 1,
        email: 'user@lokaluxe.id',
        fullName: 'Test User',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(activeSession.isExpired, isFalse);

      final expiredSession = SessionData(
        userId: 1,
        email: 'user@lokaluxe.id',
        fullName: 'Test User',
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
        expiresAt: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(expiredSession.isExpired, isTrue);

      final json = activeSession.toJson();
      final fromJson = SessionData.fromJson(json);
      expect(fromJson.email, 'user@lokaluxe.id');
      expect(fromJson.userId, 1);
      expect(fromJson.isExpired, isFalse);
    });
  });

  group('4. AuthResult Tests', () {
    test('AuthResult factory constructors work correctly', () {
      final success = AuthResult.success(message: 'Login Berhasil');
      expect(success.isSuccess, isTrue);
      expect(success.message, 'Login Berhasil');

      final failure = AuthResult.failure('Kredensial salah');
      expect(failure.isSuccess, isFalse);
      expect(failure.message, 'Kredensial salah');
    });
  });
}
