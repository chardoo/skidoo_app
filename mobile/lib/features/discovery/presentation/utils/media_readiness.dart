/// Which slides are ready to be looked at, and whether the carousel may move.
///
/// Swiping from a photo that has not arrived onto another that has not arrived
/// is two spinners in a row: the reader took an action and got less than they
/// had before. The carousel refuses that one move — and only that one. See
/// [canAdvance] for the exact rule, which is narrower than it sounds.
///
/// **Resolved, not loaded.** A slide stops blocking when its fetch *settles*,
/// however it settles. A photo that failed shows an error and can be swiped
/// past; a photo still downloading after [kReadinessCeiling] is let through
/// anyway. Both are deliberate, and both exist for the same reason: a gate
/// that waits for success is a gate that never opens on a dead connection, and
/// a reader pinned to one slide with no way out is a worse bug than the one
/// this fixes. The ceiling is the backstop for the failure mode that has no
/// error to report — a request that hangs rather than fails, which is exactly
/// what a captive portal or a vanished network produces.
///
/// Nothing here fetches anything the feed was not already fetching.
/// `feed_prefetch.dart` warms the neighbouring slides; this watches those same
/// warms finish. The only thing added is knowing *when*.
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:jperg_app/core/widgets/jperg_image.dart';

/// Fetches [url] and completes when it has settled, successfully or not.
typedef Warmer = Future<void> Function(
  BuildContext context,
  String url,
  double logicalWidth,
);

/// How long a slide may hold the carousel still before it is let through
/// regardless.
///
/// Four seconds: long enough that a photo arriving over a slow connection
/// usually wins the race and the reader never knows there was a gate, short
/// enough that somebody whose network has died is not left prodding a screen
/// that ignores them. It is a ceiling on *being blocked*, not a timeout on the
/// download — the image goes on loading, and lands when it lands.
const Duration kReadinessCeiling = Duration(seconds: 4);

/// Whether the carousel may move forward from the slide in front.
///
/// The rule in one line: refuse only the move from one unresolved slide to
/// another.
///
/// A reader looking at a picture that *has* arrived may always swipe on, even
/// onto one still loading — they are leaving something real behind, which is
/// an ordinary swipe into an ordinary spinner, and blocking it would mean
/// barely being able to advance at all on a slow connection. What is refused
/// is only the move that trades a spinner for a spinner.
bool canAdvance({
  required bool currentResolved,
  required bool nextResolved,
}) =>
    currentResolved || nextResolved;

/// Tracks which media URLs have settled, for one carousel.
///
/// Per-carousel and per-URL rather than global, and the URL is the one at *this
/// carousel's* width — the same string handed to [JpergImage.precache], since
/// the delivery URL and so the cache entry both depend on the display width.
/// The same photo shown somewhere narrower is a different decode and is not
/// this object's business.
class MediaReadiness extends ChangeNotifier {
  MediaReadiness({this.ceiling = kReadinessCeiling, Warmer? warmer})
      : _warm = warmer ?? _precache;

  /// Every slide settled, nothing ever fetched.
  ///
  /// For tests that are about something else — the automatic slide, the
  /// explore CTA — and would otherwise sit behind a gate waiting on a network
  /// the test environment does not have. Says plainly that readiness is not
  /// what the test is exercising.
  factory MediaReadiness.resolved() = _AlwaysResolved;

  final Duration ceiling;

  /// How a URL is fetched. Swapped out by tests, which have no network and
  /// need to decide for themselves when a slide settles — the whole behaviour
  /// here is about *when*, so a warm that resolves on its own schedule would
  /// test nothing.
  final Warmer _warm;

  static Future<void> _precache(
    BuildContext context,
    String url,
    double logicalWidth,
  ) =>
      JpergImage.precache(context, url, logicalWidth: logicalWidth);

  final Set<String> _resolved = <String>{};
  final Map<String, Timer> _ceilings = <String, Timer>{};
  bool _disposed = false;

  /// Whether this slide may be landed on.
  ///
  /// A null URL counts as resolved. That is the slide with nothing to warm —
  /// a video on somebody else's host, where no still can be derived — and a
  /// slide that can never resolve must never be the reason a carousel stops
  /// moving.
  bool isResolved(String? url) => url == null || _resolved.contains(url);

  /// Warm [url] if it is not already in flight, and note when it settles.
  ///
  /// Safe to call repeatedly — the carousel calls it on every page change for
  /// the same three slides, and a URL already warming or already resolved is
  /// ignored rather than fetched twice.
  void track(BuildContext context, String url, {required double logicalWidth}) {
    if (_disposed || _resolved.contains(url) || _ceilings.containsKey(url)) {
      return;
    }

    // Armed before the fetch, not after: the point of it is the fetch that
    // never comes back, and a timer started in a completion handler would
    // never start for exactly that case.
    _ceilings[url] = Timer(ceiling, () => _resolve(url));

    // Both outcomes resolve, and the error branch is handled rather than
    // merely observed. `JpergImage.precache` reports a failed load through its
    // own onError and completes normally, so in practice only the first branch
    // runs — but a warm that throws must still open the gate, and an unhandled
    // async error would otherwise surface as a crash from a photo that was
    // only ever being fetched early.
    unawaited(_warm(context, url, logicalWidth).then(
      (_) => _resolve(url),
      onError: (Object _, StackTrace __) => _resolve(url),
    ));
  }

  /// Mark a URL settled without fetching it — for a slide whose image the
  /// carousel saw arrive by some other route.
  void markResolved(String url) => _resolve(url);

  void _resolve(String url) {
    if (_disposed) return;
    _ceilings.remove(url)?.cancel();
    if (_resolved.add(url)) notifyListeners();
  }

  @override
  void dispose() {
    // Idempotent. A card can be torn down by more than one path, and
    // ChangeNotifier asserts on a second dispose — which would turn tidying up
    // into a crash.
    if (_disposed) return;
    _disposed = true;
    for (final timer in _ceilings.values) {
      timer.cancel();
    }
    _ceilings.clear();
    super.dispose();
  }
}

/// See [MediaReadiness.resolved].
class _AlwaysResolved extends MediaReadiness {
  _AlwaysResolved() : super(warmer: _nothingToDo);

  static Future<void> _nothingToDo(BuildContext _, String __, double ___) async {}

  @override
  bool isResolved(String? url) => true;
}
