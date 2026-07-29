import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:skidoo_app/components/media/media_rail_action.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/components/media/media_action_buttons.dart';
import 'package:skidoo_app/core/common/widgets/expandable_caption.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/event_comment_page.dart';
import 'package:skidoo_app/features/discovery/presentation/utils/open_photographer_profile.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_interaction_bar.dart' show FollowButton;
import 'package:skidoo_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/event_more_options_sheet.dart';
import 'package:skidoo_app/features/gallery/presentation/widgets/gallery_share_sheet.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

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
    context.read<DiscoveryBloc>().add(
        DiscoveryReactionToggled(widget.event.id, isLike: !liked));
  }

  void _toggleSave() {
    if (!widget.isAuthenticated) {
      widget.onTap();
      return;
    }
    context.read<DiscoveryBloc>().add(DiscoveryEventSaveToggled(widget.event.id));
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
          onDoubleTap: _toggleLike,
          onTap: widget.onTap,
          cardIndex: widget.cardIndex,
          activeCardIndex: widget.activeCardIndex,
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
        Positioned(
          left: 16.w,
          right: 88.w,
          bottom: 24.h,
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
                            ? CachedNetworkImageProvider(event.photographerProfileUrl!)
                            : null,
                        child: event.photographerProfileUrl == null
                            ? Text(
                                event.photographerName.isNotEmpty
                                    ? event.photographerName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w700),
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
                      onLoginRequired: widget.isAuthenticated ? null : widget.onTap,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 26.h),
              MediaRailAction(
                icon: Icons.favorite_rounded,
                iconColor: liked ? const Color(0xFFFF3B5C) : Colors.white,
                label: '${event.likes}',
                onTap: _toggleLike,
              ),
              SizedBox(height: AppSpacing.lg.h),
              MediaRailAction(
                icon: Icons.mode_comment_rounded,
                label: '${event.commentCount}',
                onTap: _openComments,
              ),
              SizedBox(height: AppSpacing.lg.h),
              BlocBuilder<DiscoveryBloc, DiscoveryState>(
                buildWhen: (prev, next) => prev.savedEventIds != next.savedEventIds,
                builder: (context, state) {
                  final saved = state.savedEventIds.contains(event.id);
                  return MediaRailAction(
                    icon: Icons.bookmark_rounded,
                    iconColor: saved ? Colors.amberAccent : Colors.white,
                    onTap: _toggleSave,
                  );
                },
              ),
              SizedBox(height: AppSpacing.lg.h),
              MediaRailAction(
                icon: Icons.near_me_rounded,
                onTap: _share,
              ),
              SizedBox(height: AppSpacing.lg.h),
              MediaRailAction(
                icon: Icons.ios_share_rounded,
                busy: _sharingExternal,
                onTap: _shareExternal,
              ),
              SizedBox(height: AppSpacing.lg.h),
              MediaRailAction(
                icon: Icons.more_horiz_rounded,
                onTap: _showMoreOptions,
              ),
            ],
            ),
          ),
        ),
      ],
    );
  }
}
