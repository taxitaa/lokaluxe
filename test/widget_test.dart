import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lokaluxe/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Location selection and English auth navigation', (WidgetTester tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const LokaLuxeApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Pick Location'), findsOneWidget);
    await tester.tap(find.text('Jakarta').first);
    await tester.pumpAndSettle();

    // 1. Verify Splash Screen elements
    expect(find.text('Start Exploring\nthe World'), findsOneWidget);
    expect(find.text('Start Exploring'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);

    // 2. Tap "Mulai Eksplorasi" -> Navigates to Login Screen
    await tester.tap(find.text('Start Exploring'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('LOCALLUXE APP'), findsOneWidget);
    expect(find.text('Sign in to LocalLuxe'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);

    // 3. Tap "Daftar Sekarang" -> Navigates to Register Screen
    final daftarBtn = find.text('Create an account');
    await tester.ensureVisible(daftarBtn);
    await tester.pumpAndSettle();
    await tester.tap(daftarBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });
}
