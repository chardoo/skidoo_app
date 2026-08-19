import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/session/session_reset.dart';

/// Signing out has to leave nothing of the account behind.
///
/// The bug this guards: none of the session's in-memory state survives a
/// *launch*, so a leak is invisible unless you switch accounts without killing
/// the app — which is exactly what testing two accounts on one phone looks
/// like. The previous account's conversations, unread badge, basket and
/// follows were all still there for whoever signed in next.
void main() {
  setUp(SessionReset.clearRegistrations);
  tearDown(SessionReset.clearRegistrations);

  group('running the teardown', () {
    test('every registered holder is torn down', () async {
      final cleared = <String>[];
      SessionReset.register(#a, 'a', () => cleared.add('a'));
      SessionReset.register(#b, 'b', () => cleared.add('b'));

      await SessionReset.run();

      expect(cleared, unorderedEquals(['a', 'b']));
    });

    test('async teardowns are awaited, not fired and forgotten', () async {
      // Sign-out navigates the moment removeToken returns. A teardown still
      // running at that point is a teardown racing the next sign-in.
      var done = false;
      SessionReset.register(#slow, 'slow', () async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        done = true;
      });

      await SessionReset.run();

      expect(done, isTrue);
    });

    test('one failure cannot strand the rest', () async {
      // A half-cleared session is worse than the failure that caused it: what
      // survives is precisely the data that should not.
      final cleared = <String>[];
      SessionReset.register(#first, 'first', () => cleared.add('first'));
      SessionReset.register(#boom, 'boom', () => throw StateError('nope'));
      SessionReset.register(#last, 'last', () => cleared.add('last'));

      await SessionReset.run();

      expect(cleared, unorderedEquals(['first', 'last']));
    });

    test('a failing teardown never blocks signing out', () async {
      SessionReset.register(#boom, 'boom', () async => throw StateError('nope'));

      // Not "does not throw eventually" — removeToken awaits this, and an
      // escaping error would leave someone unable to sign out at all.
      await expectLater(SessionReset.run(), completes);
    });

    test('screen caches are emptied even with nothing registered', () async {
      final cache = SessionCache<String>('test-cache')..save('account A data');
      expect(cache.value, isNotNull);

      await SessionReset.run();

      expect(cache.value, isNull);
    });
  });

  group('registration', () {
    test('re-registering the same holder replaces it rather than stacking',
        () async {
      // A bloc built a second time must not leave its predecessor's teardown
      // behind to run against a closed object.
      var runs = 0;
      final owner = Object();
      SessionReset.register(owner, 'holder', () => runs++);
      SessionReset.register(owner, 'holder', () => runs++);

      await SessionReset.run();

      expect(runs, 1);
      expect(SessionReset.registeredCount, 1);
    });

    test('a closed holder unregisters and is not called', () async {
      var called = false;
      final owner = Object();
      SessionReset.register(owner, 'holder', () => called = true);
      SessionReset.unregister(owner);

      await SessionReset.run();

      expect(called, isFalse);
    });

    test('a teardown may unregister itself while running', () async {
      // Iterating the live map while a handler removes itself would throw, and
      // the throw would be swallowed — a teardown that silently stopped
      // happening is the worst shape this bug could take.
      final owner = Object();
      var called = false;
      SessionReset.register(owner, 'self-removing', () {
        called = true;
        SessionReset.unregister(owner);
      });

      await expectLater(SessionReset.run(), completes);
      expect(called, isTrue);
    });
  });

  group('what sign-out is wired to clear', () {
    // A source check rather than a behavioural one: standing the whole app up
    // to sign out of it would need a locator, a database and a socket. What
    // can go wrong here is someone adding long-lived account state and not
    // registering it, and that is a question about this file.
    late String locator;
    late String authService;

    setUpAll(() {
      locator = File('lib/core/di/service_locator.dart').readAsStringSync();
      authService = File('lib/services/auth_service.dart').readAsStringSync();
    });

    test('sign-out runs the teardown at all', () {
      // Every sign-out path in the app funnels through removeToken — the
      // account page, the web sidebar, the 401 interceptor, the logout use
      // case — which is why the teardown hangs off it rather than off any of
      // them.
      expect(authService, contains('SessionReset.run()'));
    });

    test('the holders that outlive the navigation stack are registered', () {
      // Blocs built per screen need nothing: sign-out replaces the navigation
      // stack and disposes them. These do not go with it.
      for (final holder in const [
        'FeedCacheService', // a feed carrying the last account's like flags
        'FollowRepository', // static set — "Following" on strangers
        'CartBloc', // singleton — their basket
        'FeedMusicController', // singleton — music over the login screen
        // Chat: the socket and the rooms held beside it, then the database
        // underneath. Clearing only one of the three refills from the others.
        'ChatBackgroundService',
        'ChatDatabase',
        // Notifications: a lazy static, so it registers itself only if some
        // screen happened to build it.
        'NotificationInbox',
      ]) {
        expect(
          locator,
          matches(RegExp(r'SessionReset\.register\(\s*' + holder + r'\s*,')),
          reason: '$holder outlives sign-out and must be registered',
        );
      }
    });

    test('per-account keys are deleted, device preferences are not', () {
      for (final key in const [
        '_kHasAddedFaces', // else the next user is never asked for faces
        '_kLastFacePrompt',
        '_kPendingInterests',
        '_kAudiencePreference',
        '_kProfileUrl', // else their avatar is drawn on the new account
      ]) {
        expect(authService, contains('_delete($key)'),
            reason: '$key belongs to the account, not the device');
      }

      // The other half of the rule. Signing out is not a factory reset: these
      // describe the phone and the person holding it, not the account.
      final removeToken = authService.substring(
        authService.indexOf('Future<void> removeToken()'),
        authService.indexOf('isFreshInstall'),
      );
      for (final key in const [
        '_kHasSeenOnboarding',
        '_kHasSeenSwipeHint',
        '_kFeedMusicMuted',
        '_kInstallMarker',
      ]) {
        expect(removeToken, isNot(contains('_delete($key)')),
            reason: '$key is a device preference and must survive sign-out');
      }
    });

    test('the chat teardown covers all three places a conversation lives', () {
      // Rooms live in the database, in ChatBackgroundService's in-memory map,
      // and in ChatRoomsBloc's state. Clear one and the others put it back:
      // the bloc reloads from the database, the service's map refills the
      // bloc over the socket. This is why "we cleared the chat" was true and
      // the inbox still showed the last account's conversations.
      expect(locator, contains('disconnectAll()'),
          reason: 'the socket and the rooms held beside it');
      expect(locator, contains('ChatDatabase>().clearAll()'),
          reason: 'the conversations on disk');

      final bloc = File(
        'lib/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart',
      ).readAsStringSync();
      // The bloc is built above the Navigator, so it registers itself rather
      // than being registered from the locator, and must let go on close.
      expect(bloc, contains('SessionReset.register(this'));
      expect(bloc, contains('SessionReset.unregister(this)'));
      expect(bloc, contains('ChatRoomsSessionCleared'));

      // Tearing the socket down detaches the callbacks that drive the unread
      // badge, and this bloc — built above the Navigator — is the same
      // instance after signing in again. Wiring them only in its constructor
      // would leave the badge dead for the whole of the next session, which is
      // a quieter failure than the one being fixed and easily mistaken for it.
      expect(bloc.split('_wireBackgroundCallbacks()').length - 1,
          greaterThanOrEqualTo(3),
          reason: 'declared, called on construction, and re-armed on load');
    });

    test('login still wipes on an account switch, for sessions that never '
        'signed out', () {
      // The sign-out path is not the only way a session ends: a crash, a token
      // the server stopped accepting, an install over another account's. This
      // is the only moment those are noticed.
      final login = File(
        'lib/features/auth/domain/usecases/login_usecase.dart',
      ).readAsStringSync();
      expect(login, contains('previousUserId != user.id'));
      expect(login, contains('_chatDb.clearAll()'));
      expect(login, contains('_e2ee.clearAllKeys()'));
    });

    test('the last account id survives, because the login check reads it', () {
      // LoginUseCase compares it against the incoming user to decide whether
      // to wipe chat history and E2EE keys. Clearing it here would make every
      // post-logout sign-in look like the same account returning — which is
      // the exact bug its own comment describes having been fixed.
      final removeToken = authService.substring(
        authService.indexOf('Future<void> removeToken()'),
        authService.indexOf('isFreshInstall'),
      );
      expect(removeToken, isNot(contains('_delete(_kLastAccountId)')));
    });
  });
}
