import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:jperg_app/core/cache/jperg_image_cache.dart';
import 'package:flutter/material.dart';
import 'package:jperg_app/components/comments/comment_sheet_scope.dart';
import 'package:jperg_app/components/media/media_reaction_rail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/components/media/media_action_buttons.dart';
import 'package:jperg_app/components/media/share_target_sheet.dart';
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
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/music/presentation/feed_music_controller.dart';
import 'package:jperg_app/features/music/presentation/widgets/feed_music_pill.dart';

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

  FeedMusicController? _music;

  /// Whether this card should have the feed's sound right now.
  ///
  /// Every one of these has to hold, and any of them going false silences the
  /// card. They are deliberately all *derived* rather than tracked with flags:
  /// a card that computes the answer fresh on every rebuild cannot drift out
  /// of step with the screen, which is the failure mode that makes feed audio
  /// play over the wrong thing.
  bool get _wantsMusic {
    // Nothing to play. The overwhelmingly common case — most events are
    // unscored — and the cheapest check, so it goes first.
    if (widget.event.music.isEmpty) return false;

    // Not the card in focus. The same notifier that gates video playback, so
    // sound and picture can never disagree about which card is current.
    if (widget.activeCardIndex.value != widget.cardIndex) return false;

    // A video slide brings its own audio. Two soundtracks at once is the one
    // outcome nobody wants, so the music yields — and comes back the moment
    // the carousel returns to a photo.
    if (_activeMediaIsVideo) return false;

    // Off-screen but still mounted: an inactive tab of Home's IndexedStack, or
    // an inactive pill tab inside it. TickerMode is how this app already
    // answers that question — JpergVideoPlayer reads the same signal — and it
    // composes down the tree, so one disabled ancestor covers every feed
    // beneath it. Reading it here also registers the dependency that rebuilds
    // this card when the answer changes.
    if (!TickerMode.valuesOf(context).enabled) return false;

    // Anything was pushed over the feed — the event's pictures, a profile, a
    // deep link, or a modal sheet, since a sheet is a route too and
    // `isCurrent` does not distinguish. So opening comments or the share sheet
    // pauses the music and closing them resumes it, which is a defensible
    // place to land: someone reading a comment thread is no longer watching.
    // Telling the two apart would mean a RouteObserver<PageRoute> and a
    // subscription per card, which is a lot of machinery for a debatable
    // difference — worth revisiting only if the pause turns out to grate.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return false;

    return true;
  }

  /// Pushes [_wantsMusic] to the controller. Safe to call on every build —
  /// claiming what this card already owns is a no-op.
  void _syncMusic() {
    final music = _music;
    if (music == null) return;
    if (_wantsMusic) {
      music.claim(this, widget.event.id, widget.event.music);
    } else {
      music.release(this);
    }
  }

  void _onActiveCardChanged() {
    if (mounted) _syncMusic();
  }

  @override
  void initState() {
    super.initState();
    widget.activeCardIndex.addListener(_onActiveCardChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolved here rather than in initState: the locator is fine either way,
    // but TickerMode and ModalRoute are inherited, and this is the first point
    // both can be read — and the callback for whenever either changes.
    //
    // Absent from the locator is a supported state, not a bug to assert on: a
    // card is a card without music, and a widget test that mounts one to check
    // its share sheet should not have to stand up an audio stack to do it.
    // This is the same stance the rest of the feature takes — music never
    // stops a feed from working.
    _music ??= sl.isRegistered<FeedMusicController>()
        ? sl<FeedMusicController>()
        : null;
    _syncMusic();
  }

  @override
  void didUpdateWidget(FullBleedEventCard old) {
    super.didUpdateWidget(old);
    if (!identical(old.activeCardIndex, widget.activeCardIndex)) {
      old.activeCardIndex.removeListener(_onActiveCardChanged);
      widget.activeCardIndex.addListener(_onActiveCardChanged);
    }
    // A recycled card is a different post with the same State — the feed's
    // ValueKey usually prevents it, but a soundtrack that outlived its event
    // would be the worst kind of wrong, so this re-decides rather than assumes.
    if (old.event.id != widget.event.id) _syncMusic();
  }

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

  /// The strip along the bottom the floating nav bar occupies.
  ///
  /// Left clear of the caption scrim so the bar has real photo behind it to
  /// frost. Roughly the pill's height plus the margin it floats on; it does
  /// not have to be exact, only to keep the darkest end of the gradient out
  /// from under the glass.
  static const double _navBand = 96;

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
    widget.activeCardIndex.removeListener(_onActiveCardChanged);
    // Hands the sound back before going: a card scrolled out of the PageView's
    // cache would otherwise keep the feed's one player held for a post that no
    // longer exists, and nothing else would ever release it.
    _music?.release(this);
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

  /// Asks where the post is going, then goes there. See [ShareTargetSheet].
  void _openShareTargets() {
    if (!widget.isAuthenticated) {
      widget.onTap();
      return;
    }
    if (widget.event.pictures.isEmpty) return;
    ShareTargetSheet.show(
      context,
      title: 'Share this event',
      onInApp: _share,
      onExternal: _shareExternal,
    );
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

    // Scales up out of the way when a comment sheet opens — see
    // [CommentPushArea].
    return CommentPushArea(
      child: Stack(
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
              if (i == _mediaIndex) return;
              setState(() => _mediaIndex = i);
              // Swiping onto a video silences the music and swiping back off
              // one restores it — see [_wantsMusic].
              _syncMusic();
            },
          ),

          // ── Bottom gradient scrim for text legibility ───────────────────
          //
          // It stops short of the very bottom, and that is deliberate: the
          // floating nav bar sits in the last ~100px, and this used to run to
          // 67 % black straight underneath it. The bar frosts whatever is
          // behind it, so it was faithfully blurring a near-black gradient and
          // reading as an opaque slab — no tint or blur radius could have
          // fixed that, because there was genuinely nothing back there to see.
          //
          // The caption sits above this band, so it keeps the contrast it
          // needs; the strip the bar occupies is left as photo.
          Positioned(
            left: 0,
            right: 0,
            bottom: _navBand,
            height: 220,
            child: const IgnorePointer(
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
            bottom: _activeMediaIsVideo ? (24 + _videoControlsBand).h : 24.h,
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
                // ── Now playing ─────────────────────────────────────────────
                // Lit only while this card actually holds the feed's one
                // player, so exactly one pill can be visible at a time. A
                // scored event whose turn has not come shows nothing, which is
                // the honest answer — the pill is a statement about sound, not
                // a badge saying music exists.
                if (_music != null)
                  ValueListenableBuilder<FeedMusicNowPlaying?>(
                    valueListenable: _music!.nowPlaying,
                    builder: (context, playing, _) {
                      if (playing == null || playing.eventId != event.id) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: EdgeInsets.only(top: AppSpacing.xs.h),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _music!.muted,
                          builder: (context, muted, __) => FeedMusicPill(
                            track: playing.track,
                            muted: muted,
                            onToggleMute: _music!.toggleMute,
                          ),
                        ),
                      );
                    },
                  ),
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
                            backgroundImage:
                                event.photographerProfileUrl != null
                                    ? CachedNetworkImageProvider(
                                        event.photographerProfileUrl!,
                                        cacheManager: kIsWeb
                                            ? null
                                            : JpergImageCache.instance,
                                      )
                                    : null,
                            child: event.photographerProfileUrl == null
                                ? Text(
                                    event.photographerName.isNotEmpty
                                        ? event.photographerName[0]
                                            .toUpperCase()
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
                        // Like disappears when engagement is off; comment stays
                        // and is drawn unavailable. They are not the same case:
                        // a missing heart says nothing, but a rail with no
                        // comment button at all reads as one that never had one,
                        // and the owner having closed the thread is worth
                        // stating. Same split the card bar and the web column
                        // already make.
                        if (_engagementAllowed)
                          MediaReaction.like(
                            liked: liked,
                            count: event.likes,
                            onTap: _toggleLike,
                          ),
                        if (_engagementAllowed)
                          MediaReaction.comment(
                            count: event.commentCount,
                            onTap: _openComments,
                          )
                        else
                          MediaReaction.commentsDisabled(
                            count: event.commentCount,
                          ),
                        MediaReaction.bookmark(
                          saved: state.savedEventIds.contains(event.id),
                          onTap: _toggleSave,
                        ),
                        // One button, two destinations, named in the sheet it
                        // opens — the paper plane and the share arrow beside it
                        // were two buttons for one intention.
                        MediaReaction.share(
                          busy: _sharingExternal,
                          onTap: _openShareTargets,
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
      ),
    );
  }
}
