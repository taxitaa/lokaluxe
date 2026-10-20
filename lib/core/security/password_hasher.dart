import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class PasswordHasher {
  static const int iterations = 10000;

  /// Menghasilkan random salt yang unik dan aman per pengguna
  static String generateSalt([int length = 16]) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return base64Url.encode(bytes);
  }

  /// Hash password menggunakan PBKDF2-HMAC-SHA256 dengan salt unik
  static String hashPassword(String password, String salt) {
    final saltBytes = utf8.encode(salt);
    final passwordBytes = utf8.encode(password);

    // PBKDF2-HMAC-SHA256 key stretching
    final hmac = Hmac(sha256, passwordBytes);
    var current = hmac.convert(saltBytes).bytes;
    var result = List<int>.from(current);

    for (int i = 1; i < iterations; i++) {
      current = hmac.convert(current).bytes;
      for (int j = 0; j < result.length; j++) {
        result[j] ^= current[j];
      }
    }

    return base64Url.encode(result);
  }

  /// Memvalidasi password input dengan hash dan salt yang tersimpan di database
  static bool verifyPassword(
    String inputPassword,
    String storedHash,
    String salt,
  ) {
    if (storedHash.isEmpty || salt.isEmpty) return false;
    final computedHash = hashPassword(inputPassword, salt);
    return computedHash == storedHash;
  }
}
