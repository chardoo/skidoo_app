import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/ads/data/models/ad_model.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/ads/presentation/pages/feed_comment_sheet.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_interaction_bar.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_photo_preview.dart';

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
    this.creatorPhotoUrl,
    this.mediaUrl,
    this.mediaIsVideo = false,
    this.body,
    this.secondaryLabel,
    this.commentsEnabled = true,
    this.ctaLabel,
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
  final String? creatorPhotoUrl;

  final String? mediaUrl;
  final bool mediaIsVideo;

  /// ad body copy · request description — shown as expandable caption
  final String? body;

  /// Footer subtitle: null for ads (creator already in header);
  /// "WeddingType · Accra" for requests.
  final String? secondaryLabel;

  final bool commentsEnabled;

  final String? ctaLabel;
  final VoidCallback? onCtaTap;

  /// Called once after first render (ad impression tracking)
  final VoidCallback? onInit;

  // ── Factories ──────────────────────────────────────────────────────────────

  factory FeedItemData.fromAd(
    AdModel ad, {
    required VoidCallback onCtaTap,
    VoidCallback? onInit,
  }) =>
      FeedItemData(
        type: FeedItemType.ad,
        id: ad.adId,
        title: ad.headline,
        creatorName:
            ad.advertiserName.isNotEmpty ? ad.advertiserName : 'Advertiser',
        creatorPhotoUrl: ad.advertiserPhoto,
        mediaUrl: ad.mediaUrl,
        mediaIsVideo: ad.isVideo,
        body: ad.body.isNotEmpty ? ad.body : null,
        commentsEnabled: ad.commentsEnabled,
        ctaLabel: ad.ctaText.isEmpty ? 'Learn More' : ad.ctaText,
        onCtaTap: onCtaTap,
        onInit: onInit,
      );

  factory FeedItemData.fromRequest(
    FeedRequestModel req, {
    required VoidCallback onMessageTap,
  }) {
    final parts = <String>[];
    if (req.eventType.isNotEmpty) parts.add(req.eventType);
    if (req.location.isNotEmpty) parts.add(req.location);
    return FeedItemData(
      type: FeedItemType.request,
      id: req.id,
      title: req.title,
      creatorName:
          req.requesterName.isNotEmpty ? req.requesterName : 'Anonymous',
      creatorPhotoUrl: req.requesterPhoto,
      mediaUrl: req.assetUrl,
      mediaIsVideo: req.assetType == 'video',
      body: req.description.isNotEmpty ? req.description : null,
      secondaryLabel: parts.isEmpty ? null : parts.join(' · '),
      commentsEnabled: req.commentsEnabled,
      ctaLabel: 'Message Requester',
      onCtaTap: onMessageTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card widget — mirrors EventDiscoveryCard layout exactly
// ─────────────────────────────────────────────────────────────────────────────

class FeedItemCard extends StatefulWidget {
  const FeedItemCard({super.key, required this.data});
  final FeedItemData data;

  @override
  State<FeedItemCard> createState() => _FeedItemCardState();
}

class _FeedItemCardState extends State<FeedItemCard> {
  VideoPlayerController? _videoCtrl;
  bool _videoReady = false;

  bool _liked = false;
  bool _disliked = false;
  bool _saved = false;
  bool _bodyExpanded = false;
  bool _initFired = false;

  @override
  void initState() {
    super.initState();
    if (widget.data.mediaIsVideo && widget.data.mediaUrl != null) {
      _initVideo(widget.data.mediaUrl!);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initFired) return;
      _initFired = true;
      widget.data.onInit?.call();
    });
  }

  Future<void> _initVideo(String url) async {
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await ctrl.initialize();
      await ctrl.setVolume(0);
      await ctrl.setLooping(true);
      await ctrl.play();
      if (mounted) {
        setState(() {
          _videoCtrl = ctrl;
          _videoReady = true;
        });
      } else {
        ctrl.dispose();
      }
    } catch (_) {
      ctrl.dispose();
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  void _handleLike() {
    HapticFeedback.lightImpact();
    setState(() {
      _liked = !_liked;
      if (_liked) _disliked = false;
    });
  }

  void _handleDislike() {
    HapticFeedback.lightImpact();
    setState(() {
      _disliked = !_disliked;
      if (_disliked) _liked = false;
    });
  }

  void _handleSave() {
    HapticFeedback.selectionClick();
    setState(() => _saved = !_saved);
  }

  void _handleComment() {
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

    // Same height formula as EventDiscoveryCard
    final mediaH = d.mediaIsVideo
        ? (size.width * 1.55).clamp(540.0, 620.0)
        : (size.width * 1.0).clamp(340.0, 480.0);

    return Container(
      color: ext.homeBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Photo area — identical Stack structure to EventDiscoveryCard ─
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            width: double.infinity,
            height: mediaH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _MediaBackground(
                  data: d,
                  videoCtrl: _videoCtrl,
                  videoReady: _videoReady,
                  ext: ext,
                ),

                // Top gradient — covers overlaid header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 100.h,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xAA000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),

                // Bottom gradient
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 120.h,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xCC000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),

                // Post header overlaid on image — mirrors _PostHeader
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 14.w, vertical: 12.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Creator avatar + name (mirrors photographer name row)
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _CreatorAvatar(data: d),
                              SizedBox(width: 8.w),
                              Flexible(
                                child: Text(
                                  d.creatorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                    shadows: const [
                                      Shadow(
                                          blurRadius: 12,
                                          color: Colors.black87),
                                      Shadow(
                                          blurRadius: 4,
                                          color: Colors.black54),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        // Type badge — replaces the owner pill / more-options
                        _TypeBadge(type: d.type, ext: ext),
                      ],
                    ),
                  ),
                ),

                // Footer: title + secondary label — mirrors _ImageFooter
                Positioned(
                  bottom: 14.h,
                  left: 14.w,
                  right: 14.w,
                  child: _FooterOverlay(data: d),
                ),
              ],
            ),
          ),

          // ── 2. Spacing — same as EventDiscoveryCard (no page dots here) ───
          SizedBox(height: 6.h),

          // ── 3. Interaction bar ────────────────────────────────────────────
          CardInteractionBar(
            liked: _liked,
            disliked: _disliked,
            saved: _saved,
            likeCount: 0,
            dislikeCount: 0,
            commentCount: 0,
            ext: ext,
            onLike: _handleLike,
            onDislike: _handleDislike,
            onComment: _handleComment,
            onShare: _handleShare,
            onSave: _handleSave,
          ),

          // ── 4. Caption — mirrors CardDescriptionText pattern ──────────────
          if (d.body != null)
            _BodyText(
              creatorName: d.creatorName,
              body: d.body!,
              ext: ext,
              expanded: _bodyExpanded,
              onToggle: () =>
                  setState(() => _bodyExpanded = !_bodyExpanded),
            ),

          // ── 5. CTA button ─────────────────────────────────────────────────
          if (d.ctaLabel != null && d.onCtaTap != null)
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 14.h),
              child: _GoldCtaButton(
                label: d.ctaLabel!,
                onTap: d.onCtaTap!,
                ext: ext,
                type: d.type,
              ),
            )
          else
            SizedBox(height: 6.h),

          // ── 6. Divider ────────────────────────────────────────────────────
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
// Uses the same blur + colour-corrected contained-image technique as
// PostPhotoCarousel for images, and a VideoPlayer for video.

class _MediaBackground extends StatelessWidget {
  const _MediaBackground({
    required this.data,
    required this.videoCtrl,
    required this.videoReady,
    required this.ext,
  });
  final FeedItemData data;
  final VideoPlayerController? videoCtrl;
  final bool videoReady;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    if (data.mediaIsVideo) {
      if (videoReady && videoCtrl != null) {
        final w = videoCtrl!.value.size.width > 0
            ? videoCtrl!.value.size.width
            : 1.0;
        final h = videoCtrl!.value.size.height > 0
            ? videoCtrl!.value.size.height
            : 1.0;
        return ColoredBox(
          color: const Color(0xFF0A0A0A),
          child: SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                  width: w, height: h, child: VideoPlayer(videoCtrl!)),
            ),
          ),
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
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            placeholder: (_, __) =>
                const ColoredBox(color: Color(0xFF111111)),
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: Color(0xFF111111)),
          ),
        ),
        const ColoredBox(color: Color(0x55000000)),
        ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            1.18, -0.06, -0.06, 0, 18,
            -0.05,  1.16, -0.05, 0, 18,
            -0.05, -0.05,  1.20, 0, 18,
            0,     0,     0,     1, 0,
          ]),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            placeholder: (_, __) => const SizedBox.shrink(),
            errorWidget: (_, __, ___) =>
                const ColoredBox(color: Color(0xFF111111)),
          ),
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
    final photo = data.creatorPhotoUrl;
    final name = data.creatorName;
    return Container(
      width: 28.w,
      height: 28.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white24,
        border: Border.all(color: Colors.white30, width: 0.8),
        image: photo != null
            ? DecorationImage(
                image: NetworkImage(photo), fit: BoxFit.cover)
            : null,
      ),
      child: photo == null
          ? Center(
              child: data.type == FeedItemType.request
                  ? Icon(Icons.person_rounded,
                      color: Colors.white, size: 14.sp)
                  : Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            )
          : null,
    );
  }
}

// ── Type badge — mirrors the owner-pill style from EventDiscoveryCard ─────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type, required this.ext});
  final FeedItemType type;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final isAd = type == FeedItemType.ad;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isAd
              ? [
                  ext.accentGold.withValues(alpha: 0.25),
                  const Color(0xFFFF6B35).withValues(alpha: 0.18),
                ]
              : [
                  const Color(0x303B82F6),
                  const Color(0x301A56DB),
                ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isAd
              ? ext.accentGold.withValues(alpha: 0.7)
              : const Color(0xFF3B82F6).withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAd
                ? Icons.bolt_rounded
                : Icons.radio_button_checked_rounded,
            size: 10.sp,
            color: isAd ? ext.accentGold : const Color(0xFF60A5FA),
          ),
          SizedBox(width: 4.w),
          Text(
            isAd ? 'Sponsored' : 'Open Request',
            style: TextStyle(
              color: isAd ? ext.accentGold : const Color(0xFF93C5FD),
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
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

// ── CTA button ────────────────────────────────────────────────────────────────

class _GoldCtaButton extends StatelessWidget {
  const _GoldCtaButton({
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 13.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [ext.accentGold, const Color(0xFFFF6B35)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == FeedItemType.request) ...[
              Icon(Icons.chat_bubble_rounded,
                  size: 15.sp, color: Colors.white),
              SizedBox(width: 7.w),
            ],
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
