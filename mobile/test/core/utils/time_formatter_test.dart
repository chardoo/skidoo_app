import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/utils/time_formatter.dart';

void main() {
  group('TimeFormatter.relative', () {
    final now = DateTime.now();

    test('"Just now" under a minute', () {
      expect(TimeFormatter.relative(now.subtract(const Duration(seconds: 5))),
          'Just now');
    });

    test('minutes under an hour', () {
      expect(TimeFormatter.relative(now.subtract(const Duration(minutes: 5))),
          '5m');
    });

    test('hours under a day', () {
      expect(TimeFormatter.relative(now.subtract(const Duration(hours: 2))),
          '2h');
    });

    test('days under a week', () {
      expect(TimeFormatter.relative(now.subtract(const Duration(days: 3))),
          '3d');
    });

    test('weeks under a month', () {
      expect(TimeFormatter.relative(now.subtract(const Duration(days: 15))),
          '2w');
    });

    test('falls back to d/m beyond a month', () {
      final old = DateTime(2026, 4, 15);
      expect(TimeFormatter.relative(old), '15/4');
    });
  });

  group('TimeFormatter.absolute', () {
    test('spells out the moment the compact label hides', () {
      expect(TimeFormatter.absolute(DateTime(2026, 4, 15, 14, 3)),
          '15 Apr 2026 at 14:03');
    });
  });
}
