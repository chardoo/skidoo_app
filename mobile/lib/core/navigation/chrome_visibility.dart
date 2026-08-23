import 'package:flutter/widgets.dart';

/// Whether the navigation chrome is expanded, driven by which way the content
/// is moving.
///
/// Reading further collapses it: the top tabs slide away and the bottom bar
/// narrows to bare icons. Coming back up restores both. The photo is the
/// content; the chrome is how you leave it.
///
/// **One notifier, not one per bar.** The two bars are in different widgets —
/// the bottom bar belongs to the home shell, the top bar to the page inside it
/// — and they respond to the same gesture. Given a scroll listener each they
/// would eventually disagree, and the failure is visible: tabs gone while the
/// bar is still wide, or a bar that collapses on a scroll the tabs ignored.
class ChromeVisibility {
  const ChromeVisibility._();

  /// True when the chrome is at full size.
  static final expanded = ValueNotifier<bool>(true);

  /// How far the content must travel before the chrome reacts.
  ///
  /// Without it, a few pixels of overscroll or a thumb resting on the glass
  /// flickers the bars. Roughly a finger's slack.
  static const double _threshold = 48;

  static double _downAccumulated = 0;

  /// Feed a scroll notification in. Returns false so it keeps bubbling — this
  /// observes, it does not consume.
  static bool handle(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      final atTop = notification.metrics.pixels <= 0;

      if (delta > 0 && !atTop) {
        _downAccumulated += delta;
        if (_downAccumulated >= _threshold) _set(false);
      } else if (delta < 0 || atTop) {
        // Any upward movement restores immediately. Deliberately not
        // thresholded: reaching for the nav is a deliberate act, and making
        // someone drag twice for it is the kind of cleverness people describe
        // as the bar being broken.
        _downAccumulated = 0;
        _set(true);
      }
    } else if (notification is ScrollEndNotification) {
      _downAccumulated = 0;
      // Back at the top with nowhere further to go — the chrome belongs open,
      // whatever the last gesture was.
      if (notification.metrics.pixels <= 0) _set(true);
    }
    return false;
  }

  /// Force it open — for leaving a scrolling screen, opening a sheet, or any
  /// moment where the person is no longer reading.
  ///
  /// A collapsed bar left behind on a screen that does not scroll cannot be
  /// restored: there is no gesture to restore it with.
  static void reset() {
    _downAccumulated = 0;
    _set(true);
  }

  static void _set(bool value) {
    if (expanded.value != value) expanded.value = value;
  }
}
