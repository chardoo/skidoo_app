/// The Terms and the Privacy Policy, and the screens obliged to link them.
///
/// Asserted against the source rather than by driving each screen, because the
/// failure being guarded against is not a broken widget — it is a screen that
/// renders perfectly while linking nothing, or linking a host that does not
/// resolve. Neither shows up in a render.
///
/// The app shipped with exactly one legal link, on the sign-up page, pointing
/// at `piccotechnologies.com/privacy` — a host that fails on an SSL error for
/// every path. So the single link shown at the moment somebody agreed to the
/// terms went nowhere, and no other screen had one at all.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/config/legal_links.dart';


/// The row sizes its text in `.sp`, so it needs ScreenUtil the same way every
/// screen it sits on does.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  final lib = Directory('lib');

  List<File> dartFiles() => lib
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  group('legal URLs', () {
    test('no screen points at the host that does not resolve', () {
      final offenders = <String>[];
      for (final file in dartFiles()) {
        final source = file.readAsStringSync();
        // legal_links.dart names it in a comment explaining why it is gone.
        if (file.path.endsWith('core/config/legal_links.dart')) continue;
        if (source.contains('piccotechnologies.com')) {
          offenders.add(file.path);
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'piccotechnologies.com fails on SSL for every path — use '
            'LegalLinks.privacy / LegalLinks.terms',
      );
    });

    test('both documents live on the host that serves them', () {
      expect(LegalLinks.privacy, 'https://jperg.com/privacy');
      expect(LegalLinks.terms, 'https://jperg.com/terms');
    });

    test('nothing hard-codes a legal path of its own', () {
      // One place to change when these move. A second copy is how the first
      // one rotted unnoticed.
      final offenders = <String>[];
      final pattern = RegExp(r'''['"]https?://[^'"]*/(privacy|terms)''');
      for (final file in dartFiles()) {
        if (file.path.endsWith('core/config/legal_links.dart')) continue;
        final offending = file
            .readAsLinesSync()
            // Doc comments quote example URLs — in_app_web_view_page's usage
            // note shows `https://example.com/privacy`, which is prose.
            .where((line) => !line.trimLeft().startsWith('//'))
            .any(pattern.hasMatch);
        if (offending) offenders.add(file.path);
      }
      expect(offenders, isEmpty, reason: 'use LegalLinks instead');
    });
  });

  group('screens that must offer them', () {
    /// Sign-up and the three biometric screens are the obligations: two store
    /// reviews turn on them, and a face is the one thing here somebody cannot
    /// take back. Settings and Help are where people actually go looking.
    const required = <String, String>{
      'lib/features/auth/presentation/pages/signup_page.dart':
          'the moment an account is agreed to',
      'lib/features/auth/presentation/pages/face_capture_step_page.dart':
          'face enrolment during onboarding',
      'lib/features/user_profile/presentation/pages/face_recognition_page.dart':
          'face enrolment from the profile',
      'lib/features/gallery/presentation/found/pages/easy_search_page.dart':
          'selfies compared against one album',
      'lib/features/settings/presentation/pages/face_data_page.dart':
          'managing stored face data',
      'lib/features/settings/presentation/pages/privacy_settings_page.dart':
          'the screen about privacy',
      'lib/features/settings/presentation/pages/settings_page.dart':
          'where people look for them',
      'lib/features/settings/presentation/pages/help_support_page.dart':
          'where people look for them',
      'lib/features/photographers/presentation/pages/verify_terms_page.dart':
          'three boxes agreeing to documents',
    };

    for (final entry in required.entries) {
      test('${entry.key.split('/').last} links them — ${entry.value}', () {
        final file = File(entry.key);
        expect(file.existsSync(), isTrue, reason: '${entry.key} moved');
        final source = file.readAsStringSync();
        expect(
          source.contains('LegalLinksRow') ||
              source.contains('LegalLinks.open'),
          isTrue,
          reason: '${entry.key} should offer the policy — ${entry.value}',
        );
      });
    }
  });

  group('LegalLinksRow', () {
    testWidgets('draws both documents as buttons', (tester) async {
      await tester.pumpWidget(host(const LegalLinksRow()));
      await tester.pump();

      expect(find.text('Privacy Policy'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsOneWidget);
    });

    testWidgets('carries its prefix when given one', (tester) async {
      await tester.pumpWidget(
        host(const LegalLinksRow(prefix: 'Read them first:')),
      );
      await tester.pump();

      expect(find.text('Read them first: '), findsOneWidget);
    });

    testWidgets('a narrow screen wraps instead of overflowing',
        (tester) async {
      // Both labels plus a prefix do not fit one line on a small phone. A Row
      // would overflow here; the Wrap is the reason it does not.
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        host(const LegalLinksRow(
          prefix: 'By creating an account, you agree to our',
        )),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
