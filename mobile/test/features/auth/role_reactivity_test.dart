import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Upgrading to a creator has to change the app, not just the database.
///
/// The role used to be reachable only through `getRole()`, a one-shot async
/// read. Every screen that shows or hides on it kept the answer it happened to
/// get at build time — so somebody who became a creator mid-session went on
/// being offered "Become a creator", saw no creator control in the feed's top
/// bar, and had no portfolio section, until they signed in again. There was a
/// message apologising for exactly that.
///
/// The role is a [ValueNotifier] now. These cover the notifier's own contract;
/// the screens that read it are checked at the bottom.
void main() {
  setUp(() => AuthService.role.value = '');
  tearDown(() => AuthService.role.value = '');

  group('the role as a live value', () {
    test('isPhotographer follows it', () {
      expect(AuthService.isPhotographer, isFalse);
      AuthService.role.value = 'photographer';
      expect(AuthService.isPhotographer, isTrue);
      AuthService.role.value = 'user';
      expect(AuthService.isPhotographer, isFalse);
    });

    testWidgets('a widget watching it rebuilds the moment it changes',
        (t) async {
      await t.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<String>(
          valueListenable: AuthService.role,
          builder: (context, role, _) => Text(
            role == 'photographer' ? 'CREATOR TOOLS' : 'BECOME A CREATOR',
          ),
        ),
      ));

      expect(find.text('BECOME A CREATOR'), findsOneWidget);

      // What the upgrade wizard does on its way out.
      AuthService.role.value = 'photographer';
      await t.pump();

      expect(find.text('CREATOR TOOLS'), findsOneWidget);
      expect(find.text('BECOME A CREATOR'), findsNothing);
    });

    testWidgets('the change lands on the same frame, with no empty flash',
        (t) async {
      // The screens this replaced used FutureBuilder, so every rebuild showed
      // nothing for a frame while the read resolved — visible as the section
      // blinking on an ordinary rebuild. A notifier has the answer already.
      final seen = <String>[];
      await t.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<String>(
          valueListenable: AuthService.role,
          builder: (context, role, _) {
            seen.add(role);
            return const SizedBox.shrink();
          },
        ),
      ));

      AuthService.role.value = 'photographer';
      await t.pump();

      expect(seen, ['', 'photographer'],
          reason: 'no intermediate state where the role is unknown');
    });
  });

  group('what has to be watching it', () {
    String read(String path) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path has moved');
      return file.readAsStringSync();
    }

    test('setting the role publishes it before writing to storage', () {
      // An upgrade finishes by navigating. A screen rebuilding on that frame
      // has to see the new role, not wait on a keychain write.
      final auth = read('lib/services/auth_service.dart');
      final setRole = auth.substring(
        auth.indexOf('Future<void> setRole('),
        auth.indexOf('Future<String> getRole()'),
      );
      expect(setRole, contains('AuthService.role.value = value'));
    });

    test('every role-gated surface watches the value', () {
      // Each of these is somewhere a creator gains something the moment they
      // upgrade. A FutureBuilder on getRole() here is the bug: it resolves
      // once, and nothing rebuilds it when the role moves.
      const surfaces = {
        // The control in the feed's top bar — the one that is meant to appear.
        'lib/features/home/presentation/widgets/creator_mode_menu.dart':
            'the creator control in the feed top bar',
        // The offer to upgrade, which must stop being offered.
        'lib/features/settings/presentation/pages/account_security_page.dart':
            'the "become a creator" invitation',
        'lib/features/settings/presentation/pages/settings_page.dart':
            'the Photographer settings section',
        'lib/features/user_profile/presentation/pages/account_page.dart':
            'the portfolio card',
      };

      surfaces.forEach((path, what) {
        final source = read(path);
        expect(source, contains('valueListenable: AuthService.role'),
            reason: '$what must watch the role');
        expect(
          source,
          isNot(contains('future: sl<AuthService>().getRole()')),
          reason: '$what reads the role once and never updates',
        );
      });
    });

    test('signing out drops the role with the rest of the account', () {
      // Otherwise a photographer signing out hands the next person creator
      // tools for an account that has none.
      final auth = read('lib/services/auth_service.dart');
      final removeToken = auth.substring(
        auth.indexOf('Future<void> removeToken()'),
        auth.indexOf('isFreshInstall'),
      );
      expect(removeToken, contains("role.value = ''"));
    });

    test('a returning creator has their role before the first frame', () {
      // Seeded alongside the other synchronous auth state, so the app does not
      // open as a viewer and correct itself a moment later.
      final main = read('lib/main.dart');
      expect(main, contains('primeRole()'));
      final seeding = main.substring(main.indexOf('AuthService.isAuthenticated.value'));
      expect(seeding.indexOf('primeRole()'), lessThan(seeding.indexOf('runApp')),
          reason: 'primed before the app is built');
    });
  });
}
