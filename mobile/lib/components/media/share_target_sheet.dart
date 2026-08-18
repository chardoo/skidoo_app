import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Where a photo is going: to someone in the app, or out of it.
///
/// The rails used to ask this by carrying two glyphs side by side — a paper
/// plane for the in-app DM picker and the OS share arrow. Two buttons for one
/// intention, and the difference between them was carried entirely by two
/// similar-looking icons: from the outside, "send" and "share" name the same
/// act. Now the rail carries one share button and the choice is made here,
/// with the two destinations named in words.
///
/// Styled after `EventMoreOptionsSheet` — the same rounded top, drag handle
/// and surface — so it reads as one of the app's sheets rather than a new kind
/// of surface.
///
/// Both callbacks fire *after* this sheet has closed. The in-app route opens
/// the DM picker, which is itself a modal sheet, and stacking one on the other
/// leaves the user two pops from where they started.
class ShareTargetSheet extends StatelessWidget {
  const ShareTargetSheet({
    super.key,
    required this.onInApp,
    required this.onExternal,
    this.title = 'Share this photo',
  });

  final VoidCallback onInApp;
  final VoidCallback onExternal;
  final String title;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onInApp,
    required VoidCallback onExternal,
    String title = 'Share this photo',
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ShareTargetSheet(
        onInApp: onInApp,
        onExternal: onExternal,
        title: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      decoration: BoxDecoration(
        color: ext.homeBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      // The tiles' ink needs a Material to paint on, and this decorated
      // Container would otherwise swallow it — the same reason
      // EventMoreOptionsSheet carries one.
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
              Text(
                title,
                style: TextStyle(
                  color: ext.greetingColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 15.sp,
                ),
              ),
              SizedBox(height: AppSpacing.lg.h),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
                child: Row(
                  children: [
                    Expanded(
                      child: _ShareTarget(
                        ext: ext,
                        icon: Icons.near_me_outlined,
                        label: 'In app',
                        semanticLabel: 'Send to someone in the app',
                        onTap: () {
                          Navigator.of(context).pop();
                          onInApp();
                        },
                      ),
                    ),
                    SizedBox(width: AppSpacing.md.w),
                    Expanded(
                      child: _ShareTarget(
                        ext: ext,
                        icon: Icons.ios_share_rounded,
                        label: 'External',
                        semanticLabel: 'Share outside the app',
                        onTap: () {
                          Navigator.of(context).pop();
                          onExternal();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.xl.h),
            ],
          ),
        ),
      ),
    );
  }
}

/// One destination: the glyph in a soft circle, its name underneath.
///
/// No card. The first version boxed each option in a filled, bordered
/// container, which put two heavy rectangles in a sheet that holds two words —
/// the frame was doing more work than the thing inside it. The circle is the
/// same treatment the Hide/Report sheet gives its icons, so the two sheets
/// look like they were drawn by the same hand, and the tap target is the whole
/// column rather than the visible circle.
class _ShareTarget extends StatelessWidget {
  const _ShareTarget({
    required this.ext,
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final AppThemeExtension ext;
  final IconData icon;
  final String label;

  /// The label alone is two words in a box; a screen reader needs the whole
  /// sentence, which is why this is not just [label].
  final String semanticLabel;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      // One node carrying the whole sentence. Without this the tile announces
      // twice — the label here, then "In app" from the Text inside it — and
      // the second reading is the one that says least.
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52.w,
                height: 52.w,
                decoration: BoxDecoration(
                  color: ext.searchFieldFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: ext.accentGold, size: 22.sp),
              ),
              SizedBox(height: AppSpacing.sm.h),
              Text(
                label,
                style: TextStyle(
                  color: ext.greetingColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 13.sp,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
