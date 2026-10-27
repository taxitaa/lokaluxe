import 'package:flutter_test/flutter_test.dart';
import 'package:lokaluxe/core/services/localization_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('defaults to Indonesian and persists the selected language', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = LocalizationProvider();

    expect(provider.langCode, 'id');
    await provider.initialize();
    expect(provider.strings.pickLocation, 'Pilih Lokasi');

    await provider.setLanguage('en');
    expect(provider.strings.pickLocation, 'Pick Location');

    final restoredProvider = LocalizationProvider();
    await restoredProvider.initialize();
    expect(restoredProvider.langCode, 'en');
  });
}
