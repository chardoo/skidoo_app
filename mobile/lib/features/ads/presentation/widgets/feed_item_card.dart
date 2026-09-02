import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';

import 'package:jperg_app/components/comments/comment_sheet_scope.dart';
import 'package:jperg_app/components/media/media_reaction_rail.dart';
import 'package:jperg_app/core/cache/comment_counts.dart';
import 'package:jperg_app/core/common/widgets/get_app_sheet.dart';
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/core/widgets/media_backdrop.dart';
import 'package:jperg_app/core/widgets/video_player/jperg_video_player.dart';
import 'package:jperg_app/features/ads/data/models/ad_model.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/models/ad.dart';
import 'package:jperg_app/features/ads/models/ad_campaign.dart';
import 'package:jperg_app/features/ads/models/ad_media.dart';
import 'package:jperg_app/features/ads/presentation/widgets/media_carousel.dart';
import 'package:jperg_app/features/ads/presentation/pages/feed_comment_sheet.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/card_photo_preview.dart'
    show CardGradientPlaceholder;
import 'package:jperg_app/features/discovery/presentation/widgets/report_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model — same shape for campaigns and requests
// ─────────────────────────────────────────────────────────────────────────────

enum FeedItemType { ad, request }

class FeedItemData {
  const FeedItemData({
    required this.type,
    required this.id,
    required this.title,
    required this.creatorName,
    this.campaignId = '',
    this.creatorId = '',
    this.creatorPhotoUrl,
    this.mediaUrl,
    this.mediaIsVideo = false,
    this.mediaList = const <AdMedia>[],
    this.body,
    this.contentTags = const <String>[],
    this.commentsEnabled = true,
    this.commentCount = 0,
    this.likeCount = 0,
    this.viewerLiked = false,
    this.eventDate,
    this.eventTime,
    this.location,
    this.coverageLabel,
    this.budgetLabel,
    this.viewerInterested = false,
    this.ctaLabel,
    this.ctaUrl,
    this.onCtaTap,
    this.onInit,
  });

  final FeedItemType type;

  /// ad_id or request_id — what a comment is filed against.
  final String id;

  /// The campaign the ad belongs to. Likes are counted per campaign, not per
  /// creative: one campaign runs an ad per placement, and nobody thinks of
  /// theirs as having separate numbers in the feed and in explore.
  final String campaignId;

  /// headline (campaign) · request title
  final String title;

  /// advertiser name (campaign) · requester name
  final String creatorName;
  final String creatorId;
  final String? creatorPhotoUrl;

  final String? mediaUrl;
  final bool mediaIsVideo;

  /// Ordered media. Falls back to wrapping [mediaUrl] for older payloads.
  final List<AdMedia> mediaList;

  /// Body copy (campaign) · description (request).
  final String? body;

  /// "#wedding #photography" — campaign copy the advertiser wrote. Not the
  /// campaign's targeting interests, which say who sees it rather than what it
  /// is about.
  final List<String> contentTags;

  final bool commentsEnabled;
  final int commentCount;

  /// Campaign only. Real, server-side, and per campaign — see [campaignId].
  final int likeCount;
  final bool viewerLiked;

  // ── Request only ─────────────────────────────────────────────────────────
  //
  // The three lines under the title on a request card: when, where, and how
  // much of the day. Each is null on requests that did not say, and the row is
  // left out rather than drawn empty.
  final DateTime? eventDate;

  /// "10:00" at the venue. Shown beside the date when given.
  final String? eventTime;
  final String? location;

  /// "Full Day Coverage (~8 hrs)".
  final String? coverageLabel;

  /// "GHS 4,500 - GHS 6,000".
  final String? budgetLabel;

  /// Whether this viewer has already answered.
  final bool viewerInterested;

  final String? ctaLabel;

  /// Opened in the browser when the CTA is pressed. Null for requests, which
  /// use [onCtaTap] to open the interest sheet instead.
  final String? ctaUrl;
  final VoidCallback? onCtaTap;

  /// Called once after the first frame — the ad impression.
  final VoidCallback? onInit;

  // ── Factories ──────────────────────────────────────────────────────────────

  factory FeedItemData.fromAd(
    AdModel ad, {
    required VoidCallback onCtaTap,
    VoidCallback? onInit,
  }) {
    final mediaList = ad.media.isNotEmpty
        ? ad.media
        : (ad.mediaUrl != null && ad.mediaUrl!.isNotEmpty
            ? [AdMedia(id: '', url: ad.mediaUrl!, mediaType: ad.mediaType)]
            : <AdMedia>[]);
    return FeedItemData(
      type: FeedItemType.ad,
      id: ad.adId,
      campaignId: ad.campaignId,
      title: ad.headline,
      creatorName:
          ad.advertiserName.isNotEmpty ? ad.advertiserName : 'Advertiser',
      creatorId: ad.advertiserId,
      creatorPhotoUrl: ad.advertiserPhoto,
      mediaUrl: ad.mediaUrl,
      mediaIsVideo: ad.isVideo,
      mediaList: mediaList,
      body: ad.body.isNotEmpty ? ad.body : null,
      contentTags: ad.contentTags,
      // The venue the advertiser named, if any. Same field the request card
      // uses for the same thing — where it happens, never who sees it.
      location: (ad.location?.isNotEmpty ?? false) ? ad.location : null,
      commentsEnabled: ad.commentsEnabled,
      commentCount: ad.commentCount,
      likeCount: ad.likeCount,
      viewerLiked: ad.viewerLiked,
      ctaLabel: ad.ctaUrl.isNotEmpty
          ? (ad.ctaText.isEmpty ? 'Learn More' : ad.ctaText)
          : null,
      ctaUrl: ad.ctaUrl.isNotEmpty ? ad.ctaUrl : null,
      onCtaTap: ad.ctaUrl.isNotEmpty ? onCtaTap : null,
      onInit: onInit,
    );
  }

  /// A sponsored slot straight from a campaign, for when the ad-serve endpoint
  /// has nothing to hand back — the campaign is live but not yet through the
  /// targeting pipeline.
  factory FeedItemData.fromCampaign(AdCampaign campaign) {
    Ad? firstAd;
    for (final adSet in campaign.adSets) {
      if (adSet.ads.isNotEmpty) {
        firstAd = adSet.ads.first;
        break;
      }
    }

    // Media priority: the campaign's own uploads, then whatever the creatives
    // carry, then nothing — which draws the gradient.
    List<AdMedia> mediaList = campaign.media;
    if (mediaList.isEmpty) {
      final collected = <AdMedia>[];
      for (final adSet in campaign.adSets) {
        for (final ad in adSet.ads) {
          if (ad.media.isNotEmpty) {
            collected.addAll(ad.media);
          } else if (ad.mediaUrl != null && ad.mediaUrl!.isNotEmpty) {
            collected.add(AdMedia(
              id: ad.id,
              url: ad.mediaUrl!,
              mediaType: ad.mediaType.value,
            ));
          }
        }
      }
      if (collected.isNotEmpty) mediaList = collected;
    }

    final firstMedia = mediaList.isNotEmpty ? mediaList.first : null;
    final title = (firstAd?.headline.isNotEmpty ?? false)
        ? firstAd!.headline
        : campaign.name;
    final body = (firstAd?.body?.isNotEmpty ?? false)
        ? firstAd!.body
        : campaign.objective.label;
    final ctaLabel =
        (firstAd?.ctaText.isNotEmpty ?? false) ? firstAd!.ctaText : null;
    final ctaUrl =
        (firstAd?.ctaUrl.isNotEmpty ?? false) ? firstAd!.ctaUrl : null;

    return FeedItemData(
      type: FeedItemType.ad,
      id: campaign.id,
      campaignId: campaign.id,
      title: title,
      creatorName: (campaign.advertiserName?.isNotEmpty ?? false)
          ? campaign.advertiserName!
          : 'Advertiser',
      creatorId: campaign.advertiserId,
      creatorPhotoUrl: campaign.advertiserPhoto,
      mediaUrl: firstMedia?.url,
      mediaIsVideo: firstMedia?.isVideo ?? false,
      mediaList: mediaList,
      body: body,
      contentTags: campaign.contentTags,
      commentsEnabled: campaign.commentsEnabled,
      commentCount: campaign.commentCount,
      ctaLabel: (ctaUrl != null && ctaUrl.isNotEmpty) ? ctaLabel : null,
      ctaUrl: (ctaUrl != null && ctaUrl.isNotEmpty) ? ctaUrl : null,
      onCtaTap: null,
    );
  }

  factory FeedItemData.fromRequest(
    FeedRequestModel req, {
    /// Answering it — the photographer's only action on a request. Null on
    /// your own, which you cannot answer.
    VoidCallback? onAnswerTap,
  }) {
    final mediaList = req.media.isNotEmpty
        ? req.media
        : (req.assetUrl != null && req.assetUrl!.isNotEmpty
            ? [
                AdMedia(
                    id: '',
                    url: req.assetUrl!,
                    mediaType: req.assetType ?? 'image')
              ]
            : <AdMedia>[]);
    return FeedItemData(
      type: FeedItemType.request,
      id: req.id,
      title: req.title,
      creatorName:
          req.requesterName.isNotEmpty ? req.requesterName : 'Anonymous',
      creatorId: req.requesterId,
      creatorPhotoUrl: req.requesterPhoto,
      mediaUrl: req.assetUrl,
      mediaIsVideo: req.assetType == 'video',
      mediaList: mediaList,
      body: req.description.isNotEmpty ? req.description : null,
      commentsEnabled: req.commentsEnabled,
      commentCount: req.commentCount,
      eventDate: req.eventDate,
      eventTime: req.eventTime,
      location: req.location.isNotEmpty ? req.location : null,
      coverageLabel: req.coverageLabel,
      budgetLabel: req.budgetLabel,
      viewerInterested: req.viewerInterested,
      ctaLabel: req.viewerInterested ? 'Interest sent' : 'Express interest',
      ctaUrl: null,
      onCtaTap: onAnswerTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The card — one full-screen page of the feed, like the event cards beside it
// ─────────────────────────────────────────────────────────────────────────────

/// A sponsored campaign or a photographer request, as a page of the feed.
///
/// It used to be an Instagram-shaped column — header, image, buttons, caption —
/// scaled down inside a [FittedBox] to fit a pager built for full-bleed media.
/// Between two edge-to-edge posts it read as a different app: a small card
/// floating in a black screen, with an avatar and a follow button no other page
/// of the feed had.
///
/// So it is the same page shape as an event now. The media fills the screen,
/// the copy sits on it, and the only things that differ are the ones that
/// should: a pill naming what this is, and a button that does the one thing the
/// card exists for.
class FeedItemCard extends StatefulWidget {
  const FeedItemCard({
    super.key,
    required this.data,
    this.onHide,
    this.isAuthenticated = true,
    this.onLoginRequired,
    this.fullBleed = true,
  });

  final FeedItemData data;
  final VoidCallback? onHide;

  /// Whether this is a page of the feed or a tile in a list.
  ///
  /// The request board deals the same poster into a scrolling list, where two
  /// things about a feed page make no sense: the copy stepping up over a
  /// navigation bar that is always visible there, and a tap toggling chrome
  /// the reader can already see. Everything else — the media, the pill, the
  /// rail, the button — is the same card, which is the point of the flag
  /// rather than a second widget.
  final bool fullBleed;

  /// False for guests — every action calls [onLoginRequired] instead.
  final bool isAuthenticated;
  final VoidCallback? onLoginRequired;

  @override
  State<FeedItemCard> createState() => _FeedItemCardState();
}

class _FeedItemCardState extends State<FeedItemCard> {
  final PageController _pageCtrl = PageController();
  final _repo = AdsRepository();

  int _currentPage = 0;
  bool _initFired = false;
  bool _sharing = false;

  /// The heart, optimistically. Server-backed now — it used to be a bool that
  /// forgot itself the moment the card scrolled out of the pager.
  late bool _liked = widget.data.viewerLiked;
  late int _likes = widget.data.likeCount;

  /// The number on the comment glyph, read live so it moves the moment
  /// somebody comments rather than showing whatever the feed was fetched with
  /// until the list is rebuilt. The comment sheet reports the server's count
  /// here as it posts — see [CommentCounts].
  int get _commentCount =>
      CommentCounts.instance.countFor(widget.data.id) ??
      widget.data.commentCount;

  /// The strip along the bottom the floating nav bar occupies, matched to the
  /// event card's so the two kinds of page put their copy in the same place.
  static const double _navBand = 96;

  @override
  void initState() {
    super.initState();
    _pageCtrl.addListener(() {
      final page = _pageCtrl.page?.round() ?? 0;
      if (page != _currentPage && mounted) setState(() => _currentPage = page);
    });
    FeedChrome.visible.addListener(_rebuild);
    CommentCounts.instance.addListener(_rebuild);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initFired) return;
      _initFired = true;
      widget.data.onInit?.call();
    });
  }

  @override
  void didUpdateWidget(FeedItemCard old) {
    super.didUpdateWidget(old);
    // A recycled slot showing a different campaign must not inherit the last
    // one's heart.
    if (old.data.id != widget.data.id) {
      _liked = widget.data.viewerLiked;
      _likes = widget.data.likeCount;
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    FeedChrome.visible.removeListener(_rebuild);
    CommentCounts.instance.removeListener(_rebuild);
    _pageCtrl.dispose();
    super.dispose();
  }

  /// True when the caller is a guest — and prompts them to sign in.
  bool _requireAuth() {
    if (!widget.isAuthenticated) {
      widget.onLoginRequired?.call();
      return true;
    }
    return false;
  }

  Future<void> _toggleLike() async {
    if (_requireAuth()) return;
    final d = widget.data;
    if (d.campaignId.isEmpty) return;

    HapticFeedback.lightImpact();
    final wasLiked = _liked;
    final wasLikes = _likes;
    setState(() {
      _liked = !wasLiked;
      _likes = (wasLiked ? wasLikes - 1 : wasLikes + 1).clamp(0, 1 << 31);
    });

    final result = await _repo.toggleCampaignLike(d.campaignId);
    if (!mounted) return;
    if (result == null) {
      // Nothing was recorded, so the heart goes back rather than sitting there
      // filled on the strength of a request that failed.
      setState(() {
        _liked = wasLiked;
        _likes = wasLikes;
      });
      return;
    }
    setState(() {
      _liked = result.liked;
      _likes = result.likes;
    });
  }

  void _handleComment() {
    if (_requireAuth()) return;
    final d = widget.data;
    FeedCommentSheet.show(
      context,
      targetType: d.type == FeedItemType.ad ? 'ad' : 'request',
      targetId: d.id,
      title: d.title.isNotEmpty
          ? d.title
          : (d.type == FeedItemType.ad ? 'Ad' : 'Request'),
      subtitle: 'by ${d.creatorName}',
      commentsEnabled: d.commentsEnabled,
    );
  }

  Future<void> _handleShare() async {
    if (_requireAuth()) return;
    if (_sharing) return;
    if (kIsWeb) {
      final ext = Theme.of(context).extension<AppThemeExtension>()!;
      GetAppSheet.show(context, ext: ext);
      return;
    }
    setState(() => _sharing = true);
    try {
      final text =
          widget.data.title.isNotEmpty ? widget.data.title : 'Check this out';
      await Share.share(text, subject: widget.data.title);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _handleCta() async {
    if (_requireAuth()) return;
    final d = widget.data;

    // A request's button opens the interest sheet; there is no URL to follow.
    if (d.type == FeedItemType.request) {
      d.onCtaTap?.call();
      return;
    }

    // A campaign's: count the click, then hand over to the browser.
    d.onCtaTap?.call();
    final raw = d.ctaUrl;
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Could not open that link.');
    }
  }

  void _showMoreOptions() {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    _FeedItemMoreOptionsSheet.show(
      context,
      ext: ext,
      type: widget.data.type,
      assetId: widget.data.id,
      onHide: widget.onHide,
    );
  }

  /// Where the copy sits above the bottom edge — the event card's rule, so the
  /// two kinds of page agree: the block steps over the navigation bar when it
  /// appears rather than being buried under frosted glass.
  double get _blockBottom => FeedChrome.visible.value ? _navBand + 12 : 24.h;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    if (d.id.isEmpty && d.title.isEmpty) return const SizedBox.shrink();

    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final isAd = d.type == FeedItemType.ad;

    // Scales up out of the way when a comment sheet opens — see
    // [CommentPushArea]. `fillsBand` is the default now: the card is a page of
    // full-bleed media like every other one in this pager.
    return CommentPushArea(
      child: GestureDetector(
        // Same gesture as an event card: the chrome is what a tap is for on a
        // full-bleed page. The CTA and the rail take their own taps.
        onTap:
            widget.isAuthenticated ? FeedChrome.toggle : widget.onLoginRequired,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _FeedItemMedia(
              data: d,
              ext: ext,
              pageController: _pageCtrl,
            ),

            // Page dots for a carousel campaign. Above the copy block, which is
            // where the eye already is.
            if (d.mediaList.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: _blockBottom + 220.h,
                child: CommentSheetHide(
                  child: MediaPageDots(
                      count: d.mediaList.length, current: _currentPage),
                ),
              ),

            // The scrim the copy sits on. On a page it stops short of the very
            // bottom for the same reason the event card's does: the nav bar
            // frosts what is behind it, and a near-black gradient gives it
            // nothing to frost. In a tile there is no bar, so it runs to the
            // edge.
            Positioned(
              left: 0,
              right: 0,
              bottom: widget.fullBleed ? _navBand : 0,
              height: 320,
              child: const CommentSheetHide(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xCC000000)],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── The rail ─────────────────────────────────────────────────────
            //
            // A campaign can be liked, discussed and passed on. A request
            // carries share alone: it is a job going begging, not a post — the
            // way to answer one is the button, and a heart on somebody's work
            // enquiry says nothing they can use.
            Positioned(
              right: 12.w,
              top: 0,
              bottom: 0,
              child: CommentSheetHide(
                child: Align(
                  alignment: const Alignment(0, 0.15),
                  child: MediaReactionRail(
                    actions: [
                      // Always, for a campaign. Closing the thread is the
                      // advertiser declining a conversation, not declining
                      // reactions.
                      if (isAd)
                        MediaReaction.like(
                          liked: _liked,
                          count: _likes,
                          onTap: _toggleLike,
                        ),
                      if (isAd)
                        if (d.commentsEnabled)
                          MediaReaction.comment(
                            count: _commentCount,
                            onTap: _handleComment,
                          )
                        else
                          MediaReaction.commentsDisabled(count: _commentCount),
                      MediaReaction.share(
                        busy: _sharing,
                        onTap: _handleShare,
                      ),
                      // Not in the design, and kept: this is how an ad gets
                      // reported or hidden, and removing that from advertising
                      // is not a simplification.
                      MediaReaction.more(onTap: _showMoreOptions),
                    ],
                  ),
                ),
              ),
            ),

            // ── The copy, and the one button ────────────────────────────────
            //
            // Inset by the same 16 on both sides. The right edge used to clear
            // 72 for the rail, which cost the button a fifth of the screen it
            // had no reason to give up: the rail is centred at 0.15 and ends
            // well above this block, so under it there was simply a gap.
            //
            // The rail still has to be cleared where it genuinely overlaps —
            // the *text* can grow tall enough to reach it — so that clearance
            // moved inside, onto the lines that need it. See [kRailClearance].
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: 16.w,
              right: 16.w,
              bottom: _blockBottom,
              child: CommentSheetHide(
                child: isAd
                    ? _CampaignCopy(data: d, ext: ext, onCta: _handleCta)
                    : _RequestCopy(data: d, ext: ext, onCta: _handleCta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Media ────────────────────────────────────────────────────────────────────

/// The picture behind everything: one image, a swipeable few, a clip, or — for
/// a campaign with no cover — a gradient that at least belongs to the app.
///
/// Contained rather than cropped. An advertiser's flyer has words on it and a
/// requester's photo is of a venue; filling the screen with either means
/// cutting something off the edges that was put there deliberately.
class _FeedItemMedia extends StatelessWidget {
  const _FeedItemMedia({
    required this.data,
    required this.ext,
    required this.pageController,
  });

  final FeedItemData data;
  final AppThemeExtension ext;
  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    final d = data;

    if (d.mediaList.length > 1) {
      return PageView.builder(
        controller: pageController,
        itemCount: d.mediaList.length,
        itemBuilder: (_, i) => _SingleMediaFrame(
          media: d.mediaList[i],
          title: d.title,
          creatorName: d.creatorName,
        ),
      );
    }

    final single = d.mediaList.isNotEmpty ? d.mediaList.first : null;
    final url = single?.url ?? d.mediaUrl;
    final isVideo = single?.isVideo ?? d.mediaIsVideo;

    if (url == null || url.isEmpty) {
      return CardGradientPlaceholder(
        name: d.title.isNotEmpty ? d.title : d.creatorName,
      );
    }

    if (isVideo) {
      return JpergVideoPlayer(
        url: url,
        autoPlay: true,
        loop: true,
        fit: BoxFit.contain,
        backgroundColor: ext.mediaLetterbox,
        showControls: true,
        allowFullscreen: true,
        listenToPauseNotifier: true,
      );
    }

    return MediaBackdrop(
      url: url,
      child: JpergImage(
        imageUrl: url,
        fit: BoxFit.contain,
        semanticLabel:
            d.type == FeedItemType.ad ? 'Advertisement image' : 'Request image',
        placeholder: (_, __) => Center(
          child:
              CircularProgressIndicator(color: ext.accentGold, strokeWidth: 2),
        ),
        errorWidget: (_, __, ___) => const JpergImagePlaceholder(),
      ),
    );
  }
}

// ── The copy blocks ──────────────────────────────────────────────────────────

/// How much of the right edge the reaction rail can reach into.
///
/// The copy block now runs the full width of the card, so anything in it that
/// sits high enough to meet the rail has to keep out of its way itself. The
/// button does not — it is always the bottom-most row and the rail ends above
/// it — which is the whole point of moving this inwards: the one element with
/// a reason to be wide gets to be wide.
///
/// Measured from the rail's own inset (12) plus its width, rounded up so a
/// long caption stops short of the icons rather than touching them.
const double kRailClearance = 56;

class _CampaignCopy extends StatelessWidget {
  const _CampaignCopy({
    required this.data,
    required this.ext,
    required this.onCta,
  });

  final FeedItemData data;
  final AppThemeExtension ext;
  final VoidCallback onCta;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The words keep clear of the rail; the button below does not need to.
        Padding(
          padding: EdgeInsets.only(right: kRailClearance.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _KindPill(
                label: 'Sponsored',
                color: ext.publicAmber,
              ),
              SizedBox(height: AppSpacing.sm.h),
              Text(
                d.creatorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (d.title.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  d.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (d.body != null && d.body!.isNotEmpty) ...[
                SizedBox(height: AppSpacing.xs.h),
                Text(
                  d.body!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.sp,
                    height: 1.35,
                  ),
                ),
              ],
              // Where it happens, when the advertiser said. A campaign is often
              // for an actual event, and until now the card had nowhere to say
              // where — the only place a campaign named was its targeting,
              // which the viewer never sees and should not.
              if (d.location != null) ...[
                SizedBox(height: AppSpacing.xs.h),
                Row(
                  children: [
                    Icon(Icons.place_rounded,
                        size: 14.r,
                        color: Colors.white.withValues(alpha: 0.75)),
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        d.location!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (d.contentTags.isNotEmpty) ...[
                SizedBox(height: AppSpacing.xs.h),
                Text(
                  d.contentTags.map((t) => '#$t').join(' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (d.ctaLabel != null) ...[
          SizedBox(height: AppSpacing.md.h),
          _CtaButton(label: d.ctaLabel!, ext: ext, onTap: onCta),
        ],
      ],
    );
  }
}

class _RequestCopy extends StatelessWidget {
  const _RequestCopy({
    required this.data,
    required this.ext,
    required this.onCta,
  });

  final FeedItemData data;
  final AppThemeExtension ext;
  final VoidCallback onCta;

  /// "Sep 15, 2026 · 10:00 AM", or just the date, or nothing at all.
  String? get _whenLabel {
    final date = data.eventDate;
    if (date == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = '${months[date.month - 1]} ${date.day}, ${date.year}';
    final time = data.eventTime;
    if (time == null || time.isEmpty) return day;

    // "14:30" as the venue would say it out loud.
    final parts = time.split(':');
    final hour = int.tryParse(parts.first);
    if (hour == null || parts.length < 2) return day;
    final suffix = hour < 12 ? 'AM' : 'PM';
    final twelve = hour % 12 == 0 ? 12 : hour % 12;
    return '$day · $twelve:${parts[1]} $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final when = _whenLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // The words keep clear of the rail; the button below does not need to.
        Padding(
          padding: EdgeInsets.only(right: kRailClearance.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _KindPill(label: 'Photographer Request', color: ext.accentGold),
              SizedBox(height: AppSpacing.sm.h),
              Text(
                d.creatorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (d.title.isNotEmpty) ...[
                SizedBox(height: 2.h),
                Text(
                  d.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              // What a photographer decides on: when, where, how long. Every one of
              // them is optional on the request, and a row with nothing to say is
              // left out rather than drawn as an icon beside a dash.
              if (when != null)
                _RequestRow(icon: Icons.calendar_today_rounded, label: when),
              if (d.location != null)
                _RequestRow(icon: Icons.place_rounded, label: d.location!),
              if (d.coverageLabel != null)
                _RequestRow(
                    icon: Icons.access_time_rounded, label: d.coverageLabel!),
              if (d.budgetLabel != null) ...[
                SizedBox(height: AppSpacing.sm.h),
                Text(
                  d.budgetLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ext.accentGold,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (d.ctaLabel != null) ...[
          SizedBox(height: AppSpacing.md.h),
          _CtaButton(
            label: d.ctaLabel!,
            ext: ext,
            onTap: onCta,
            // Your own request, or one you have already answered: the button
            // still says where it stands, it just has nothing left to do.
            enabled: d.onCtaTap != null,
          ),
        ],
      ],
    );
  }
}

/// One line of a request: an icon and a fact.
class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 6.h),
      child: Row(
        children: [
          Icon(icon, size: 14.sp, color: Colors.white.withValues(alpha: 0.85)),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Sponsored" / "Photographer Request" — what this page is, said plainly.
///
/// Over an arbitrary photograph, so it carries its own ground rather than
/// relying on the scrim reaching this far up.
class _KindPill extends StatelessWidget {
  const _KindPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The one thing the card is for: "Book Now", "Express interest".
///
/// Outlined rather than filled, per the design — it sits on somebody's
/// photograph, and a solid block of colour there reads as a banner ad pasted
/// over the picture rather than as part of the post.
class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.label,
    required this.ext,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final AppThemeExtension ext;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color =
        enabled ? ext.accentGold : Colors.white.withValues(alpha: 0.45);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          height: 46.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color, width: 1.4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── One page of a carousel campaign ──────────────────────────────────────────

class _SingleMediaFrame extends StatelessWidget {
  const _SingleMediaFrame({
    required this.media,
    required this.title,
    required this.creatorName,
  });

  final AdMedia media;
  final String title;
  final String creatorName;

  @override
  Widget build(BuildContext context) {
    if (media.url.isEmpty) {
      return CardGradientPlaceholder(
        name: title.isNotEmpty ? title : creatorName,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: JpergImage(
            imageUrl: media.url,
            fit: BoxFit.cover,
            isBlurBackground: true,
            placeholder: (_, __) => const JpergImagePlaceholder(),
            errorWidget: (_, __, ___) => const JpergImagePlaceholder(),
          ),
        ),
        const ColoredBox(color: Color(0x55000000)),
        JpergImage(
          imageUrl: media.url,
          fit: BoxFit.contain,
          semanticLabel: 'Advertisement image',
          placeholder: (_, __) => const Center(
            child: CircularProgressIndicator(
                color: Colors.white70, strokeWidth: 2),
          ),
          errorWidget: (_, __, ___) => const JpergImagePlaceholder(),
        ),
        if (media.isVideo)
          const Center(
            child: Icon(Icons.play_circle_rounded,
                color: Colors.white70, size: 54),
          ),
      ],
    );
  }
}

// ── Page dots ────────────────────────────────────────────────────────────────

// ── More options ─────────────────────────────────────────────────────────────

class _FeedItemMoreOptionsSheet extends StatelessWidget {
  const _FeedItemMoreOptionsSheet({
    required this.ext,
    required this.type,
    required this.assetId,
    this.onHide,
  });

  final AppThemeExtension ext;
  final FeedItemType type;
  final String assetId;
  final VoidCallback? onHide;

  static void show(
    BuildContext context, {
    required AppThemeExtension ext,
    required FeedItemType type,
    required String assetId,
    VoidCallback? onHide,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FeedItemMoreOptionsSheet(
        ext: ext,
        type: type,
        assetId: assetId,
        onHide: onHide,
      ),
    );
  }

  String get _assetType => type == FeedItemType.ad ? 'campaign' : 'request';

  @override
  Widget build(BuildContext context) {
    final label = type == FeedItemType.ad ? 'campaign' : 'request';
    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      // ListTile ink paints on the nearest Material ancestor; this decorated
      // Container sits between the sheet's Material and the tiles and would
      // swallow it (and assert in debug). A transparency Material paints
      // nothing and just gives the ink somewhere to land.
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: ext.searchHintColor.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
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
                  'Hide this $label',
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15.sp,
                  ),
                ),
                subtitle: Text(
                  "You won't see this $label again",
                  style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  onHide?.call();
                },
              ),
              Divider(
                  height: 1, color: ext.searchHintColor.withValues(alpha: 0.1)),
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
                  'Report $label',
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
                    assetType: _assetType,
                    assetId: assetId,
                  );
                },
              ),
              SizedBox(height: AppSpacing.sm.h),
            ],
          ),
        ),
      ),
    );
  }
}
