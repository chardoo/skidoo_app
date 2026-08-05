import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/ads/models/ad_campaign.dart';

/// The state of a campaign, in one pill.
///
/// It appears on every list row and at the top of the details screen, and the
/// two used to colour it separately — so a campaign could read amber in a list
/// and blue on the screen the list opened.
class CampaignStatusPill extends StatelessWidget {
  const CampaignStatusPill({super.key, required this.status, required this.ext});

  final CampaignStatus status;
  final AppThemeExtension ext;

  /// Tinted fill, saturated text — the design's pills, not Material chips.
  (Color, Color) _colours() => switch (status) {
        CampaignStatus.active => (
            ext.accentGold.withValues(alpha: 0.14),
            ext.accentGold,
          ),
        CampaignStatus.paused => (
            const Color(0xFFF59E0B).withValues(alpha: 0.16),
            const Color(0xFFB45309),
          ),
        CampaignStatus.pendingReview => (
            const Color(0xFFF59E0B).withValues(alpha: 0.16),
            const Color(0xFFB45309),
          ),
        // Unpaid is a call to action, not a warning — there is a window
        // running and something the advertiser can do about it.
        CampaignStatus.pendingPayment ||
        CampaignStatus.approvedUnpaid =>
          (
            const Color(0xFF3B82F6).withValues(alpha: 0.14),
            const Color(0xFF1D4ED8),
          ),
        CampaignStatus.paymentExpired || CampaignStatus.rejected => (
            ext.errorRed.withValues(alpha: 0.14),
            ext.errorRed,
          ),
        CampaignStatus.draft || CampaignStatus.completed => (
            ext.searchHintColor.withValues(alpha: 0.16),
            ext.searchHintColor,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = _colours();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.sm.r),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: ink,
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
