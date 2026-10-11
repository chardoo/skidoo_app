/// Closing the app mid-signup, and what you come back to.
///
/// The token is written the moment a verification code is accepted —
/// `VerifyCodeUseCase` calls `establishSession` before the wizard has asked
/// for a face, a preference, a portfolio or an ID. Launch routing read exactly
/// that and sent anybody with a token to Home, so closing the app anywhere in
/// the four steps abandoned the whole wizard: no face, no interests, and for a
/// creator no portfolio, no ID and not even the role they had just spent two
/// screens asking for.
///
/// Skipping is not that. Skip is a decision and moves to the next step. What
/// is recovered here is the phone being put down.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/auth/onboarding_step.dart';
import 'package:jperg_app/features/auth/presentation/pages/audience_preference_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/face_capture_step_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/interests_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/onboarding_complete_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/onboarding_resume_page.dart';
import 'package:jperg_app/features/follow/presentation/pages/follow_suggestions_page.dart';
import 'package:jperg_app/features/home/presentation/pages/home_page.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_setup_entry.dart';
import 'package:jperg_app/features/photographers/presentation/pages/portfolio_edit_page.dart';
import 'package:jperg_app/features/photographers/presentation/pages/verify_terms_page.dart';

void main() {
  group('the stored step', () {
    test('survives a round trip', () {
      for (final step in OnboardingStep.values) {
        expect(OnboardingStep.fromId(step.id), step, reason: step.name);
      }
    });

    test('is stored by name, not position', () {
      // Reordering the enum must not move everybody to a different screen.
      expect(OnboardingStep.face.id, 'face');
      expect(OnboardingStep.verify.id, 'verify');
      expect(OnboardingStep.done.id, 'done');
    });

    test('an absent one means no resume', () {
      expect(OnboardingStep.fromId(null), isNull);
      expect(OnboardingStep.fromId(''), isNull);
    });

    test('an unrecognised one means no resume, not a crash', () {
      // A build that drops a step leaves people holding a marker for it, and
      // the honest answer is Home rather than an exception on first launch.
      expect(OnboardingStep.fromId('a_step_we_removed'), isNull);
    });
  });

  group('resuming draws the step itself', () {
    /// The page builds a widget per step; asserting the type is asserting the
    /// screen, without a service locator or a network behind it.
    Type drawn(OnboardingStep? step) =>
        OnboardingResumePage.pageFor(step).runtimeType;

    test('face', () => expect(drawn(OnboardingStep.face), FaceCaptureStepPage));
    test('audience',
        () => expect(drawn(OnboardingStep.audience), AudiencePreferencePage));
    test('interests',
        () => expect(drawn(OnboardingStep.interests), InterestsPage));
    test('follow',
        () => expect(drawn(OnboardingStep.follow), FollowSuggestionsPage));
    test('portfolio',
        () => expect(drawn(OnboardingStep.portfolio), PortfolioEditPage));
    test('verify', () => expect(drawn(OnboardingStep.verify), VerifyTermsPage));

    test('done — the work is finished and owed its sentence', () {
      // Reached the end, closed the app before tapping through. Dropping them
      // into a feed leaves them wondering whether any of it saved.
      expect(drawn(OnboardingStep.done), OnboardingCompletePage);
    });

    test('null lands somewhere, rather than on nothing', () {
      // Should not arrive — the route is only chosen when a step is set — but
      // a blank screen at launch is the worst way to be wrong.
      expect(drawn(null), HomePage);
    });
  });

  group('the creator steps resume as wizard steps', () {
    test('not as the settings screens they share code with', () {
      // `CreatorSetupEntry.onboarding` is what keeps the four dots on them and
      // sends them to the completion screen, rather than popping back to an
      // account page that is not underneath.
      final portfolio = OnboardingResumePage.pageFor(OnboardingStep.portfolio)
          as PortfolioEditPage;
      expect(portfolio.entry, CreatorSetupEntry.onboarding);

      final verify = OnboardingResumePage.pageFor(OnboardingStep.verify)
          as VerifyTermsPage;
      expect(verify.entry, CreatorSetupEntry.onboarding);
    });
  });

  group('every step marks itself', () {
    /// Which file is expected to write which step.
    const marks = <OnboardingStep, String>{
      OnboardingStep.face:
          'lib/features/auth/presentation/pages/face_capture_step_page.dart',
      OnboardingStep.audience:
          'lib/features/auth/presentation/pages/audience_preference_page.dart',
      OnboardingStep.interests:
          'lib/features/auth/presentation/pages/interests_page.dart',
      OnboardingStep.follow:
          'lib/features/follow/presentation/pages/follow_suggestions_page.dart',
      OnboardingStep.portfolio:
          'lib/features/photographers/presentation/pages/portfolio_edit_page.dart',
      OnboardingStep.verify:
          'lib/features/photographers/presentation/pages/verify_terms_page.dart',
      OnboardingStep.done:
          'lib/features/auth/presentation/pages/onboarding_complete_page.dart',
    };

    for (final entry in marks.entries) {
      test('${entry.key.name} is written by ${entry.value.split('/').last}', () {
        final source = File(entry.value).readAsStringSync();
        expect(
          source,
          contains('setOnboardingStep(OnboardingStep.${entry.key.name})'),
          reason: 'a step that does not mark itself cannot be returned to',
        );
      });
    }

    test('and the creator steps only mark inside the wizard', () {
      // Both screens are also reached from Account & Security and from an
      // ordinary portfolio edit. Neither is a signup to come back to.
      for (final path in [
        'lib/features/photographers/presentation/pages/portfolio_edit_page.dart',
        'lib/features/photographers/presentation/pages/verify_terms_page.dart',
      ]) {
        final source = File(path).readAsStringSync();
        final mark = source.indexOf('setOnboardingStep');
        final guard = source.indexOf('widget.entry.isOnboarding');
        expect(guard, isNot(-1), reason: '$path must guard the mark');
        expect(guard, lessThan(mark), reason: '$path marks unguarded');
      }
    });
  });

  group('only tapping through ends it', () {
    test('the last screen clears the marker', () {
      final source = File(
        'lib/features/auth/presentation/pages/onboarding_complete_page.dart',
      ).readAsStringSync();
      // In _goHome, not in initState: arriving is not finishing.
      final clear = source.indexOf('clearOnboardingStep');
      final goHome = source.indexOf('void _goHome()');
      expect(clear, isNot(-1));
      expect(clear, greaterThan(goHome));
    });

    test('and so does the creator branch, when it ends there', () {
      final source = File(
        'lib/features/photographers/presentation/pages/creator_ready_page.dart',
      ).readAsStringSync();
      expect(source, contains('clearOnboardingStep'));
    });

    test('nothing else clears it', () {
      // Specifically: no step clears it on the way past, which would make the
      // step before the last one un-resumable.
      final offenders = <String>[];
      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final source = file.readAsStringSync();
        if (!source.contains('clearOnboardingStep')) continue;
        final allowed = file.path.endsWith('onboarding_complete_page.dart') ||
            file.path.endsWith('creator_ready_page.dart') ||
            file.path.endsWith('auth_service.dart');
        if (!allowed) offenders.add(file.path);
      }
      expect(offenders, isEmpty);
    });
  });

  group('signing out takes the wizard with it', () {
    test('the marker and the guest flag are both dropped', () {
      // Left behind, the next person to sign in on this phone resumes a
      // stranger's signup — and signing out is not a request to browse
      // anonymously.
      final source = File('lib/services/auth_service.dart').readAsStringSync();
      final signOut = source.indexOf('_delete(_kHasAddedFaces)');
      final after = source.substring(signOut);
      expect(after, contains('_delete(_kOnboardingStep)'));
      expect(after, contains('_delete(_kIsGuest)'));
    });
  });
}
