import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:jperg_app/API/dio_client_service.dart';
import 'package:jperg_app/core/constants/onesignal.dart';
import 'package:jperg_app/core/di/service_locator.dart';

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
    });

    OneSignal.Notifications.addClickListener((event) {
      // The backend puts a `screen` key in every payload (see NotificationType
      // in main/app/services/notification_service.py). Routing on it needs
      // named routes this app does not have yet, so for now a tap just opens
      // the app on its normal launch route.
      final data = event.notification.additionalData;
      debugPrint('$_tag tapped ← screen=${data?['screen']} type=${data?['type']}');
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

Future<void> pushLogin(String userId) async {
  if (!_supported || userId.isEmpty) return;
  if (!_initialised) await initPush();
  if (_externalId == userId) return;

  try {
    await OneSignal.login(userId);
    _externalId = userId;
    debugPrint('$_tag registered external id $userId');

    // Belt and braces. login() stores the id as an `external_id` alias, which
    // is what the backend targets — but alias targeting depends on which
    // OneSignal user model the app sits on, and when it resolves to nobody the
    // send still returns 200. A tag is just a key/value on the subscription,
    // independent of the user model, so the backend can match on it instead by
    // flipping ONESIGNAL_TARGETING=tags with no deploy and no app release.
    try {
      await OneSignal.User.addTagWithKey('userId', userId);
      debugPrint('$_tag tagged userId=$userId');
    } catch (e) {
      debugPrint('$_tag tagging FAILED: $e');
    }
  } catch (e) {
    debugPrint('$_tag login FAILED for $userId: $e');
    return;
  }

  // Secondary registration path: hand the subscription id to the backend so it
  // can also target this device directly via send_push_to_players.
  // Best-effort — external-id targeting works without it.
  unawaited(_registerDeviceWithBackend());
}

Future<void> pushLogout() async {
  if (!_supported || !_initialised || _loggingOut) return;
  _loggingOut = true;

  try {
    // Drop the backend's copy first, while the auth token still exists —
    // AuthService.removeToken() deletes it immediately after this returns, and
    // the endpoint is authenticated.
    await _unregisterDeviceWithBackend();

    // Before logout, or the tag outlives the session it belongs to and keeps
    // matching a filter for whoever signs in on this phone next.
    try {
      await OneSignal.User.removeTag('userId');
    } catch (_) {}

    await OneSignal.logout();
    debugPrint('$_tag unregistered external id $_externalId');
  } catch (e) {
    debugPrint('$_tag logout FAILED: $e');
  } finally {
    _externalId = null;
    _registeredPlayerId = null;
    _loggingOut = false;
  }
}

Future<void> _registerDeviceWithBackend() async {
  final playerId = OneSignal.User.pushSubscription.id;
  if (playerId == null || playerId.isEmpty) {
    // Not an error — the id simply does not exist yet. The subscription
    // observer in initPush() will call back here once it does.
    debugPrint('$_tag no subscription id yet — deferring device registration');
    return;
  }
  // The observer fires on every subscription change, not just the first.
  if (playerId == _registeredPlayerId) return;

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
    debugPrint('$_tag device registered with backend');
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
