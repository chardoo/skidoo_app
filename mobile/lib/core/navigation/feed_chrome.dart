import 'package:flutter/widgets.dart';

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

/// Marks the part of the tree that has the floating navigation bar beneath it.
///
/// [FeedChrome.visible] says whether the bar is *up*; this says whether there
/// is a bar at all. Both are needed, and conflating them is a bug the feed had:
/// the notifier is a static that outlives the shell which owns the bar, so a
/// card on a screen with no bar read "visible" left over from the Home feed and
/// stepped its caption over ninety-six points of nothing. Logging out and
/// continuing as a guest was the reliable way to see it — the guest feed is a
/// different route with no bar, and the flag stayed true until the app was
/// restarted.
///
/// Presence is the signal, so there is no boolean to pass down wrongly. The
/// shell that draws the bar wraps its body; everything else gets false for
/// free. That includes pushed routes, which are siblings of the shell in the
/// navigator rather than descendants of it — so a shared-event link opened
/// over the Home feed correctly reports no bar, which a flag threaded through
/// call sites would have got wrong.
class FeedNavBarScope extends InheritedWidget {
  const FeedNavBarScope({super.key, required super.child});

  /// Whether a navigation bar sits below [context].
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FeedNavBarScope>() != null;

  @override
  bool updateShouldNotify(FeedNavBarScope oldWidget) => false;
}
