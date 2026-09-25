import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/services/push_notification_service.dart';

/// Whether a notification arrives depends on three things being true at once —
/// the OS allows them, the device's subscription is opted in, and that
/// subscription carries the account's external id — and they are set at three
/// different moments by three different callers. Every failure this file has
/// had was one of them quietly not happening, and none of them raises: the
/// backend's send still returns 200 with nobody on the other end.
///
/// So what is pinned here is the *order*: what gets asserted after a grant,
/// after a sign-in, on a resume, and what must not happen when somebody has
/// asked for silence.
class _FakeBackend extends PushBackend {
  _FakeBackend({
    this.permission = PushPermission.granted,
    this.attached,
    this.grants = true,
    this.throwOnLogin = false,
  });

  PushPermission permission;
  String? attached;

  /// What the OS dialog answers.
  bool grants;
  bool throwOnLogin;

  final calls = <String>[];

  @override
  Future<void> init() async => calls.add('init');

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    if (grants) permission = PushPermission.granted;
    return grants;
  }

  @override
  Future<PushPermission> permissionState() async => permission;

  @override
  Future<void> setSubscribed(bool subscribed) async =>
      calls.add('setSubscribed($subscribed)');

  @override
  Future<void> login(String userId) async {
    calls.add('login($userId)');
    if (throwOnLogin) throw StateError('the SDK is having a day');
    attached = userId;
  }

  @override
  Future<void> logout() async {
    calls.add('logout');
    attached = null;
  }

  @override
  Future<String?> attachedUserId() async => attached;
}

/// Every service a test builds, so tearDown can detach their lifecycle
/// listeners. One left attached goes on hearing about foregrounds from
/// whatever test runs next, and this service's whole job is acting on those.
final _built = <PushNotificationService>[];

PushNotificationService serviceFor(_FakeBackend backend,
    {bool muted = false}) {
  final service =
      PushNotificationService.forTest(backend: backend, isMuted: () => muted);
  _built.add(service);
  return service;
}

/// Drive the app to the background and back, the way the OS actually does it.
///
/// Through `inactive` in both directions rather than straight across:
/// [AppLifecycleListener] asserts on the transitions, and paused → resumed is
/// not one a device ever performs.
void background(WidgetTester t) {
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
}

void foreground(WidgetTester t) {
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

void main() {
  tearDown(() {
    for (final service in _built) {
      service.dispose();
    }
    _built.clear();
    // The binding remembers the last state, so a test that ended backgrounded
    // would make the next one's first transition an invalid one.
    TestWidgetsFlutterBinding.ensureInitialized()
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  group('granting permission', () {
    test('subscribes the device', () async {
      // The bug this is here for: optIn() is refused while permission is
      // missing, so the setSubscribed that runs *before* the prompt is always
      // skipped. Nothing ran after the grant, so a device the previous account
      // had opted out of stayed opted out — permission allowed, switch on,
      // nothing arriving, until the next cold start.
      final backend = _FakeBackend(permission: PushPermission.undecided);

      final granted = await serviceFor(backend).requestPermission();

      expect(granted, isTrue);
      expect(backend.calls, ['requestPermission', 'setSubscribed(true)']);
    });

    test('declined subscribes nothing', () async {
      final backend =
          _FakeBackend(permission: PushPermission.undecided, grants: false);

      final granted = await serviceFor(backend).requestPermission();

      expect(granted, isFalse);
      expect(backend.calls, ['requestPermission']);
    });

    test('does not undo a deliberate silence', () async {
      // Permission and the master switch answer different questions. Somebody
      // who allowed notifications and then turned them off in the app has not
      // asked for them back.
      final backend = _FakeBackend(permission: PushPermission.undecided);

      await serviceFor(backend, muted: true).requestPermission();

      expect(backend.calls, ['requestPermission']);
    });
  });

  group('signing in', () {
    test('attaches the account and subscribes the device', () async {
      final backend = _FakeBackend();

      await serviceFor(backend).login('u1');

      expect(backend.calls, ['login(u1)', 'setSubscribed(true)']);
      expect(backend.attached, 'u1');
    });

    test('opts out instead when push is muted on this device', () async {
      final backend = _FakeBackend();

      await serviceFor(backend, muted: true).login('u1');

      expect(backend.calls, ['login(u1)', 'setSubscribed(false)']);
    });

    test('claims nothing while the OS has not been asked', () async {
      // setSubscribed(true) cannot take effect without permission — optIn()
      // would raise the dialog — so asserting it here would look like it had
      // worked and leave the device unsubscribed. The prompt that follows is
      // what carries it, via requestPermission above.
      final backend = _FakeBackend(permission: PushPermission.undecided);

      await serviceFor(backend).login('u1');

      expect(backend.calls, ['login(u1)']);
    });

    test('signing in as somebody else re-attaches the device', () async {
      // Two accounts on one phone. The second sign-in has to move the device,
      // or the pushes keep going to whoever had it first.
      final backend = _FakeBackend();
      final service = serviceFor(backend);

      await service.login('u1');
      await service.logout();
      await service.login('u2');

      expect(backend.attached, 'u2');
      expect(backend.calls, [
        'login(u1)',
        'setSubscribed(true)',
        'logout',
        'login(u2)',
        'setSubscribed(true)',
      ]);
    });
  });

  group('reconcile', () {
    test('re-asserts the account it was last told about', () async {
      // What the resume hook calls. It has no idea who is signed in — that is
      // the point of remembering.
      final backend = _FakeBackend();
      final service = serviceFor(backend);
      await service.login('u1');
      backend.calls.clear();

      await service.reconcile();

      expect(backend.calls, ['login(u1)', 'setSubscribed(true)']);
    });

    test('a permission granted while away is picked up', () async {
      // Sent to the system settings app by the switch, allowed there, came
      // back. Nothing else in the process is told, so a resume that did not
      // re-check left the device unsubscribed behind a permission that now
      // allowed it.
      final backend = _FakeBackend(permission: PushPermission.denied);
      final service = serviceFor(backend);
      await service.login('u1');
      backend.calls.clear();

      backend.permission = PushPermission.granted;
      await service.reconcile();

      expect(backend.calls, ['login(u1)', 'setSubscribed(true)']);
    });

    test('asserts nobody after a sign-out', () async {
      // A resume on the sign-in screen must not put the device back on the
      // account that just left.
      final backend = _FakeBackend();
      final service = serviceFor(backend);
      await service.login('u1');
      await service.logout();
      backend.calls.clear();

      await service.reconcile();

      expect(backend.calls, ['setSubscribed(true)']);
      expect(backend.attached, isNull);
    });

    test('a signed-out launch still matches the master switch', () async {
      final backend = _FakeBackend();

      await serviceFor(backend, muted: true).reconcile();

      expect(backend.calls, ['setSubscribed(false)']);
    });

    test('a throwing SDK does not escape', () async {
      // Reached from a lifecycle callback and from sign-in. A throw here would
      // take the screen, and push failing must never do that.
      final backend = _FakeBackend(throwOnLogin: true);

      await expectLater(serviceFor(backend).login('u1'), completes);
    });
  });

  group('prompting', () {
    test('an answered question is not asked again', () async {
      // Not a no-op: requestPermission opens the system settings page once the
      // OS is done showing its own dialog. Every launch is far too often.
      for (final decided in [PushPermission.granted, PushPermission.denied]) {
        final backend = _FakeBackend(permission: decided);

        await serviceFor(backend).promptIfUndecided();

        expect(backend.calls, isEmpty, reason: '$decided was asked again');
      }
    });

    testWidgets('a launch asks, with nobody signed in', (t) async {
      // The headline of this group. The ask used to be signed-in only, so a
      // guest was never asked at all — and a guest who is never asked is one
      // the app cannot reach when their photos are found, which is the single
      // notification they are here for.
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final backend = _FakeBackend(permission: PushPermission.undecided);

      unawaited(serviceFor(backend).promptAtLaunch());
      await t.pump(PushNotificationService.launchPromptDelay);
      await t.pump();

      expect(backend.calls, contains('requestPermission'));
    });

    testWidgets('an ask that cannot be shown is not spent', (t) async {
      // iOS refuses to present the dialog unless the app is frontmost and
      // discards the attempt rather than queueing it, so a launch somebody
      // switched away from is a launch where they were never asked.
      final backend = _FakeBackend(permission: PushPermission.undecided);
      final service = serviceFor(backend);
      // init() is what registers the lifecycle listener that retries.
      await service.init();
      background(t);

      unawaited(service.promptAtLaunch());
      await t.pump(PushNotificationService.launchPromptDelay);
      await t.pump();
      expect(backend.calls, isNot(contains('requestPermission')),
          reason: 'nothing can be shown in the background');

      // Coming back is what puts the question.
      foreground(t);
      await t.pump();
      await t.pump();

      expect(backend.calls, contains('requestPermission'));
    });

    testWidgets('an ask abandoned after a long absence is put on the next return',
        (t) async {
      // The in-flight wait above gives up after two minutes rather than
      // holding a pending prompt for the life of the process. Past that, the
      // launch ask is gone — and somebody who opened the app, was called away,
      // and came back ten minutes later had simply never been asked. This is
      // the half that covers them: the question is still outstanding, so the
      // next foreground puts it.
      final backend = _FakeBackend(permission: PushPermission.undecided);
      final service = serviceFor(backend);
      await service.init();
      background(t);

      unawaited(service.promptAtLaunch());
      await t.pump(PushNotificationService.launchPromptDelay);
      // Long enough for the in-flight wait to time out and give up.
      await t.pump(const Duration(minutes: 3));
      expect(backend.calls, isNot(contains('requestPermission')),
          reason: 'the launch ask should have been abandoned, not queued');

      foreground(t);
      await t.pump();
      await t.pump();

      expect(backend.calls, contains('requestPermission'),
          reason: 'coming back must put the question that was never asked');
    });

    testWidgets('two asks at once only ask once', (t) async {
      // A prompt waiting on the app to come forward, and a resume firing the
      // retry. Two concurrent requestPermission calls is the one thing that
      // must not happen: past the OS dialog the second opens system settings.
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      final backend = _FakeBackend(permission: PushPermission.undecided);
      final service = serviceFor(backend);

      unawaited(service.promptIfUndecided());
      unawaited(service.promptIfUndecided());
      await t.pump();
      await t.pump();

      expect(backend.calls.where((c) => c == 'requestPermission'), hasLength(1));
    });

    test('the launch asks, and does not gate the ask on being signed in', () {
      // main() is not reachable from a test, and this is the line the whole
      // group exists to protect: it was `if (!signedIn) return;` above the
      // prompt, so every guest launch skipped it silently. Nothing else here
      // would notice it coming back.
      final source = File('lib/main.dart').readAsStringSync();

      expect(source, contains('promptAtLaunch()'),
          reason: 'the cold start has to ask');
      expect(
        source,
        isNot(contains('if (!signedIn) return')),
        reason: 'the ask must not be signed-in only — a guest who is never '
            'asked cannot be told their photos were found',
      );
    });

    testWidgets('a decided answer stops the retrying', (t) async {
      final backend = _FakeBackend(permission: PushPermission.undecided);
      final service = serviceFor(backend);
      await service.init();
      t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      unawaited(service.promptAtLaunch());
      await t.pump(PushNotificationService.launchPromptDelay);
      await t.pump();
      expect(backend.calls, contains('requestPermission'));
      backend.calls.clear();

      // Granted now. Every later foreground must leave it alone.
      background(t);
      foreground(t);
      await t.pump();
      await t.pump();

      expect(backend.calls, isNot(contains('requestPermission')));
    });
  });
}
