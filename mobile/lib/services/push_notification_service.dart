import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:jperg_app/services/push_permission.dart';

import 'push_notification_service_stub.dart'
    if (dart.library.io) 'push_notification_service_io.dart' as impl;

export 'package:jperg_app/services/push_permission.dart';

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
/// Every method is a no-op on web and desktop; only iOS and Android reach the
/// SDK. Nothing here throws — push failing must never take the app with it.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  /// How long to wait after sign-in before asking for notification permission,
  /// so the OS dialog lands on a settled screen rather than mid-render.
  static const Duration permissionPromptDelay = Duration(seconds: 10);

  /// Wires up the SDK and its listeners. Safe to call before sign-in — the
  /// device simply has no external id attached until [login] runs.
  Future<void> init() => impl.initPush();

  /// Asks for the OS notification permission. Kept separate from [init] so the
  /// prompt can be timed deliberately: iOS only ever lets you ask once, and
  /// asking a stranger on the splash screen converts far worse than asking
  /// someone who has just signed in.
  ///
  /// Returns false on web/desktop, on failure, or when the user declines.
  Future<bool> requestPermission() => impl.requestPushPermission();

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
      impl.setPushSubscribed(subscribed);

  /// Whether the OS is currently letting this app post notifications.
  ///
  /// The app's own on/off switches are a stored preference and nothing more —
  /// they were happy to read "on" for someone the OS had never asked, which is
  /// the one state where no notification can arrive and nothing says so.
  Future<bool> hasPermission() => impl.hasPushPermission();

  /// The full answer, including whether the question has been put at all.
  /// See [PushPermission] for why the third state matters.
  Future<PushPermission> permissionState() => impl.pushPermissionState();

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

  /// Attaches this device to [userId] so backend sends addressed to that
  /// external id reach it. [userId] must be the `id` from the login response.
  ///
  /// Idempotent — repeat calls with the same id do nothing, so this is safe on
  /// every app start as well as on an actual sign-in.
  Future<void> login(String userId) => impl.pushLogin(userId);

  /// Detaches the device from the current user. Called from
  /// `AuthService.removeToken`, so every logout path is covered — otherwise
  /// the next person to sign in on this phone would receive the previous
  /// account's notifications.
  Future<void> logout() => impl.pushLogout();
}
