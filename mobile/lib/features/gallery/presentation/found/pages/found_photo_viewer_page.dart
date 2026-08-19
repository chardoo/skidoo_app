import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/widgets/image_aspect.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/dark_media_surface.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:jperg_app/core/purchase/photo_checkout.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_photo_actions.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_photo_filmstrip.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_selection_panel.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_review_prompt.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_photo_stage.dart';
import 'package:jperg_app/models/photos/Photo.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';

/// Full-screen viewer for an album's photos: "n of total" in the app bar, the
/// photo with its badge/action-rail/photographer overlays, and a filmstrip of
/// the whole album along the bottom. Swiping the photo and tapping a
/// thumbnail are two ways to drive the same index.
class FoundPhotoViewerPage extends StatefulWidget {
  const FoundPhotoViewerPage({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.onViewAlbum,
    this.showSocialActions = true,
    this.purchaseGated = false,
    this.selection,
    this.onCheckout,
    this.onIndexChanged,
    this.title,
  });

  final List<Photo> photos;
  final int initialIndex;

  /// The album's keep/discard selection, when the viewer was opened from one.
  ///
  /// Null from the other seven entry points — the Found feed, the discovery
  /// grid, a profile's liked and bookmarked grids, search, the request page,
  /// a shared `/p/{id}` link — and those used to get no Buy pill and no panel
  /// at all. A priced photo could be looked at there and not bought, which is
  /// the whole of what this screen is for. It makes its own now: see
  /// [_selection].
  final PhotoSelection? selection;

  /// Runs the album's checkout. The viewer delegates rather than repeating it,
  /// so free-saving and payment have exactly one implementation — see
  /// FoundAlbumPage._checkout. Null when the viewer owns the selection, in
  /// which case it runs the same shared checkout itself.
  final VoidCallback? onCheckout;

  /// The event name for the app bar. When given, the "n of total" counter
  /// moves off the bar and onto the photo as a pill, per the design — the bar
  /// names *where you are* and the pill says *where you are in it*. Null keeps
  /// the older layout for the callers that have no album to name.
  final String? title;

  /// Whether to offer the like/comment/save/share rail. False where the photos
  /// are someone's work on show rather than photos of you — see
  /// [FoundPhotoStage.showSocialActions].
  final bool showSocialActions;

  /// Whether the rail's contents follow the photo's price and visibility.
  ///
  /// True only for the two Found-you entry points — the Found feed and a Found
  /// album — where a photo is of the viewer and may be one they have not paid
  /// for. The other six callers show someone's work rather than photos of the
  /// viewer, there is nothing for them to have bought, and their rail is
  /// unchanged. See [FoundPhotoActions].
  final bool purchaseGated;

  /// Shown as "View album" on the photo. Left null when the viewer was pushed
  /// from the album page itself.
  ///
  /// Takes the photo it was pressed on, because one viewer can span several
  /// events — see FoundResultsViewerPage. A fixed callback would send the
  /// person to the album of whichever photo they happened to open at.
  final ValueChanged<Photo>? onViewAlbum;

  /// Fires as the pager settles on each photo. Used by the results viewer to
  /// fetch the next page before the swiping reaches the end of what it has.
  final ValueChanged<int>? onIndexChanged;

  @override
  State<FoundPhotoViewerPage> createState() => _FoundPhotoViewerPageState();
}

class _FoundPhotoViewerPageState extends State<FoundPhotoViewerPage> {
  late int _index = widget.initialIndex.clamp(0, widget.photos.length - 1);
  late final PageController _pageCtrl = PageController(initialPage: _index);

  /// The one this viewer owns, when it was not handed one. Browsing rather
  /// than reviewing: nothing is selected until Buy is pressed.
  ///
  /// It lives and dies with this screen. There is no basket anywhere in the
  /// app — you buy the photos you are looking at, from where you are looking
  /// at them, and closing the screen ends it.
  PhotoSelection? _ownSelection;

  /// Whichever is in play. The album's when it came from one, so a photo
  /// bought here is already ticked back on the grid; otherwise this screen's.
  PhotoSelection get _selection =>
      widget.selection ??
      (_ownSelection ??= PhotoSelection(photos: widget.photos));

  bool _checkingOut = false;

  @override
  void didUpdateWidget(FoundPhotoViewerPage old) {
    super.didUpdateWidget(old);
    if (identical(old.photos, widget.photos)) return;

    _ownSelection?.updatePhotos(widget.photos);

    // The list can be replaced under the viewer: the results viewer opens on
    // the photos the grid had and swaps in the server's full result set when
    // it arrives. Follow the photo being looked at rather than the slot it
    // happened to occupy — the two lists are ordered differently, so holding
    // the index would silently change which picture is on screen.
    if (old.photos.isEmpty || widget.photos.isEmpty) return;
    final current = old.photos[_index.clamp(0, old.photos.length - 1)].id;
    final moved = widget.photos.indexWhere((p) => p.id == current);
    if (moved < 0 || moved == _index) return;

    _index = moved;
    // The controller cannot be jumped mid-build; the pager has not been laid
    // out against the new list yet either.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pageCtrl.hasClients) _pageCtrl.jumpToPage(moved);
    });
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _ownSelection?.dispose();
    super.dispose();
  }

  /// Pay for what is selected.
  ///
  /// An album hands its own [FoundPhotoViewerPage.onCheckout] down, because it
  /// owns the listener that pushes the payment screen and this route would be
  /// stranded behind it. With no album there is nothing to go back to, so the
  /// same shared checkout runs here.
  Future<void> _checkout() async {
    if (widget.onCheckout != null) {
      Navigator.of(context).pop();
      widget.onCheckout!.call();
      return;
    }
    setState(() => _checkingOut = true);
    try {
      await runPhotoCheckout(context, _selection);
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  void _goTo(int index) {
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  /// The filmstrip is being dragged: follow it immediately.
  ///
  /// Jumps rather than animates. A scrub can cross many photos in one gesture,
  /// and animating each step would queue transitions the finger has already
  /// moved past — the photo would lag behind the strip and then race to catch
  /// up. The strip's own movement is the animation.
  void _scrubTo(int index) {
    if (!_pageCtrl.hasClients || index == _index) return;
    _pageCtrl.jumpToPage(index);
  }

  /// Dark in a light app as well: the photo is the whole point of this screen,
  /// and the surround's job is to get out of its way. It is also most of the
  /// screen — the media is boxed to its own shape — and the overlays that sit
  /// *on* it (badge, action rail, meta bar) are white-on-scrim for an arbitrary
  /// photo underneath, which a pale surround undercuts.
  @override
  Widget build(BuildContext context) =>
      DarkMediaSurface(child: Builder(builder: _buildViewer));

  /// Answer the "is this your photo?" prompt for the photo on screen.
  ///
  /// Yes leaves it selected, No takes the tick off — the same state the grid's
  /// "Not me" tile shows, and the same state the total below is counted from.
  /// Either way it moves on, because the question has been answered and
  /// staring at the same photo is not the next thing anyone wants.
  void _answerReview({required bool mine}) {
    final selection = widget.selection;
    if (selection == null) return;
    final photo = widget.photos[_index];

    if (selection.isSelected(photo.id) != mine) selection.toggle(photo.id);

    if (_index < widget.photos.length - 1) {
      _goTo(_index + 1);
    } else {
      // The last one. Back to the grid, where the bar totals what survived.
      Navigator.of(context).pop();
    }
  }

  Widget _buildViewer(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final total = widget.photos.length;
    final selection = widget.selection;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Column(
          children: [
            _ViewerTopBar(index: _index, total: total, title: widget.title),
            // Review mode only: recognition proposed this photo and the person
            // is confirming it. Above the image, not over it — the answer
            // depends on seeing the whole frame.
            if (selection != null &&
                selection.reviewMode &&
                widget.photos[_index].isPendingReview) ...[
              SizedBox(height: AppSpacing.sm.h),
              FoundReviewPrompt(
                onYes: () => _answerReview(mine: true),
                onNo: () => _answerReview(mine: false),
              ),
              SizedBox(height: AppSpacing.sm.h),
            ],
            _buildMedia(total),
            if (total > 1) ...[
              SizedBox(height: AppSpacing.lg.h),
              FoundPhotoFilmstrip(
                photos: widget.photos,
                activeIndex: _index,
                onTap: _goTo,
                onScrub: _scrubTo,
              ),
            ],
            // Present in every flow now, not only when an album handed one
            // down. It draws nothing until something priced is selected, so a
            // free album or a photo nobody has pressed Buy on looks exactly as
            // it did.
            PhotoCheckoutListener(
              onSuccess: _selection.clear,
              child: FoundSelectionPanel(
                selection: _selection,
                isBusy: _checkingOut,
                onCheckout: _checkout,
              ),
            ),
          ],
        ),
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }

  /// The pager: centred in the space between the top bar and the filmstrip,
  /// and exactly as tall as the current photo needs.
  ///
  /// Two separate things, and both matter. The media sits in the middle of the
  /// page — that is the design, and it is what makes a wide shot and a tall one
  /// feel like the same screen. But its *height* is the image's own
  /// (`width ÷ aspect ratio`) rather than every pixel the column had left, so
  /// the pager's bounds are the photo's bounds: the overlays hang off the
  /// image's edges, swipes and taps land on the photo rather than on empty
  /// background, and a page of an unknown shape can't be handed a fixed slab.
  ///
  /// [Expanded] + [Center] is what centres it; the inner [SizedBox] is what
  /// keeps it the photo's size. The height is capped at what is actually
  /// available so a tall portrait fills the screen instead of overflowing,
  /// without this having to know what the top bar and filmstrip cost.
  Widget _buildMedia(int total) {
    final photo = widget.photos[_index];

    return Expanded(
      child: Center(
        child: ResolvedAspect(
          imageUrl: photo.url,
          knownAspect: photo.aspectRatio,
          builder: (context, aspect) => LayoutBuilder(
            builder: (context, constraints) {
              final natural = constraints.maxWidth / aspect;
              return AnimatedSize(
                // Pages differ in shape, and onPageChanged fires as the swipe
                // crosses the midpoint — without this the media would jump
                // under the user's thumb.
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: SizedBox(
                  // Width is pinned as well as height: [Center] passes loose
                  // constraints, which would leave the pager unbounded.
                  width: constraints.maxWidth,
                  height: math.min(natural, constraints.maxHeight),
                  child: PageView.builder(
                    controller: _pageCtrl,
                    itemCount: total,
                    onPageChanged: (i) {
                      setState(() => _index = i);
                      widget.onIndexChanged?.call(i);
                    },
                    itemBuilder: (_, i) => FoundPhotoStage(
                      key: ValueKey('stage_${widget.photos[i].id}'),
                      photo: widget.photos[i],
                      isActive: i == _index,
                      onViewAlbum: widget.onViewAlbum == null
                          ? null
                          : () => widget.onViewAlbum!(widget.photos[i]),
                      showSocialActions: widget.showSocialActions,
                      purchaseGated: widget.purchaseGated,
                      // The one in play, not only an album's: this is what puts
                      // the Buy pill on a priced photo whichever screen opened
                      // the viewer.
                      selection: _selection,
                      // Only when the bar has taken the title — otherwise the
                      // counter is still up there and two would disagree.
                      counter:
                          widget.title == null ? null : '${i + 1} of $total',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ViewerTopBar extends StatelessWidget {
  const _ViewerTopBar({
    required this.index,
    required this.total,
    this.title,
  });

  final int index;
  final int total;

  /// The album's name. When present it takes the centre and the counter moves
  /// onto the photo — see [FoundPhotoViewerPage.title].
  final String? title;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final title = this.title;
    if (title != null) {
      return SizedBox(
        height: 48.h,
        child: Row(
          children: [
            const AppBackButton(),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            // Balances the back button so the title sits truly centred, and
            // holds the place the design gives the overflow menu. Nothing is
            // wired to it yet — an enabled button that does nothing is worse
            // than one that reads as unavailable.
            IconButton(
              onPressed: null,
              icon: Icon(
                Icons.more_vert_rounded,
                size: 20.sp,
                color: ext.greetingColor.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 48.h,
      child: Stack(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: AppBackButton(),
          ),
          Center(
            // One label for the whole counter. Split across spans it reads out as
            // "1", "of", "2" — three fragments — and the WidgetSpan leaves a
            // placeholder character in the middle of the plain text.
            child: Semantics(
              label: '${index + 1} of $total',
              child: ExcludeSemantics(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: ext.greetingColor.withValues(alpha: 0.7),
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      height: 1.0,
                      leadingDistribution: TextLeadingDistribution.even,
                    ),
                    children: [
                      TextSpan(
                        text: '${index + 1}',
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: Transform.translate(
                          offset:
                              Offset(0, 1), // positive = down; tweak by 0.5–1.5
                          child: Text(
                            ' of ',
                            style: TextStyle(
                              fontWeight: FontWeight.w400,
                              fontSize: 15.sp,
                              color: ext.greetingColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                      TextSpan(
                        text: '$total',
                        style: const TextStyle(
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
