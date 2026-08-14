import 'package:flutter/material.dart';

/// A normal push that opts the destination out of the edge swipe-back gesture.
///
/// Every route in the app can be dragged back from the leading edge (see
/// `AppPageTransitionsBuilder`). That is right for a screen the user reads, and
/// wrong for a screen that is itself a horizontal pager: in a full-screen photo
/// viewer the leading 20 logical pixels would pop the whole viewer instead of
/// turning to the previous photo, so a thumb that lands slightly too far left
/// throws the user out of the gallery. iOS's own photo browser disables the
/// gesture for exactly this reason.
///
/// The route still animates like every other push, and still has its back
/// button and the system back gesture — only the drag is off.
class NoSwipeBackPageRoute<T> extends MaterialPageRoute<T> {
  NoSwipeBackPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  @override
  bool get popGestureEnabled => false;
}
