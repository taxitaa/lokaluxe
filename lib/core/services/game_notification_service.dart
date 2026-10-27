import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/voucher_data.dart';
import 'session_service.dart';

enum VoucherNotificationResult { shown, permissionRequested, unsupported }

class GameNotificationService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.lokaluxe/game_notifications',
  );
  static const _historyKeyPrefix = 'game_notification_history_';

  static Future<String?> _historyKeyForCurrentAccount() async {
    final session = await SessionService.getSessionData();
    if (session == null || session.isExpired || session.userId <= 0) {
      return null;
    }
    return '$_historyKeyPrefix${session.userId}';
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final historyKey = await _historyKeyForCurrentAccount();
    if (historyKey == null) return const [];
    final preferences = await SharedPreferences.getInstance();
    final storedItems = preferences.getStringList(historyKey) ?? const [];
    return storedItems
        .map((item) => jsonDecode(item))
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static Future<VoucherNotificationResult> showVoucherReward(
    VoucherData voucher,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final historyKey = await _historyKeyForCurrentAccount();
    if (historyKey != null) {
      final history = preferences.getStringList(historyKey) ?? <String>[];
      history.insert(
        0,
        jsonEncode({
          'title': 'Selamat! Voucher berhasil didapat',
          'body': '${voucher.discount} — ${voucher.title}',
          'createdAt': DateTime.now().toIso8601String(),
          'type': 'game_reward',
        }),
      );
      await preferences.setStringList(historyKey, history.take(100).toList());
    }

    if (defaultTargetPlatform != TargetPlatform.android) {
      return VoucherNotificationResult.unsupported;
    }

    final result = await _channel.invokeMethod<String>(
      'showVoucherNotification',
      {
        'title': 'Selamat! Voucher berhasil didapat',
        'body': '${voucher.discount} — ${voucher.title}',
      },
    );

    return switch (result) {
      'shown' => VoucherNotificationResult.shown,
      'permission_requested' => VoucherNotificationResult.permissionRequested,
      _ => throw StateError('Status notifikasi tidak dikenal: $result'),
    };
  }
}

class ProfilePhotoService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.lokaluxe/profile_photo',
  );

  static Future<Uint8List?> pickProfilePhoto() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      throw UnsupportedError('Pemilihan foto profil tersedia di Android.');
    }
    return _channel.invokeMethod<Uint8List>('pickProfilePhoto');
  }
}
