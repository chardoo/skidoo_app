import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/core/purchase/photo_price_badge.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// Horizontal thumbnail rail under the Found viewer.
///
/// The binding runs both ways:
///
///  * paging the photo above moves the strip, keeping the active thumb centred
///    so it always shows where you are;
///  * **dragging the strip changes the photo above** — whichever thumbnail is
///    under the centre becomes the one on screen, updating continuously as you
///    scrub rather than only when you let go, and snapping onto a thumb so it
///    can never rest between two.
///
/// The second direction is the one with a trap in it: the photo it selects is
/// fed back in as [activeIndex], which would ordinarily animate the strip back
/// to centre — against the finger still dragging it. [_scrubbing] suppresses
/// the auto-centre for exactly as long as the gesture owns the strip.
class FoundPhotoFilmstrip extends StatefulWidget {
  const FoundPhotoFilmstrip({
    super.key,
    required this.photos,
    required this.activeIndex,
    required this.onTap,
    this.onScrub,
  });

  final List<Photo> photos;
  final int activeIndex;

  /// A thumbnail was tapped — a deliberate jump, worth animating.
  final ValueChanged<int> onTap;

  /// The strip was dragged onto a new thumbnail. Fires continuously during the
  /// drag, so the photo above should change *without* animating through every
  /// page in between — the strip is already the animation.
  final ValueChanged<int>? onScrub;

  @override
  State<FoundPhotoFilmstrip> createState() => _FoundPhotoFilmstripState();
}

class _FoundPhotoFilmstripState extends State<FoundPhotoFilmstrip> {
  final _scrollCtrl = ScrollController();

  /// True while the user's own drag owns the strip. Auto-centring is off for
  /// the duration, or the selection this drag produces would fight it.
  bool _scrubbing = false;

  /// Last index reported from a scrub, so a change is only announced once per
  /// thumbnail rather than on every scroll frame.
  int? _lastScrubbed;

  /// Thumb width + trailing gap — also the scroll extent of one item, which
  /// is what centring maths needs.
  double get _itemExtent => 64.w + AppSpacing.sm.w;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _centreOnActive(animate: false));
  }

  @override
  void didUpdateWidget(FoundPhotoFilmstrip old) {
    super.didUpdateWidget(old);
    // Not while dragging: this change is almost certainly the one this drag
    // just caused, and centring on it would yank the strip out from under the
    // finger that is still moving it.
    if (old.activeIndex != widget.activeIndex && !_scrubbing) {
      _centreOnActive();
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Scroll offset that puts [index] under the centre of the viewport.
  double _offsetFor(int index) {
    final viewport = _scrollCtrl.position.viewportDimension;
    final target = (index * _itemExtent) - (viewport / 2) + (_itemExtent / 2);
    return target.clamp(0.0, _scrollCtrl.position.maxScrollExtent);
  }

  /// The thumbnail currently under the centre — the exact inverse of
  /// [_offsetFor], so scrubbing and centring can never disagree about which
  /// thumb an offset means.
  int _indexAtCentre() {
    final viewport = _scrollCtrl.position.viewportDimension;
    final raw =
        (_scrollCtrl.offset + (viewport / 2) - (_itemExtent / 2)) / _itemExtent;
    return raw.round().clamp(0, widget.photos.length - 1);
  }

  void _centreOnActive({bool animate = true}) {
    if (!_scrollCtrl.hasClients) return;
    final clamped = _offsetFor(widget.activeIndex);
    if (!animate) {
      _scrollCtrl.jumpTo(clamped);
      return;
    }
    _scrollCtrl.animateTo(
      clamped,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  bool _onScrollNotification(ScrollNotification n) {
    if (widget.onScrub == null || !_scrollCtrl.hasClients) return false;

    // `dragDetails != null` distinguishes a finger from our own animateTo —
    // without it, auto-centring would look like a scrub and select things on
    // its own.
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _scrubbing = true;
      _lastScrubbed = widget.activeIndex;
      return false;
    }

    if (n is ScrollUpdateNotification && _scrubbing) {
      final index = _indexAtCentre();
      if (index != _lastScrubbed) {
        _lastScrubbed = index;
        // The tick that makes this feel native rather than merely functional.
        HapticFeedback.selectionClick();
        widget.onScrub!(index);
      }
      return false;
    }

    if (n is ScrollEndNotification && _scrubbing) {
      _scrubbing = false;
      // Snap: a thumb must never be left straddling the centre, or the strip
      // stops saying which photo is showing.
      final index = _indexAtCentre();
      // Against `_lastScrubbed`, not `activeIndex`: the parent's rebuild from
      // the final ScrollUpdate has not necessarily landed yet, so activeIndex
      // can still read as the previous photo and this would announce the same
      // one twice.
      if (index != _lastScrubbed) {
        _lastScrubbed = index;
        widget.onScrub!(index);
      }
      _scrollCtrl.animateTo(
        _offsetFor(index),
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return SizedBox(
      height: 64.w,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: ListView.separated(
          controller: _scrollCtrl,
          scrollDirection: Axis.horizontal,
          // Momentum that decelerates like the platform expects; the snap on
          // ScrollEnd is what lands it on a thumb.
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
          itemCount: widget.photos.length,
          separatorBuilder: (_, __) => SizedBox(width: AppSpacing.sm.w),
          itemBuilder: (_, index) {
            final active = index == widget.activeIndex;
            return Semantics(
              button: true,
              selected: active,
              label: 'Photo ${index + 1}',
              child: GestureDetector(
                onTap: () => widget.onTap(index),
                child: Container(
                  width: 64.w,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.sm.r),
                    // Accent green, per the Found/PhotoSelected designs — not
                    // white. `accentGold` is #1D9E75 in both light and dark, so
                    // the ring needs no per-theme variant even though the strip
                    // around it does.
                    border: Border.all(
                      color: active ? ext.accentGold : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      JpergImage(
                        imageUrl: widget.photos[index].url,
                        fit: BoxFit.cover,
                        logicalWidth: 64,
                        placeholder: (_, __) => const JpergImagePlaceholder(),
                        errorWidget: (_, __, ___) =>
                            const JpergImagePlaceholder(),
                      ),
                      // Priced photos carry their amount here too, so scrubbing
                      // the strip shows which of them cost money without having
                      // to land on each one and read the pill.
                      if (widget.photos[index].price > 0 &&
                          !widget.photos[index].isPurchased)
                        Positioned(
                          left: 3.w,
                          bottom: 3.h,
                          child: PhotoPriceBadge(
                            price: widget.photos[index].price,
                            compact: true,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
