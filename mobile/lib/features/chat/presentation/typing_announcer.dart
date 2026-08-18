import 'dart:async';

/// Decides when to tell the room we started and stopped typing.
///
/// Extracted from ChatRoomBloc because the timing *is* the feature, and it was
/// wrong in a way that only showed up as "their indicator never goes away".
///
/// The problem it solves: the composer cannot tell us when someone stopped.
/// Its `onChanged` fires on edits and answers "is the field non-empty", which
/// is a different question — someone who types a sentence and then stops to
/// think leaves text in the box and produces no further events at all. Nothing
/// in that sequence ever says `false`. The indicator on the other screen was
/// therefore left to the receiver's expiry timer, counted from the last
/// *throttled* frame, which lands several seconds after they actually stopped.
///
/// So the stop is inferred here, from silence: [markTyping] pushes an idle
/// deadline out on every keystroke, and when it finally elapses we announce the
/// stop ourselves.
///
/// [markStopped] is the same announcement made explicitly, and is idempotent so
/// every place that legitimately knows typing has ended — the box emptied, the
/// message sent, the room closed — can just call it.
class TypingAnnouncer {
  TypingAnnouncer({
    required this.send,
    this.idleTimeout = const Duration(seconds: 4),
    this.sendInterval = const Duration(seconds: 3),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Source of "now" for the send throttle. Injectable because the throttle and
  /// the idle timer have to agree about time: a test that advances timers while
  /// the throttle reads the wall clock sees the two disagree, and so would any
  /// future change that put this on a different clock.
  final DateTime Function() _clock;

  /// Emits the frame. Separate from this class so it can be observed in tests
  /// and so this holds no opinion about transport.
  final void Function(bool isTyping) send;

  /// How long the composer may sit untouched before we announce the stop.
  final Duration idleTimeout;

  /// Minimum gap between outgoing "still typing" frames, so a keystroke does
  /// not become a frame.
  final Duration sendInterval;

  DateTime? _lastSentAt;
  Timer? _idleTimer;

  /// Whether the room currently believes we are typing.
  ///
  /// Tracked separately from the throttle clock: that gets cleared whenever a
  /// stop is sent, so using it to decide whether a stop is still owed conflated
  /// "sent a frame recently" with "currently shown as typing" — and the case
  /// where those differ is exactly the one that stranded the indicator.
  bool get isAnnounced => _announced;
  bool _announced = false;

  /// A keystroke. Safe to call on every one.
  void markTyping() {
    final at = _clock();

    _idleTimer?.cancel();
    _idleTimer = Timer(idleTimeout, markStopped);

    final last = _lastSentAt;
    if (_announced && last != null && at.difference(last) < sendInterval) {
      return;
    }
    _lastSentAt = at;
    _announced = true;
    send(true);
  }

  /// We have stopped. No-op if the room does not currently think otherwise.
  void markStopped() {
    _idleTimer?.cancel();
    _idleTimer = null;
    _lastSentAt = null;

    if (!_announced) return;
    _announced = false;
    // Never throttled: this is the frame that clears the indicator on the
    // other end, so dropping it strands it until the backstop expiry.
    send(false);
  }

  /// Drop pending work without announcing anything — for a teardown where the
  /// transport is already gone and a frame could not be delivered anyway.
  void dispose() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }
}
