import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/get_app_sheet.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/event_pictures_page.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_interaction_bar.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_description_text.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/event_comment_page.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/report_sheet.dart';
import 'package:skidoo_app/features/gallery/presentation/widgets/gallery_share_sheet.dart';
import 'package:skidoo_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';
import 'package:skidoo_app/features/follow/data/follow_repository.dart';

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
  bool _liked = false;
  bool _disliked = false;
  int _likeCount = 0;
  int _dislikeCount = 0;
  bool _descExpanded = false;
  bool _showHeartBurst = false;
  // Web-only: whether the inline comment panel is open (replaces reactions col).
  bool _webCommentsOpen = false;

  late final AnimationController _heartCtrl;

  // Stored so we can safely dispatch from dispose() without using context.
  DiscoveryBloc? _discoveryBloc;

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
        setState(() {
          _currentPage = page;
          if (page > _maxRevealedPage) _maxRevealedPage = page;
        });
      }
    });
    // Notify the bloc that this card is now visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _discoveryBloc = context.read<DiscoveryBloc>();
      _discoveryBloc?.add(DiscoveryEventVisible(widget.event.id));
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
  }

  @override
  void dispose() {
    // Notify the bloc that this card has left the viewport.
    _discoveryBloc?.add(DiscoveryEventHidden(widget.event.id));
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
    final pics = widget.event.pictures;
    final currentPic = pics.isNotEmpty
        ? pics[_currentPage.clamp(0, pics.length - 1)]
        : null;

    if (currentPic?.isVideo == true) {
      // Videos: use supplied aspect ratio when available, else 16:9 default.
      final ar = currentPic!.aspectRatio ?? (16 / 9);
      return (availableWidth / ar)
          .clamp(_kMinMediaHeight, screenHeight * 0.92);
    }

    final ar = currentPic?.aspectRatio;
    if (ar != null && ar > 0) {
      return (availableWidth / ar)
          .clamp(_kMinMediaHeight, screenHeight * 0.92);
    }

    // Fallback for legacy records without server dimensions: 4:5 portrait.
    return (availableWidth / 0.8).clamp(_kMinMediaHeight, screenHeight * 0.88);
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
    return GestureDetector(
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
                    pics: pics.take(_visibleCount).toList(),
                    pageController: _pageCtrl,
                    showBlur: !widget.isAuthenticated && pics.length > 3,
                    onTap: handleTap,
                    scrollable: widget.isAuthenticated,
                    onDoubleTap: widget.isAuthenticated
                        ? _handleDoubleTap
                        : widget.onTap,
                    cardIndex: widget.cardIndex,
                    activeCardIndex: widget.activeCardIndex,
                  ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 220.h,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    stops: [0.0, 0.5, 1.0],
                    colors: [
                      Color(0xF2000000),
                      Color(0x88000000),
                      Color(0x00000000),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16.h,
              left: 14.w,
              right: kIsWeb ? 14.w : 82.w,
              child: _ImageFooter(event: widget.event),
            ),
            if (_showHeartBurst)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(child: _HeartBurst(ctrl: _heartCtrl)),
                ),
              ),
            if (pics.length > 1)
              Positioned(
                bottom: 10.h,
                left: 0,
                right: 0,
                child: _PageDots(
                  totalCount: _visibleCount,
                  controller: _pageCtrl,
                  maxRevealedPage: _maxRevealedPage,
                ),
              ),
            if (!widget.isAuthenticated && pics.isEmpty)
              _UnauthCta(onTap: widget.onTap),
          ],
        ),
      ),
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
  }) {
    // Shared reactions column — used standalone or as a narrow strip beside
    // the inline comment panel.
    Widget buildReactions(BuildContext ctx) => _WebReactionsColumn(
          liked: _liked,
          disliked: _disliked,
          saved: _isSaved(ctx),
          likeCount: _likeCount,
          dislikeCount: _dislikeCount,
          commentCount: widget.event.commentCount,
          commentsEnabled: commentsEnabled,
          ext: ext,
          isExternalPanel: isExternalPanel,
          photographerName: widget.event.photographerName,
          photographerId: widget.event.photographerId,
          isFollowed: widget.event.isFollowed,
          isOwner: widget.isOwner,
          isAuthenticated: widget.isAuthenticated,
          onPhotographerTap: () => _openPhotographerProfile(ctx),
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
              ? () => setState(() => _webCommentsOpen = !_webCommentsOpen)
              : widget.isAuthenticated
                  ? null
                  : widget.onTap,
          onShare: () => GetAppSheet.show(context, ext: ext),
          onSave: widget.isAuthenticated
              ? () => context
                  .read<DiscoveryBloc>()
                  .add(DiscoveryEventSaveToggled(widget.event.id))
              : widget.onTap,
        );

    if (!_webCommentsOpen || reactionsOnly) {
      return BlocBuilder<DiscoveryBloc, DiscoveryState>(
        buildWhen: (prev, next) => prev.savedEventIds != next.savedEventIds,
        builder: (ctx2, _) => buildReactions(ctx2),
      );
    }

    final commentsPanel = EventCommentInlinePanel(
      event: widget.event,
      isExternalPanel: isExternalPanel,
      onClose: () => setState(() => _webCommentsOpen = false),
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
    final commentsEnabled = AppConfigRepository.current.commentsEnabled &&
        widget.event.commentsEnabled &&
        (widget.event.pictures.isEmpty ||
            widget.event.pictures[
                    _currentPage.clamp(0, widget.event.pictures.length - 1)]
                .commentsEnabled);

    return LayoutBuilder(builder: (ctx, cons) {
      // External panel activates when the card has ≥ 60px of room beyond the
      // 480px content column (viewport ≈ 780px+, any laptop at a normal window
      // size). Below that threshold the panel stays inside the card (170px).
      final isWide = cons.maxWidth >= _kWebColumnWidth + 60.0; // ≥ 540px
      const cardW = _kWebColumnWidth; // 480

      if (isWide) {
        // ── Desktop: card+reactions centred; comments grow right without
        //    shifting the card when there is enough room. On narrower viewports
        //    (e.g. the Following feed which is capped at 720 px) leftPad shrinks
        //    so the comment panel is never clipped off-screen.
        final mediaH = _computeMediaHeight(cardW, screenH);
        const reactionsW = 64.0;
        const commentsW = 340.0;

        // Centering pad when comments are closed.
        final basePad =
            ((cons.maxWidth - cardW - reactionsW) / 2).clamp(0.0, double.infinity);

        // If opening comments would overflow the available width, reduce leftPad
        // so all three columns (card + reactions + comments) fit on screen.
        final leftPad = (!_webCommentsOpen ||
                basePad + cardW + reactionsW + commentsW <= cons.maxWidth)
            ? basePad
            : ((cons.maxWidth - cardW - reactionsW - commentsW) / 2)
                .clamp(0.0, double.infinity);

        // Effective comments width — capped to whatever space remains after the
        // card and reactions columns (prevents overflow when viewport is narrow).
        final effectiveCommentsW = _webCommentsOpen
            ? (cons.maxWidth - leftPad - cardW - reactionsW)
                .clamp(0.0, commentsW)
            : commentsW;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Left spacer — centres card (shrinks when comments open) ───
            SizedBox(width: leftPad),
            // ── Card column (image + caption, rounded card) ───────────
            Container(
              width: cardW,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: mediaH,
                      child: _buildMediaStack(
                          context, ext, pics, cardW, mediaH),
                    ),
                    Container(
                      color: ext.cardSurface,
                      child: CardDescriptionText(
                        event: widget.event,
                        ext: ext,
                        expanded: _descExpanded,
                        onToggle: () =>
                            setState(() => _descExpanded = !_descExpanded),
                      ),
                    ),
                    Container(color: ext.cardSurface, height: 8),
                  ],
                ),
              ),
            ),
            // ── Reactions — always 64 px, always flush to card ────────────
            SizedBox(
              width: reactionsW,
              height: mediaH,
              child: _buildWebRightPanel(context, ext, commentsEnabled,
                  isExternalPanel: true, reactionsOnly: true),
            ),
            // ── Comments panel — fills available space up to commentsW ─────
            if (_webCommentsOpen)
              SizedBox(
                width: effectiveCommentsW,
                height: mediaH,
                child: EventCommentInlinePanel(
                  event: widget.event,
                  isExternalPanel: true,
                  onClose: () => setState(() => _webCommentsOpen = false),
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
      AppConfigRepository.current.commentsEnabled &&
      widget.event.commentsEnabled &&
      (widget.event.pictures.isEmpty ||
          widget.event.pictures[
                  _currentPage.clamp(0, widget.event.pictures.length - 1)]
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
        ext: ext,
        onLike: widget.isAuthenticated
            ? () {
                setState(() {
                  if (!_liked && _disliked) {
                    _disliked = false;
                    _dislikeCount =
                        (_dislikeCount - 1).clamp(0, 999999999);
                  }
                  _liked = !_liked;
                  _likeCount += _liked ? 1 : -1;
                });
                ctx.read<DiscoveryBloc>().add(
                      DiscoveryReactionToggled(widget.event.id,
                          isLike: true),
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
                      DiscoveryReactionToggled(widget.event.id,
                          isLike: false),
                    );
              }
            : widget.onTap,
        onComment: widget.isAuthenticated
            ? (widget.onCommentTap ??
                () => _showCommentSheet(context, ext))
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
          child: _PostHeader(
            event: widget.event,
            ext: ext,
            isOwner: widget.isOwner,
            isAuthenticated: widget.isAuthenticated,
            onPhotographerTap: () => _openPhotographerProfile(context),
            onHide: widget.onHide,
            onLoginRequired: widget.onTap,
            onImage: false,
          ),
        ),

        // ── Full-width image ─────────────────────────────────────────────
        LayoutBuilder(
          builder: (ctx, constraints) {
            final mediaH =
                _computeMediaHeight(constraints.maxWidth, screenH);
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
            onToggle: () =>
                setState(() => _descExpanded = !_descExpanded),
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

  void _openPhotographerProfile(BuildContext context) {
    final photographer = PhotographerModel(
      widget.event.photographerId,
      '',
      widget.event.photographerName,
      '',
    );
    // HomeBloc may not be in the tree on the unauthenticated discovery page.
    HomeBloc? homeBloc;
    try {
      homeBloc = context.read<HomeBloc>();
    } catch (_) {}

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => homeBloc != null
            ? BlocProvider.value(
                value: homeBloc,
                child: PhotographerProfilePage(photographer: photographer),
              )
            : PhotographerProfilePage(photographer: photographer),
      ),
    );
  }

  void _showCommentSheet(BuildContext context, AppThemeExtension ext) {
    EventCommentPage.show(context, widget.event);
  }
}

// ── Post header ───────────────────────────────────────────────────────────────

class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.event,
    required this.ext,
    this.isOwner = false,
    this.isAuthenticated = false,
    this.onPhotographerTap,
    this.onHide,
    this.onLoginRequired,
    this.onImage = false,
  });
  final EventDiscovery event;
  final AppThemeExtension ext;
  final bool isOwner;
  final bool isAuthenticated;
  final VoidCallback? onPhotographerTap;
  final VoidCallback? onHide;
  final VoidCallback? onLoginRequired;
  final bool onImage;

  void _showMoreOptions(BuildContext context) {
    if (!isAuthenticated) {
      onLoginRequired?.call();
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventMoreOptionsSheet(
        ext: ext,
        eventId: event.id,
        onHide: onHide,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = event.photographerName;
    final nameColor = onImage ? Colors.white : ext.greetingColor;
    final iconColor = onImage ? Colors.white : ext.greetingColor;
    final textShadows = onImage
        ? const [
            Shadow(blurRadius: 12, color: Colors.black87),
            Shadow(blurRadius: 4, color: Colors.black54),
          ]
        : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 9.h, 4.w, 9.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar ─────────────────────────────────────────────────────
          GestureDetector(
            onTap: onPhotographerTap,
            child: _CreatorInitialsAvatar(
              name: name,
              size: 36.w,
              onImage: onImage,
            ),
          ),

          SizedBox(width: 10.w),

          // ── Name (no subtitle — keeps the header slim) ─────────────────
          Expanded(
            child: GestureDetector(
              onTap: onPhotographerTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: nameColor,
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        shadows: textShadows,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isOwner) ...[
                    SizedBox(width: 6.w),
                    _OwnerPill(ext: ext),
                  ],
                ],
              ),
            ),
          ),

          // ── Follow pill — hidden for own posts ─────────────────────────
          if (!isOwner) ...[
            SizedBox(width: 10.w),
            FollowButton(
              photographerId: event.photographerId,
              onImage: onImage,
              initialFollowing: event.isFollowed,
              onLoginRequired: isAuthenticated ? null : onLoginRequired,
            ),
          ],

          // ── More options ───────────────────────────────────────────────
          GestureDetector(
            onTap: () => _showMoreOptions(context),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              child: Icon(Icons.more_horiz_rounded,
                  color: iconColor, size: 21.sp),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Owner pill badge ──────────────────────────────────────────────────────────

class _OwnerPill extends StatelessWidget {
  const _OwnerPill({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ext.accentGold.withValues(alpha: 0.18),
            const Color(0xFFFF8C00).withValues(alpha: 0.12),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: ext.accentGold.withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded,
              size: 9.sp, color: ext.accentGold),
          SizedBox(width: 3.w),
          Text(
            'Your post',
            style: TextStyle(
              color: ext.accentGold,
              fontSize: 9.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Creator initials avatar — used on image overlays ─────────────────────────

class _CreatorInitialsAvatar extends StatelessWidget {
  const _CreatorInitialsAvatar({
    required this.name,
    required this.size,
    this.onImage = false,
  });
  final String name;
  final double size;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    const borderPad = 2.5;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [ext.accentGold, const Color(0xFFFF6B35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: ext.accentGold.withValues(alpha: 0.40),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(borderPad),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFFFFAB40), Color(0xFFFF6B35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: (size - borderPad * 2) * 0.42,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

// ── Image footer — TikTok-style text overlay at bottom-left ──────────────────

class _ImageFooter extends StatefulWidget {
  const _ImageFooter({required this.event});
  final EventDiscovery event;

  @override
  State<_ImageFooter> createState() => _ImageFooterState();
}

class _ImageFooterState extends State<_ImageFooter> {
  bool _tagsExpanded = false;

  static const _heavy = [
    Shadow(blurRadius: 20, color: Colors.black),
    Shadow(blurRadius: 6, color: Colors.black87),
  ];
  static const _soft = [
    Shadow(blurRadius: 10, color: Colors.black87),
  ];

  String get _tagLine {
    final tags = widget.event.contentTags;
    if (tags.isEmpty) return '';
    return tags.map((t) => '#$t').join('  ');
  }

  @override
  Widget build(BuildContext context) {
    final tagLine = _tagLine;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Event name first — large and bold
        Text(
          widget.event.eventName,
          maxLines: _tagsExpanded ? null : 2,
          overflow:
              _tagsExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.15,
            shadows: _heavy,
          ),
        ),

        // Content tags — inline with "more / less" pinned to the right
        if (tagLine.isNotEmpty) ...[
          SizedBox(height: 4.h),
          GestureDetector(
            onTap: () => setState(() => _tagsExpanded = !_tagsExpanded),
            child: _tagsExpanded
                ? Text(
                    tagLine,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      shadows: _soft,
                    ),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          tagLine,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                            shadows: _soft,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'more',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          shadows: _soft,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

// ── Double-tap heart burst ────────────────────────────────────────────────────

class _HeartBurst extends StatelessWidget {
  const _HeartBurst({required this.ctrl});
  final AnimationController ctrl;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final t = ctrl.value;
        // Scale: 0→1.4 in first half, 1.4→1.2 in second half
        final scale = t < 0.4 ? (t / 0.4) * 1.4 : 1.4 - ((t - 0.4) / 0.6) * 0.2;
        // Opacity: full until 0.6, then fade out
        final opacity = t < 0.6 ? 1.0 : 1.0 - ((t - 0.6) / 0.4);

        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale.clamp(0.0, 2.0),
            child: Icon(
              Icons.favorite_rounded,
              color: Colors.white,
              size: 90.sp,
              shadows: const [
                Shadow(blurRadius: 20, color: Colors.black54),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Page dots ─────────────────────────────────────────────────────────────────
// Smooth Instagram-style dots: width and opacity interpolate continuously with
// the PageController's fractional .page value so animation tracks the finger.

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.totalCount,
    required this.controller,
    required this.maxRevealedPage,
  });

  final int totalCount;
  final PageController controller;

  /// The highest page index the user has swiped to so far.
  /// Dots are revealed up to this index, with a minimum of min(3, totalCount).
  final int maxRevealedPage;

  @override
  Widget build(BuildContext context) {
    // Show min(3, totalCount) dots immediately. Reveal the next dot one step
    // early — when the user reaches the last-but-one of the currently shown
    // dots — so there's always one more waiting ahead.
    final revealedCount = math.min(
      totalCount,
      math.max(math.min(3, totalCount), maxRevealedPage + 3),
    );

    return ListenableBuilder(
      listenable: controller,
      builder: (_, __) {
        final page =
            controller.hasClients ? (controller.page ?? 0.0) : 0.0;
        return AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(revealedCount, (i) {
              final t = (page - i).abs().clamp(0.0, 1.0);
              // Active dot is wider; interpolated continuously while swiping.
              final w = 20.w - 14.w * t;
              final color = Color.lerp(
                Colors.white,
                Colors.white.withValues(alpha: 0.35),
                t,
              )!;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: w,
                height: 6.h,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ── Event "more options" bottom sheet ─────────────────────────────────────────


class _EventMoreOptionsSheet extends StatelessWidget {
  const _EventMoreOptionsSheet({
    required this.ext,
    required this.eventId,
    this.onHide,
  });
  final AppThemeExtension ext;
  final String eventId;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: EdgeInsets.symmetric(vertical: 12.h),
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),

            // Hide option
            ListTile(
              leading: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: ext.searchFieldFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.visibility_off_outlined,
                    color: ext.greetingColor, size: 20.sp),
              ),
              title: Text(
                'Hide event',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15.sp,
                ),
              ),
              subtitle: Text(
                "You won't see this event again",
                style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
              ),
              onTap: () {
                Navigator.of(context).pop();
                onHide?.call();
              },
            ),

            Divider(height: 1, color: ext.searchHintColor.withValues(alpha: 0.1)),

            // Report option — opens the reason picker sheet
            ListTile(
              leading: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.flag_outlined,
                    color: Colors.redAccent, size: 20.sp),
              ),
              title: Text(
                'Report event',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 15.sp,
                ),
              ),
              subtitle: Text(
                'Inappropriate, misleading or harmful content',
                style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
              ),
              trailing: Icon(Icons.chevron_right_rounded,
                  color: ext.searchHintColor, size: 20.sp),
              onTap: () {
                Navigator.of(context).pop();
                ReportSheet.show(
                  context,
                  ext: ext,
                  assetType: 'event',
                  assetId: eventId,
                );
              },
            ),

            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}

// ── Unauthenticated full CTA ──────────────────────────────────────────────────

class _UnauthCta extends StatelessWidget {
  const _UnauthCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),
          alignment: Alignment.center,
          child: Text(
            'Tap to explore',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Web: vertical reactions column ────────────────────────────────────────────

class _WebReactionsColumn extends StatelessWidget {
  const _WebReactionsColumn({
    required this.liked,
    required this.disliked,
    required this.saved,
    required this.likeCount,
    required this.dislikeCount,
    required this.commentCount,
    required this.commentsEnabled,
    required this.ext,
    required this.isExternalPanel,
    required this.onLike,
    required this.onDislike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
    this.photographerName = '',
    this.photographerId = '',
    this.isFollowed = false,
    this.isOwner = false,
    this.isAuthenticated = false,
    this.onPhotographerTap,
    this.onLoginRequired,
  });

  final bool liked;
  final bool disliked;
  final bool saved;
  final int likeCount;
  final int dislikeCount;
  final int commentCount;
  final bool commentsEnabled;
  final AppThemeExtension ext;
  final bool isExternalPanel;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final VoidCallback? onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;
  // Photographer badge shown at the bottom of the external panel (web desktop).
  final String photographerName;
  final String photographerId;
  final bool isFollowed;
  final bool isOwner;
  final bool isAuthenticated;
  final VoidCallback? onPhotographerTap;
  final VoidCallback? onLoginRequired;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isExternalPanel
        ? null
        : Border(
            left: BorderSide(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.08),
              width: 0.5,
            ),
          );
    final iconSize = isExternalPanel ? 32.0 : null;

    return Container(
      decoration: BoxDecoration(color: ext.homeBackground, border: border),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // ── Photographer badge — external panel only (TikTok creator pin) ─
            if (isExternalPanel && photographerName.isNotEmpty) ...[
              _WebCreatorPin(
                name: photographerName,
                photographerId: photographerId,
                isFollowed: isFollowed,
                isOwner: isOwner,
                isAuthenticated: isAuthenticated,
                ext: ext,
                onTap: onPhotographerTap,
                onLoginRequired: onLoginRequired,
              ),
              const SizedBox(height: 28),
            ],

            // ── Reactions ─────────────────────────────────────────────────────
            _WebActionBtn(
              icon: liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              iconColor: liked ? const Color(0xFFFF3B5C) : ext.greetingColor,
              count: likeCount,
              countColor: liked ? const Color(0xFFFF3B5C) : ext.greetingColor,
              iconSize: iconSize,
              onTap: onLike,
            ),
            const SizedBox(height: 28),
            _WebActionBtn(
              icon: disliked
                  ? Icons.thumb_down_rounded
                  : Icons.thumb_down_outlined,
              iconColor: disliked ? const Color(0xFF5B6EF5) : ext.greetingColor,
              count: dislikeCount,
              countColor:
                  disliked ? const Color(0xFF5B6EF5) : ext.greetingColor,
              iconSize: iconSize,
              onTap: onDislike,
            ),
            const SizedBox(height: 28),
            _WebActionBtn(
              icon: commentsEnabled
                  ? Icons.mode_comment_outlined
                  : Icons.comments_disabled_outlined,
              iconColor: commentsEnabled
                  ? ext.greetingColor
                  : ext.searchHintColor.withValues(alpha: 0.4),
              count: commentCount,
              countColor: commentsEnabled
                  ? ext.greetingColor
                  : ext.searchHintColor.withValues(alpha: 0.4),
              iconSize: iconSize,
              onTap: onComment,
            ),
            const SizedBox(height: 28),
            _WebActionBtn(
              icon: saved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              iconColor: saved ? ext.accentGold : ext.greetingColor,
              count: null,
              countColor: ext.greetingColor,
              iconSize: iconSize,
              onTap: onSave,
            ),
            const SizedBox(height: 28),
            _WebActionBtn(
              icon: Icons.near_me_outlined,
              iconColor: ext.greetingColor,
              count: null,
              countColor: ext.greetingColor,
              iconSize: iconSize,
              onTap: onShare,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Web creator pin — avatar with TikTok-style follow/unfollow badge ──────────

class _WebCreatorPin extends StatefulWidget {
  const _WebCreatorPin({
    required this.name,
    required this.photographerId,
    required this.isFollowed,
    required this.isOwner,
    required this.isAuthenticated,
    required this.ext,
    this.onTap,
    this.onLoginRequired,
  });

  final String name;
  final String photographerId;
  final bool isFollowed;
  final bool isOwner;
  final bool isAuthenticated;
  final AppThemeExtension ext;
  final VoidCallback? onTap;
  final VoidCallback? onLoginRequired;

  @override
  State<_WebCreatorPin> createState() => _WebCreatorPinState();
}

class _WebCreatorPinState extends State<_WebCreatorPin> {
  late bool _following;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _following = widget.isFollowed ||
        FollowRepository.followedIds.contains(widget.photographerId);
  }

  Future<void> _toggle() async {
    if (_loading || widget.photographerId.isEmpty) return;
    if (!widget.isAuthenticated) {
      widget.onLoginRequired?.call();
      return;
    }
    final willFollow = !_following;
    setState(() { _following = willFollow; _loading = true; });
    try {
      if (willFollow) {
        await FollowRepository().follow(widget.photographerId);
      } else {
        await FollowRepository().unfollow(widget.photographerId);
      }
    } catch (_) {
      if (mounted) setState(() => _following = !willFollow);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
    final ext = widget.ext;

    return SizedBox(
      width: 48,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // ── Avatar ──────────────────────────────────────────────────────
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [ext.accentGold, const Color(0xFFFF6B35)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: ext.accentGold.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFFFAB40), Color(0xFFFF6B35)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Follow / unfollow badge — bottom-center of avatar ───────────
          if (!widget.isOwner)
            Positioned(
              bottom: -8,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _toggle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _following
                          ? Colors.white.withValues(alpha: 0.9)
                          : const Color(0xFFFF3B5C),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ext.homeBackground,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _loading
                          ? SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: _following
                                    ? Colors.black54
                                    : Colors.white,
                              ),
                            )
                          : Icon(
                              _following
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              size: 13,
                              color: _following ? Colors.black54 : Colors.white,
                            ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Web: single action button (icon + count, hover-scale) ────────────────────

class _WebActionBtn extends StatefulWidget {
  const _WebActionBtn({
    required this.icon,
    required this.iconColor,
    required this.count,
    required this.countColor,
    required this.onTap,
    this.iconSize,
  });

  final IconData icon;
  final Color iconColor;
  final int? count;
  final Color countColor;
  /// Null disables the button (dimmed, non-interactive).
  final VoidCallback? onTap;
  /// Override icon size; when null falls back to 28.sp.
  final double? iconSize;

  @override
  State<_WebActionBtn> createState() => _WebActionBtnState();
}

class _WebActionBtnState extends State<_WebActionBtn> {
  bool _hovered = false;

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return MouseRegion(
      cursor:
          enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) { if (enabled) setState(() => _hovered = true); },
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.14 : 1.0,
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Light circular background behind each icon
              Container(
                width: (widget.iconSize ?? 28.sp) + 16,
                height: (widget.iconSize ?? 28.sp) + 16,
                decoration: BoxDecoration(
                  color: widget.iconColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, color: widget.iconColor,
                    size: widget.iconSize ?? 28.sp),
              ),
              if (widget.count != null && widget.count! > 0) ...[
                const SizedBox(height: 4),
                Text(
                  _fmt(widget.count!),
                  style: TextStyle(
                    color: widget.countColor,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
