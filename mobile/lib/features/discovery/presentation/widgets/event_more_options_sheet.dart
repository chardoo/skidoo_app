import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/report_sheet.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

/// Hide / Report bottom sheet for an event — shared by the classic feed
/// card's post header, the web reactions column, and the full-bleed
/// TikTok-style card.
class EventMoreOptionsSheet extends StatelessWidget {
  const EventMoreOptionsSheet({
    super.key,
    required this.ext,
    required this.eventId,
    this.onHide,
  });
  final AppThemeExtension ext;
  final String eventId;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
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
            // Drag handle
            Container(
              margin: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),

            // Hide option
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
                'Hide event',
                style: TextStyle(
                  color: ext.greetingColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15.sp,
                ),
              ),
              subtitle: Text(
                "You won't see this event again",
                style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
              ),
              onTap: () {
                Navigator.of(context).pop();
                onHide?.call();
              },
            ),

            Divider(height: 1, color: ext.searchHintColor.withValues(alpha: 0.1)),

            // Report option — opens the reason picker sheet
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
                'Report event',
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
                  assetType: 'event',
                  assetId: eventId,
                );
              },
            ),

            SizedBox(height: AppSpacing.sm.h),
          ],
        ),
      ),
    );
  }
}
