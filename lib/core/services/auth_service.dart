import '../database/db_helper.dart';
import '../models/user_model.dart';
import '../security/password_hasher.dart';
import 'biometric_service.dart';
import 'session_service.dart';

class AuthResult {
  final bool isSuccess;
  final String message;
  final UserModel? user;

  const AuthResult({
    required this.isSuccess,
    required this.message,
    this.user,
  });

  factory AuthResult.success({UserModel? user, required String message}) =>
      AuthResult(isSuccess: true, message: message, user: user);

  factory AuthResult.failure(String message) =>
      AuthResult(isSuccess: false, message: message);
}

class AuthService {
  /// Registrasi akun baru dengan PBKDF2/SHA-256 + Salt acak unik
  /// Sesuai ketentuan: Setelah registrasi berhasil, akun TIDAK otomatis login
  /// Pengguna harus diarahkan kembali ke halaman Login.
  static Future<AuthResult> register({
    required String fullName,
    required String email,
    required String password,
    String currency = 'IDR (Rupiah Indonesia)',
  }) async {
    final cleanName = fullName.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    // Validasi input
    if (cleanName.isEmpty) {
      return AuthResult.failure('Nama lengkap wajib diisi');
    }
    if (cleanEmail.isEmpty || !cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      return AuthResult.failure('Format email tidak valid');
    }
    if (cleanPassword.length < 6) {
      return AuthResult.failure('Kata sandi minimal 6 karakter');
    }

    try {
      // 1. Cek apakah email sudah terdaftar
      final existingUser = await DBHelper.getUserByEmail(cleanEmail);
      if (existingUser != null) {
        return AuthResult.failure(
          'Email sudah terdaftar. Silakan masuk atau gunakan email lain.',
        );
      }

      // 2. Generate Salt acak yang unik per pengguna
      final salt = PasswordHasher.generateSalt();

      // 3. Hash password menggunakan PBKDF2-HMAC-SHA256
      final passwordHash = PasswordHasher.hashPassword(cleanPassword, salt);

      // 4. Simpan ke SQLite tabel users
      final newUser = UserModel(
        fullName: cleanName,
        email: cleanEmail,
        passwordHash: passwordHash,
        salt: salt,
        currency: currency,
        createdAt: DateTime.now().toIso8601String(),
      );

      final insertId = await DBHelper.registerUser(newUser);
      if (insertId > 0) {
        final registeredUser = UserModel(
          id: insertId,
          fullName: cleanName,
          email: cleanEmail,
          passwordHash: passwordHash,
          salt: salt,
          currency: currency,
        );

        return AuthResult.success(
          user: registeredUser,
          message: 'Pendaftaran akun berhasil! Silakan masuk dengan akun baru Anda.',
        );
      } else {
        return AuthResult.failure('Gagal menyimpan data ke database lokal');
      }
    } catch (e) {
      return AuthResult.failure('Terjadi kesalahan saat registrasi: $e');
    }
  }

  /// Login manual menggunakan email dan password
  /// Menghitung ulang hash dari password input + salt dan membandingkannya
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      return AuthResult.failure('Email dan kata sandi wajib diisi');
    }

    try {
      // 1. Ambil data pengguna dari database berdasarkan email
      final user = await DBHelper.getUserByEmail(cleanEmail);
      if (user == null) {
        return AuthResult.failure('Akun dengan email ini belum terdaftar');
      }

      // 2. Verifikasi hash password input menggunakan salt unik pengguna
      final isPasswordValid = PasswordHasher.verifyPassword(
        cleanPassword,
        user.passwordHash,
        user.salt,
      );

      if (!isPasswordValid) {
        return AuthResult.failure('Kata sandi yang Anda masukkan salah');
      }

      // 3. Login sukses: Buat token sesi aman di flutter_secure_storage
      if (user.id != null) {
        await SessionService.saveSession(
          userId: user.id!,
          email: user.email,
          fullName: user.fullName,
        );
        // Aktifkan biometrik untuk akun ini pada login berikutnya
        await SessionService.setBiometricEnabled(true);
      }

      return AuthResult.success(
        user: user,
        message: 'Selamat datang kembali, ${user.fullName}!',
      );
    } catch (e) {
      return AuthResult.failure('Terjadi kesalahan saat login: $e');
    }
  }

  /// Login cepat menggunakan biometrik (sidik jari / wajah)
  /// Hanya dapat digunakan setelah login manual pertama berhasil
  static Future<AuthResult> loginWithBiometrics() async {
    try {
      // 1. Cek dukungan hardware perangkat
      final isSupported = await BiometricService.isBiometricSupported();
      if (!isSupported) {
        return AuthResult.failure(
          'Perangkat Anda belum mendukung sensor biometrik',
        );
      }

      // 2. Cek apakah pengguna sudah pernah login manual sebelumnya
      final isBioEnabled = await SessionService.isBiometricEnabled();
      final lastEmail = await SessionService.getLastLoggedInEmail();

      if (!isBioEnabled || lastEmail == null || lastEmail.isEmpty) {
        return AuthResult.failure(
          'Silakan masuk dengan email dan kata sandi terlebih dahulu untuk mengaktifkan biometrik',
        );
      }

      // 3. Jalankan dialog sensor sidik jari
      final didAuthenticate = await BiometricService.authenticate(
        reason: 'Pindai sidik jari Anda untuk masuk ke akun LocalLuxe',
      );

      if (!didAuthenticate) {
        return AuthResult.failure('Verifikasi biometrik dibatalkan atau gagal');
      }

      // 4. Ambil data pengguna dari database lokal
      final user = await DBHelper.getUserByEmail(lastEmail);
      if (user == null || user.id == null) {
        return AuthResult.failure('Data akun biometrik tidak ditemukan');
      }

      // 5. Perbarui sesi aktif
      await SessionService.saveSession(
        userId: user.id!,
        email: user.email,
        fullName: user.fullName,
      );

      return AuthResult.success(
        user: user,
        message: 'Autentikasi biometrik berhasil!',
      );
    } catch (e) {
      return AuthResult.failure('Gagal melakukan login biometrik: $e');
    }
  }

  /// Memeriksa status sesi aktif saat aplikasi dibuka (Splash Screen)
  static Future<UserModel?> checkSession() async {
    try {
      final isActive = await SessionService.isSessionActive();
      if (!isActive) return null;

      final session = await SessionService.getSessionData();
      if (session == null) return null;

      // Ambil profil terbaru dari SQLite
      return await DBHelper.getUserByEmail(session.email);
    } catch (_) {
      return null;
    }
  }

  /// Logout aman: menghapus token sesi dari keystore/keychain
  static Future<void> logout() async {
    await SessionService.clearSession();
  }
}
