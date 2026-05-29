import 'dart:async';
import 'dart:ui';

import 'package:skidoo_app/core/widgets/skidoo_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skidoo_app/core/common/widgets/get_app_sheet.dart';

import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:skidoo_app/features/ads/data/models/ad_model.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/ads/models/ad.dart';
import 'package:skidoo_app/features/ads/models/ad_campaign.dart';
import 'package:skidoo_app/features/ads/models/ad_media.dart';
import 'package:skidoo_app/features/ads/presentation/pages/feed_comment_sheet.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_interaction_bar.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_photo_preview.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/report_sheet.dart';
import 'package:skidoo_app/core/widgets/video_player/skidoo_video_player.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model — same shape for ads and requests, mirrors EventDiscovery fields
// ─────────────────────────────────────────────────────────────────────────────

enum FeedItemType { ad, request }

class FeedItemData {
  const FeedItemData({
    required this.type,
    required this.id,
    required this.title,
    required this.creatorName,
    this.creatorId = '',
    this.creatorRole = '',
    this.creatorPhotoUrl,
    this.mediaUrl,
    this.mediaIsVideo = false,
    this.mediaList = const <AdMedia>[],
    this.body,
    this.secondaryLabel,
    this.commentsEnabled = true,
    this.commentCount = 0,
    this.ctaLabel,
    this.ctaUrl,
    this.onCtaTap,
    this.onInit,
  });

  final FeedItemType type;

  /// ad_id or request_id
  final String id;

  /// headline (ad) · request title
  final String title;

  /// advertiser name (ad) · requester name
  final String creatorName;

  /// advertiser_id (ad) · requester_id — used by the Follow button.
  final String creatorId;

  /// "photographer" | "client" — used to open a direct chat room.
  final String creatorRole;
  final String? creatorPhotoUrl;

  final String? mediaUrl;
  final bool mediaIsVideo;

  /// Ordered list of media items (new API). Falls back to single-item wrapping
  /// of mediaUrl for backward compat.
  final List<AdMedia> mediaList;

  /// ad body copy · request description — shown as expandable caption
  final String? body;

  /// Footer subtitle: null for ads (creator already in header);
  /// "WeddingType · Accra" for requests.
  final String? secondaryLabel;

  final bool commentsEnabled;
  final int commentCount;

  final String? ctaLabel;

  /// The URL to open in the external browser when the CTA is tapped.
  /// Null for request cards, which use [onCtaTap] for messaging instead.
  final String? ctaUrl;

  /// For ads: click-tracking callback. For requests: opens the chat.
  final VoidCallback? onCtaTap;

  /// Called once after first render (ad impression tracking)
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
      title: ad.headline,
      creatorName:
          ad.advertiserName.isNotEmpty ? ad.advertiserName : 'Advertiser',
      creatorId: ad.advertiserId,
      creatorRole: ad.advertiserType ?? ChatConfig.rolePhotographer,
      creatorPhotoUrl: ad.advertiserPhoto,
      mediaUrl: ad.mediaUrl,
      mediaIsVideo: ad.isVideo,
      mediaList: mediaList,
      body: ad.body.isNotEmpty ? ad.body : null,
      commentsEnabled: ad.commentsEnabled,
      commentCount: ad.commentCount,
      ctaLabel: ad.ctaUrl.isNotEmpty ? (ad.ctaText.isEmpty ? 'Learn More' : ad.ctaText) : null,
      ctaUrl: ad.ctaUrl.isNotEmpty ? ad.ctaUrl : null,
      onCtaTap: ad.ctaUrl.isNotEmpty ? onCtaTap : null,
      onInit: onInit,
    );
  }

  /// Builds a sponsored-content slot directly from an [AdCampaign].
  /// Used when the ad-serve endpoint returns null (campaign not yet active
  /// in the targeting pipeline) so the feed falls back to direct campaign data.
  factory FeedItemData.fromCampaign(AdCampaign campaign) {
    // Collect the first Ad creative across all ad sets.
    Ad? firstAd;
    for (final adSet in campaign.adSets) {
      if (adSet.ads.isNotEmpty) {
        firstAd = adSet.ads.first;
        break;
      }
    }

    // Media priority:
    //   1. Campaign-level media list (covers/banners).
    //   2. Ad-level mediaUrl collected across every ad in every ad set.
    //   3. Empty → the card shows a gradient placeholder.
    List<AdMedia> mediaList = campaign.media;
    if (mediaList.isEmpty) {
      final collected = <AdMedia>[];
      for (final adSet in campaign.adSets) {
        for (final ad in adSet.ads) {
          if (ad.media.isNotEmpty) {
            // Use the full media list from the ad (backend stores multiple images here)
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

    debugPrint(
      '[FeedItemCard] fromCampaign id=${campaign.id} '
      'name="${campaign.name}" '
      'campaignMedia=${campaign.media.length} '
      'adSets=${campaign.adSets.length} '
      'resolvedMedia=${mediaList.length} '
      'firstMediaUrl=${firstMedia?.url} '
      'firstAd=${firstAd?.id}',
    );

    // Use ad-creative copy when available — more descriptive than campaign name.
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
      title: title,
      creatorName: (campaign.advertiserName?.isNotEmpty ?? false)
          ? campaign.advertiserName!
          : 'Advertiser',
      creatorId: campaign.advertiserId,
      creatorRole: campaign.advertiserType.isNotEmpty
          ? campaign.advertiserType
          : ChatConfig.rolePhotographer,
      creatorPhotoUrl: campaign.advertiserPhoto,
      mediaUrl: firstMedia?.url,
      mediaIsVideo: firstMedia?.isVideo ?? false,
      mediaList: mediaList,
      body: body,
      commentsEnabled: campaign.commentsEnabled,
      commentCount: campaign.commentCount,
      ctaLabel: (ctaUrl != null && ctaUrl.isNotEmpty) ? ctaLabel : null,
      ctaUrl: (ctaUrl != null && ctaUrl.isNotEmpty) ? ctaUrl : null,
      onCtaTap: null,
    );
  }

  factory FeedItemData.fromRequest(
    FeedRequestModel req, {
    required VoidCallback onMessageTap,
  }) {
    final parts = <String>[];
    if (req.eventType.isNotEmpty) parts.add(req.eventType);
    if (req.location.isNotEmpty) parts.add(req.location);
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
      creatorRole: req.requesterType.isNotEmpty
          ? req.requesterType
          : ChatConfig.roleClient,
      creatorPhotoUrl: req.requesterPhoto,
      mediaUrl: req.assetUrl,
      mediaIsVideo: req.assetType == 'video',
      mediaList: mediaList,
      body: req.description.isNotEmpty ? req.description : null,
      secondaryLabel: parts.isEmpty ? null : parts.join(' · '),
      commentsEnabled: req.commentsEnabled,
      commentCount: req.commentCount,
      ctaLabel: 'Message Requester',
      ctaUrl: null,
      onCtaTap: onMessageTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card widget — mirrors EventDiscoveryCard layout exactly
// ─────────────────────────────────────────────────────────────────────────────

class FeedItemCard extends StatefulWidget {
  const FeedItemCard({
    super.key,
    required this.data,
    this.onHide,
    this.isAuthenticated = true,
    this.onLoginRequired,
  });
  final FeedItemData data;
  final VoidCallback? onHide;
  /// Set false for guest/unauthenticated users — all interactive actions will
  /// call [onLoginRequired] instead of performing the real action.
  final bool isAuthenticated;
  final VoidCallback? onLoginRequired;

  @override
  State<FeedItemCard> createState() => _FeedItemCardState();
}

class _FeedItemCardState extends State<FeedItemCard> with WidgetsBindingObserver {

  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  bool _liked = false;
  bool _disliked = false;
  bool _saved = false;
  bool _bodyExpanded = false;
  bool _initFired = false;
  bool _chatLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageCtrl.addListener(() {
      final page = _pageCtrl.page?.round() ?? 0;
      if (page != _currentPage && mounted) setState(() => _currentPage = page);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initFired) return;
      _initFired = true;
      widget.data.onInit?.call();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageCtrl.dispose();
    super.dispose();
  }

  /// Returns true and fires the login prompt when the user is not authenticated.
  bool _requireAuth() {
    if (!widget.isAuthenticated) {
      widget.onLoginRequired?.call();
      return true;
    }
    return false;
  }

  void _handleLike() {
    if (_requireAuth()) return;
    HapticFeedback.lightImpact();
    setState(() {
      _liked = !_liked;
      if (_liked) _disliked = false;
    });
  }

  void _handleDislike() {
    if (_requireAuth()) return;
    HapticFeedback.lightImpact();
    setState(() {
      _disliked = !_disliked;
      if (_disliked) _liked = false;
    });
  }

  void _handleSave() {
    if (_requireAuth()) return;
    HapticFeedback.selectionClick();
    setState(() => _saved = !_saved);
  }

  Future<void> _handleCtaTap() async {
    if (_requireAuth()) return;
    final d = widget.data;
    // For requests: onCtaTap opens the chat — call it and stop.
    if (d.type == FeedItemType.request) {
      d.onCtaTap?.call();
      return;
    }
    // For ads/campaigns: fire tracking (non-blocking) then open URL.
    d.onCtaTap?.call();
    final raw = d.ctaUrl;
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openChat() async {
    if (_requireAuth()) return;
    final d = widget.data;
    if (d.creatorId.isEmpty || _chatLoading) return;
    HapticFeedback.lightImpact();
    setState(() => _chatLoading = true);
    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: d.creatorId,
        recipientRole: d.creatorRole.isNotEmpty
            ? d.creatorRole
            : ChatConfig.rolePhotographer,
        localDisplayName: d.creatorName,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
      );
    } catch (e) {
      if (!mounted) return;
      final isBlocked = e is ServerException && e.message.contains('400');
      AppSnackBar.error(
        context,
        isBlocked ? 'This user is not accepting messages.' : 'Could not open chat. Try again.',
      );
    } finally {
      if (mounted) setState(() => _chatLoading = false);
    }
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
    if (kIsWeb) {
      final ext = Theme.of(context).extension<AppThemeExtension>()!;
      GetAppSheet.show(context, ext: ext);
      return;
    }
    final text =
        widget.data.title.isNotEmpty ? widget.data.title : 'Check this out';
    await Share.share(text, subject: widget.data.title);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    if (d.id.isEmpty && d.title.isEmpty) return const SizedBox.shrink();

    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final size = MediaQuery.sizeOf(context);

    final isVideo = d.mediaList.length == 1
        ? d.mediaList[0].isVideo
        : d.mediaIsVideo;
    final mediaH = isVideo
        ? (size.height * 0.80).clamp(540.0, 780.0)
        : (size.height * 0.75).clamp(480.0, 740.0);

    return Container(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Header — above the image ───────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CreatorAvatar(data: d),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        d.creatorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      _TypeLabel(type: d.type, ext: ext),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                FollowButton(
                  photographerId: d.creatorId,
                  onLoginRequired: widget.isAuthenticated
                      ? null
                      : widget.onLoginRequired,
                ),
                SizedBox(width: 6.w),
                GestureDetector(
                  onTap: () => _FeedItemMoreOptionsSheet.show(
                    context,
                    ext: ext,
                    type: d.type,
                    assetId: d.id,
                    onHide: widget.onHide,
                  ),
                  child: Icon(Icons.more_horiz_rounded,
                      color: ext.searchHintColor, size: 22.sp),
                ),
              ],
            ),
          ),

          // ── 2. Media ───────────────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            width: double.infinity,
            height: mediaH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (d.mediaList.length > 1)
                  PageView.builder(
                    controller: _pageCtrl,
                    itemCount: d.mediaList.length,
                    itemBuilder: (_, i) => _SingleMediaFrame(
                      media: d.mediaList[i],
                      ext: ext,
                      title: d.title,
                      creatorName: d.creatorName,
                    ),
                  )
                else if (d.mediaList.length == 1 && !d.mediaList[0].isVideo)
                  // Single image from mediaList — use _SingleMediaFrame so it
                  // reads media.url directly instead of the legacy data.mediaUrl.
                  _SingleMediaFrame(
                    media: d.mediaList[0],
                    ext: ext,
                    title: d.title,
                    creatorName: d.creatorName,
                  )
                else
                  // Single video or legacy mediaUrl
                  _MediaBackground(data: d, ext: ext),

                // Bottom gradient
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 130.h,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xDD000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),

                // Footer: title + secondary label
                Positioned(
                  bottom: 14.h,
                  left: 14.w,
                  right: 14.w,
                  child: _FooterOverlay(data: d),
                ),

                // Page dots for multi-image (Instagram-style)
                if (d.mediaList.length > 1)
                  Positioned(
                    bottom: 58.h,
                    left: 0,
                    right: 0,
                    child: _AdPageDots(
                      count: d.mediaList.length,
                      current: _currentPage,
                      ext: ext,
                    ),
                  ),
              ],
            ),
          ),

          // ── 3. CTA strip — between image and reactions ────────────────────
          // Show when: ad/campaign has a URL, or request has a message handler.
          if (d.ctaLabel != null &&
              (d.ctaUrl?.isNotEmpty == true ||
                  (d.type == FeedItemType.request && d.onCtaTap != null)))
            _CtaStrip(
              label: d.ctaLabel!,
              onTap: _handleCtaTap,
              ext: ext,
              type: d.type,
            ),

          // ── 4. Interaction bar ─────────────────────────────────────────────
          CardInteractionBar(
            liked: _liked,
            disliked: _disliked,
            saved: _saved,
            likeCount: 0,
            dislikeCount: 0,
            commentCount: d.commentCount,
            commentsEnabled: d.commentsEnabled,
            ext: ext,
            onLike: _handleLike,
            onDislike: _handleDislike,
            onComment: _handleComment,
            onShare: _handleShare,
            onSave: _handleSave,
            onMessage: d.creatorId.isNotEmpty
                ? (_chatLoading ? null : _openChat)
                : null,
          ),

          // ── 5. Caption ─────────────────────────────────────────────────────
          if (d.body != null)
            _BodyText(
              creatorName: d.creatorName,
              body: d.body!,
              ext: ext,
              expanded: _bodyExpanded,
              onToggle: () => setState(() => _bodyExpanded = !_bodyExpanded),
            ),

          SizedBox(height: 6.h),

          // ── 6. Divider ─────────────────────────────────────────────────────
          Divider(
            height: 1,
            thickness: 0.5,
            color: ext.searchHintColor.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}

// ── Media background ──────────────────────────────────────────────────────────
/// Renders either a [SkidooVideoPlayer] for video items or a blurred image
/// background for photo items.

class _MediaBackground extends StatelessWidget {
  const _MediaBackground({required this.data, required this.ext});

  final FeedItemData data;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final d = data;

    // ── Video ──────────────────────────────────────────────────────────────
    if (d.mediaIsVideo ||
        (d.mediaList.length == 1 && d.mediaList[0].isVideo)) {
      final url = d.mediaList.isNotEmpty ? d.mediaList[0].url : d.mediaUrl;
      if (url != null && url.isNotEmpty) {
        return SkidooVideoPlayer(
          url: url,
          autoPlay: true,
          loop: true,
          fit: BoxFit.contain,
          backgroundColor: const Color(0xFF0A0A0A),
          showControls: true,
          allowFullscreen: true,
          listenToPauseNotifier: true,
        );
      }
      return const ColoredBox(
        color: Color(0xFF0A0A0A),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                color: Colors.white30, strokeWidth: 2),
          ),
        ),
      );
    }

    // ── Image (legacy mediaUrl path) ────────────────────────────────────────
    final url = data.mediaUrl;
    if (url == null || url.isEmpty) {
      return CardGradientPlaceholder(
        name: data.title.isNotEmpty ? data.title : data.creatorName,
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: SkidooImage(
            imageUrl: url,
            fit: BoxFit.cover,
            isBlurBackground: true,
            placeholder: (_, __) => const ColoredBox(color: Color(0xFF111111)),
            errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF111111)),
          ),
        ),
        const ColoredBox(color: Color(0x55000000)),
        SkidooImage(
          imageUrl: url,
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox.shrink(),
          errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF111111)),
          colorFilter: const ColorFilter.matrix(<double>[
            1.18, -0.06, -0.06, 0, 18,
            -0.05,  1.16, -0.05, 0, 18,
            -0.05, -0.05,  1.20, 0, 18,
            0,     0,     0,     1, 0,
          ]),
        ),
      ],
    );
  }
}

// ── Creator avatar ────────────────────────────────────────────────────────────

class _CreatorAvatar extends StatelessWidget {
  const _CreatorAvatar({required this.data});
  final FeedItemData data;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final photo = data.creatorPhotoUrl;
    final name = data.creatorName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    const borderPad = 2.0;

    return Container(
      width: 38.w,
      height: 38.w,
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
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: photo == null
              ? const LinearGradient(
                  colors: [Color(0xFFFFAB40), Color(0xFFFF6B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          image: photo != null
              ? DecorationImage(image: NetworkImage(photo), fit: BoxFit.cover)
              : null,
        ),
        alignment: Alignment.center,
        child: photo == null
            ? Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              )
            : null,
      ),
    );
  }
}

// ── Type label — small inline subtitle below creator name ────────────────────

class _TypeLabel extends StatelessWidget {
  const _TypeLabel({required this.type, required this.ext});
  final FeedItemType type;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final isAd = type == FeedItemType.ad;
    final bgColor =
        isAd ? ext.accentGold : const Color(0xFF3B82F6);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.5.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4.r),
        boxShadow: [
          BoxShadow(
            color: bgColor.withValues(alpha: 0.35),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAd ? Icons.bolt_rounded : Icons.radio_button_checked_rounded,
            size: 10.sp,
            color: Colors.white,
          ),
          SizedBox(width: 2.w),
          Text(
            isAd ? 'Sponsored' : 'Open Request',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── CTA strip — sits between image and reactions, full-width tappable ─────────

class _CtaStrip extends StatefulWidget {
  const _CtaStrip({
    required this.label,
    required this.onTap,
    required this.ext,
    required this.type,
  });
  final String label;
  final VoidCallback onTap;
  final AppThemeExtension ext;
  final FeedItemType type;

  @override
  State<_CtaStrip> createState() => _CtaStripState();
}

class _CtaStripState extends State<_CtaStrip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  @override
  void initState() {
    super.initState();
    // Pulse twice to signal this is interactive, then come to rest.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ctrl
          .forward()
          .then((_) => _ctrl.reverse())
          .then((_) => mounted
              ? _ctrl.forward().then((_) => _ctrl.reverse())
              : null);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAd = widget.type == FeedItemType.ad;
    final ext = widget.ext;
    final accentColor = isAd ? ext.accentGold : const Color(0xFF3B82F6);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final p = _ctrl.value;
        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.07 + p * 0.14),
              border: Border.symmetric(
                horizontal: BorderSide(
                  color: accentColor.withValues(alpha: 0.18 + p * 0.5),
                  width: 0.8 + p * 0.8,
                ),
              ),
              boxShadow: p > 0
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.18 * p),
                        blurRadius: 10 * p,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: child,
          ),
        );
      },
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 3.w,
            height: 16.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isAd
                    ? [widget.ext.accentGold, const Color(0xFFFF6B35)]
                    : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              widget.label,
              style: TextStyle(
                color: isAd ? widget.ext.accentGold : const Color(0xFF3B82F6),
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ),
          Icon(
            isAd ? Icons.open_in_new_rounded : Icons.arrow_forward_ios_rounded,
            size: isAd ? 16.sp : 13.sp,
            color: (isAd ? widget.ext.accentGold : const Color(0xFF3B82F6))
                .withValues(alpha: 0.7),
          ),
        ],
      ),
    );
  }
}

// ── Footer overlay — mirrors _ImageFooter from EventDiscoveryCard ─────────────

class _FooterOverlay extends StatelessWidget {
  const _FooterOverlay({required this.data});
  final FeedItemData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data.title.isNotEmpty)
          Text(
            data.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              height: 1.2,
              shadows: const [
                Shadow(blurRadius: 12, color: Colors.black87),
                Shadow(blurRadius: 4, color: Colors.black54),
              ],
            ),
          ),
        if (data.secondaryLabel != null &&
            data.secondaryLabel!.isNotEmpty) ...[
          SizedBox(height: 3.h),
          Text(
            data.secondaryLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
              shadows: const [
                Shadow(blurRadius: 8, color: Colors.black87),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Body caption — mirrors CardDescriptionText pattern ────────────────────────

class _BodyText extends StatelessWidget {
  const _BodyText({
    required this.creatorName,
    required this.body,
    required this.ext,
    required this.expanded,
    required this.onToggle,
  });
  final String creatorName;
  final String body;
  final AppThemeExtension ext;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            child: RichText(
              maxLines: expanded ? null : 2,
              overflow:
                  expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              text: TextSpan(
                style: TextStyle(
                    fontSize: 13.sp,
                    height: 1.5,
                    color: ext.greetingColor),
                children: [
                  TextSpan(
                    text: '$creatorName  ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: ext.greetingColor,
                    ),
                  ),
                  TextSpan(text: body),
                ],
              ),
            ),
          ),
          if (!expanded) ...[
            SizedBox(height: 2.h),
            GestureDetector(
              onTap: onToggle,
              child: Text(
                'more',
                style: TextStyle(
                    color: ext.searchHintColor, fontSize: 12.sp),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── More options sheet ────────────────────────────────────────────────────────

// ── Single media frame (used inside PageView for multi-image) ─────────────────

class _SingleMediaFrame extends StatelessWidget {
  const _SingleMediaFrame({
    required this.media,
    required this.ext,
    required this.title,
    required this.creatorName,
  });
  final AdMedia media;
  final AppThemeExtension ext;
  final String title;
  final String creatorName;

  @override
  Widget build(BuildContext context) {
    debugPrint(
      '[_SingleMediaFrame] build — url="${media.url}" '
      'mediaType=${media.mediaType} isVideo=${media.isVideo}',
    );
    if (media.url.isEmpty) {
      debugPrint('[_SingleMediaFrame] ← url empty, showing placeholder');
      return CardGradientPlaceholder(
        name: title.isNotEmpty ? title : creatorName,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: SkidooImage(
            imageUrl: media.url,
            fit: BoxFit.cover,
            isBlurBackground: true,
            placeholder: (_, __) => const ColoredBox(color: Color(0xFF111111)),
            errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF111111)),
          ),
        ),
        const ColoredBox(color: Color(0x55000000)),
        SkidooImage(
          imageUrl: media.url,
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox.shrink(),
          colorFilter: const ColorFilter.matrix(<double>[
            1.18, -0.06, -0.06, 0, 18,
            -0.05,  1.16, -0.05, 0, 18,
            -0.05, -0.05,  1.20, 0, 18,
            0,     0,     0,     1, 0,
          ]),
          errorWidget: (_, __, ___) => const ColoredBox(color: Color(0xFF111111)),
        ),
        if (media.isVideo)
          const Center(
            child: Icon(
              Icons.play_circle_rounded,
              color: Colors.white70,
              size: 54,
            ),
          ),
      ],
    );
  }
}

// ── Instagram-style page dots ─────────────────────────────────────────────────

class _AdPageDots extends StatelessWidget {
  const _AdPageDots({
    required this.count,
    required this.current,
    required this.ext,
  });
  final int count;
  final int current;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18.0 : 6.0,
          height: 6.0,
          decoration: BoxDecoration(
            color: active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── More options sheet ────────────────────────────────────────────────────────

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

  String get _assetType =>
      type == FeedItemType.ad ? 'campaign' : 'request';

  @override
  Widget build(BuildContext context) {
    final label = type == FeedItemType.ad ? 'campaign' : 'request';
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
            Container(
              margin: EdgeInsets.symmetric(vertical: 12.h),
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),

            // Hide
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

            Divider(height: 1, color: ext.searchHintColor.withValues(alpha: 0.1)),

            // Report
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

            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }
}
