/// Why the portfolio and verification screens are open.
///
/// The same two screens serve three situations, and each wants different
/// chrome and a different ending:
///
///  * [editing] — a photographer changing a portfolio they already have.
///    Plain "Portfolio" app bar, Save, pop with a snackbar.
///  * [settings] — "Become a Creator" from Account & Security, long after
///    onboarding finished. "Become a Creator" app bar with the two-step
///    [CreatorSteps] row, ending on [CreatorReadyPage].
///  * [onboarding] — "Share my work" during the signup wizard. Steps 3 and 4
///    of the four-dot wizard, ending on the shared completion screen like
///    every other branch.
///
/// This was a single `isCreatorSetup` bool, which could say *that* setup was
/// happening but not *where from* — and the two places need different
/// answers. Two bools would make "from onboarding but not setup" expressible,
/// which is not a thing.
enum CreatorSetupEntry {
  editing,
  settings,
  onboarding;

  /// True for the two that are a first-time setup wizard rather than an edit.
  bool get isSetup => this != CreatorSetupEntry.editing;

  /// True only inside the signup wizard, where the shared onboarding chrome
  /// and the four-dot progress bar belong.
  bool get isOnboarding => this == CreatorSetupEntry.onboarding;
}
