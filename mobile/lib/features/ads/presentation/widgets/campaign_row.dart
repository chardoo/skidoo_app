import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/number_format.dart';
import 'package:skidoo_app/features/ads/models/ad_campaign.dart';
import 'package:skidoo_app/features/ads/presentation/widgets/campaign_status_pill.dart';

/// One campaign in the Broadcasts list.
///
/// Three lines and a thumbnail — the name, what it is and what it costs a day,
/// and how it is doing. No inline actions: the row carried a budget bar, an
/// edit pencil and a strip of buttons, which made six campaigns an unreadable
/// wall. Everything it used to offer lives on the details screen the row opens.
class CampaignRow extends StatelessWidget {
  const CampaignRow({
    super.key,
    required this.campaign,
    required this.ext,
    required this.onTap,
  });

  final AdCampaign campaign;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  /// "Lead Generation • GHS 80/day".
  String get _subtitle {
    final perDay = campaign.dailyBudget;
    final money = perDay == null
        ? '${campaign.currency} ${campaign.budgetAmount.toStringAsFixed(0)}'
        : '${campaign.currency} ${perDay.toStringAsFixed(0)}/day';
    return '${campaign.objective.label} • $money';
  }

  /// "3.2K reach • 94 clicks", or "Not started" for something that has never
  /// run — zeros there would read as a campaign doing badly rather than one
  /// that has not begun.
  String get _performance {
    if (campaign.impressions == 0 && campaign.clicks == 0) {
      return switch (campaign.status) {
        CampaignStatus.draft => 'Not started',
        CampaignStatus.pendingReview => 'Awaiting review',
        CampaignStatus.approvedUnpaid ||
        CampaignStatus.pendingPayment =>
          'Awaiting payment',
        CampaignStatus.paymentExpired => 'Payment window closed',
        CampaignStatus.rejected => 'Not approved',
        _ => 'No activity yet',
      };
    }
    return '${compactCount(campaign.reach)} reach • '
        '${compactCount(campaign.clicks)} clicks';
  }

  @override
  Widget build(BuildContext context) {
    final cover = campaign.media.isNotEmpty ? campaign.media.first.url : null;

    return Semantics(
      button: true,
      label: '${campaign.name}, ${campaign.status.label}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: EdgeInsets.fromLTRB(
            AppSpacing.md.w, 0, AppSpacing.md.w, AppSpacing.sm.h,
          ),
          padding: EdgeInsets.all(AppSpacing.md.w),
          decoration: BoxDecoration(
            color: ext.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.md.r),
            border: Border.all(
              color: ext.searchHintColor.withValues(alpha: 0.14),
              width: 0.8,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm.r),
                child: SizedBox(
                  width: 56.w,
                  height: 56.w,
                  child: cover == null
                      ? ColoredBox(
                          color: ext.avatarBackground,
                          child: Icon(Icons.campaign_outlined,
                              size: 22.r, color: ext.searchHintColor),
                        )
                      : Image.network(
                          cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: ext.avatarBackground,
                            child: Icon(Icons.broken_image_outlined,
                                size: 20.r, color: ext.searchHintColor),
                          ),
                        ),
                ),
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.headline?.isNotEmpty == true
                          ? campaign.headline!
                          : campaign.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      _subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ext.searchHintColor, fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _performance,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ext.searchHintColor.withValues(alpha: 0.8),
                        fontSize: 11.5.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              CampaignStatusPill(status: campaign.status, ext: ext),
            ],
          ),
        ),
      ),
    );
  }
}
