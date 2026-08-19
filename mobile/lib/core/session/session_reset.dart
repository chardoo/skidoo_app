import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/cache/session_cache.dart';

/// Everything the app has to forget when a session ends.
///
/// [SessionCache] already emptied the screen-level caches, and that was never
/// the whole story: a signed-in session also lives in long-lived blocs, in
/// static sets several screens write to, in a socket authenticated as one
/// account, and on disk. None of it was torn down, so signing out and back in
/// as somebody else left the previous account's conversations in the inbox,
/// their unread badge on the tab bar, their basket, and the people they follow
/// marked as followed.
///
/// The reason it was missed is worth stating: none of that survives a *launch*,
/// so it is invisible unless you switch accounts without killing the app —
/// which is exactly what testing two accounts on one phone looks like.
///
/// ## How to use it
///
/// Anything holding data that belongs to one signed-in account registers a
/// teardown here, and that is the whole contract. Handlers run on logout, from
/// `AuthService.removeToken`, which every sign-out path already funnels
/// through — the account page, the web sidebar, the 401 interceptor and the
/// logout use case.
///
/// The alternative, clearing state from each logout call site, is the design
/// this replaces: five call sites, each having to know the whole app, and each
/// a place to forget one thing. New state added tomorrow only has to remember
/// this file.
///
/// ## What does *not* belong here
///
/// Device preferences, not account ones — the theme, the chosen language,
/// whether the swipe hint has been seen, whether feed music is muted. Signing
/// out is not a factory reset, and someone who muted the feed does not expect
/// it loud again because they switched accounts.
///
/// Chat history and E2EE keys are also deliberately absent. They are wiped on
/// *login* instead, and only when the account differs from the last one on this
/// device — see `LoginUseCase.establishSession`. Wiping them here would delete
/// the cached history of someone who signed out and straight back in, which is
/// the case that caching exists for.
class SessionReset {
  SessionReset._();

  static final Map<Object, _Handler> _handlers = {};

  /// Registers [teardown] against [owner], replacing any previous entry for it.
  ///
  /// Keyed by identity so a rebuilt holder replaces its predecessor instead of
  /// stacking up — a bloc created for a second time must not leave the first
  /// one's teardown behind to run against a closed object.
  ///
  /// [debugName] is what a failure is reported as. Worth being specific: a
  /// teardown that throws is swallowed so it cannot strand a sign-out, and this
  /// name is then the only trace of it.
  static void register(
    Object owner,
    String debugName,
    FutureOr<void> Function() teardown,
  ) {
    _handlers[owner] = _Handler(debugName, teardown);
  }

  /// Drops [owner]'s teardown. Call from `dispose`/`close` — a bloc that has
  /// been closed cannot be reset, and asking it to would throw on the next
  /// sign-out rather than at the point of the mistake.
  static void unregister(Object owner) => _handlers.remove(owner);

  @visibleForTesting
  static int get registeredCount => _handlers.length;

  @visibleForTesting
  static void clearRegistrations() => _handlers.clear();

  /// Forgets the signed-in account.
  ///
  /// Every handler runs even if an earlier one fails: a half-cleared session is
  /// worse than the failure that caused it, since what survives is exactly the
  /// data that should not. Failures are logged and swallowed for the same
  /// reason — no teardown may leave somebody unable to sign out.
  static Future<void> run() async {
    // The screen-level caches first: they are the cheapest, they cannot fail,
    // and a handler below may repopulate one if it triggers a fetch.
    SessionCache.clearAll();

    // Snapshot: a teardown is allowed to unregister itself, and iterating the
    // live map while it does throws.
    for (final entry in List.of(_handlers.entries)) {
      try {
        await entry.value.teardown();
      } catch (e, st) {
        debugPrint('[SessionReset] ${entry.value.debugName} failed: $e\n$st');
      }
    }
  }
}

class _Handler {
  const _Handler(this.debugName, this.teardown);
  final String debugName;
  final FutureOr<void> Function() teardown;
}
