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
///
/// Measured off the design frame: the sheet's top edge sits at 62.7 % of the
/// screen, leaving the media 37.3 %. It was 0.72, which left the media 28 % —
/// a third short, and enough that a landscape photo read as a letterbox strip
/// rather than as the thing being discussed.
const double kCommentSheetFraction = 0.70;

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
///
/// Each open sheet is held *with the route it was opened over*, and that is
/// not bookkeeping — it is what keeps the push local. The flag is global, the
/// sheet is not: a sheet left open on a page below, or in a tab the user
/// switched away from, used to squeeze the media on every screen pushed
/// afterwards. A photo opened from an album came up laid out into the 30 %
/// band the sheet leaves — a portrait shot at 190 × 253 in the top third of
/// the screen, with the rest black. Only the page the sheet is actually over
/// has anything to make room for; see [isOpenOver].
class CommentSheetScope {
  const CommentSheetScope._();

  /// The host route of each open sheet, in the order they opened. Null for a
  /// sheet opened from a context with no [ModalRoute] above it, which is
  /// treated as "over everything" — the old behaviour, and the only safe
  /// reading when there is no route to compare against.
  static final List<Route<dynamic>?> _hosts = <Route<dynamic>?>[];

  static final ValueNotifier<int> _openCount = ValueNotifier<int>(0);

  /// Listenable for [CommentPushArea]. Read [isOpen] for the answer.
  static ValueListenable<int> get openCount => _openCount;

  static bool get isOpen => _openCount.value > 0;

  /// Whether an open sheet is sitting over [route] — the question a
  /// [CommentPushArea] actually has to answer before it gives up two thirds of
  /// its height.
  static bool isOpenOver(Route<dynamic>? route) {
    if (_hosts.isEmpty) return false;
    if (route == null) return true;
    return _hosts.any((host) => host == null || identical(host, route));
  }

  static void _enter(Route<dynamic>? host) {
    _hosts.add(host);
    _openCount.value = _hosts.length;
  }

  static void _exit(Route<dynamic>? host) {
    final index = _hosts.indexWhere((entry) => identical(entry, host));
    // Never below zero, and never the wrong entry: a hot reload or a sheet
    // dismissed by a route pop we did not observe would otherwise leave the
    // count negative and the page permanently unable to push again.
    if (index >= 0) {
      _hosts.removeAt(index);
    } else if (_hosts.isNotEmpty) {
      _hosts.removeLast();
    }
    _openCount.value = _hosts.length;
  }

  /// Resets the count — for tests, and for a sign-out that tears down routes
  /// without unwinding them.
  @visibleForTesting
  static void reset() {
    _hosts.clear();
    _openCount.value = 0;
  }
}

/// Shows a comment sheet, and tells the page underneath to make room.
///
/// Three differences from a plain `showModalBottomSheet`, and all three are
/// the point:
///
///   * **No barrier colour.** The photo behind stays lit. Dimming it was
///     right when the sheet covered it anyway; now that the page scales up
///     into the strip above, the thing the user is reading comments about is
///     meant to be visible.
///   * **The barrier stops at the sheet**, when [allowMediaGestures] says so.
///     A modal barrier spans the whole screen and swallows every gesture that
///     lands on it, colour or no colour — so the media in the strip was a
///     picture of a carousel rather than a carousel. See
///     [_PassThroughBottomSheetRoute].
///   * **The scope flag**, so [CommentPushArea] knows to push.
///
/// The flag is raised and dropped by the route itself, not around the `await`
/// here — see [_PassThroughBottomSheetRoute.install]. Awaiting covers a sheet
/// dismissed by a swipe, the back button or a barrier tap, because all of
/// those pop it; it does not cover a route *removed* without its future ever
/// completing — a navigator torn down with the sheet still on it, a stack
/// replaced under it — and a flag left raised there is permanent. It squeezes
/// the media on every screen opened afterwards, on a page that has no sheet
/// anywhere near it.
Future<T?> showCommentSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool allowMediaGestures = true,
}) {
  return Navigator.of(context).push(
    _PassThroughBottomSheetRoute<T>(
      builder: builder,
      allowMediaGestures: allowMediaGestures,
      // The page this sheet is being opened over, so the push stays on it. Read
      // here rather than in the route: this context is inside the page, the
      // navigator's is not.
      host: ModalRoute.of(context),
      // Themes do not cross a route boundary on their own, and this is
      // pushed by hand rather than by showModalBottomSheet.
      capturedThemes: InheritedTheme.capture(
          from: context, to: Navigator.of(context).context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      modalBarrierColor: Colors.transparent,
      useSafeArea: true,
    ),
  );
}

/// A bottom sheet whose modal barrier covers only the sheet, leaving the strip
/// above it live.
///
/// A [ModalRoute]'s barrier is a full-screen gesture sink: it wins the arena
/// for every pointer that touches it, which is what makes a modal modal. That
/// is wrong for this one. The media pushed into the band above the sheet is
/// still the subject of the conversation — the reader has to be able to swipe
/// through a post's photos while reading about them, the way they could before
/// the sheet went up. With a full-screen barrier those swipes never reached the
/// carousel and the band behaved like a screenshot of one.
///
/// So the barrier is inset to start where the sheet does. Below that line it is
/// unchanged, including tap-to-dismiss; above it, pointers fall through to the
/// page. Tapping the media therefore no longer closes the sheet, which is also
/// what the arrangement implies: the photo is part of what you are looking at,
/// not "outside" the sheet.
class _PassThroughBottomSheetRoute<T> extends ModalBottomSheetRoute<T> {
  _PassThroughBottomSheetRoute({
    required super.builder,
    required super.isScrollControlled,
    this.allowMediaGestures = true,
    this.host,
    super.capturedThemes,
    super.backgroundColor,
    super.modalBarrierColor,
    super.useSafeArea,
  });

  /// The route this sheet was opened over — the one page that has to make
  /// room. See [CommentSheetScope.isOpenOver].
  final Route<dynamic>? host;

  /// Whether this route is currently counted as open, so the pair can never
  /// run twice in either direction.
  bool _counted = false;

  /// The flag goes up when the route is installed and comes down the moment
  /// the sheet is finished with, so the page drops back as the sheet animates
  /// away rather than a beat after it has gone.
  @override
  void install() {
    super.install();
    _counted = true;
    CommentSheetScope._enter(host);
  }

  @override
  void didComplete(T? result) {
    _dropFlag();
    super.didComplete(result);
  }

  /// The backstop, and the reason the flag is on the route at all: `dispose`
  /// is the one call the navigator makes on every way out, including the ones
  /// that never complete the route — a stack replaced under the sheet, a
  /// navigator torn down with it still on top.
  @override
  void dispose() {
    _dropFlag();
    super.dispose();
  }

  void _dropFlag() {
    if (!_counted) return;
    _counted = false;
    CommentSheetScope._exit(host);
  }

  /// Whether the band above the sheet takes gestures.
  ///
  /// True on a **feed**, where the sheet is about a post and the band holds
  /// that post's carousel: swiping between its photos while reading about them
  /// is the point, and every photo swiped to is still one the comments are
  /// about.
  ///
  /// False in a **viewer**, where the sheet is about one specific picture id.
  /// The viewer is a `PageView` of unrelated photos, so a swipe there would
  /// leave the reader looking at photo B under photo A's comments — a sheet
  /// captioning the wrong image, with a like button wired to the wrong id. The
  /// band stays a full barrier there, which is the pre-existing behaviour.
  final bool allowMediaGestures;

  @override
  Widget buildModalBarrier() {
    final barrier = super.buildModalBarrier();
    if (!allowMediaGestures) return barrier;
    return Builder(
      builder: (context) => Padding(
        // The band the sheet leaves — the same fraction the sheet sizes itself
        // from, so the barrier's top edge and the sheet's are the same line.
        padding: EdgeInsets.only(
          top: MediaQuery.sizeOf(context).height * (1 - kCommentSheetFraction),
        ),
        child: barrier,
      ),
    );
  }
}

/// Pushes its child up into the strip above an open comment sheet.
///
/// The YouTube arrangement: the thing being discussed stays on screen, whole
/// and lit, while the discussion takes the space below it. Before this, the
/// sheet was a modal over a dimmed page — you could read the comments or look
/// at the photo, not both.
///
/// The child is **laid out into** the strip — given its width and its height,
/// anchored to the top — so the media fills that band the way it filled the
/// screen. This used to be a uniform `Transform.scale` to ~26 %, which shrank
/// the width along with the height and left a thumbnail-sized photo marooned
/// in the middle of a wide empty band.
///
/// [OverflowBox] rather than a `SizedBox`, and that is not interchangeable:
/// these wrap cards inside a `PageView`, whose pages carry **tight**
/// constraints, and under a tight constraint a box cannot make itself shorter
/// than its parent says. A `SizedBox` silently does nothing there. `OverflowBox`
/// keeps its own full-screen size — which is fine, the sheet covers the rest —
/// and re-constrains its *child* to the strip, which is the part that has to
/// happen for the media to fill it.
///
/// See [fillsBand] for the children that cannot take that constraint.
class CommentPushArea extends StatelessWidget {
  const CommentPushArea({
    super.key,
    required this.child,
    this.fillsBand = true,
    this.duration = const Duration(milliseconds: 260),
    this.curve = Curves.easeOutCubic,
  });

  final Widget child;

  /// Whether [child] can be laid out at the strip's height.
  ///
  /// True for a media-shaped child — a `Stack` of a full-bleed photo and its
  /// overlays, which fills whatever box it is given. That is the arrangement
  /// the designs draw, and the reason this widget exists.
  ///
  /// False for a **column-shaped** card: header, then media, then a reaction
  /// bar. A `Column` does not shrink to fit, so handing one a strip-height box
  /// overflows it — black-and-yellow stripes in debug, silently clipped in
  /// release — and clipping the outside does not help, because the `RenderFlex`
  /// reports the overflow itself. Those children keep their natural height and
  /// are clipped to the band instead: the media still ends up in the strip, it
  /// is just showing the top of a full-size card rather than a card refitted to
  /// the band.
  final bool fillsBand;

  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;
    // What the sheet leaves. Measured off the screen, the same thing the sheet
    // sizes itself from — not off this widget's own box, which may be an inch
    // of a scrolling card.
    final strip = screenH * (1 - kCommentSheetFraction);

    // The page this media is on. A sheet open over some *other* page is none
    // of its business: the flag is global, the sheet is one route deep, and
    // reading the count alone laid every later screen's media into the band
    // behind a sheet nobody could see. See [CommentSheetScope.isOpenOver].
    final host = ModalRoute.of(context);

    return ValueListenableBuilder<int>(
      valueListenable: CommentSheetScope.openCount,
      builder: (context, count, _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(
            begin: screenH,
            end: count > 0 && CommentSheetScope.isOpenOver(host)
                ? strip
                : screenH),
        duration: duration,
        curve: curve,
        builder: (context, height, child) {
          // The common case, and the one that must cost nothing: no sheet
          // open, so no extra box at all.
          if (height >= screenH) return child!;

          if (!fillsBand) {
            return ClipRect(
              clipper: _TopBandClipper(height),
              child: child,
            );
          }

          return ClipRect(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              // Tight, so the child fills the band rather than sitting in it.
              minHeight: height,
              maxHeight: height,
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

/// Clips to a band across the top of the box, whatever the box's own height.
///
/// Used for the children that cannot be relaid out into the strip — see
/// [CommentPushArea.fillsBand]. Clamped to the box, so a child shorter than the
/// band is left alone rather than clipped to a rect bigger than itself.
class _TopBandClipper extends CustomClipper<Rect> {
  const _TopBandClipper(this.height);

  final double height;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, height.clamp(0.0, size.height));

  @override
  bool shouldReclip(_TopBandClipper oldClipper) => oldClipper.height != height;
}

/// Hides its child while a comment sheet is open.
///
/// For the engagement rail and the rest of the chrome layered over the media —
/// the reaction column, the caption, the gradient scrim under it. They act on
/// the post, and once the post is a band at the top of the screen a like button
/// floating over it is chrome for a screen the reader has left. The designs
/// draw that band as media and nothing else.
///
/// Fades rather than cuts, on the same curve as [CommentPushArea], so the
/// controls leave with the push instead of blinking out ahead of it. Kept in
/// the tree at zero opacity and ignoring pointers: removing it outright would
/// relayout the stack it sits in, mid-animation.
class CommentSheetHide extends StatelessWidget {
  const CommentSheetHide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOut,
  });

  final Widget child;
  final Duration duration;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: CommentSheetScope.openCount,
      builder: (context, count, _) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 1, end: count > 0 ? 0 : 1),
        duration: duration,
        curve: curve,
        builder: (context, opacity, child) => IgnorePointer(
          ignoring: opacity < 0.5,
          child: Opacity(opacity: opacity, child: child),
        ),
        child: child,
      ),
    );
  }
}
