import 'package:flutter/foundation.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// Which post the vertical feed currently has under the reader.
///
/// This exists for one reader: an open comment sheet. The sheet is a route of
/// its own and the feed is the route beneath it, so there is no inherited
/// widget, bloc or context that reaches from one to the other — the same
/// problem [CommentSheetScope] solves in the other direction, and solved the
/// same way.
///
/// It matters because the band above the sheet is deliberately live. The
/// sheet's barrier stops at its own top edge so the reader can keep swiping
/// the media while reading about it (see `allowMediaGestures`), and a vertical
/// swipe there does not page a carousel — it pages the *feed*. So the post
/// changed under a sheet that was still showing the previous post's thread,
/// title, input bar and like targets.
///
/// Published by the card that is in front, because that is the only widget
/// that knows both which post it holds and whether it is the one on screen.
/// The feeds themselves need no changes and cannot disagree with each other:
/// a card off-screen in an inactive tab is not in front and stays quiet.
class FeedActiveEvent {
  const FeedActiveEvent._();

  static final ValueNotifier<EventDiscovery?> _current =
      ValueNotifier<EventDiscovery?>(null);

  /// The post in front, or null before any card has claimed the position.
  ///
  /// Null is "nobody has said", not "no post" — a listener should hold what it
  /// has rather than blank itself.
  static ValueListenable<EventDiscovery?> get current => _current;

  /// Claims the front position for [event].
  ///
  /// Same-post claims are dropped rather than re-broadcast. Cards publish from
  /// their lifecycle callbacks, which fire for reasons that have nothing to do
  /// with the feed moving — a rebuild, a route change, a tab regaining its
  /// ticker — and each one would otherwise look to a listener like a swipe.
  static void publish(EventDiscovery event) {
    if (_current.value?.id == event.id) return;
    _current.value = event;
  }

  /// For tests, and for a sign-out that tears feeds down without unwinding
  /// them.
  @visibleForTesting
  static void reset() => _current.value = null;
}
