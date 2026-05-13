import 'dart:developer' as dev;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/ads/data/models/ad_model.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/features/ads/presentation/pages/feed_comment_sheet.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_interaction_bar.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/card_photo_preview.dart';

const _tag = '[AdFeedCard]';

class AdFeedCard extends StatefulWidget {
  const AdFeedCard({
    super.key,
    required this.ad,
  });

  final AdModel ad;

  @override
  State<AdFeedCard> createState() => _AdFeedCardState();
}

class _AdFeedCardState extends State<AdFeedCard> {
  final _repo = AdsRepository();
  bool _impressionFired = false;

  bool _liked = false;
  bool _disliked = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    dev.log(
      '$_tag initState — adId="${widget.ad.adId}" '
      'headline="${widget.ad.headline}" '
      'mediaType=${widget.ad.mediaType} '
      'mediaUrl=${widget.ad.mediaUrl} '
      'advertiserName="${widget.ad.advertiserName}" '
      'placement="${widget.ad.placement}"',
      name: 'AdFeedCard',
    );

    if (widget.ad.adId.isEmpty) {
      dev.log('$_tag skipping impression — adId is empty', name: 'AdFeedCard');
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _fireImpression());
  }

  void _fireImpression() {
    if (_impressionFired) return;
    _impressionFired = true;
    dev.log(
      '$_tag firing impression adId=${widget.ad.adId} placement=${widget.ad.placement}',
      name: 'AdFeedCard',
    );
    _repo.trackImpression(
      adId: widget.ad.adId,
      adsetId: widget.ad.adsetId,
      campaignId: widget.ad.campaignId,
      placement: widget.ad.placement,
      impressionToken: widget.ad.impressionToken,
    );
  }

  void _handleCtaTap() {
    dev.log(
      '$_tag CTA tapped adId=${widget.ad.adId} ctaUrl=${widget.ad.ctaUrl}',
      name: 'AdFeedCard',
    );
    _repo.trackClick(
      adId: widget.ad.adId,
      campaignId: widget.ad.campaignId,
    );
  }

  void _handleLike() {
    HapticFeedback.lightImpact();
    setState(() {
      _liked = !_liked;
      if (_liked) _disliked = false;
    });
    if (_liked) {
      _repo.trackClick(adId: widget.ad.adId, campaignId: widget.ad.campaignId);
    }
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

  void _handleComment(BuildContext context) {
    FeedCommentSheet.show(
      context,
      targetType: 'ad',
      targetId: widget.ad.adId,
      title: widget.ad.headline.isNotEmpty ? widget.ad.headline : 'Ad',
      subtitle: widget.ad.advertiserName.isNotEmpty
          ? 'by ${widget.ad.advertiserName}'
          : null,
      commentsEnabled: widget.ad.commentsEnabled,
    );
  }

  Future<void> _handleShare() async {
    final ad = widget.ad;
    final text = ad.ctaUrl.isNotEmpty
        ? '${ad.headline.isNotEmpty ? ad.headline : 'Check this out'}\n${ad.ctaUrl}'
        : ad.headline;
    if (text.isEmpty) return;
    await Share.share(text, subject: ad.headline);
  }

  @override
  Widget build(BuildContext context) {
    dev.log(
      '$_tag build adId="${widget.ad.adId}" headline="${widget.ad.headline}" '
      'mediaType=${widget.ad.mediaType} mediaUrl=${widget.ad.mediaUrl}',
      name: 'AdFeedCard',
    );

    // Don't render a shell with absolutely no content.
    if (widget.ad.adId.isEmpty &&
        widget.ad.headline.isEmpty &&
        widget.ad.advertiserName.isEmpty) {
      dev.log('$_tag skipping render — ad has no content', name: 'AdFeedCard');
      return const SizedBox.shrink();
    }

    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final ad = widget.ad;
    final size = MediaQuery.sizeOf(context);

    final mediaH = ad.isVideo
        ? (size.width * 1.45).clamp(480.0, 580.0)
        : (size.width * 1.0).clamp(340.0, 480.0);

    return Container(
      color: ext.homeBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Full-bleed media area ─────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: mediaH,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Media background — image, video, or gradient placeholder
                _AdMediaBg(ad: ad, ext: ext),

                // Top gradient
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 110.h,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xBB000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),

                // Bottom gradient
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 160.h,
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

                // Top overlay: Sponsored badge (left) + Advertiser chip (right)
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
                        _SponsoredBadge(ext: ext),
                        const Spacer(),
                        _AdvertiserChip(ad: ad),
                      ],
                    ),
                  ),
                ),

                // Bottom overlay: headline + body
                Positioned(
                  bottom: 14.h,
                  left: 14.w,
                  right: 14.w,
                  child: _AdOverlayContent(ad: ad),
                ),
              ],
            ),
          ),

          // ── Interaction bar ───────────────────────────────────────────────
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
            onComment: () => _handleComment(context),
            onShare: _handleShare,
            onSave: _handleSave,
          ),

          // ── CTA button ───────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
            child: _GradientCtaButton(
              label: ad.ctaText.isEmpty ? 'Learn More' : ad.ctaText,
              onTap: _handleCtaTap,
              ext: ext,
            ),
          ),

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

// ── Ad media background ───────────────────────────────────────────────────────

class _AdMediaBg extends StatelessWidget {
  const _AdMediaBg({required this.ad, required this.ext});
  final AdModel ad;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final url = ad.mediaUrl;

    // No media — rich gradient placeholder keyed on the advertiser/headline
    if (url == null || url.isEmpty) {
      final seed = ad.advertiserName.isNotEmpty
          ? ad.advertiserName
          : ad.headline;
      return CardGradientPlaceholder(name: seed);
    }

    // Image — blurred background + contained foreground (same as PostPhotoCarousel)
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

// ── Sponsored badge ───────────────────────────────────────────────────────────

class _SponsoredBadge extends StatelessWidget {
  const _SponsoredBadge({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ext.accentGold.withValues(alpha: 0.25),
            const Color(0xFFFF6B35).withValues(alpha: 0.18),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: ext.accentGold.withValues(alpha: 0.7),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 10.sp, color: ext.accentGold),
          SizedBox(width: 4.w),
          Text(
            'Sponsored',
            style: TextStyle(
              color: ext.accentGold,
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

// ── Advertiser chip ───────────────────────────────────────────────────────────

class _AdvertiserChip extends StatelessWidget {
  const _AdvertiserChip({required this.ad});
  final AdModel ad;

  @override
  Widget build(BuildContext context) {
    final name = ad.advertiserName.isNotEmpty ? ad.advertiserName : 'Advertiser';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26.w,
          height: 26.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white24,
            border: Border.all(color: Colors.white30, width: 0.8),
            image: ad.advertiserPhoto != null
                ? DecorationImage(
                    image: NetworkImage(ad.advertiserPhoto!),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: ad.advertiserPhoto == null
              ? Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : null,
        ),
        SizedBox(width: 6.w),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 100.w),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Headline + body overlaid at bottom of media ───────────────────────────────

class _AdOverlayContent extends StatelessWidget {
  const _AdOverlayContent({required this.ad});
  final AdModel ad;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (ad.headline.isNotEmpty)
          Text(
            ad.headline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22.sp,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.15,
              shadows: const [
                Shadow(blurRadius: 14, color: Colors.black87),
                Shadow(blurRadius: 4, color: Colors.black54),
              ],
            ),
          ),
        if (ad.body.isNotEmpty) ...[
          SizedBox(height: 4.h),
          Text(
            ad.body,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13.sp,
              height: 1.4,
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

// ── Gold gradient CTA button ──────────────────────────────────────────────────

class _GradientCtaButton extends StatelessWidget {
  const _GradientCtaButton({
    required this.label,
    required this.onTap,
    required this.ext,
  });
  final String label;
  final VoidCallback onTap;
  final AppThemeExtension ext;

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
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
