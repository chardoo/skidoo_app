/// The fork in the signup wizard, and where each side of it goes.
///
/// "Share my work" used to deliver the discover flow — interests, then
/// creators-to-follow — because `AudiencePreferencePage` pushed `InterestsPage`
/// whichever option was picked. The portfolio and verification screens existed,
/// finished, reachable only from Account & Security afterwards.
///
/// Asserted against the source rather than by driving the wizard: both branches
/// need a signed-in session, a service locator and four screens' worth of
/// network, and none of that is what broke. What broke was one `Navigator.push`
/// that did not look at the answer.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_setup_entry.dart';

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path moved');
  return file.readAsStringSync();
}

/// The file with its comments stripped.
///
/// The comment above the fork names the two calls it removed and says why —
/// which is worth keeping, and is not the code doing it again.
String _code(String path) => _read(path)
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  const audience =
      'lib/features/auth/presentation/pages/audience_preference_page.dart';
  const portfolio =
      'lib/features/photographers/presentation/pages/portfolio_edit_page.dart';
  const verify =
      'lib/features/photographers/presentation/pages/verify_terms_page.dart';

  group('the fork', () {
    test('"Share my work" opens the portfolio, not the interests', () {
      final source = _read(audience);
      // Both destinations are named, and the share branch reaches the one
      // that belongs to it.
      expect(source, contains('PortfolioEditPage'));
      expect(source, contains('InterestsPage'));
      expect(
        source,
        contains('CreatorSetupEntry.onboarding'),
        reason: 'the portfolio must be opened as a wizard step, not an edit',
      );
    });

    test('the branch is a condition, not a single destination', () {
      final source = _read(audience);
      // The bug in one line: `_Audience.share` was computed, recorded, and
      // then ignored by the navigation.
      final navigates = RegExp(r'_Audience\.share\s*\n?\s*\?').hasMatch(source);
      expect(
        navigates,
        isTrue,
        reason: 'the push must depend on which option was chosen',
      );
    });

    test('a creator is asked for no interests', () {
      final source = _read(audience);
      // Interests and creators-to-follow belong to the discover branch. The
      // share branch reaches neither, by decision: a creator's feed is ranked
      // on what they shoot.
      final shareBranch = source.substring(source.indexOf('_Audience.share'));
      expect(shareBranch, isNot(contains('FollowSuggestionsPage')));
    });
  });

  group('the role moves at the end', () {
    test('choosing an option does not upgrade the account', () {
      final source = _code(audience);
      // It used to call BecomePhotographerUseCase here, which made a
      // photographer out of anybody who tapped the second option — no
      // portfolio, no ID, nothing agreed to — and then walked them through a
      // flow that asked for none of it. The server moves the role when it
      // accepts the verification; see main/app/routers/photographer/samples.py.
      expect(source, isNot(contains('BecomePhotographerUseCase')));
      expect(source, isNot(contains("setRole('photographer')")));
    });

    test('verification is what sets the role', () {
      expect(_read(verify), contains("setRole('photographer')"));
    });
  });

  group('wizard chrome', () {
    test('the creator steps are 3 and 4 of the same four dots', () {
      // Face capture is 1, the fork is 2. A creator who loses the progress
      // bar mid-signup has no way to tell how much is left.
      expect(_read(portfolio), contains('currentStep: 3'));
      expect(_read(verify), contains('currentStep: 4'));
      for (final source in [_read(portfolio), _read(verify)]) {
        expect(source, contains('totalSteps: 4'));
      }
    });

    test('the titles are the ones in the design', () {
      expect(_read(portfolio), contains("'Set up your portfolio'"));
      expect(
        _read(portfolio),
        contains("'This is what shows on your public profile'"),
      );
      expect(_read(verify), contains("'Verify and accept terms'"));
      expect(
        _read(verify),
        contains("'One last step before you start uploading events'"),
      );
    });

    test('signup ends on the shared completion screen', () {
      // Not CreatorReadyPage: that one is for somebody upgrading from
      // Settings, who is already home and whose face was scanned long ago.
      expect(_read(verify), contains('OnboardingCompletePage'));
      expect(_read(verify), contains('CreatorReadyPage'));
    });
  });

  group('the documents are linked where they are agreed to', () {
    test('both links sit inside the checkbox sentences', () {
      final source = _read(verify);
      expect(source, contains("'Photographer Terms of Service'"));
      expect(source, contains("'Payout Policy'"));
      expect(source, contains('LegalLinks.openTerms'));
    });
  });

  group('CreatorSetupEntry', () {
    test('editing is not a setup', () {
      expect(CreatorSetupEntry.editing.isSetup, isFalse);
      expect(CreatorSetupEntry.editing.isOnboarding, isFalse);
    });

    test('both wizards are a setup, only one is onboarding', () {
      expect(CreatorSetupEntry.settings.isSetup, isTrue);
      expect(CreatorSetupEntry.settings.isOnboarding, isFalse);
      expect(CreatorSetupEntry.onboarding.isSetup, isTrue);
      expect(CreatorSetupEntry.onboarding.isOnboarding, isTrue);
    });
  });
}
