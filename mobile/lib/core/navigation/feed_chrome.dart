import 'package:flutter/foundation.dart';

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

  static void toggle() => visible.value = !visible.value;

  static void show() {
    if (!visible.value) visible.value = true;
  }

  static void hide() {
    if (visible.value) visible.value = false;
  }
}
