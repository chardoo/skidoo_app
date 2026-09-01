import 'dart:async';

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
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/utils/open_event_photos.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_card/explore_event_cta.dart';
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
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:jperg_app/features/music/presentation/feed_music_controller.dart';
import 'package:jperg_app/features/music/presentation/widgets/feed_music_pill.dart';
import 'package:jperg_app/features/music/presentation/widgets/feed_volume_button.dart';
import 'package:jperg_app/features/music/presentation/widgets/music_track_sheet.dart';

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

  /// Whether this card is the one the person is actually looking at.
  ///
  /// Both the soundtrack and the automatic slide hang off this, and both are
  /// wrong in the same embarrassing way if it drifts: sound over the wrong
  /// post, photos moving on a card nobody can see. It is deliberately
  /// *derived* rather than tracked with a flag — an answer computed fresh on
  /// every rebuild cannot fall out of step with the screen.
  bool get _cardIsInFront {
    // Not the card in focus. The same notifier that gates video playback, so
    // sound, picture and slide can never disagree about which card is current.
    if (widget.activeCardIndex.value != widget.cardIndex) return false;

    // Off-screen but still mounted: an inactive tab of Home's IndexedStack, or
    // an inactive pill tab inside it. TickerMode is how this app already
    // answers that question — JpergVideoPlayer reads the same signal — and it
    // composes down the tree, so one disabled ancestor covers every feed
    // beneath it. Reading it here also registers the dependency that rebuilds
    // this card when the answer changes.
    if (!TickerMode.valuesOf(context).enabled) return false;

    // Anything was pushed over the feed — the event's photos, a profile, a
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

  /// Whether this card should have the feed's sound right now.
  bool get _wantsMusic {
    // Nothing to play. The overwhelmingly common case — most events are
    // unscored — and the cheapest check, so it goes first.
    if (widget.event.music.isEmpty) return false;

    // A video slide brings its own audio. Two soundtracks at once is the one
    // outcome nobody wants, so the music yields — and comes back the moment
    // the carousel returns to a photo.
    if (_activeMediaIsVideo) return false;

    return _cardIsInFront;
  }

  // ── The automatic slide ────────────────────────────────────────────────────
  //
  // A card that lands and sits there introduces its album on its own: the
  // photos step forward every few seconds until the third, where the "Explore
  // event photos" offer comes up and the stepping stops for good. It is an
  // introduction, not a slideshow — nobody asked to watch an album hands-free,
  // and a carousel that keeps moving under a reader is an argument with them.

  /// Photos between one showing of the CTA and the next, and equally the point
  /// the automatic slide gives up. Both are the same number in the design and
  /// for the same reason: the third photo is where the offer belongs.
  static const int _exploreEvery = 3;

  Timer? _slideTimer;

  /// Set once the slide has done its job, and never unset. Reaching the third
  /// photo ends it; so does a swipe, because the moment somebody drives the
  /// carousel themselves, a second hand on the wheel is the last thing they
  /// want.
  bool _slideDone = false;

  /// Whether the page change now arriving is one this card asked for. Without
  /// it every automatic step would read as a human swipe and stop the slide on
  /// its own first move.
  bool _selfDrivenSlide = false;

  bool get _wantsAutoSlide {
    if (_slideDone) return false;

    // Paced by the super admin, and zero is the off switch — see AppConfig.
    if (AppConfigRepository.current.feedSlideIntervalSeconds <= 0) return false;

    final pics = widget.event.pictures;
    if (pics.length < 2) return false;

    // At (or past) the photo the CTA belongs on. Nothing further is automatic.
    if (_mediaIndex >= _exploreEvery - 1) return false;

    // A clip is playing with its own sound and its own length. Sliding off it
    // after a few seconds would cut it mid-sentence, so the slide waits for a
    // swipe here rather than talking over the video.
    if (_activeMediaIsVideo) return false;

    return _cardIsInFront;
  }

  /// Safe to call on every rebuild and every change of circumstance: it either
  /// arms the timer or cancels it, and re-arming one already armed is a no-op.
  void _syncAutoSlide() {
    if (!_wantsAutoSlide) {
      _slideTimer?.cancel();
      _slideTimer = null;
      return;
    }
    _slideTimer ??= Timer(
      Duration(seconds: AppConfigRepository.current.feedSlideIntervalSeconds),
      _advanceSlide,
    );
  }

  void _advanceSlide() {
    _slideTimer = null;
    // The circumstances can have changed in the seconds since this was armed —
    // the card scrolled away, a sheet opened, the admin turned it off.
    if (!mounted || !_wantsAutoSlide || !_mediaPageCtrl.hasClients) return;

    final next = _mediaIndex + 1;
    if (next >= widget.event.pictures.length) {
      _slideDone = true;
      return;
    }
    _selfDrivenSlide = true;
    _mediaPageCtrl.animateToPage(
      next,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  /// Whether the CTA belongs on the photo showing now: where the slide stops,
  /// every third photo after that, and the last photo of the album — which for
  /// a single-photo post is the first one, and has to be, or that post would
  /// have no way into the viewer at all now that a tap belongs to the chrome.
  bool get _showExploreCta {
    final pics = widget.event.pictures;
    if (pics.isEmpty) return false;
    if (_mediaIndex == pics.length - 1) return true;
    return (_mediaIndex + 1) % _exploreEvery == 0;
  }

  /// What the offer says, which depends on what is behind it.
  ///
  /// A post with one photo has no album: "Explore event photos" there promises
  /// a set that does not exist, and whoever taps it lands on the single picture
  /// they were already looking at, wondering where the rest went. The offer is
  /// still worth making — a tap belongs to the chrome now, so this is the only
  /// way to see that photo properly — it just has to say what it does.
  String get _exploreCtaLabel {
    final pics = widget.event.pictures;
    if (pics.length != 1) return 'Explore event photos';
    return pics.first.isVideo
        ? ExploreEventCta.forOneVideo
        : ExploreEventCta.forOneImage;
  }

  /// Opens the album in the shared full-screen viewer, at the photo on screen.
  void _openEventPhotos() {
    // On the guest feed [onTap] is the login sheet, and the album is what
    // signing in buys — the same bargain every reaction on this card makes.
    if (!widget.isAuthenticated) {
      widget.onTap();
      return;
    }
    openEventPhotos(context, widget.event, initialIndex: _mediaIndex);
  }

  /// A tap on the photo shows the navigation bar and the sound control, or
  /// sends them away again.
  ///
  /// It used to open the event. Nothing opens on a tap now — the way into the
  /// album is the "Explore event photos" offer, which appears where a reader
  /// is most likely to want it. The trade is deliberate: the chrome is what
  /// somebody reaches for repeatedly while reading a feed, and a full-bleed
  /// photo leaves nowhere else to put that gesture.
  void _onCardTapped() {
    if (!widget.isAuthenticated) {
      widget.onTap();
      return;
    }
    FeedChrome.toggle();
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
    if (!mounted) return;
    _syncMusic();
    _syncAutoSlide();
  }

  @override
  void initState() {
    super.initState();
    widget.activeCardIndex.addListener(_onActiveCardChanged);
    // The caption steps up out of the navigation bar's way when it appears,
    // and the sound control appears with it — see [_captionBottom].
    FeedChrome.visible.addListener(_onChromeChanged);
  }

  void _onChromeChanged() {
    if (mounted) setState(() {});
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
    // Same reason it is here rather than in initState: the slide waits on
    // TickerMode and the route, and this is the first point either can be read.
    _syncAutoSlide();
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
    if (old.event.id != widget.event.id) {
      // A new post has not been introduced yet, whatever the last one did.
      _slideDone = false;
      _syncMusic();
      _syncAutoSlide();
    }
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

  /// Where the caption sits above the bottom edge.
  ///
  /// The event's name, its description, the track and the hashtags are the
  /// post — the navigation bar is a visitor. When the bar comes up the caption
  /// steps over it rather than being buried under frosted glass, which is what
  /// used to happen: the last line of a caption and the music pill sat behind
  /// the bar and simply could not be read.
  double get _captionBottom {
    final base = _activeMediaIsVideo ? (24 + _videoControlsBand).h : 24.h;
    return FeedChrome.visible.value ? base + _navBand : base;
  }

  bool _sharingExternal = false;

  @override
  void dispose() {
    widget.activeCardIndex.removeListener(_onActiveCardChanged);
    FeedChrome.visible.removeListener(_onChromeChanged);
    _slideTimer?.cancel();
    // Hands the sound back before going: a card scrolled out of the PageView's
    // cache would otherwise keep the feed's one player held for a post that no
    // longer exists, and nothing else would ever release it.
    _music?.release(this);
    _mediaPageCtrl.dispose();
    super.dispose();
  }

  /// What the card was built holding — the Feed tab's copy of this post, or
  /// Following's, or a profile's. The bloc prefers its own record where it has
  /// one and falls back to this, which is what lets a post the bloc never
  /// fetched be liked at all.
  EventReactionState get _ownReaction => EventReactionState(
        likes: widget.event.likes,
        dislikes: widget.event.dislikes,
        userReaction: widget.event.userReaction,
      );

  void _toggleLike() {
    if (!widget.isAuthenticated) {
      widget.onTap();
      return;
    }
    final reaction =
        context.read<DiscoveryBloc>().state.reactions[widget.event.id] ??
            _ownReaction;
    context.read<DiscoveryBloc>().add(DiscoveryReactionToggled(
          widget.event.id,
          isLike: !reaction.liked,
          snapshot: _ownReaction,
        ));
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
            onTap: _onCardTapped,
            cardIndex: widget.cardIndex,
            activeCardIndex: widget.activeCardIndex,
            onMediaChanged: (i) {
              if (i == _mediaIndex) return;

              // A change this card did not ask for is a swipe, and a swipe
              // ends the automatic slide — see [_slideDone].
              final wasSelfDriven = _selfDrivenSlide;
              _selfDrivenSlide = false;
              if (!wasSelfDriven) _slideDone = true;

              setState(() => _mediaIndex = i);

              // Where the CTA lives, and so where the slide has finished its
              // job even when it got there under its own power.
              if (i >= _exploreEvery - 1) _slideDone = true;

              // Swiping onto a video silences the music and swiping back off
              // one restores it — see [_wantsMusic].
              _syncMusic();
              _syncAutoSlide();
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
          //
          // The scrim, the caption and the rail are all chrome over the photo,
          // and all of it goes while a comment sheet is open — see
          // [CommentSheetHide]. The band above the sheet is media and nothing
          // else, which is what the designs draw.
          const Positioned(
            left: 0,
            right: 0,
            bottom: _navBand,
            height: 220,
            child: CommentSheetHide(
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
          ),

          // ── "Explore event photos" ───────────────────────────────────────
          //
          // Centred on the photo rather than tucked into a corner: it is the
          // way into the album now that a tap belongs to the chrome, and it
          // has to be found without being hunted for. It comes and goes with
          // the photo showing — see [_showExploreCta].
          if (_showExploreCta)
            Positioned.fill(
              child: CommentSheetHide(
                child: Align(
                  alignment: const Alignment(0, -0.05),
                  child: ExploreEventCta(
                    label: _exploreCtaLabel,
                    onTap: _openEventPhotos,
                  ),
                ),
              ),
            ),

          // ── Sound switch ─────────────────────────────────────────────────
          //
          // Rides in the navigation bar's band and appears with it. Only when
          // this card actually holds the feed's player: a mute button on a post
          // making no sound is a control with nothing to control, and there is
          // exactly one player, so at most one card can offer it.
          if (_music != null && FeedChrome.visible.value)
            ValueListenableBuilder<FeedMusicNowPlaying?>(
              valueListenable: _music!.nowPlaying,
              builder: (context, playing, _) {
                if (playing == null || playing.eventId != event.id) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  right: 16.w,
                  bottom: _navBand + 8,
                  child: CommentSheetHide(
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _music!.muted,
                      builder: (context, muted, __) => FeedVolumeButton(
                        muted: muted,
                        onTap: _music!.toggleMute,
                      ),
                    ),
                  ),
                );
              },
            ),

          // ── Bottom-left caption ──────────────────────────────────────────
          // Sits above the video's scrubber rather than over it — see
          // [_videoControlsBand] — and steps up over the navigation bar when
          // that appears, see [_captionBottom].
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left: 16.w,
            right: 88.w,
            bottom: _captionBottom,
            child: CommentSheetHide(
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
                              onOpenTrack: () => MusicTrackSheet.show(
                                context,
                                playing.track,
                              ),
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
          ),

          // ── Right action rail ─────────────────────────────────────────────
          Positioned(
            right: 12.w,
            top: 0,
            bottom: 0,
            child: CommentSheetHide(
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
                    // The bookmark and the heart both read bloc state: the
                    // reaction has to come from there rather than from the
                    // event this card was built with, or a like in Following
                    // would be recorded and never shown — see
                    // [EventReactionState].
                    BlocBuilder<DiscoveryBloc, DiscoveryState>(
                      buildWhen: (prev, next) =>
                          prev.savedEventIds != next.savedEventIds ||
                          prev.reactions[widget.event.id] !=
                              next.reactions[widget.event.id],
                      builder: (context, state) {
                        // The bloc's record where it has one, this card's own
                        // copy otherwise — the first time a post is liked in
                        // Following there is nothing in the bloc yet.
                        final reaction =
                            state.reactions[event.id] ?? _ownReaction;
                        return MediaReactionRail(
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
                                liked: reaction.liked,
                                count: reaction.likes,
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
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
