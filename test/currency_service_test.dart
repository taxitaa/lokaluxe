import 'package:flutter_test/flutter_test.dart';
import 'package:lokaluxe/core/services/currency_service.dart';

void main() {
  test('converts budget amounts between selected currency and IDR', () {
    const rates = {'USD': 0.000062, 'JPY': 0.0094};

    final idrFromUsd = CurrencyService.convertBetween(
      amount: 100,
      sourceCurrency: 'USD',
      targetCurrency: 'IDR',
      rates: rates,
    );
    final jpyFromIdr = CurrencyService.convertBetween(
      amount: idrFromUsd,
      sourceCurrency: 'IDR',
      targetCurrency: 'JPY',
      rates: rates,
    );

    expect(idrFromUsd, closeTo(100 / 0.000062, 0.001));
    expect(jpyFromIdr, closeTo(idrFromUsd * 0.0094, 0.001));
  });

  test('supports conversion and formatting for additional currencies', () {
    const additionalCurrencies = ['SGD', 'MYR', 'KRW', 'GBP'];

    for (final currency in additionalCurrencies) {
      final converted = CurrencyService.convert(
        amountIDR: 1_000_000,
        targetCurrency: currency,
        rates: const {},
      );

      expect(converted, greaterThan(0));
      expect(CurrencyService.currencySymbols[currency], isNotEmpty);
      expect(CurrencyService.currencyNames[currency], isNotEmpty);
      expect(CurrencyService.currencyFlags[currency], isNotEmpty);
      expect(
        CurrencyService.formatAmount(converted, currency),
        startsWith(CurrencyService.currencySymbols[currency]!),
      );
    }
  });
}
