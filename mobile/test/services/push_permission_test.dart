import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/services/push_permission.dart';

/// The bug these lock down: the app's notification switches were a stored
/// preference and nothing else. Turning them on wrote `muted = false` and
/// stopped, so someone who had never seen the OS dialog — or had declined it —
/// flipped the switch, watched it stay on, and never received a notification.
/// Nothing anywhere said why.
///
/// The fix hangs on there being three states rather than two. "Not yet asked"
/// is a dialog worth showing; "refused" is a decision to leave alone, because
/// requestPermission(fallbackToSettings: true) does not quietly return false
/// once the OS is finished — it opens the system settings page.
void main() {
  test('only granted counts as allowed', () {
    expect(PushPermission.granted.isGranted, isTrue);
    expect(PushPermission.undecided.isGranted, isFalse);
    expect(PushPermission.denied.isGranted, isFalse);
  });

  test('undecided is not denied — they call for opposite behaviour', () {
    // The whole point of the third state. Collapsing these is what sent a
    // declined user to system settings ten seconds after every launch.
    expect(PushPermission.undecided, isNot(PushPermission.denied));
  });

  group('what each state should drive', () {
    // promptIfUndecided shows the dialog for exactly one state; enabling a
    // switch asks for two of them (undecided asks, denied falls back to
    // settings) and skips the work for the third.
    bool prompts(PushPermission p) => p == PushPermission.undecided;
    bool needsRequest(PushPermission p) => !p.isGranted;

    test('the unprompted moments ask once, and only once', () {
      expect(prompts(PushPermission.undecided), isTrue);
      expect(prompts(PushPermission.granted), isFalse);
      expect(prompts(PushPermission.denied), isFalse,
          reason: 'a launch must not reopen system settings for someone who '
              'has already said no');
    });

    test('turning a switch on skips the ask only when already allowed', () {
      expect(needsRequest(PushPermission.granted), isFalse);
      expect(needsRequest(PushPermission.undecided), isTrue);
      expect(needsRequest(PushPermission.denied), isTrue,
          reason: 'deliberate: the user just asked for notifications, so '
              'pointing them at settings is an answer rather than a nag');
    });
  });
}
