import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/ads/presentation/pages/create_campaign_page.dart';
import 'package:skidoo_app/features/ads/presentation/pages/post_request_page.dart';

class CreateBottomSheet extends StatelessWidget {
  const CreateBottomSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const CreateBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag handle ─────────────────────────────────────────────
              Center(
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 12.h),
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: ext.searchHintColor.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),

              // ── Title ────────────────────────────────────────────────────
              Text(
                'Create',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'What would you like to post?',
                style: TextStyle(
                  color: ext.searchHintColor,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 20.h),

              // ── Option: Post a Request ────────────────────────────────────
              _CreateOption(
                icon: Icons.edit_note_rounded,
                iconColor: const Color(0xFF3B82F6),
                iconBgColor: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                title: 'Post a Request',
                subtitle: 'Free  ·  Goes live after review',
                description:
                    'Looking for a photographer? Post your event details and let them come to you.',
                badgeLabel: 'Free',
                badgeColor: const Color(0xFF10B981),
                ext: ext,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PostRequestPage(),
                    ),
                  );
                },
              ),

              SizedBox(height: 12.h),

              // ── Option: Create Campaign ───────────────────────────────────
              _CreateOption(
                icon: Icons.rocket_launch_rounded,
                iconColor: ext.accentGold,
                iconBgColor: ext.accentGold.withValues(alpha: 0.12),
                title: 'Create Campaign',
                subtitle: 'Paid  ·  More reach  ·  4 steps',
                description:
                    'Run a targeted ad in the discovery feed to reach the right audience.',
                badgeLabel: 'Boosted',
                badgeColor: ext.accentGold,
                ext: ext,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateCampaignPage(),
                    ),
                  );
                },
              ),

              SizedBox(height: 8.h),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single option card ────────────────────────────────────────────────────────

class _CreateOption extends StatelessWidget {
  const _CreateOption({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.badgeLabel,
    required this.badgeColor,
    required this.ext,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final String description;
  final String badgeLabel;
  final Color badgeColor;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: ext.cardSurface,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: ext.searchHintColor.withValues(alpha: 0.1),
            width: 0.8,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(14.r),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 24.sp),
            ),
            SizedBox(width: 14.w),

            // Text block
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: ext.greetingColor,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20.r),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.35),
                            width: 0.7,
                          ),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    description,
                    style: TextStyle(
                      color: ext.greetingColor.withValues(alpha: 0.65),
                      fontSize: 12.sp,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: ext.searchHintColor,
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}
