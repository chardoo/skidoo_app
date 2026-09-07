import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/services/notification_prefs_service.dart';
import 'package:jperg_app/services/push_permission.dart';

import 'push_notification_service_io.dart' as impl;

export 'package:jperg_app/services/push_permission.dart';

/// The platform calls, behind an object.
///
/// The import above is a set of top-level functions, which is the wrong shape
/// for testing the order things happen in — and the order is where every bug
/// in this file has been. So the calls go through here, and a test can hand
/// [PushNotificationService.forTest] a fake.
class PushBackend {
  const PushBackend();

  Future<void> init() => impl.initPush();
  Future<bool> requestPermission() => impl.requestPushPermission();
  Future<PushPermission> permissionState() => impl.pushPermissionState();
  Future<void> setSubscribed(bool subscribed) =>
      impl.setPushSubscribed(subscribed);
  Future<void> login(String userId) => impl.pushLogin(userId);
  Future<void> logout() => impl.pushLogout();

  /// Who the SDK says this device is attached to. Null for nobody.
  Future<String?> attachedUserId() => impl.pushAttachedUserId();
}

/// OneSignal push notifications.
///
/// The backend addresses every push by *external user id*, and that id is
/// always `User.id` — the same value the JWT carries as `userId`, for clients
/// and photographers alike (there is no separate Client table). So the whole
/// contract on this side is: call [login] with `user.id` once a session is
/// established, and [logout] when it is torn down. Miss that and the backend's
/// sends still return 200, just with `recipients: 0` — nothing arrives and
/// nothing errors.
///
/// Three things all have to be true for a notification to land, and they are
/// set in three different places at three different times: the OS has to allow
/// them, the device's subscription has to be opted in, and the subscription has
/// to carry this account's external id. [reconcile] is the one routine that
/// asserts all three, and the fix for every "it just stopped working" this file
/// has had is to run it more often rather than to trust that a call made once
/// took effect.
///
/// Nothing here throws — push failing must never take the app with it.
class PushNotificationService {
  PushNotificationService._({
    PushBackend backend = const PushBackend(),
    bool Function()? isMuted,
  })  : _backend = backend,
        _isMuted = isMuted ?? _mutedFromPreferences;

  /// A service with the platform swapped out. Tests only.
  @visibleForTesting
  factory PushNotificationService.forTest({
    required PushBackend backend,
    bool Function()? isMuted,
  }) =>
      PushNotificationService._(backend: backend, isMuted: isMuted);

  static final PushNotificationService instance = PushNotificationService._();

  final PushBackend _backend;

  /// The device's own "not right now". Read through a function because it
  /// changes under this service — the settings switch writes it — and because
  /// a test has no service locator.
  final bool Function() _isMuted;

  static bool _mutedFromPreferences() {
    try {
      return sl<NotificationPrefsService>().isMuted;
    } catch (_) {
      // Not registered yet, or never on this platform. Nobody has asked for
      // silence, so do not invent it.
      return false;
    }
  }

  /// How long to wait after sign-in before asking for notification permission,
  /// so the OS dialog lands on a settled screen rather than mid-render.
  static const Duration permissionPromptDelay = Duration(seconds: 10);

  /// The account this device should be reachable as, once known. Held so
  /// [reconcile] can re-assert it from a lifecycle callback that has no idea
  /// who is signed in.
  String? _userId;

  AppLifecycleListener? _lifecycle;

  /// Wires up the SDK and its listeners. Safe to call before sign-in — the
  /// device simply has no external id attached until [login] runs.
  ///
  /// Also starts watching for the app coming back to the foreground. That is
  /// the moment a permission granted in the system settings app becomes true,
  /// and nothing else in the process gets told about it: without this, someone
  /// sent to Settings by the switch on the notification screen turned
  /// notifications on, came back, and found the switch still off and the
  /// device still unsubscribed.
  Future<void> init() async {
    await _backend.init();
    _watchLifecycle();
  }

  void _watchLifecycle() {
    if (_lifecycle != null) return;
    try {
      _lifecycle = AppLifecycleListener(
        onResume: () => unawaited(reconcile()),
      );
    } catch (e) {
      // Bindings not up yet. Not worth failing init over — every other entry
      // point still reconciles.
      debugPrint('[Push] could not watch the lifecycle: $e');
    }
  }

  /// Asks for the OS notification permission, and subscribes the device if the
  /// answer is yes.
  ///
  /// The second half is not a nicety. `optIn()` is refused while permission is
  /// missing — the SDK would raise its own dialog — so the subscription call
  /// that runs *before* the prompt is always skipped, and for a device that had
  /// been opted out (by the previous account on this phone, whose opt-out
  /// outlives their session) nothing ever put it back. The person granted
  /// permission, saw no error, and received nothing until the next cold start.
  ///
  /// Returns false on failure, or when the user declines.
  Future<bool> requestPermission() async {
    final granted = await _backend.requestPermission();
    if (granted && !_isMuted()) await _backend.setSubscribed(true);
    return granted;
  }

  /// Opt this device in or out of receiving pushes at all.
  ///
  /// What the "Push notifications" master switch has to call. The local
  /// `notifications_muted` preference beside it is read only by the chat code,
  /// so on its own it silenced nothing the server sent — the switch said push
  /// was off and the pushes kept arriving.
  ///
  /// Never prompts: opting in is skipped when permission has not been granted,
  /// because the SDK's `optIn()` raises the dialog itself. Safe to call from a
  /// signed-out launch. Use [ensurePermission] where asking is the intent.
  Future<void> setSubscribed(bool subscribed) =>
      _backend.setSubscribed(subscribed);

  /// Whether the OS is currently letting this app post notifications.
  ///
  /// The app's own on/off switches are a stored preference and nothing more —
  /// they were happy to read "on" for someone the OS had never asked, which is
  /// the one state where no notification can arrive and nothing says so.
  Future<bool> hasPermission() async => (await permissionState()).isGranted;

  /// The full answer, including whether the question has been put at all.
  /// See [PushPermission] for why the third state matters.
  Future<PushPermission> permissionState() => _backend.permissionState();

  /// Asks once, if there is anything to ask.
  ///
  /// For the unprompted moments — app launch, just after signing in — where the
  /// dialog is offered rather than requested. Granted needs nothing; denied is
  /// a decision already made, and re-requesting it is not a no-op:
  /// [requestPermission] sends the person to the system settings page once the
  /// OS is done showing its own dialog, which every launch is far too often.
  Future<void> promptIfUndecided() async {
    if (await permissionState() != PushPermission.undecided) return;
    // iOS will not present the dialog unless the app is frontmost, and the
    // attempt is spent rather than queued — so a prompt fired while the person
    // is on their home screen is a launch where they were simply never asked,
    // with nothing to show it happened. The wait before this one is ten
    // seconds, which is long enough to lose the race often.
    if (!await _waitForForeground()) return;
    if (await permissionState() != PushPermission.undecided) return;
    await requestPermission();
  }

  /// Resolves once the app is frontmost, or false if it does not become so
  /// within [timeout] — in which case the ask is left for the next launch,
  /// which is better than spending it on a dialog nobody can see.
  Future<bool> _waitForForeground({
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return true;
    }

    final completer = Completer<bool>();
    late final AppLifecycleListener listener;
    listener = AppLifecycleListener(
      onResume: () {
        if (!completer.isCompleted) completer.complete(true);
      },
    );

    try {
      return await completer.future.timeout(timeout, onTimeout: () => false);
    } finally {
      listener.dispose();
    }
  }

  /// Turns notifications on for real: grants first, preference second.
  ///
  /// Returns whether the OS ended up allowing them, so a switch can refuse to
  /// move rather than claim something the system will not honour. Already
  /// granted is a true with no dialog — iOS only ever shows it once, and
  /// [requestPermission] falls back to opening system settings after that.
  Future<bool> ensurePermission() async {
    if (await hasPermission()) return true;
    return requestPermission();
  }

  /// Make every layer agree that this device should receive notifications.
  ///
  /// Attached to the right account, opted in unless the person asked for
  /// silence, and never left opted out behind a permission that has since been
  /// granted. Safe and cheap to call repeatedly — it asks the SDK what is true
  /// before changing anything — which is the point: it runs at launch, on
  /// sign-in, and every time the app returns to the foreground, so a state that
  /// drifts for any reason is corrected at the next of those rather than
  /// staying broken until a reinstall.
  ///
  /// [userId] is remembered, so later calls with nothing to pass still know
  /// which account to assert.
  Future<void> reconcile({String? userId}) async {
    if (userId != null && userId.isNotEmpty) _userId = userId;
    final id = _userId;

    try {
      if (id != null) {
        // login() is idempotent and now checks the SDK's own answer first, so
        // this costs a read when everything is already right.
        await _backend.login(id);
      }

      final muted = _isMuted();
      if (muted) {
        // Opting out never prompts, so it always applies.
        await _backend.setSubscribed(false);
        return;
      }

      // Only when the OS allows it. setSubscribed(true) is a no-op otherwise —
      // deliberately, since optIn() would raise a dialog — so asserting it here
      // without the check would quietly do nothing and read as if it had worked.
      if ((await _backend.permissionState()).isGranted) {
        await _backend.setSubscribed(true);
      }
    } catch (e) {
      debugPrint('[Push] reconcile failed: $e');
    }
  }

  /// Attaches this device to [userId] so backend sends addressed to that
  /// external id reach it. [userId] must be the `id` from the login response.
  ///
  /// Goes through [reconcile] so a sign-in also fixes a subscription the
  /// previous account left opted out — signing in and receiving nothing was
  /// exactly that, and the switch on the settings screen read "on" throughout.
  Future<void> login(String userId) => reconcile(userId: userId);

  /// Detaches the device from the current user. Called from
  /// `AuthService.removeToken`, so every logout path is covered — otherwise
  /// the next person to sign in on this phone would receive the previous
  /// account's notifications.
  Future<void> logout() async {
    _userId = null;
    await _backend.logout();
  }
}
