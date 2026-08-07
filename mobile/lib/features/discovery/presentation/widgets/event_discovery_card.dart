import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/components/media/media_action_buttons.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/common/widgets/get_app_sheet.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/animations/app_animations.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/pages/event_pictures_page.dart';
import 'package:jperg_app/features/discovery/presentation/utils/open_photographer_profile.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/card_interaction_bar.dart'
    show CardInteractionBar;
import 'package:jperg_app/features/discovery/presentation/widgets/card_description_text.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:jperg_app/features/discovery/presentation/pages/event_comment_page.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_card/carousel_arrow.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_card/heart_burst.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_card/image_footer.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_card/page_dots.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_card/post_header.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_card/unauth_cta.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_card/web_reactions_column.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_more_options_sheet.dart';
import 'package:jperg_app/features/gallery/presentation/widgets/gallery_share_sheet.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';

/// Width of the main content column on web — must match app.dart's _kWebColumnWidth.
const double _kWebColumnWidth = 480.0;

class EventDiscoveryCard extends StatefulWidget {
  const EventDiscoveryCard({
    super.key,
    required this.event,
    required this.onTap,
    this.isAuthenticated = false,
    this.isOwner = false,
    this.onCommentTap,
    this.cardIndex = 0,
    this.activeCardIndex,
    this.webCommentsOpen,
    this.onHide,
  });

  final EventDiscovery event;
  final VoidCallback onTap;
  final bool isAuthenticated;
  final bool isOwner;
  final VoidCallback? onCommentTap;

  /// Position of this card in the feed list.
  final int cardIndex;

  /// Shared notifier; its value is the currently active card index.
  /// When null the card is treated as always active (e.g. discovery page).
  final ValueNotifier<int>? activeCardIndex;

  /// Web desktop/laptop only: feed-level "comments open" flag shared by every
  /// card, so that opening comments stays open as the user scrolls between
  /// cards (each card then shows its own event's thread). Null on mobile, where
  /// the per-card local flag is used instead.
  final ValueNotifier<bool>? webCommentsOpen;

  /// Called when the user hides this event from their feed.
  final VoidCallback? onHide;

  @override
  State<EventDiscoveryCard> createState() => _EventDiscoveryCardState();
}

// Minimum media area height — tall enough for all 5 reaction buttons to fit
// beside the image without overflowing into the next card.
const double _kMinMediaHeight = 380.0;

class _EventDiscoveryCardState extends State<EventDiscoveryCard>
    with SingleTickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _currentPage = 0;
  int _maxRevealedPage = 0;
  // Web: true while the pointer is over the media — reveals the prev/next arrows.
  bool _mediaHovered = false;
  bool _liked = false;
  bool _disliked = false;
  int _likeCount = 0;
  int _dislikeCount = 0;
  bool _descExpanded = false;
  bool _showHeartBurst = false;
  // Whether the inline comment panel is open (replaces reactions col).
  // On web desktop/laptop this is driven by the shared feed-level notifier
  // ([widget.webCommentsOpen]) so the state carries across cards as you scroll;
  // on mobile it falls back to this local flag.
  bool _localCommentsOpen = false;
  bool get _useSharedComments => kIsWeb && widget.webCommentsOpen != null;
  bool get _webCommentsOpen =>
      _useSharedComments ? widget.webCommentsOpen!.value : _localCommentsOpen;
  // Rendering gate: comments only show on the active/focused card, so inactive
  // cards in the feed stay closed even while the shared flag is open. When the
  // user scrolls on, the new active card opens its own thread (flag persists).
  bool get _commentsVisible => _webCommentsOpen && _isFocused;
  void _setCommentsOpen(bool value) {
    if (_useSharedComments) {
      widget.webCommentsOpen!.value = value; // listener rebuilds every card
    } else {
      setState(() => _localCommentsOpen = value);
    }
  }

  void _onSharedCommentsChanged() {
    if (mounted) setState(() {});
  }

  late final AnimationController _heartCtrl;

  // Stored so we can safely dispatch from dispose() without using context.
  DiscoveryBloc? _discoveryBloc;

  // Canonical aspect ratio (width ÷ height) for the whole card, computed once
  // per event from the *tallest* image so every slide renders in an identical
  // frame. Null when no media has known dimensions (legacy records).
  double? _frameAspectRatio;

  // Auto-scroll through the carousel while this card is the focused one.
  Timer? _autoScroll;
  // Set true around a programmatic page change so the page listener can tell
  // auto-advances apart from real user swipes.
  bool _isAutoAdvancing = false;
  // When the user last swiped manually — auto-scroll pauses for one interval
  // after a manual swipe so it doesn't fight the user.
  DateTime? _lastManualSwipe;
  static const _kAutoScrollInterval = Duration(seconds: 4);

  void _syncReactionFromEvent(EventDiscovery event) {
    _liked = event.userReaction == 'like';
    _disliked = event.userReaction == 'dislike';
    _likeCount = event.likes;
    _dislikeCount = event.dislikes;
  }

  bool _isSaved(BuildContext context) {
    try {
      return context
          .read<DiscoveryBloc>()
          .state
          .savedEventIds
          .contains(widget.event.id);
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _syncReactionFromEvent(widget.event);
    _frameAspectRatio = _computeFrameAspectRatio();
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) {
          setState(() => _showHeartBurst = false);
          _heartCtrl.reset();
        }
      });
    _pageCtrl.addListener(() {
      final page = _pageCtrl.page?.round() ?? 0;
      if (page != _currentPage && mounted) {
        // A page change that wasn't triggered by our own animateToPage is a
        // real user swipe — pause auto-scroll briefly so it doesn't fight them.
        if (!_isAutoAdvancing) _lastManualSwipe = DateTime.now();
        setState(() {
          _currentPage = page;
          if (page > _maxRevealedPage) _maxRevealedPage = page;
        });
      }
    });
    // Restart/stop auto-scroll as feed focus moves between cards.
    widget.activeCardIndex?.addListener(_onActiveCardChanged);
    // Rebuild when the shared "comments open" flag flips (web desktop/laptop),
    // so this card opens/closes its own thread in step with the feed.
    widget.webCommentsOpen?.addListener(_onSharedCommentsChanged);
    // Notify the bloc that this card is now visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _discoveryBloc = context.read<DiscoveryBloc>();
      _discoveryBloc?.add(DiscoveryEventVisible(widget.event.id));
      if (_isFocused) _startAutoScroll();
    });
  }

  @override
  void didUpdateWidget(EventDiscoveryCard old) {
    super.didUpdateWidget(old);
    // Sync when server-confirmed reaction data arrives for this event.
    if (old.event.id != widget.event.id ||
        old.event.likes != widget.event.likes ||
        old.event.dislikes != widget.event.dislikes ||
        old.event.userReaction != widget.event.userReaction) {
      setState(() => _syncReactionFromEvent(widget.event));
    }
    // Recompute the canonical frame when the card is rebound to a new event.
    if (old.event.id != widget.event.id) {
      _frameAspectRatio = _computeFrameAspectRatio();
      _lastManualSwipe = null;
    }
    // Re-subscribe if the feed swapped the focus notifier instance.
    if (old.activeCardIndex != widget.activeCardIndex) {
      old.activeCardIndex?.removeListener(_onActiveCardChanged);
      widget.activeCardIndex?.addListener(_onActiveCardChanged);
      // Don't setState here — didUpdateWidget is already inside a build.
      _applyAutoScrollForActive();
    }
    if (old.webCommentsOpen != widget.webCommentsOpen) {
      old.webCommentsOpen?.removeListener(_onSharedCommentsChanged);
      widget.webCommentsOpen?.addListener(_onSharedCommentsChanged);
    }
  }

  @override
  void dispose() {
    // Notify the bloc that this card has left the viewport.
    _discoveryBloc?.add(DiscoveryEventHidden(widget.event.id));
    _stopAutoScroll();
    widget.activeCardIndex?.removeListener(_onActiveCardChanged);
    widget.webCommentsOpen?.removeListener(_onSharedCommentsChanged);
    _heartCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  // ── Media height ──────────────────────────────────────────────────────────

  /// Computes the media area height from server-supplied dimensions.
  ///
  /// Uses [EventPicture.aspectRatio] (derived from backend width/height) so
  /// the card renders at the correct height on the very first frame — no
  /// async image decode needed.
  ///
  /// A minimum of [_kMinMediaHeight] ensures the reactions column always fits
  /// beside the image without overflowing into the next card, even for wide
  /// landscape shots that would otherwise produce a very short media area.
  double _computeMediaHeight(double availableWidth, double screenHeight) {
    // One fixed height for the whole card — independent of which slide is
    // showing — so the frame never resizes as the user (or auto-scroll) swipes.
    final ar = _frameAspectRatio;
    if (ar != null && ar > 0) {
      return (availableWidth / ar).clamp(_kMinMediaHeight, screenHeight * 0.92);
    }

    // Fallback for events whose media lack server dimensions: 4:5 portrait.
    return (availableWidth / 0.8).clamp(_kMinMediaHeight, screenHeight * 0.88);
  }

  /// Canonical aspect ratio for the card: the *smallest* ratio (= tallest
  /// image) among the event's media, so every slide fits within the frame
  /// without top/bottom cropping. Shorter/wider images are pillarboxed and the
  /// carousel's blurred background fills the gap. Null when no media has dims.
  double? _computeFrameAspectRatio() {
    double? minAr;
    for (final p in widget.event.pictures) {
      final ar = p.aspectRatio;
      if (ar != null && ar > 0 && (minAr == null || ar < minAr)) {
        minAr = ar;
      }
    }
    return minAr;
  }

  // ── Auto-scroll ────────────────────────────────────────────────────────────

  /// True when this card is the one the feed is currently focused on (or when
  /// there's no focus notifier, i.e. single-card contexts).
  bool get _isFocused =>
      widget.activeCardIndex == null ||
      widget.activeCardIndex!.value == widget.cardIndex;

  // Listener for activeCardIndex changes (fired outside build). Applies the
  // auto-scroll side effect, then rebuilds so the comments gate
  // (_commentsVisible) re-evaluates: a card that just became inactive hides its
  // panel, and the new active card shows its own thread when the flag is open.
  void _onActiveCardChanged() {
    if (!mounted) return;
    _applyAutoScrollForActive();
    setState(() {});
  }

  // Auto-scroll only — safe to call during build (e.g. from didUpdateWidget).
  void _applyAutoScrollForActive() {
    if (_isFocused) {
      _startAutoScroll();
    } else {
      _stopAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScroll?.cancel();
    // Only auto-scroll real, multi-image carousels for signed-in users (the
    // unauth teaser caps at 3 slides and ends on a locked overlay).
    if (!widget.isAuthenticated || _visibleCount <= 1) return;
    _autoScroll = Timer.periodic(_kAutoScrollInterval, (_) => _autoTick());
  }

  void _stopAutoScroll() {
    _autoScroll?.cancel();
    _autoScroll = null;
  }

  void _autoTick() {
    if (!mounted || !_isFocused || !_pageCtrl.hasClients) return;
    final count = _visibleCount;
    if (count <= 1) return;
    final pics = widget.event.pictures;
    final idx = _currentPage.clamp(0, pics.length - 1);
    // Pause on a video slide so the user can watch it.
    if (idx < pics.length && pics[idx].isVideo) return;
    // Hold off for one interval after a manual swipe.
    if (_lastManualSwipe != null &&
        DateTime.now().difference(_lastManualSwipe!) < _kAutoScrollInterval) {
      return;
    }
    final next = (_currentPage + 1) % count;
    _isAutoAdvancing = true;
    _pageCtrl
        .animateToPage(next,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOut)
        .whenComplete(() => _isAutoAdvancing = false);
  }

  void _handleDoubleTap() {
    HapticFeedback.lightImpact();
    final wasLiked = _liked;
    setState(() {
      if (!_liked) {
        _liked = true;
        _likeCount++;
        if (_disliked) {
          _disliked = false;
          _dislikeCount = (_dislikeCount - 1).clamp(0, 999999999);
        }
      }
      _showHeartBurst = true;
    });
    _heartCtrl.forward(from: 0);
    if (!wasLiked) {
      context.read<DiscoveryBloc>().add(
            DiscoveryReactionToggled(widget.event.id, isLike: true),
          );
    }
  }

  void handleTap() {
    if (!widget.isAuthenticated) {
      widget.onTap();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventPicturesPage(event: widget.event)),
    );
  }

  int get _visibleCount {
    if (widget.isAuthenticated) return widget.event.pictures.length;
    return math.min(3, widget.event.pictures.length);
  }

  // ── Shared media stack (used by both mobile + web layouts) ─────────────────

  Widget _buildMediaStack(BuildContext context, AppThemeExtension ext,
      List<EventPicture> pics, double width, double height) {
    final visible = pics.take(_visibleCount).toList();
    final curIdx =
        visible.isEmpty ? 0 : _currentPage.clamp(0, visible.length - 1);
    final onVideo = curIdx < visible.length && visible[curIdx].isVideo;
    // On video slides, reserve the bottom strip occupied by the player's
    // control bar (scrubber + timestamps + fullscreen, anchored at bottom: 0)
    // so the card's gradient, footer and page dots lift clear of it and the
    // controls stay visible and tappable.
    final controlsReserve = onVideo ? 60.h : 0.0;
    // Web: show prev/next carousel arrows when hovering a multi-photo card.
    final showArrows = kIsWeb && widget.isAuthenticated && visible.length > 1;
    return MouseRegion(
        onEnter:
            showArrows ? (_) => setState(() => _mediaHovered = true) : null,
        onExit:
            showArrows ? (_) => setState(() => _mediaHovered = false) : null,
        child: GestureDetector(
          onTap: widget.isAuthenticated ? null : widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                pics.isEmpty
                    ? CardGradientPlaceholder(name: widget.event.eventName)
                    : PostPhotoCarousel(
                        pics: visible,
                        pageController: _pageCtrl,
                        showBlur: !widget.isAuthenticated && pics.length > 3,
                        onTap: handleTap,
                        scrollable: widget.isAuthenticated,
                        // Double-tap-to-like answers to the same switch as the
                        // like button — otherwise it is a silent way past a
                        // hidden control.
                        onDoubleTap: widget.isAuthenticated
                            ? (_engagementAllowed ? _handleDoubleTap : () {})
                            : widget.onTap,
                        cardIndex: widget.cardIndex,
                        activeCardIndex: widget.activeCardIndex,
                      ),
                Positioned(
                  bottom: controlsReserve,
                  left: 0,
                  right: 0,
                  height: 160.h,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: [0.0, 0.55, 1.0],
                        colors: [
                          Color(
                              0x99000000), // 60 % — text shadows handle legibility
                          Color(0x33000000), // 20 %
                          Color(0x00000000), // 0 %
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 16.h + controlsReserve,
                  left: 14.w,
                  right: kIsWeb ? 14.w : 82.w,
                  child: ImageFooter(event: widget.event),
                ),
                if (_showHeartBurst)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(child: HeartBurst(ctrl: _heartCtrl)),
                    ),
                  ),
                if (pics.length > 1)
                  Positioned(
                    bottom: 10.h + controlsReserve,
                    left: 0,
                    right: 0,
                    child: PageDots(
                      totalCount: _visibleCount,
                      controller: _pageCtrl,
                      maxRevealedPage: _maxRevealedPage,
                    ),
                  ),
                if (!widget.isAuthenticated && pics.isEmpty)
                  UnauthCta(onTap: widget.onTap),

                // ── Web: prev / next carousel arrows (hover-revealed) ───────────
                if (showArrows)
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !_mediaHovered,
                      child: AnimatedOpacity(
                        opacity: _mediaHovered ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 160),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: controlsReserve),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Semantics(
                                button: true,
                                label: 'Previous photo',
                                child: CarouselArrow(
                                  isLeft: true,
                                  enabled: curIdx > 0,
                                  onTap: () => _goToCarouselPage(curIdx - 1),
                                ),
                              ),
                              Semantics(
                                button: true,
                                label: 'Next photo',
                                child: CarouselArrow(
                                  isLeft: false,
                                  enabled: curIdx < visible.length - 1,
                                  onTap: () => _goToCarouselPage(curIdx + 1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ));
  }

  /// Animate the photo carousel to [target], clamped to the visible range.
  void _goToCarouselPage(int target) {
    if (!_pageCtrl.hasClients) return;
    final t = target.clamp(0, _visibleCount - 1);
    _pageCtrl.animateToPage(
      t,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  // ── Web layout — image left, reactions/comments panel right ─────────────────

  // ── Shared right-panel builder (reactions + optional inline comments) ────────

  Widget _buildWebRightPanel(
    BuildContext context,
    AppThemeExtension ext,
    bool commentsEnabled, {
    required bool isExternalPanel,
    bool reactionsOnly = false,
    double? mediaH,
  }) {
    // Shared reactions column — used standalone or as a narrow strip beside
    // the inline comment panel.
    Widget buildReactions(BuildContext ctx) => WebReactionsColumn(
          liked: _liked,
          disliked: _disliked,
          saved: _isSaved(ctx),
          likeCount: _likeCount,
          dislikeCount: _dislikeCount,
          commentCount: widget.event.commentCount,
          commentsEnabled: commentsEnabled,
          reactionsEnabled: _engagementAllowed,
          ext: ext,
          isExternalPanel: isExternalPanel,
          mediaH: mediaH! * 1.5,
          photographerName: widget.event.photographerName,
          photographerId: widget.event.photographerId,
          photographerProfileUrl: widget.event.photographerProfileUrl,
          isFollowed: widget.event.isFollowed,
          isOwner: widget.isOwner,
          isAuthenticated: widget.isAuthenticated,
          onPhotographerTap: () => openPhotographerProfile(
            ctx,
            photographerId: widget.event.photographerId,
            photographerName: widget.event.photographerName,
            photographerProfileUrl: widget.event.photographerProfileUrl,
          ),
          onLoginRequired: widget.onTap,
          onLike: widget.isAuthenticated
              ? () {
                  setState(() {
                    if (!_liked && _disliked) {
                      _disliked = false;
                      _dislikeCount = (_dislikeCount - 1).clamp(0, 999999999);
                    }
                    _liked = !_liked;
                    _likeCount += _liked ? 1 : -1;
                  });
                  context.read<DiscoveryBloc>().add(
                      DiscoveryReactionToggled(widget.event.id, isLike: true));
                }
              : widget.onTap,
          onDislike: widget.isAuthenticated
              ? () {
                  setState(() {
                    if (!_disliked && _liked) {
                      _liked = false;
                      _likeCount = (_likeCount - 1).clamp(0, 999999999);
                    }
                    _disliked = !_disliked;
                    _dislikeCount += _disliked ? 1 : -1;
                  });
                  context.read<DiscoveryBloc>().add(
                      DiscoveryReactionToggled(widget.event.id, isLike: false));
                }
              : widget.onTap,
          // Toggle: tapping the comment icon closes the panel when it's open.
          onComment: widget.isAuthenticated && commentsEnabled
              ? () => _setCommentsOpen(!_webCommentsOpen)
              : widget.isAuthenticated
                  ? null
                  : widget.onTap,
          onShare: () => GetAppSheet.show(context, ext: ext),
          onSave: widget.isAuthenticated
              ? () => context
                  .read<DiscoveryBloc>()
                  .add(DiscoveryEventSaveToggled(widget.event.id))
              : widget.onTap,
          onMore: widget.isAuthenticated
              ? () => _showEventMoreOptions(ctx, ext)
              : null,
        );

    if (!_commentsVisible || reactionsOnly) {
      return BlocBuilder<DiscoveryBloc, DiscoveryState>(
        buildWhen: (prev, next) => prev.savedEventIds != next.savedEventIds,
        builder: (ctx2, _) => buildReactions(ctx2),
      );
    }

    // Slide + fade the panel in from the side each time it appears (when the
    // card becomes active with comments open, or the user opens them). Reveal
    // plays once on insertion and honours reduce-motion.
    final commentsPanel = Reveal(
      offset: const Offset(40, 0),
      duration: AppMotion.fast,
      child: EventCommentInlinePanel(
        event: widget.event,
        isExternalPanel: isExternalPanel,
        onClose: () => _setCommentsOpen(false),
        onCommentSent: _onCommentSent,
      ),
    );

    // Narrow (inside-card) layout: comments replace reactions.
    if (!isExternalPanel) return commentsPanel;

    // External (desktop) layout: reactions strip stays visible on the left,
    // comment thread fills the remaining space to the right.
    // LayoutBuilder guards against the rare case where the panel hasn't grown
    // wide enough to fit both (≥ 240 px = 64 reactions + 176 comments).
    return LayoutBuilder(builder: (ctx, cons) {
      if (cons.maxWidth >= 240.0) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64.0,
              child: BlocBuilder<DiscoveryBloc, DiscoveryState>(
                buildWhen: (prev, next) =>
                    prev.savedEventIds != next.savedEventIds,
                builder: (ctx2, _) => buildReactions(ctx2),
              ),
            ),
            Expanded(child: commentsPanel),
          ],
        );
      }
      return commentsPanel;
    });
  }

  Widget _buildWebCard(BuildContext context, AppThemeExtension ext,
      List<EventPicture> pics, double screenH) {
    // Same split as the native path: comments also answer to the admin
    // kill-switch, reactions only to the owner's own setting.
    final commentsEnabled =
        AppConfigRepository.current.commentsEnabled && _engagementAllowed;

    return LayoutBuilder(builder: (ctx, cons) {
      // External panel activates when the card has ≥ 60px of room beyond the
      // 480px content column (viewport ≈ 780px+, any laptop at a normal window
      // size). Below that threshold the panel stays inside the card (170px).
      final isWide = cons.maxWidth >= _kWebColumnWidth + 60.0; // ≥ 540px
      const cardW = _kWebColumnWidth; // 480

      if (isWide) {
        final mediaH = _computeMediaHeight(cardW, screenH);
        const reactionsW = 64.0;

        // Card column (image + caption) — identical in both states.
        final cardColumn = SizedBox(
          width: cardW,
          child: Material(
            color: ext.cardSurface,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: mediaH,
                  child: _buildMediaStack(context, ext, pics, cardW, mediaH),
                ),
                CardDescriptionText(
                  event: widget.event,
                  ext: ext,
                  expanded: _descExpanded,
                  onToggle: () =>
                      setState(() => _descExpanded = !_descExpanded),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );

        final reactionsColumn = SizedBox(
          width: reactionsW,
          height: mediaH,
          child: _buildWebRightPanel(context, ext, commentsEnabled,
              isExternalPanel: true, reactionsOnly: true, mediaH: mediaH),
        );

        // Reserve the comment column's width on the right in BOTH states, so
        // the card sits at the exact same x-position whether comments are open
        // or closed — opening them never shifts ("pushes") the card.
        const desiredCommentsW = 400.0;
        final commentsW =
            (cons.maxWidth - cardW - reactionsW).clamp(0.0, desiredCommentsW);

        // Centred pad if the card were alone; and the largest pad that still
        // leaves room for the reserved comment column. The card stays centred
        // when there's space, and is biased left only as much as needed.
        final basePad = ((cons.maxWidth - cardW - reactionsW) / 2)
            .clamp(0.0, double.infinity);
        final maxPadWithComments =
            (cons.maxWidth - cardW - reactionsW - commentsW)
                .clamp(0.0, double.infinity);
        final leftPad = math.min(basePad, maxPadWithComments);

        // Comment thread grows to (almost) the full viewport height when open.
        final panelH =
            (screenH - 80.0).clamp(mediaH, double.infinity).toDouble();

        // One identical Row for both states — only the comment child is added
        // or removed. The card (and its video element) keeps its position and
        // its state, so toggling comments never tears it down / reloads it.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: leftPad),
            cardColumn,
            reactionsColumn,
            if (_commentsVisible)
              SizedBox(
                width: commentsW,
                height: panelH,
                child: EventCommentInlinePanel(
                  event: widget.event,
                  isExternalPanel: true,
                  onClose: () => _setCommentsOpen(false),
                  onCommentSent: _onCommentSent,
                ),
              ),
          ],
        );
      }

      // ── Narrow (mobile web): same layout as native — reactions beneath ─────
      return _buildMobileLayout(context, ext, pics, screenH);
    });
  }

  // ── Shared helpers: used by both native and mobile-web layouts ───────────────

  bool get _commentsEnabled =>
      AppConfigRepository.current.commentsEnabled && _engagementAllowed;

  /// Whether the owner permits engagement on what is currently on screen.
  ///
  /// Gates reactions as well as comments: `comments_enabled` is the owner's
  /// "no feedback on this" switch, so a disabled event should not collect
  /// likes or dislikes either.
  ///
  /// Unlike [_commentsEnabled] this ignores the global admin comments toggle —
  /// that kill-switch is about written comments, and it would be wrong for an
  /// admin disabling comments app-wide to also silence every like.
  bool get _engagementAllowed =>
      widget.event.commentsEnabled &&
      (widget.event.pictures.isEmpty ||
          widget
              .event
              .pictures[_currentPage.clamp(0, widget.event.pictures.length - 1)]
              .commentsEnabled);

  /// Builds the interaction bar with all reaction handlers wired up.
  /// Used by both the native iOS/Android path and the narrow mobile-web path.
  Widget _buildInteractionBar(BuildContext context, AppThemeExtension ext) {
    return BlocBuilder<DiscoveryBloc, DiscoveryState>(
      buildWhen: (prev, next) => prev.savedEventIds != next.savedEventIds,
      builder: (ctx, _) => CardInteractionBar(
        liked: _liked,
        disliked: _disliked,
        saved: _isSaved(ctx),
        likeCount: _likeCount,
        dislikeCount: _dislikeCount,
        commentCount: widget.event.commentCount,
        commentsEnabled: _commentsEnabled,
        reactionsEnabled: _engagementAllowed,
        ext: ext,
        onLike: widget.isAuthenticated
            ? () {
                setState(() {
                  if (!_liked && _disliked) {
                    _disliked = false;
                    _dislikeCount = (_dislikeCount - 1).clamp(0, 999999999);
                  }
                  _liked = !_liked;
                  _likeCount += _liked ? 1 : -1;
                });
                ctx.read<DiscoveryBloc>().add(
                      DiscoveryReactionToggled(widget.event.id, isLike: true),
                    );
              }
            : widget.onTap,
        onDislike: widget.isAuthenticated
            ? () {
                setState(() {
                  if (!_disliked && _liked) {
                    _liked = false;
                    _likeCount = (_likeCount - 1).clamp(0, 999999999);
                  }
                  _disliked = !_disliked;
                  _dislikeCount += _disliked ? 1 : -1;
                });
                ctx.read<DiscoveryBloc>().add(
                      DiscoveryReactionToggled(widget.event.id, isLike: false),
                    );
              }
            : widget.onTap,
        onComment: widget.isAuthenticated
            ? (widget.onCommentTap ?? () => _showCommentSheet(context, ext))
            : widget.onTap,
        onShare: widget.isAuthenticated
            ? () {
                final p = widget.event.pictures;
                if (p.isEmpty) return;
                GalleryShareSheet.show(
                  context,
                  imageUrl: p[_currentPage.clamp(0, p.length - 1)].url,
                  photoLabel: widget.event.eventName,
                );
              }
            : widget.onTap,
        onShareExternal: widget.isAuthenticated
            ? () {
                final p = widget.event.pictures;
                if (p.isEmpty) return Future.value();
                final pic = p[_currentPage.clamp(0, p.length - 1)];
                return shareOverlayPhotoExternally(
                  context,
                  imageId: pic.id,
                  photographerName: widget.event.photographerName,
                  eventName: widget.event.eventName,
                  description: widget.event.description,
                  // The event, not the single photo: someone sharing a shot
                  // from an album is showing off the album, and the recipient
                  // lands somewhere with the rest of it rather than on one
                  // picture with no context.
                  link: DeepLink(DeepLinkKind.event, id: widget.event.id),
                );
              }
            : null,
        onSave: widget.isAuthenticated
            ? () => ctx
                .read<DiscoveryBloc>()
                .add(DiscoveryEventSaveToggled(widget.event.id))
            : widget.onTap,
      ),
    );
  }

  /// Shared card layout for native iOS/Android AND narrow mobile-web.
  /// header → full-width image → interaction bar below → caption → gap.
  Widget _buildMobileLayout(
    BuildContext context,
    AppThemeExtension ext,
    List<EventPicture> pics,
    double screenH,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Slim header ──────────────────────────────────────────────────
        Container(
          color: ext.cardSurface,
          child: PostHeader(
            event: widget.event,
            ext: ext,
            isOwner: widget.isOwner,
            isAuthenticated: widget.isAuthenticated,
            onPhotographerTap: () => openPhotographerProfile(
              context,
              photographerId: widget.event.photographerId,
              photographerName: widget.event.photographerName,
              photographerProfileUrl: widget.event.photographerProfileUrl,
            ),
            onHide: widget.onHide,
            onLoginRequired: widget.onTap,
            onImage: false,
          ),
        ),

        // ── Full-width image ─────────────────────────────────────────────
        LayoutBuilder(
          builder: (ctx, constraints) {
            final mediaH = _computeMediaHeight(constraints.maxWidth, screenH);
            return _buildMediaStack(
                ctx, ext, pics, constraints.maxWidth, mediaH);
          },
        ),

        // ── Interaction bar below the image ──────────────────────────────
        Container(
          color: ext.cardSurface,
          child: _buildInteractionBar(context, ext),
        ),

        // ── Caption ──────────────────────────────────────────────────────
        Container(
          color: ext.cardSurface,
          child: CardDescriptionText(
            event: widget.event,
            ext: ext,
            expanded: _descExpanded,
            onToggle: () => setState(() => _descExpanded = !_descExpanded),
          ),
        ),

        // ── Card gap ─────────────────────────────────────────────────────
        Container(height: 10.h, color: ext.homeBackground),
      ],
    );
  }

  // ── Entry point ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final pics = widget.event.pictures;
    final screenH = MediaQuery.sizeOf(context).height;

    if (kIsWeb) return _buildWebCard(context, ext, pics, screenH);

    // Native iOS / Android — reactions beneath the image.
    return _buildMobileLayout(context, ext, pics, screenH);
  }

  void _showCommentSheet(BuildContext context, AppThemeExtension ext) {
    EventCommentPage.show(context, widget.event, onCommentSent: _onCommentSent);
  }

  /// Opens the Hide / Report sheet (used by the web card's more-options button;
  /// mobile uses the post header's menu). Prompts login when unauthenticated.
  void _showEventMoreOptions(BuildContext context, AppThemeExtension ext) {
    if (!widget.isAuthenticated) {
      widget.onTap();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => EventMoreOptionsSheet(
        ext: ext,
        eventId: widget.event.id,
        onHide: widget.onHide,
      ),
    );
  }

  /// Optimistically bump the feed card's comment count when the user posts a
  /// comment. The feed rebuilds from DiscoveryBloc state, so the count updates
  /// live without waiting for a reload.
  void _onCommentSent() {
    _discoveryBloc?.add(DiscoveryCommentAdded(widget.event.id));
  }
}
