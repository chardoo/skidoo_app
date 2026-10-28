import 'package:flutter/foundation.dart';

import 'package:jperg_app/core/utils/media_transform.dart';

/// How fast this connection is, measured from the images already fetched, and
/// which rung the feed should ask for because of it.
///
/// Why this exists
/// ───────────────
/// A fixed rung is a bet that every reader has the same connection. They do
/// not. The feed rung is ~204 KB, which lands in under a fifth of a second on
/// wifi and takes **over half a second on a 3 Mbps mobile link** — and in Ghana
/// that is the common case, not the edge case. The 640 rung is ~59 KB, 3.4x
/// smaller, and on a phone-width card the difference is visible only if you go
/// looking for it. Spending a slow reader's half-second on detail they did not
/// ask for is the wrong trade.
///
/// This is what Instagram does — they serve lower-quality images on slower
/// connections and expose a "use less cellular data" switch for the same
/// reason. The ladder already has the rungs; this decides which one.
///
/// Measured, not declared
/// ──────────────────────
/// No connectivity plugin, and deliberately: "on wifi" and "on 4G" are not
/// throughput. A café wifi behind a captive portal is slower than good LTE, and
/// a connection type cannot tell you that. What can is the download that just
/// finished — so every warmed image reports what it cost (see
/// `feed_prefetch.dart`), and the estimate is the app's own recent history.
///
/// Starts at [_optimistic] rather than pessimistic. The first few cards of a
/// session have no samples yet, and opening on the small rung would make a good
/// connection look bad for exactly the cards a reader judges the app by; a slow
/// connection corrects itself within two or three images.
class NetworkQuality {
  NetworkQuality._();

  static final NetworkQuality instance = NetworkQuality._();

  /// For tests, which must not inherit an estimate from the last one.
  @visibleForTesting
  static void resetForTest() => instance._reset();

  /// What a feed card should arrive within for the scroll to feel immediate.
  ///
  /// 400 ms is about the limit of what reads as "it was already there" when a
  /// card is warmed one swipe ahead. The thresholds below are this budget
  /// divided by each rung's measured size.
  static const _budget = Duration(milliseconds: 400);

  /// Measured rung sizes, in bytes — see the figures in
  /// `MediaTransform.image`. Used only to turn [_budget] into a throughput.
  static const _rungBytes = <int, int>{320: 18348, 640: 59494, 1080: 203744};

  /// Where a session starts, before anything has been measured.
  static const _optimistic = 1080;

  /// Throughput has to beat a threshold by this much to move *up* a tier, and
  /// fall below it by this much to move down.
  ///
  /// Without it an estimate sitting near a boundary flips tier every few
  /// images, and each flip changes the URL the feed asks for — so the card
  /// that was warmed at one size is requested at another and the warm-up is
  /// thrown away. Hysteresis costs a little accuracy and buys a stable answer.
  static const _hysteresis = 1.25;

  /// Samples smaller than this say more about latency than about bandwidth: a
  /// 2 KB thumbnail's time is almost entirely the round trip, so dividing its
  /// size by its duration reports a throughput far below the truth.
  static const _minSampleBytes = 20 * 1024;

  /// How much a new sample moves the estimate. Low, because one slow fetch is
  /// usually a slow *object* — a cold edge, a retried connection — rather than
  /// a slow connection, and over-reacting to it drops quality for everyone
  /// behind a single unlucky request.
  static const _alpha = 0.25;

  double? _bytesPerSecond;
  int _cap = _optimistic;

  void _reset() {
    _bytesPerSecond = null;
    _cap = _optimistic;
  }

  /// The ceiling the feed should pass to [MediaTransform.image].
  ///
  /// Stable between samples on purpose — see [_hysteresis]. Callers may read
  /// this per card without worrying that two reads a moment apart disagree.
  int get feedMaxPhysicalWidth => _cap;

  /// The current estimate, for diagnostics. Null until anything is measured.
  double? get bytesPerSecond => _bytesPerSecond;

  /// Report a finished download.
  ///
  /// Silent about anything it cannot learn from: a zero duration, an empty
  /// body, a sample too small to be about bandwidth.
  void record({required int bytes, required Duration elapsed}) {
    if (bytes < _minSampleBytes) return;
    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0) return;

    final sample = bytes / seconds;
    final previous = _bytesPerSecond;
    _bytesPerSecond =
        previous == null ? sample : previous + _alpha * (sample - previous);
    _cap = _capFor(_bytesPerSecond!, current: _cap);
  }

  /// The widest rung whose measured size fits [_budget] at this throughput,
  /// with [_hysteresis] applied against [current] so the answer does not flap.
  ///
  /// Pure, and separated from the state above because this is the part worth
  /// pinning: the arithmetic is where a tiering mistake would hide.
  @visibleForTesting
  static int capFor(double bytesPerSecond, {required int current}) =>
      _capFor(bytesPerSecond, current: current);

  static int _capFor(double bytesPerSecond, {required int current}) {
    final budget = _budget.inMicroseconds / Duration.microsecondsPerSecond;
    // Widest first: take the best rung this connection can actually afford.
    final rungs = _rungBytes.keys.toList()..sort((a, b) => b.compareTo(a));

    for (final rung in rungs) {
      final needed = _rungBytes[rung]! / budget;
      // Moving up to a wider rung demands headroom; staying or dropping does
      // not. That asymmetry is the hysteresis.
      final threshold = rung > current ? needed * _hysteresis : needed;
      if (bytesPerSecond >= threshold) return rung;
    }
    // Slower than the smallest rung's budget. It is still the smallest rung —
    // there is nothing below it, and the original would be far worse.
    return rungs.last;
  }
}
