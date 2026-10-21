import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/voucher_data.dart';

enum VoucherNotificationResult { shown, permissionRequested, unsupported }

class GameNotificationService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.lokaluxe/game_notifications',
  );

  static Future<VoucherNotificationResult> showVoucherReward(
    VoucherData voucher,
  ) async {
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
