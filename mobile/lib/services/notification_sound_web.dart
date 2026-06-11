import 'package:web/web.dart' as web;

// A single shared AudioContext, created lazily on first use. Browsers cap the
// number of contexts, so we never allocate one per notification.
web.AudioContext? _ctx;

/// Web: synthesize a soft two-note "ding" via the Web Audio API.
///
/// Using an oscillator instead of an `<audio>` element means there is no asset
/// to bundle and nothing for the browser's autoplay policy to block once the
/// user has interacted with the page (which, inside a live chat session, they
/// always have).
void playNotificationTone() {
  try {
    final ctx = _ctx ??= web.AudioContext();
    // The context can start "suspended" until a user gesture; nudge it awake.
    if (ctx.state == 'suspended') {
      ctx.resume();
    }
    final now = ctx.currentTime;
    _chime(ctx, 784.0, now, 0.14); // G5
    _chime(ctx, 1046.5, now + 0.12, 0.18); // C6 — a gentle rising interval
  } catch (_) {
    // Best-effort: never let audio failures bubble into message handling.
  }
}

void _chime(web.AudioContext ctx, double freq, num start, num duration) {
  final osc = ctx.createOscillator();
  final gain = ctx.createGain();
  osc.type = 'sine';
  osc.frequency.value = freq;
  // Fast attack, smooth exponential decay → a soft bell, not a flat beep.
  gain.gain
    ..setValueAtTime(0.0001, start)
    ..exponentialRampToValueAtTime(0.18, start + 0.012)
    ..exponentialRampToValueAtTime(0.0001, start + duration);
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.start(start);
  osc.stop(start + duration);
}
