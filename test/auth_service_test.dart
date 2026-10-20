import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lokaluxe/core/database/db_helper.dart';
import 'package:lokaluxe/core/security/password_hasher.dart';
import 'package:lokaluxe/core/services/auth_service.dart';
import 'package:lokaluxe/core/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('E2E Backend Authentication & SQLite Suite', () {
    test('1. Default seed user has hashed password with salt in SQLite', () async {
      final user = await DBHelper.getUserByEmail('amalia@localluxe.id');
      expect(user, isNotNull);
      expect(user!.salt, isNotEmpty);
      expect(user.passwordHash, isNotEmpty);
      expect(user.passwordHash, isNot(equals('password123')));

      // Verifikasi login default user
      final loginResult = await AuthService.login(
        email: 'amalia@localluxe.id',
        password: 'password123',
      );
      expect(loginResult.isSuccess, isTrue);
      expect(loginResult.user, isNotNull);
      expect(loginResult.user!.fullName, 'Amalia Nur Azizah');
    });

    test('2. Registrasi user baru meng-hash password dan menolak duplikasi email', () async {
      final uniqueId = DateTime.now().microsecondsSinceEpoch;
      final email = 'budi_$uniqueId@nusantara.id';
      const password = 'BudiLokaLuxePassword2026!';

      // Registrasi user baru
      final regResult = await AuthService.register(
        fullName: 'Budi Santoso',
        email: email,
        password: password,
      );

      expect(regResult.isSuccess, isTrue);
      expect(regResult.message, contains('Pendaftaran akun berhasil'));

      // Periksa bahwa password di database tersimpan dalam bentuk hash + salt
      final savedUser = await DBHelper.getUserByEmail(email);
      expect(savedUser, isNotNull);
      expect(savedUser!.fullName, 'Budi Santoso');
      expect(savedUser.salt, isNotEmpty);
      expect(savedUser.passwordHash, isNotEmpty);
      expect(savedUser.passwordHash, isNot(equals(password)));
      expect(PasswordHasher.verifyPassword(password, savedUser.passwordHash, savedUser.salt), isTrue);

      // Coba registrasi ulang dengan email yang sama -> harus ditolak
      final dupResult = await AuthService.register(
        fullName: 'Budi Santoso Kloning',
        email: email,
        password: 'OtherPassword123',
      );
      expect(dupResult.isSuccess, isFalse);
      expect(dupResult.message, contains('sudah terdaftar'));
    });

    test('3. Login validasi password salah vs benar', () async {
      final uniqueId = DateTime.now().microsecondsSinceEpoch;
      final email = 'login_test_$uniqueId@nusantara.id';
      const password = 'MyPassword123!';

      // Buat user
      await AuthService.register(
        fullName: 'Login Tester',
        email: email,
        password: password,
      );

      // Login dengan password salah -> gagal
      final wrongPassResult = await AuthService.login(
        email: email,
        password: 'WrongPassword!',
      );
      expect(wrongPassResult.isSuccess, isFalse);
      expect(wrongPassResult.message, contains('Kata sandi yang Anda masukkan salah'));

      // Login dengan email belum terdaftar -> gagal
      final unknownEmailResult = await AuthService.login(
        email: 'unknown_$uniqueId@example.com',
        password: 'SomePassword123',
      );
      expect(unknownEmailResult.isSuccess, isFalse);
      expect(unknownEmailResult.message, contains('belum terdaftar'));

      // Login dengan kredensial benar -> sukses
      final correctResult = await AuthService.login(
        email: email,
        password: password,
      );
      expect(correctResult.isSuccess, isTrue);
      expect(correctResult.user!.email, email);
    });

    test('4. Session Management: Simpan sesi, cek sesi aktif, dan logout', () async {
      const email = 'amalia@localluxe.id';

      // Login berhasil
      await AuthService.login(
        email: email,
        password: 'password123',
      );

      // Cek sesi aktif
      final activeUser = await AuthService.checkSession();
      expect(activeUser, isNotNull);
      expect(activeUser!.email, email);

      final isSessionActive = await SessionService.isSessionActive();
      expect(isSessionActive, isTrue);

      // Logout
      await AuthService.logout();

      final sessionAfterLogout = await AuthService.checkSession();
      expect(sessionAfterLogout, isNull);

      final isStillActive = await SessionService.isSessionActive();
      expect(isStillActive, isFalse);
    });
  });
}
