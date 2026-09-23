import 'package:flutter/foundation.dart';

import 'package:jperg_app/core/navigation/chrome_visibility.dart';

/// Whether the app's floating bottom navigation is on screen — and with it the
/// feed's sound control, which rides in the same band.
///
/// The feed is full-bleed media: the bar and the controls are visitors on
/// somebody's photograph, and the tap that summons them is the same tap that
/// sends them away. That tap happens on a card, deep inside the Home tab, while
/// the bar itself lives in the Scaffold two feature folders away — hence one
/// notifier both sides can see rather than a callback threaded through every
/// feed, card and carousel in between.
///
/// Distinct from [ChromeVisibility], which is about the bar's *size*: reading
/// down a scrolling list narrows it to bare icons. This is about the bar being
/// there at all.
class FeedChrome {
  const FeedChrome._();

  /// Starts hidden. The app opens on the feed, and the first thing anyone sees
  /// should be the photograph.
  static final ValueNotifier<bool> visible = ValueNotifier<bool>(false);

  static void toggle() => _set(!visible.value);

  static void show() => _set(true);

  static void hide() => _set(false);

  static void _set(bool value) {
    if (visible.value == value) return;
    // Chrome that is being summoned arrives at full size.
    //
    // The two notifiers answer different questions and are set by different
    // gestures — [ChromeVisibility] by reading down a list, this one by a tap
    // on a photo — so they drifted apart in the one case where the second
    // gesture undoes the first: scroll down far enough to narrow the bar to
    // bare icons, let the tap send it away, then tap again to bring it back.
    // It came back narrowed, with nothing left to scroll to widen it, and the
    // tap looked like it had summoned a broken bar.
    //
    // Only on the way in. Going away is not a moment to be resizing anything,
    // and the bar that slides off screen is the one that should slide back.
    if (value) ChromeVisibility.reset();
    visible.value = value;
  }
}
