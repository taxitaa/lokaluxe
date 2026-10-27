import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lokaluxe/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Location selection and Indonesian auth navigation', (
    WidgetTester tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const LokaLuxeApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Pilih Lokasi'), findsOneWidget);
    await tester.tap(find.text('Jakarta').first);
    await tester.pumpAndSettle();

    // 1. Verify Splash Screen elements
    expect(find.text('Mulai Menjelajahi\nDunia'), findsOneWidget);
    expect(find.text('Mulai Jelajah'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);

    // 2. Tap "Mulai Jelajah" -> Navigates to Login Screen
    await tester.tap(find.text('Mulai Jelajah'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('LOCALLUXE APP'), findsOneWidget);
    expect(find.text('Masuk ke LokaLuxe'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Buat akun'), findsOneWidget);

    // 3. Tap "Buat akun" -> Navigates to Register Screen
    final daftarBtn = find.text('Buat akun');
    await tester.ensureVisible(daftarBtn);
    await tester.pumpAndSettle();
    await tester.tap(daftarBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Buat akun Anda'), findsOneWidget);
    expect(find.text('Masukkan nama lengkap Anda'), findsOneWidget);
    expect(find.text('Masukkan email Anda'), findsOneWidget);
    expect(find.text('Buat akun'), findsOneWidget);
  });
}
