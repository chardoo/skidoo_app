import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/constants/onesignal.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/deep_links/deep_link_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/services/push_permission.dart';
import 'package:jperg_app/features/notifications/data/notification_inbox.dart';

const _tag = '[Push]';

/// `dart.library.io` is also true on macOS, Windows and Linux, where
/// onesignal_flutter has no implementation and every call throws
/// MissingPluginException. Only the two platforms that can actually receive a
/// push get past here.
bool get _supported => Platform.isIOS || Platform.isAndroid;

bool _initialised = false;

/// The id last registered with OneSignal, so repeat [pushLogin] calls on app
/// resume are free.
String? _externalId;

/// The subscription id last handed to our backend, so the subscription
/// observer does not re-POST the same one on every change it reports.
String? _registeredPlayerId;

/// Who it was handed over *for*.
///
/// The guard used to be the subscription id alone, and a subscription id
/// belongs to the device, not the account — it is the same value before and
/// after somebody signs out and a second person signs in. So the check "have I
/// already registered this id?" answered yes for the new account on the
/// strength of the old one, and the arriving account was never registered at
/// all. Pairing it with the account is what makes a switch re-POST.
String? _registeredUserId;

/// Guards against re-entry. [pushLogout] is reached from
/// AuthService.removeToken, which the Dio 401 interceptor also calls — and
/// [pushLogout] itself issues a request that can 401. Without this the two
/// bounce off each other forever.
bool _loggingOut = false;

Future<void> initPush() async {
  if (!_supported || _initialised) return;

  try {
    OneSignal.Debug.setLogLevel(kDebugMode ? OSLogLevel.warn : OSLogLevel.none);
    OneSignal.initialize(kOneSignalAppId);

    // Show the notification while the app is in the foreground too. Without an
    // explicit display() the event is delivered but nothing is drawn, so
    // notifications would only ever appear with the app backgrounded.
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      debugPrint('$_tag foreground ← ${event.notification.title}');
      event.notification.display();
      // The backend wrote a row for this before it pushed, so the inbox the app
      // is holding is now one short. This is the only thing that can tell it —
      // the tab no longer refetches on every visit.
      NotificationInbox.instance.invalidate();
    });

    OneSignal.Notifications.addClickListener((event) {
      final data = event.notification.additionalData;
      debugPrint('$_tag tapped ← screen=${data?['screen']} type=${data?['type']}');

      // Tapped from the background: the same row is missing, and the tap may
      // well be heading for the inbox.
      NotificationInbox.instance.invalidate();

      // Every payload carries a `screen`, and POLICY in
      // main/app/services/notify.py is the list of what it can be.
      final link = parsePushPayload(data);
      if (link == null) {
        // A screen this build has no destination for — an older app meeting a
        // newer backend. The app still opens; it just opens where it normally
        // would, which is better than a tap that appears to do nothing.
        debugPrint('$_tag no destination for this payload — opening normally');
        return;
      }

      // Straight into the deep-link machinery rather than navigating here.
      // That is what makes a tap on a killed app work: this listener fires
      // before the Navigator exists, and DeepLinkService already holds a link
      // until the first frame and across a sign-in, then follows it. Doing it
      // here instead would mean writing that twice and getting it wrong once.
      final links = DeepLinkService.instance;
      if (links == null) {
        // DeepLinkHost has not built yet. This is the cold-start case, not a
        // rare one: main() kicks off initPush before runApp, so a tap that
        // launched the app can be parsed before the host widget exists.
        // Parked rather than dropped — the service adopts it as it is built
        // and the post-frame resume follows it.
        debugPrint('$_tag no DeepLinkService yet — holding $link');
        DeepLinkService.parkEarly(link);
        return;
      }
      unawaited(links.follow(link));
    });

    // The subscription id does not exist until the device has registered with
    // APNs/FCM, which only happens once notification permission is granted —
    // i.e. always *after* pushLogin() runs. Registering the device with our
    // backend from pushLogin alone would therefore almost never find an id.
    // This fires when it appears, whenever that is.
    OneSignal.User.pushSubscription.addObserver((state) {
      final id = state.current.id;
      debugPrint('$_tag subscription id → $id (optedIn=${state.current.optedIn})');
      if (id != null && id.isNotEmpty && _externalId != null) {
        unawaited(_registerDeviceWithBackend());
      }
    });

    _initialised = true;
    debugPrint('$_tag initialised');
  } catch (e) {
    debugPrint('$_tag init FAILED: $e');
  }
}

Future<PushPermission> pushPermissionState() async {
  if (!_supported) return PushPermission.denied;
  if (!_initialised) await initPush();

  try {
    // permissionNative rather than the cached `permission` bool: the latter is
    // whatever the SDK last observed in this process, which is false before the
    // first observer fires — so a granted app that has just started would read
    // as denied and be asked again.
    final state = await OneSignal.Notifications.permissionNative();
    final result = switch (state) {
      // Notifications do arrive under provisional and ephemeral, quietly.
      OSNotificationPermission.authorized ||
      OSNotificationPermission.provisional ||
      OSNotificationPermission.ephemeral =>
        PushPermission.granted,
      OSNotificationPermission.notDetermined => PushPermission.undecided,
      OSNotificationPermission.denied => PushPermission.denied,
    };
    debugPrint('$_tag permission state=$state → $result');
    return result;
  } catch (e) {
    debugPrint('$_tag permission read FAILED: $e');
    return PushPermission.denied;
  }
}

Future<bool> hasPushPermission() async =>
    (await pushPermissionState()).isGranted;

Future<bool> requestPushPermission() async {
  if (!_supported) return false;
  if (!_initialised) await initPush();

  try {
    // fallbackToSettings: a user who declined once can no longer be prompted by
    // the OS, so send them to the app's settings page instead.
    final granted = await OneSignal.Notifications.requestPermission(true);
    debugPrint('$_tag permission granted=$granted');
    return granted;
  } catch (e) {
    debugPrint('$_tag permission request FAILED: $e');
    return false;
  }
}

/// Opt this device's push subscription in or out.
///
/// What the "Push notifications" master switch actually has to do. It used to
/// write a local `notifications_muted` flag and stop there — a flag only the
/// chat code ever read — so turning push off silenced nothing the server sent
/// and the notifications kept arriving from a switch that said they would not.
///
/// Opting out rather than revoking the OS permission, because the switch is
/// this device's and reversible from inside the app: revoking is not something
/// an app can do, and sending someone to system settings to undo their own tap
/// is a worse answer than one they can take back where they made it.
///
/// **Never asks for permission.** `optIn()` prompts if permission has not been
/// granted — the SDK says so outright — so opting in is skipped unless the OS
/// has already said yes. That keeps this callable from app launch, where a
/// dialog would land on a guest who has no account and nothing to be notified
/// about. Asking is [requestPushPermission]'s job and belongs at a moment
/// somebody chose: the settings switch, or just after signing in.
///
/// Opting *out* never prompts, so it always applies. That is the direction
/// that matters here anyway — it is what a muted device needs.
Future<void> setPushSubscribed(bool subscribed) async {
  if (!_supported) return;
  if (!_initialised) await initPush();

  try {
    if (!subscribed) {
      OneSignal.User.pushSubscription.optOut();
      debugPrint('$_tag push subscription optedOut');
      return;
    }

    if (!await hasPushPermission()) {
      debugPrint('$_tag optIn skipped — no permission yet, and optIn would ask');
      return;
    }
    OneSignal.User.pushSubscription.optIn();
    debugPrint('$_tag push subscription optedIn');
  } catch (e) {
    debugPrint('$_tag opt${subscribed ? 'In' : 'Out'} FAILED: $e');
  }
}

/// Who the SDK currently believes this device belongs to, or null for nobody.
///
/// Asked of the SDK rather than remembered here. What this file remembers is
/// only ever what it *did* — and the whole failure this answers is the gap
/// between the two: a login that did not take, a logout that moved the
/// subscription to an anonymous user, a process that restarted with a stale
/// idea of either. The backend addresses pushes by this id, so if it is wrong
/// nothing arrives and every send still returns 200.
Future<String?> pushAttachedUserId() async {
  if (!_supported) return null;
  if (!_initialised) await initPush();
  try {
    return await OneSignal.User.getExternalId();
  } catch (e) {
    debugPrint('$_tag could not read the attached external id: $e');
    return null;
  }
}

Future<void> pushLogin(String userId) async {
  if (!_supported || userId.isEmpty) return;
  if (!_initialised) await initPush();

  // Was: `if (_externalId == userId) return;`, which trusted this process's
  // memory of a call over the SDK's own state. Anything that detached the
  // device without going through this file — a logout that raced with a
  // sign-in, an SDK-side reset — left that flag saying "attached" while the
  // device was reachable by nobody, and every later login was skipped on the
  // strength of it. Ask instead, and only skip when the SDK agrees.
  if (await pushAttachedUserId() == userId) {
    _externalId = userId;
    debugPrint('$_tag already attached to $userId');
    // Still worth doing: the tag and the backend's copy can be missing even
    // when the alias is right — a reinstall restores one and not the others.
    unawaited(_ensureTagAndRegistration(userId));
    return;
  }

  try {
    await OneSignal.login(userId);
    _externalId = userId;
    debugPrint('$_tag registered external id $userId');

    // Check it took, and say so once if it did not.
    //
    // login() hands the SDK an operation to run against its own queue; it does
    // not promise the alias is attached by the time it returns. A sign-in
    // arriving on the heels of a sign-out — the same phone, seconds apart, the
    // exact case people report as "I logged out and back in and stopped getting
    // notifications" — is where that queue is busiest and where the attach can
    // be lost. One retry costs a read and covers it; anything still wrong after
    // that is fixed by the next reconcile, which runs every time the app comes
    // back to the foreground.
    if (await pushAttachedUserId() != userId) {
      debugPrint('$_tag external id did not take — retrying');
      await OneSignal.login(userId);
    }
  } catch (e) {
    debugPrint('$_tag login FAILED for $userId: $e');
    return;
  }

  await _ensureTagAndRegistration(userId);
}

/// The two things that ride alongside the alias, neither of which is worth
/// failing a sign-in over.
Future<void> _ensureTagAndRegistration(String userId) async {
  // Belt and braces. login() stores the id as an `external_id` alias, which is
  // what the backend targets — but alias targeting depends on which OneSignal
  // user model the app sits on, and when it resolves to nobody the send still
  // returns 200. A tag is just a key/value on the subscription, independent of
  // the user model, so the backend can match on it instead by flipping
  // ONESIGNAL_TARGETING=tags with no deploy and no app release.
  try {
    await OneSignal.User.addTagWithKey('userId', userId);
    debugPrint('$_tag tagged userId=$userId');
  } catch (e) {
    debugPrint('$_tag tagging FAILED: $e');
  }

  // Secondary registration path: hand the subscription id to the backend so it
  // can also target this device directly via send_push_to_players.
  // Best-effort — external-id targeting works without it.
  await _registerDeviceWithBackend();
}

Future<void> pushLogout() => _detach(unregisterBackend: true);

/// Clear the alias without telling the backend.
///
/// For a launch that finds nobody signed in. The device can still be carrying
/// the previous account — a sign-out whose DELETE never landed, a process
/// killed between `OneSignal.logout()` being queued and run, a restore that
/// brought the subscription back with it — and until something says otherwise
/// every push for that account keeps arriving on a phone it no longer belongs
/// to. Nothing used to say otherwise: reconcile asserts the alias only when it
/// has an account to assert, so a signed-out launch left it exactly as it was.
///
/// The backend half is skipped because it cannot work: unregister-device is
/// authenticated and there is no token to call it with. Calling it anyway
/// would fire a 401 through the Dio interceptor on the startup path, which
/// triggers a sign-out of the session that does not exist.
Future<void> pushDetach() => _detach(unregisterBackend: false);

Future<void> _detach({required bool unregisterBackend}) async {
  if (!_supported || !_initialised || _loggingOut) return;
  _loggingOut = true;

  final leaving = _externalId;
  try {
    if (unregisterBackend) {
      // Drop the backend's copy first, while the auth token still exists —
      // AuthService.removeToken() deletes it immediately after this returns,
      // and the endpoint is authenticated.
      await _unregisterDeviceWithBackend();
    }

    // Before logout, or the tag outlives the session it belongs to and keeps
    // matching a filter for whoever signs in on this phone next.
    try {
      await OneSignal.User.removeTag('userId');
    } catch (_) {}

    // Cleared *before* OneSignal.logout(), not after it in the finally.
    // logout() changes the subscription, which fires the observer in
    // initPush() — and that observer re-registers the device with the backend
    // whenever an external id is set. Read a moment too early it saw the
    // account being signed out and put its player id straight back, under a
    // token that was about to be deleted. The account that just left ended up
    // registered to a phone somebody else was about to sign in on.
    _externalId = null;
    _registeredPlayerId = null;
    _registeredUserId = null;

    await OneSignal.logout();
    debugPrint('$_tag detached external id $leaving');
  } catch (e) {
    debugPrint('$_tag detach FAILED: $e');
  } finally {
    // Belt and braces for the failure paths above, which can throw before the
    // clear inside the try.
    _externalId = null;
    _registeredPlayerId = null;
    _registeredUserId = null;
    _loggingOut = false;
  }
}

/// Whether the device still needs handing to the backend.
///
/// Pulled out of [_registerDeviceWithBackend] so it can be tested: everything
/// around it is OneSignal statics and the service locator, and this is the part
/// that was wrong. It used to compare [registeredPlayerId] alone, and a
/// subscription id belongs to the *device* — it is the same value before and
/// after one person signs out and another signs in — so the guard answered
/// "already done" for an account that had never been registered at all, and the
/// new account was reachable by nobody. The account has to be part of the
/// comparison, because the backend reads it from the JWT: the same body sent
/// under a different token is a different registration.
@visibleForTesting
bool shouldRegisterDevice({
  required String? playerId,
  required String? userId,
  required String? registeredPlayerId,
  required String? registeredUserId,
}) {
  // No subscription yet. Not an error — the id does not exist until the device
  // has registered with APNs/FCM, and the observer calls back when it does.
  if (playerId == null || playerId.isEmpty) return false;
  return playerId != registeredPlayerId || userId != registeredUserId;
}

Future<void> _registerDeviceWithBackend() async {
  final playerId = OneSignal.User.pushSubscription.id;
  if (playerId == null || playerId.isEmpty) {
    debugPrint('$_tag no subscription id yet — deferring device registration');
    return;
  }
  // The observer fires on every subscription change, not just the first.
  if (!shouldRegisterDevice(
    playerId: playerId,
    userId: _externalId,
    registeredPlayerId: _registeredPlayerId,
    registeredUserId: _registeredUserId,
  )) {
    return;
  }

  try {
    await sl<Api>().dio.post(
      '/notifications/register-device',
      data: {
        'player_id': playerId,
        // The backend's DeviceRegistrationRequest: 0 = iOS, 1 = Android.
        'device_type': Platform.isIOS ? 0 : 1,
      },
    );
    _registeredPlayerId = playerId;
    _registeredUserId = _externalId;
    debugPrint('$_tag device registered with backend for $_externalId');
  } catch (e) {
    debugPrint('$_tag backend device registration FAILED: $e');
  }
}

Future<void> _unregisterDeviceWithBackend() async {
  try {
    await sl<Api>().dio.delete('/notifications/unregister-device');
    debugPrint('$_tag device unregistered with backend');
  } catch (e) {
    debugPrint('$_tag backend device unregistration FAILED: $e');
  }
}
