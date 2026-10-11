/// Which screen a cold start opens on.
///
/// Four questions, and two pairs of them were being asked as one.
///
/// **A token is not a finished signup.** The session is established the moment
/// a verification code is accepted, so "has a token" was answering "is set
/// up", and closing the app mid-wizard landed on Home with the whole thing
/// abandoned.
///
/// **Seeing the carousel is not choosing to be a guest.** Somebody who read
/// the slides and quit at the sign-up form arrived back on the guest feed
/// having never asked for it, because the tap on "Continue as guest" was never
/// written down.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/app.dart';
import 'package:jperg_app/features/auth/onboarding_step.dart';
import 'package:jperg_app/features/auth/presentation/pages/onboarding_resume_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/signup_page.dart';
import 'package:jperg_app/features/discovery/presentation/pages/discovery_page.dart';
import 'package:jperg_app/features/home/presentation/pages/home_page.dart';
import 'package:jperg_app/features/onboarding/presentation/pages/onboarding_page.dart';

void main() {
  String route({
    String token = '',
    bool hasSeenOnboarding = false,
    OnboardingStep? onboardingStep,
    bool isGuest = false,
  }) =>
      firstRouteFor(
        token: token,
        hasSeenOnboarding: hasSeenOnboarding,
        onboardingStep: onboardingStep,
        isGuest: isGuest,
      );

  group('signed in', () {
    test('with the wizard finished, goes home', () {
      expect(route(token: 'abc'), HomePage.routeName);
    });

    test('with the wizard unfinished, resumes it', () {
      // The regression. Every one of these used to be HomePage.
      for (final step in OnboardingStep.values) {
        expect(
          route(token: 'abc', onboardingStep: step),
          OnboardingResumePage.routeName,
          reason: 'closing the app on ${step.name} must come back to it',
        );
      }
    });

    test('the wizard outranks the token, not the other way round', () {
      // Both facts are true at once for anybody mid-signup: the account
      // exists *and* it is not set up. The second is the one that decides.
      expect(route(token: 'abc', onboardingStep: OnboardingStep.face),
          isNot(HomePage.routeName));
    });

    test('and the carousel flag does not enter into it', () {
      // Somebody signed in has been past that question either way.
      expect(route(token: 'abc', hasSeenOnboarding: false), HomePage.routeName);
      expect(route(token: 'abc', hasSeenOnboarding: true), HomePage.routeName);
    });
  });

  group('signed out', () {
    test('and new to the app, sees the carousel', () {
      expect(route(), OnboardingPage.routeName);
      // Even having previously browsed: the carousel has still never played.
      expect(route(isGuest: true), OnboardingPage.routeName);
    });

    test('having chosen to look around, comes back to looking around', () {
      expect(
        route(hasSeenOnboarding: true, isGuest: true),
        DiscoveryPage.routeName,
      );
    });

    test('having chosen nothing, comes back to the gate', () {
      // Read the carousel, saw the sign-up form, closed the app. They never
      // asked to browse, and used to be made a guest for it.
      expect(
        route(hasSeenOnboarding: true, isGuest: false),
        SignUpPage.routeName,
      );
    });

    test('the two are told apart by the choice, not the carousel', () {
      final chose = route(hasSeenOnboarding: true, isGuest: true);
      final didNot = route(hasSeenOnboarding: true, isGuest: false);
      expect(chose, isNot(didNot));
    });
  });

  group('a leftover wizard marker cannot strand a signed-out visitor', () {
    test('no token means the wizard is not resumed', () {
      // Signing out clears it, but a crash between the two writes must not
      // leave somebody permanently bounced into a wizard they cannot
      // authenticate for — _AuthGuard would send them to login anyway, and a
      // launch that round-trips through two redirects reads as broken.
      expect(
        route(onboardingStep: OnboardingStep.verify, hasSeenOnboarding: true),
        isNot(OnboardingResumePage.routeName),
      );
    });
  });
}
