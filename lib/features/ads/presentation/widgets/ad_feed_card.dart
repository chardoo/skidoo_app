import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/ads/data/models/ad_model.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';

const _tag = '[AdFeedCard]';

class AdFeedCard extends StatefulWidget {
  const AdFeedCard({
    super.key,
    required this.ad,
    required this.onMessageTap,
  });

  final AdModel ad;
  final VoidCallback onMessageTap;

  @override
  State<AdFeedCard> createState() => _AdFeedCardState();
}

class _AdFeedCardState extends State<AdFeedCard> {
  final _repo = AdsRepository();
  bool _impressionFired = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fireImpression());
  }

  void _fireImpression() {
    if (_impressionFired) return;
    _impressionFired = true;
    debugPrint('$_tag firing impression adId=${widget.ad.adId} placement=${widget.ad.placement}');
    _repo.trackImpression(
      adId: widget.ad.adId,
      adsetId: widget.ad.adsetId,
      campaignId: widget.ad.campaignId,
      placement: widget.ad.placement,
      impressionToken: widget.ad.impressionToken,
    );
  }

  void _handleCtaTap() {
    debugPrint('$_tag CTA tapped adId=${widget.ad.adId} ctaUrl=${widget.ad.ctaUrl}');
    _repo.trackClick(
      adId: widget.ad.adId,
      campaignId: widget.ad.campaignId,
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('$_tag build adId=${widget.ad.adId} headline="${widget.ad.headline}" mediaType=${widget.ad.mediaType}');
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final ad = widget.ad;

    return Container(
      color: ext.homeBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Sponsored header ──────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 8.h),
            child: Row(
              children: [
                _SponsoredBadge(ext: ext),
                const Spacer(),
                _AdvertiserChip(ad: ad, ext: ext),
              ],
            ),
          ),

          // ── Media ─────────────────────────────────────────────────────────
          if (ad.mediaUrl != null)
            _AdMedia(mediaUrl: ad.mediaUrl!, isVideo: ad.isVideo),

          // ── Content ───────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(14.w, 14.h, 14.w, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ad.headline,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.2,
                  ),
                ),
                if (ad.body.isNotEmpty) ...[
                  SizedBox(height: 6.h),
                  Text(
                    ad.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 13.sp,
                      height: 1.5,
                    ),
                  ),
                ],
                SizedBox(height: 14.h),

                // ── Action buttons ─────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _GradientCtaButton(
                        label: ad.ctaText,
                        onTap: _handleCtaTap,
                        ext: ext,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    _MessageButton(
                      onTap: widget.onMessageTap,
                      ext: ext,
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
              ],
            ),
          ),

          // ── Divider ───────────────────────────────────────────────────────
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
            ext.accentGold.withValues(alpha: 0.18),
            const Color(0xFFFF6B35).withValues(alpha: 0.12),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: ext.accentGold.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 10.sp, color: ext.accentGold),
          SizedBox(width: 3.w),
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
  const _AdvertiserChip({required this.ad, required this.ext});
  final AdModel ad;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            color: ext.searchFieldFill,
            shape: BoxShape.circle,
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
                    ad.advertiserName.isNotEmpty
                        ? ad.advertiserName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              : null,
        ),
        SizedBox(width: 6.w),
        Text(
          ad.advertiserName,
          style: TextStyle(
            color: ext.searchHintColor,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Ad media ──────────────────────────────────────────────────────────────────

class _AdMedia extends StatelessWidget {
  const _AdMedia({required this.mediaUrl, required this.isVideo});
  final String mediaUrl;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200.h,
      width: double.infinity,
      child: Image.network(
        mediaUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

// ── Gradient CTA button ───────────────────────────────────────────────────────

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
        padding: EdgeInsets.symmetric(vertical: 12.h),
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

// ── Message button ────────────────────────────────────────────────────────────

class _MessageButton extends StatelessWidget {
  const _MessageButton({required this.onTap, required this.ext});
  final VoidCallback onTap;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48.w,
        height: 48.w,
        decoration: BoxDecoration(
          color: ext.searchFieldFill,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: ext.searchHintColor.withValues(alpha: 0.2),
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.chat_bubble_outline_rounded,
          color: ext.greetingColor,
          size: 20.sp,
        ),
      ),
    );
  }
}
