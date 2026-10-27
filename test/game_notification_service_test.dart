import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lokaluxe/core/services/game_notification_service.dart';
import 'package:lokaluxe/core/services/session_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'notification history is empty for a new account and isolated by user',
    () async {
      await SessionService.saveSession(
        userId: 1,
        email: 'first@example.com',
        fullName: 'First User',
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList('game_notification_history_1', [
        jsonEncode({
          'title': 'Voucher earned',
          'body': '10% off',
          'createdAt': DateTime.now().toIso8601String(),
        }),
      ]);

      expect(await GameNotificationService.getHistory(), hasLength(1));

      await SessionService.saveSession(
        userId: 2,
        email: 'new@example.com',
        fullName: 'New User',
      );
      expect(await GameNotificationService.getHistory(), isEmpty);
    },
  );
}
