import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/features/admin/data/models/exchange_rates.dart';

void main() {
  group('ExchangeRates.fromJson', () {
    test('parses base and numeric rates', () {
      final r = ExchangeRates.fromJson({
        'base': 'GHS',
        'rates': {'USD': 0.085, 'NGN': 116},
      });
      expect(r.base, 'GHS');
      expect(r.rates['USD'], 0.085);
      expect(r.rates['NGN'], 116.0);
      expect(r.isEmpty, isFalse);
    });

    test('defaults base to GHS and ignores non-numeric rates', () {
      final r = ExchangeRates.fromJson({
        'rates': {'USD': 'oops', 'EUR': 0.9},
      });
      expect(r.base, 'GHS');
      expect(r.rates.containsKey('USD'), isFalse);
      expect(r.rates['EUR'], 0.9);
    });

    test('handles missing / malformed rates map', () {
      expect(ExchangeRates.fromJson({}).isEmpty, isTrue);
      expect(ExchangeRates.fromJson({'rates': null}).isEmpty, isTrue);
      expect(ExchangeRates.fromJson({'rates': 'x'}).isEmpty, isTrue);
    });
  });

  group('ExchangeRates.toGhs', () {
    const rates = ExchangeRates(rates: {'USD': 0.085, 'NGN': 116});

    test('GHS and empty currency are identity', () {
      expect(rates.toGhs(100, 'GHS'), 100);
      expect(rates.toGhs(100, ''), 100);
    });

    test('divides amount by the rate', () {
      expect(rates.toGhs(0.085, 'USD'), closeTo(1.0, 1e-9));
      expect(rates.toGhs(116, 'NGN'), closeTo(1.0, 1e-9));
    });

    test('falls back to identity for unknown or zero rate', () {
      expect(rates.toGhs(50, 'XXX'), 50);
      const zero = ExchangeRates(rates: {'ZZZ': 0});
      expect(zero.toGhs(50, 'ZZZ'), 50);
    });
  });

  group('ExchangeRates.formatGhs', () {
    test('adds thousand separators and two decimals', () {
      expect(ExchangeRates.formatGhs(0), 'GHS 0.00');
      expect(ExchangeRates.formatGhs(50), 'GHS 50.00');
      expect(ExchangeRates.formatGhs(1234.5), 'GHS 1,234.50');
      expect(ExchangeRates.formatGhs(1000000), 'GHS 1,000,000.00');
    });

    test('rounds to two decimal places', () {
      expect(ExchangeRates.formatGhs(1.005), 'GHS 1.00');
      expect(ExchangeRates.formatGhs(2.346), 'GHS 2.35');
    });
  });
}
