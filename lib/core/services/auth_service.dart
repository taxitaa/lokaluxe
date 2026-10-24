import '../database/db_helper.dart';
import '../models/user_model.dart';
import '../security/password_hasher.dart';
import 'biometric_service.dart';
import 'session_service.dart';
import 'supabase_auth_service.dart';

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
    if (SupabaseAuthService.isPartiallyConfigured) {
      return AuthResult.failure(
        'Konfigurasi Supabase belum lengkap. Isi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY.',
      );
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

      if (SupabaseAuthService.isConfigured) {
        final remoteUser = await SupabaseAuthService.signUp(
          email: cleanEmail,
          password: cleanPassword,
          fullName: cleanName,
        );
        if (remoteUser.alreadyExists) {
          return AuthResult.failure(
            'Email sudah memiliki akun online. Silakan masuk dengan kata sandi akun tersebut.',
          );
        }
        final accessToken = remoteUser.accessToken;
        if (accessToken != null) {
          final profile = await SupabaseAuthService.getOrCreateProfile(
            userId: remoteUser.user['id'] as String,
            email: cleanEmail,
            fullName: cleanName,
            accessToken: accessToken,
          );
          final localUser = _userFromProfile(profile, passwordHash, salt);
          final insertId = await DBHelper.registerUser(localUser);
          if (insertId <= 0) {
            return AuthResult.failure(
              'Akun online berhasil dibuat, tetapi gagal menyimpan profil lokal.',
            );
          }
          return AuthResult.success(
            user: UserModel(
              id: insertId,
              fullName: localUser.fullName,
              email: localUser.email,
              passwordHash: passwordHash,
              salt: salt,
              currency: localUser.currency,
              createdAt: localUser.createdAt,
            ),
            message: 'Pendaftaran akun berhasil! Silakan masuk dengan akun baru Anda.',
          );
        }

        final insertId = await DBHelper.registerUser(newUser);
        if (insertId <= 0) {
          return AuthResult.failure(
            'Akun online berhasil dibuat, tetapi gagal menyimpan profil lokal.',
          );
        }
        return AuthResult.success(
          user: newUser,
          message:
              'Akun berhasil dibuat. Silakan konfirmasi email, lalu masuk untuk mengaktifkan login lintas perangkat.',
        );
      }

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
    if (SupabaseAuthService.isPartiallyConfigured) {
      return AuthResult.failure(
        'Konfigurasi Supabase belum lengkap. Isi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY.',
      );
    }

    String? supabaseUserId;
    String? supabaseAccessToken;
    String? supabaseRefreshToken;
    try {
      // 1. Ambil data pengguna dari database berdasarkan email
      final user = await DBHelper.getUserByEmail(cleanEmail);
      if (user == null && !SupabaseAuthService.isConfigured) {
        return AuthResult.failure('Akun dengan email ini belum terdaftar');
      }

      if (user != null) {
        if (user.passwordHash.isEmpty || user.salt.isEmpty) {
          if (!SupabaseAuthService.isConfigured) {
            return AuthResult.failure(
              'Akun ini memerlukan koneksi Supabase untuk login.',
            );
          }
        } else {
          // Verifikasi kredensial lokal sebelum menautkan akun lama.
          final isPasswordValid = PasswordHasher.verifyPassword(
            cleanPassword,
            user.passwordHash,
            user.salt,
          );
          if (!isPasswordValid) {
            return AuthResult.failure('Kata sandi yang Anda masukkan salah');
          }
        }
      }

      var authenticatedUser = user;
      if (SupabaseAuthService.isConfigured) {
        SupabaseAuthResponse remoteSession;
        try {
          remoteSession = await SupabaseAuthService.signIn(
            email: cleanEmail,
            password: cleanPassword,
          );
        } on SupabaseAuthException catch (error) {
          if (user == null ||
              user.passwordHash.isEmpty ||
              user.salt.isEmpty) {
            return AuthResult.failure(
              'Akun belum ditemukan atau kata sandi salah. Periksa kembali email dan kata sandi.',
            );
          }
          if (error.statusCode != 400) {
            return AuthResult.failure(
              'Login Supabase gagal: ${error.message}.',
            );
          }

          // Pengguna lokal yang valid ditautkan ke Supabase satu kali.
          try {
            remoteSession = await SupabaseAuthService.signUp(
              email: cleanEmail,
              password: cleanPassword,
              fullName: user.fullName,
            );
          } on SupabaseAuthException catch (linkError) {
            return AuthResult.failure(
              'Akun lokal valid, tetapi gagal ditautkan ke akun online: ${linkError.message}.',
            );
          }
          if (remoteSession.alreadyExists) {
            return AuthResult.failure(
              'Email ini sudah terhubung ke akun online dengan kata sandi berbeda. Gunakan kata sandi akun online atau pulihkan kata sandinya.',
            );
          }

          if (remoteSession.accessToken == null) {
            return AuthResult.failure(
              'Akun lama sedang ditautkan. Konfirmasi email jika diminta, lalu masuk kembali untuk menggunakan perangkat lain.',
            );
          }
        }

        final accessToken = remoteSession.accessToken;
        if (accessToken == null) {
          return AuthResult.failure(
            'Login berhasil dimulai, tetapi Supabase belum memberikan sesi. Periksa konfirmasi email.',
          );
        }
        final remoteId = remoteSession.user['id'] as String?;
        if (remoteId == null || remoteId.isEmpty) {
          return AuthResult.failure('Supabase tidak mengembalikan ID akun.');
        }
        supabaseUserId = remoteId;
        supabaseAccessToken = accessToken;
        supabaseRefreshToken = remoteSession.refreshToken;

        final metadata = remoteSession.user['user_metadata'];
        final remoteFullName = metadata is Map<String, dynamic>
            ? metadata['full_name'] as String?
            : null;
        final profile = await SupabaseAuthService.getOrCreateProfile(
          userId: remoteId,
          email: cleanEmail,
          fullName: user?.fullName ?? remoteFullName ?? cleanEmail,
          accessToken: accessToken,
        );
        final profileUser = _userFromProfile(
          profile,
          user?.passwordHash ?? '',
          user?.salt ?? '',
        );
        if (user == null) {
          final insertId = await DBHelper.registerUser(profileUser);
          if (insertId <= 0) {
            return AuthResult.failure(
              'Login online berhasil, tetapi gagal menyimpan profil lokal.',
            );
          }
          authenticatedUser = UserModel(
            id: insertId,
            fullName: profileUser.fullName,
            email: profileUser.email,
            passwordHash: '',
            salt: '',
            currency: profileUser.currency,
            createdAt: profileUser.createdAt,
          );
        }
      }

      if (authenticatedUser?.id == null) {
        return AuthResult.failure('Profil akun tidak memiliki ID lokal.');
      }
      await SessionService.saveSession(
        userId: authenticatedUser!.id!,
        email: authenticatedUser.email,
        fullName: authenticatedUser.fullName,
      );
      if (supabaseUserId != null && supabaseAccessToken != null) {
        await SessionService.saveSupabaseTokens(
          accountEmail: authenticatedUser.email,
          userId: supabaseUserId,
          accessToken: supabaseAccessToken,
          refreshToken: supabaseRefreshToken,
        );
      } else {
        await SessionService.clearSupabaseTokens();
      }
      final bioEnabled = await DBHelper.getUserBiometricStatus(
        authenticatedUser.id!,
      );
      await SessionService.setBiometricEnabled(bioEnabled);

      return AuthResult.success(
        user: authenticatedUser,
        message: 'Selamat datang kembali, ${authenticatedUser.fullName}!',
      );
    } catch (e) {
      return AuthResult.failure('Terjadi kesalahan saat login: $e');
    }
  }

  /// Login cepat menggunakan biometrik dengan akun yang dipilih atau ditautkan.
  /// Mendukung metode spesifik ('fingerprint' atau 'face').
  static Future<AuthResult> loginWithBiometrics({
    String? email,
    String? method, // 'fingerprint', 'face', atau null untuk otomatis
  }) async {
    try {
      // 1. Cek dukungan hardware perangkat
      final isSupported = await BiometricService.isBiometricSupported();
      if (!isSupported) {
        return AuthResult.failure(
          'Perangkat Anda belum mendukung sensor biometrik atau belum ada sidik jari/wajah yang terdaftar.',
        );
      }

      // 2. Gunakan email yang dipilih, lalu akun biometrik yang telah ditautkan.
      String? targetEmail = email?.trim().toLowerCase();
      if (targetEmail == null || targetEmail.isEmpty) {
        targetEmail = await SessionService.getBiometricAccountEmail();
      }
      if (targetEmail == null || targetEmail.isEmpty) {
        return AuthResult.failure(
          'Akun biometrik belum ditautkan. Masukkan email akun yang ingin digunakan, lalu verifikasi biometrik.',
        );
      }

      // 3. Ambil data pengguna dari database berdasarkan email
      final user = await DBHelper.getUserByEmail(targetEmail);
      if (user == null || user.id == null) {
        return AuthResult.failure(
          'Akun dengan email "$targetEmail" belum terdaftar.',
        );
      }

      // 4. Cek pengaturan keamanan pengguna (SQLite / Secure Storage)
      final settings = await BiometricService.getUserSecuritySettings(user.id!);
      final isFp = settings['fingerprintEnabled'] == true;
      final isFace = settings['faceIdEnabled'] == true;
      final isBio = settings['biometricEnabled'] == true;

      if (method == 'fingerprint') {
        if (!isFp) {
          return AuthResult.failure(
            'Login sidik jari belum diaktifkan untuk akun ini. Silakan aktifkan di menu Profil → Security & Biometrics.',
          );
        }
      } else if (method == 'face') {
        if (!isFace) {
          return AuthResult.failure(
            'Login Face ID belum diaktifkan untuk akun ini. Silakan aktifkan di menu Profil → Security & Biometrics.',
          );
        }
      } else {
        if (!isBio && !isFp && !isFace) {
          return AuthResult.failure(
            'Login biometrik belum diaktifkan untuk akun ini. Silakan masuk dengan kata sandi terlebih dahulu, lalu aktifkan di Profil → Security & Biometrics.',
          );
        }
      }

      // 5. Tentukan pesan dialog biometrik sesuai metode yang dipilih
      final String reasonText;
      if (method == 'fingerprint') {
        reasonText = 'Pindai sidik jari Anda untuk masuk ke akun LokaLuxe';
      } else if (method == 'face') {
        reasonText = 'Arahkan wajah Anda ke kamera untuk masuk dengan Face ID';
      } else {
        final label = await BiometricService.getBiometricLabel();
        reasonText = 'Pindai $label Anda untuk masuk ke akun LokaLuxe';
      }

      // 6. Jalankan dialog sensor biometrik
      final didAuthenticate = await BiometricService.authenticate(
        reason: reasonText,
      );

      if (!didAuthenticate) {
        final label = method == 'fingerprint'
            ? 'Sidik jari'
            : (method == 'face' ? 'Face ID' : 'Biometrik');
        return AuthResult.failure('Verifikasi $label dibatalkan atau gagal.');
      }

      // 7. Simpan sesi aktif
      await SessionService.saveSession(
        userId: user.id!,
        email: user.email,
        fullName: user.fullName,
      );
      await SessionService.setBiometricAccountEmail(user.email);
      await SessionService.setBiometricEnabled(true);

      return AuthResult.success(
        user: user,
        message: 'Selamat datang kembali, ${user.fullName}!',
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

  static UserModel _userFromProfile(
    Map<String, dynamic> profile,
    String passwordHash,
    String salt,
  ) =>
      UserModel(
        fullName: (profile['full_name'] ?? '') as String,
        email: (profile['email'] ?? '') as String,
        passwordHash: passwordHash,
        salt: salt,
        currency:
            (profile['currency'] ?? 'IDR (Rupiah Indonesia)') as String,
        createdAt: profile['created_at'] as String?,
      );
}
