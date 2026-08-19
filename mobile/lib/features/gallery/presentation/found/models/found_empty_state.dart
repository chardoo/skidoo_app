/// What the Found tab shows when the grid has nothing in it.
///
/// A named decision rather than a condition inlined in `build`, because the
/// inlined version was wrong in a way that deadlocked the feature: it showed
/// "Scanning for your face — we haven't matched you to any photo yet" to
/// someone who had five matches waiting for their answer, and returned early,
/// so the review banner that is the only route to confirming them was never
/// built. Confirming was the only way to fill the grid; a filled grid was the
/// only way to reach the banner. Meanwhile the tab wore its orange dot, so the
/// app announced matches on one surface and denied them on another.
enum FoundEmptyState {
  /// Nothing found and nothing pending. The scan simply has no answer yet.
  scanning,

  /// Matches exist but are awaiting the person's confirmation. The grid stays
  /// empty — it lists confirmed photos — but the review banner belongs on
  /// screen, so the page renders normally rather than as an empty state.
  awaitingReview,

  /// The filters excluded everything. Offer to clear them.
  filteredOut,

  /// There is something to show.
  none,
}

/// Which of the above applies.
///
/// [hasAlbums] is the confirmed grid, [pendingCount] the matches awaiting an
/// answer, [filtersActive] whether the person has narrowed anything.
FoundEmptyState foundEmptyState({
  required bool hasAlbums,
  required int pendingCount,
  required bool filtersActive,
}) {
  if (hasAlbums) return FoundEmptyState.none;
  // Checked before the filter case: pending matches are not something a filter
  // hid, and the banner asking about them has to appear either way.
  if (pendingCount > 0) return FoundEmptyState.awaitingReview;
  if (filtersActive) return FoundEmptyState.filteredOut;
  return FoundEmptyState.scanning;
}
