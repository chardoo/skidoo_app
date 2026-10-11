/// Where somebody got to in the signup wizard, and whether they are owed it.
///
/// The token is written the moment a verification code is accepted — see
/// [VerifyCodeUseCase], which calls `establishSession` before the wizard has
/// asked for anything. So from the app's point of view the account exists, and
/// launch routing read exactly that: a token means Home.
///
/// Which meant closing the app anywhere in the four steps dropped the whole
/// wizard on the floor. No face enrolled, no interests, and for somebody
/// becoming a creator no portfolio, no ID and — because the role only moves
/// when verification is submitted — not even the account type they had just
/// spent two screens asking for. They landed on a stranger's version of the
/// product with no way back except hunting through Settings.
///
/// Skipping is not that. Skip is a decision, it moves to the next step, and
/// the marker moves with it. What this recovers is the phone being put down.
library;

/// One step of the wizard, in the order they are shown.
///
/// Stored by [name], so these names are a storage format: renaming one strands
/// everybody sitting on it. Adding to the end is free.
enum OnboardingStep {
  /// "Add your face" — step 1, and the same for both branches.
  face,

  /// "What best describes you?" — step 2, where the branches split.
  audience,

  /// Discover: "What do you love?" — step 3.
  interests,

  /// Discover: "Creators to follow" — step 4.
  follow,

  /// Creator: "Set up your portfolio" — step 3.
  portfolio,

  /// Creator: "Verify and accept terms" — step 4.
  verify,

  /// "You're all set" — reached the end, not yet tapped through.
  ///
  /// Still a resumable step on purpose. Somebody whose battery died on the
  /// last screen has finished the work and should be told so, rather than
  /// being dropped into a feed wondering whether any of it saved.
  done;

  /// The stored form. [name] rather than [index] so reordering the enum does
  /// not silently move everybody to a different screen.
  String get id => name;

  /// Reads a stored id back, or null if it is absent or unrecognised.
  ///
  /// Unrecognised matters: a build that drops a step leaves people holding a
  /// marker for it, and the honest answer is "no resume" rather than a crash
  /// on their first launch after an update.
  static OnboardingStep? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final step in OnboardingStep.values) {
      if (step.id == id) return step;
    }
    return null;
  }
}
