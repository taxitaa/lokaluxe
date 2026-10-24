import 'package:flutter_test/flutter_test.dart';
import 'package:lokaluxe/core/models/supabase_voucher.dart';
import 'package:lokaluxe/core/services/supabase_auth_service.dart';

void main() {
  test(
    'voucher codes use the LOKA- plus six uppercase alphanumeric format',
    () {
      final code = SupabaseAuthService.generateVoucherCode();

      expect(code, matches(RegExp(r'^LOKA-[A-Z0-9]{6}$')));
    },
  );

  test('SupabaseVoucher parses the database row', () {
    final voucher = SupabaseVoucher.fromMap({
      'id': 17,
      'code': 'LOKA-9B82XK',
      'title': 'Diskon perjalanan',
      'discount': 'DISKON 20%',
      'is_used': false,
    });

    expect(voucher.id, 17);
    expect(voucher.code, 'LOKA-9B82XK');
    expect(voucher.title, 'Diskon perjalanan');
    expect(voucher.discount, 'DISKON 20%');
    expect(voucher.isUsed, isFalse);
  });
}
