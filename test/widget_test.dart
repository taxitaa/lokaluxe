import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lokaluxe/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LokaLuxe splash to login and register navigation test', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const LokaLuxeApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // 1. Verify Splash Screen elements
    expect(find.text('Start Exploring\nthe World'), findsOneWidget);
    expect(find.text('Mulai Eksplorasi'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);

    // 2. Tap "Mulai Eksplorasi" -> Navigates to Login Screen
    await tester.tap(find.text('Mulai Eksplorasi'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('LOCALLUXE APP'), findsOneWidget);
    expect(find.text('Masuk ke LocalLuxe'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);
    expect(find.text('Daftar Sekarang'), findsOneWidget);

    // 3. Tap "Daftar Sekarang" -> Navigates to Register Screen
    final daftarBtn = find.text('Daftar Sekarang');
    await tester.ensureVisible(daftarBtn);
    await tester.pumpAndSettle();
    await tester.tap(daftarBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Buat Akun Baru'), findsOneWidget);
    expect(find.text('Nama Lengkap'), findsOneWidget);
    expect(find.text('Alamat Email'), findsOneWidget);
    expect(find.text('Daftar Akun'), findsOneWidget);
  });
}
