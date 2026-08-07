import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:jperg_app/components/media/media_reaction_rail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/components/media/media_action_buttons.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/common/widgets/expandable_caption.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/pages/event_comment_page.dart';
import 'package:jperg_app/features/discovery/presentation/utils/open_photographer_profile.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/card_interaction_bar.dart'
    show FollowButton;
import 'package:jperg_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_more_options_sheet.dart';
import 'package:jperg_app/features/gallery/presentation/widgets/gallery_share_sheet.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

/// One full-screen page of the TikTok-style vertical feed — the photo/video
/// carousel fills the entire page edge-to-edge, with the caption and action
/// rail floating on top of it. Purpose-built for the vertical `PageView`
/// feed (see `events_feed.dart`/`following_feed.dart`) rather than a rewrite
/// of `EventDiscoveryCard` — reuses [PostPhotoCarousel] for the swipeable
/// media background (already correctly gates video playback via
/// [cardIndex]/[activeCardIndex]) and [FollowButton] for follow state.
///
/// Deliberately narrower in scope than the original card: no heart-burst
/// double-tap animation, no desktop-web side-panel variant, no guest
/// lock-overlay teaser, no description expand/collapse — just the core
/// swipe/like/comment/save/share/follow interactions, matching the design
/// screenshot this was built from.
class FullBleedEventCard extends StatefulWidget {
  const FullBleedEventCard({
    super.key,
    required this.event,
    required this.cardIndex,
    required this.activeCardIndex,
    required this.onTap,
    required this.onHide,
    this.isAuthenticated = true,
  });

  final EventDiscovery event;
  final int cardIndex;
  final ValueNotifier<int> activeCardIndex;
  final VoidCallback onTap;
  final VoidCallback? onHide;

  /// Defaults to true (the Home feed, which requires login to reach at
  /// all). Set to false on the guest-facing Discovery page — [onTap] then
  /// doubles as the login prompt for every reaction (matches the
  /// established convention in [EventDiscoveryCard]).
  final bool isAuthenticated;

  @override
  State<FullBleedEventCard> createState() => _FullBleedEventCardState();
}

class _FullBleedEventCardState extends State<FullBleedEventCard> {
  final _mediaPageCtrl = PageController();

  /// Which slide of this card's carousel is showing, so the caption knows
  /// whether it is sitting over a video.
  int _mediaIndex = 0;

  /// Vertical space the video player's own controls occupy along the bottom
  /// edge: a 20 dp scrubber, the timestamp row, and 6 dp of padding
  /// (`_BottomBar` in jperg_video_player.dart). The caption is anchored to
  /// the same edge, so without clearing this band it lands on top of the
  /// scrubber — covering the progress bar and stealing the drags that would
  /// seek the video.
  static const double _videoControlsBand = 40;

  /// Whether the owner permits engagement on what is on screen.
  ///
  /// `comments_enabled` is the "no feedback on this" switch, so a disabled
  /// event collects neither comments nor reactions — including the
  /// double-tap-to-like shortcut, which would otherwise be a silent way past
  /// a hidden button.
  bool get _engagementAllowed {
    final pics = widget.event.pictures;
    if (!widget.event.commentsEnabled) return false;
    if (pics.isEmpty) return true;
    return pics[_mediaIndex.clamp(0, pics.length - 1)].commentsEnabled;
  }

  bool get _activeMediaIsVideo {
    final pics = widget.event.pictures;
    if (_mediaIndex < 0 || _mediaIndex >= pics.length) return false;
    return pics[_mediaIndex].isVideo;
  }
  bool _sharingExternal = false;

  @override
  void dispose() {
    _mediaPageCtrl.dispose();
    super.dispose();
  }

  void _toggleLike() {
    if (!widget.isAuthenticated) {
      widget.onTap();
      return;
    }
    final liked = widget.event.userReaction == 'like';
    context
        .read<DiscoveryBloc>()
        .add(DiscoveryReactionToggled(widget.event.id, isLike: !liked));
  }

  void _toggleSave() {
    if (!widget.isAuthenticated) {
      widget.onTap();
      return;
    }
    context
        .read<DiscoveryBloc>()
        .add(DiscoveryEventSaveToggled(widget.event.id));
  }

  void _openComments() {
    if (!widget.isAuthenticated) {
      widget.onTap();
      return;
    }
    EventCommentPage.show(context, widget.event);
  }

  void _share() {
    if (!widget.isAuthenticated) {
      widget.onTap();
      return;
    }
    final event = widget.event;
    if (event.pictures.isEmpty) return;
    GalleryShareSheet.show(
      context,
      imageUrl: event.pictures.first.url,
      photoLabel: event.eventName,
    );
  }

  /// Direct native OS share — its own tap target on the rail, not nested
  /// inside the "Send" sheet opened by [_share].
  Future<void> _shareExternal() async {
    if (!widget.isAuthenticated) {
      widget.onTap();
      return;
    }
    if (_sharingExternal) return;
    final event = widget.event;
    if (event.pictures.isEmpty) return;
    setState(() => _sharingExternal = true);
    try {
      await shareOverlayPhotoExternally(
        context,
        imageId: event.pictures.first.id,
        photographerName: event.photographerName,
        eventName: event.eventName,
        description: event.description,
        link: DeepLink(DeepLinkKind.event, id: event.id),
      );
    } finally {
      if (mounted) setState(() => _sharingExternal = false);
    }
  }

  void _openPhotographerProfile() {
    final event = widget.event;
    openPhotographerProfile(
      context,
      photographerId: event.photographerId,
      photographerName: event.photographerName,
      photographerProfileUrl: event.photographerProfileUrl,
    );
  }

  void _showMoreOptions() {
    if (!widget.isAuthenticated) {
      widget.onTap();
      return;
    }
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
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

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final liked = event.userReaction == 'like';

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Full-bleed media background ─────────────────────────────────
        PostPhotoCarousel(
          pics: event.pictures,
          pageController: _mediaPageCtrl,
          showBlur: false,
          onDoubleTap: _engagementAllowed ? _toggleLike : () {},
          onTap: widget.onTap,
          cardIndex: widget.cardIndex,
          activeCardIndex: widget.activeCardIndex,
          onMediaChanged: (i) {
            if (i != _mediaIndex) setState(() => _mediaIndex = i);
          },
        ),

        // ── Bottom gradient scrim for text legibility ───────────────────
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 220,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xAA000000)],
                ),
              ),
            ),
          ),
        ),

        // ── Bottom-left caption ──────────────────────────────────────────
        // Sits above the video's scrubber rather than over it — see
        // [_videoControlsBand].
        Positioned(
          left: 16.w,
          right: 88.w,
          bottom: _activeMediaIsVideo
              ? (24 + _videoControlsBand).h
              : 24.h,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                event.eventName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (event.description.isNotEmpty) ...[
                SizedBox(height: AppSpacing.xs.h),
                ExpandableCaption(
                  text: event.description,
                  collapsedMaxLines: 2,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13.sp,
                    height: 1.3,
                  ),
                  linkStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (event.contentTags.isNotEmpty) ...[
                SizedBox(height: AppSpacing.xs.h),
                ExpandableCaption(
                  text: event.contentTags.map((t) => '#$t').join(' '),
                  collapsedMaxLines: 2,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13.sp,
                    height: 1.3,
                  ),
                  linkStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),

        // ── Right action rail ─────────────────────────────────────────────
        Positioned(
          right: 12.w,
          top: 0,
          bottom: 0,
          child: Align(
            alignment: const Alignment(0, 0.4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.bottomCenter,
                  children: [
                    Semantics(
                      button: true,
                      label: "View ${event.photographerName}'s profile",
                      child: GestureDetector(
                        onTap: _openPhotographerProfile,
                        child: CircleAvatar(
                          radius: 20.r,
                          backgroundColor: Colors.white24,
                          backgroundImage: event.photographerProfileUrl != null
                              ? CachedNetworkImageProvider(
                                  event.photographerProfileUrl!)
                              : null,
                          child: event.photographerProfileUrl == null
                              ? Text(
                                  event.photographerName.isNotEmpty
                                      ? event.photographerName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700),
                                )
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -8.h,
                      child: FollowButton(
                        photographerId: event.photographerId,
                        onImage: true,
                        compact: true,
                        initialFollowing: event.isFollowed,
                        onLoginRequired:
                            widget.isAuthenticated ? null : widget.onTap,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 26.h),
                // Only the bookmark reads bloc state, but the rail is one
                // widget now, so the builder wraps the lot.
                BlocBuilder<DiscoveryBloc, DiscoveryState>(
                  buildWhen: (prev, next) =>
                      prev.savedEventIds != next.savedEventIds,
                  builder: (context, state) => MediaReactionRail(
                    actions: [
                      if (_engagementAllowed) ...[
                        MediaReaction.like(
                          liked: liked,
                          count: event.likes,
                          onTap: _toggleLike,
                        ),
                        MediaReaction.comment(
                          count: event.commentCount,
                          onTap: _openComments,
                        ),
                      ],
                      MediaReaction.bookmark(
                        saved: state.savedEventIds.contains(event.id),
                        onTap: _toggleSave,
                      ),
                      MediaReaction.send(onTap: _share),
                      MediaReaction.shareExternally(
                        busy: _sharingExternal,
                        onTap: _shareExternal,
                      ),
                      MediaReaction.more(onTap: _showMoreOptions),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
