import 'package:flutter/material.dart';
import 'package:jperg_app/features/auth/onboarding_step.dart';
import 'package:jperg_app/features/auth/presentation/pages/audience_preference_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/face_capture_step_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/interests_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/onboarding_complete_page.dart';
import 'package:jperg_app/features/follow/presentation/pages/follow_suggestions_page.dart';
import 'package:jperg_app/features/home/presentation/pages/home_page.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_setup_entry.dart';
import 'package:jperg_app/features/photographers/presentation/pages/portfolio_edit_page.dart';
import 'package:jperg_app/features/photographers/presentation/pages/verify_terms_page.dart';

/// Puts somebody back in the signup wizard where they left it.
///
/// Reached only from the cold-start route — see `_firstRoute` in `app.dart`.
/// It draws the step itself rather than wrapping it in anything, so a resumed
/// wizard is the same screen it would have been, continues into the same next
/// step, and needs nothing taught to the steps themselves.
///
/// The stack underneath is empty, which is correct: the steps already behind
/// them were answered, and `OnboardingStepScaffold` only draws a back arrow
/// when there is genuinely something to go back to.
class OnboardingResumePage extends StatelessWidget {
  const OnboardingResumePage({super.key, required this.step});

  static const routeName = '/onboarding/resume';

  /// Where they got to. Null should not arrive here — the route is only
  /// chosen when it is set — but a null lands on Home rather than on nothing,
  /// because a blank screen at launch is the worst way to be wrong.
  final OnboardingStep? step;

  @override
  Widget build(BuildContext context) => pageFor(step);

  /// Which screen a step is.
  ///
  /// A pure function of the step — it reads nothing from a context — so the
  /// mapping can be checked without a service locator, a navigator and a
  /// network standing behind every screen it names.
  static Widget pageFor(OnboardingStep? step) {
    return switch (step) {
      OnboardingStep.face => const FaceCaptureStepPage(),
      OnboardingStep.audience => const AudiencePreferencePage(),
      OnboardingStep.interests => const InterestsPage(),
      OnboardingStep.follow => const FollowSuggestionsPage(),

      // Both creator steps resume as wizard steps, not as the settings screens
      // they share code with: `CreatorSetupEntry.onboarding` is what keeps the
      // four dots on them and sends them to the completion screen rather than
      // popping back to an account page that is not underneath.
      OnboardingStep.portfolio =>
        const PortfolioEditPage(entry: CreatorSetupEntry.onboarding),
      OnboardingStep.verify =>
        const VerifyTermsPage(entry: CreatorSetupEntry.onboarding),

      // They reached the end and closed the app before tapping through. The
      // work is done and saved; what is owed is the sentence saying so.
      OnboardingStep.done => const OnboardingCompletePage(),

      null => const HomePage(),
    };
  }
}
