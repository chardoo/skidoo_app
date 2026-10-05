import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// The Privacy screen's name for the personalisation switch.
///
/// It was "Share Usage Data", under a heading reading "Diagnostic analytics",
/// subtitled "Help us improve by sharing anonymized analytics". One account in
/// 228 turned it on. The data ranks that person's own feed; the copy described
/// telemetry.
void main() {
  final source = File(
    'lib/features/settings/presentation/pages/privacy_settings_page.dart',
  ).readAsStringSync();

  test('the switch is named for what it does', () {
    expect(source, contains("label: 'Personalise my feed'"));
    expect(source, isNot(contains("label: 'Share Usage Data'")));
  });

  test('it is filed under personalisation, not diagnostics', () {
    expect(source, contains("title: 'Personalisation'"));
    expect(source, isNot(contains("title: 'Diagnostic analytics'")));
  });

  test('it still writes the same setting', () {
    // The copy changed; the flag did not. `share_usage_data` is what the
    // tracking consent gate reads.
    expect(source, contains("_set('share_usage_data', v)"));
  });

  test('it says what is not done with the data', () {
    expect(source, contains('advertisers'));
  });
}
