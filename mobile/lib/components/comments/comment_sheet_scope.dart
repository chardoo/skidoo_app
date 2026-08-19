import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

/// How much of the screen the comment sheet covers.
///
/// Lives here rather than inside the sheet because two widgets have to agree
/// on it: the sheet sizes itself to this, and [CommentPushArea] scales the page
/// into whatever is left. Split across two files they would drift, and the
/// symptom would be a photo sitting a little behind the sheet or floating a
/// little above it, which reads as a rounding bug rather than a shared
/// constant nobody updated.
const double kCommentSheetFraction = 0.72;

/// Whether a comment sheet is open, and the page-scaling that answers it.
///
/// The sheets are ordinary modal routes — they keep the back button,
/// `Navigator.pop`, and keyboard insets for free, none of which is worth
/// reimplementing. What they cannot do on their own is tell the page
/// underneath to get out of the way, because a route knows nothing about the
/// route below it. This is that channel: the sheet raises a flag on the way in
/// and drops it on the way out, and every [CommentPushArea] on screen reacts.
///
/// A counter rather than a bool. Sheets can legitimately overlap — a reply
/// sheet opened from a comment, a report sheet opened from a reply — and with
/// a bool the first one to close would drop the page back down while another
/// was still up.
class CommentSheetScope {
  const CommentSheetScope._();

  static final ValueNotifier<int> _openCount = ValueNotifier<int>(0);

  /// Listenable for [CommentPushArea]. Read [isOpen] for the answer.
  static ValueListenable<int> get openCount => _openCount;

  static bool get isOpen => _openCount.value > 0;

  static void _enter() => _openCount.value++;

  static void _exit() {
    // Never below zero: a hot reload or a sheet dismissed by a route pop we
    // did not observe would otherwise leave the count negative and the page
    // permanently unable to push again.
    _openCount.value = (_openCount.value - 1).clamp(0, 1 << 20);
  }

  /// Resets the count — for tests, and for a sign-out that tears down routes
  /// without unwinding them.
  @visibleForTesting
  static void reset() => _openCount.value = 0;
}

/// Shows a comment sheet, and tells the page underneath to make room.
///
/// Two differences from a plain `showModalBottomSheet`, and both are the
/// point:
///
///   * **No barrier colour.** The photo behind stays lit. Dimming it was
///     right when the sheet covered it anyway; now that the page scales up
///     into the strip above, the thing the user is reading comments about is
///     meant to be visible.
///   * **The scope flag**, so [CommentPushArea] knows to scale.
///
/// The flag is dropped in a `finally`, so it survives a sheet dismissed by a
/// swipe, the back button, a barrier tap, or an exception thrown while it was
/// open — all of which are routes popping without telling anyone.
Future<T?> showCommentSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) async {
  CommentSheetScope._enter();
  try {
    return await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      useSafeArea: true,
      builder: builder,
    );
  } finally {
    CommentSheetScope._exit();
  }
}

/// Scales its child into the strip above an open comment sheet.
///
/// The YouTube arrangement: the thing being discussed stays on screen, whole
/// and lit, while the discussion takes the space below it. Before this, the
/// sheet was a modal over a dimmed page — you could read the comments or look
/// at the photo, not both.
///
/// A paint-time [Transform], not a relayout. The child keeps its full size and
/// is drawn smaller, so a full-screen photo viewer does not rebuild its
/// carousel, its video player does not resize, and nothing reflows at 60 fps
/// while the sheet slides.
///
/// Scaled uniformly and anchored to the top, so nothing is cropped. A portrait
/// photo therefore ends up narrow with space either side — the alternative,
/// filling the width, would cut the top and bottom off the very thing the
/// comments are about.
class CommentPushArea extends StatelessWidget {
  const CommentPushArea({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 260),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  /// Fraction of its own height the child is drawn at when a sheet is open.
  ///
  /// Slightly less than the bare strip so the photo does not sit flush against
  /// the sheet's top edge, which reads as the two being one surface.
  static const double _openScale = (1 - kCommentSheetFraction) * 0.94;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CommentSheetScope.openCount,
      builder: (context, count, _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1, end: count > 0 ? _openScale : 1),
        duration: duration,
        curve: curve,
        builder: (context, scale, child) {
          // The common case, and the one that must cost nothing: no sheet
          // open, so no transform layer at all.
          if (scale == 1) return child!;
          return Transform.scale(
            scale: scale,
            alignment: Alignment.topCenter,
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}
