import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lokaluxe/main.dart';

void main() {
  testWidgets('LokaLuxe splash to login and main navigation test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const LokaLuxeApp());
    await tester.pumpAndSettle();

    // 1. Verify Splash Screen elements from reference screenshot 1
    expect(find.text('Start Exploring\nthe World'), findsOneWidget);
    expect(find.text('Mulai Eksplorasi'), findsOneWidget);
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget);

    // 2. Tap "Mulai Eksplorasi" -> Navigates to Login Screen
    await tester.tap(find.text('Mulai Eksplorasi'));
    await tester.pumpAndSettle();

    expect(find.text('LOCALLUXE APP'), findsOneWidget);
    expect(find.text('Masuk ke LocalLuxe'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);

    // 3. Tap "Masuk" -> Navigates to Main Navigation (Beranda)
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('Hello, Amalia! 👋'), findsOneWidget);
    expect(find.text('Kategori Pilihan'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Navigator'), findsOneWidget);
    expect(find.text('Concierge'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // 4. Test Bottom Navigation tab switching
    await tester.tap(find.text('Navigator'));
    await tester.pumpAndSettle();
    expect(find.text('Mulai Navigasi Rute'), findsOneWidget);

    await tester.tap(find.text('Concierge'));
    await tester.pumpAndSettle();
    expect(find.text('AI Concierge'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Amalia Nur Azizah'), findsOneWidget);
    expect(find.text('Kirim Saran & Kesan'), findsOneWidget);
  });
}
