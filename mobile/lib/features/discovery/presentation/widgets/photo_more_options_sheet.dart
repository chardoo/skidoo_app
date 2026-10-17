import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/report_sheet.dart';

/// The overflow menu on a photo.
///
/// A sibling of [EventMoreOptionsSheet], and the same shape: the three dots
/// open this, this opens the reason picker. It exists because a photo is the
/// app's primary piece of user content and had no way to be flagged — the
/// three-dot slot on the viewer's bar was drawn and wired to nothing, every
/// other route to Report was on an event or an ad, and the server has accepted
/// `assetType: "picture"` the whole time.
///
/// Report alone. Everything else a photo offers — like, comment, share, send,
/// download — is already on the rail down its right edge and the bar across
/// its bottom, and duplicating a control into a menu is how two of them start
/// disagreeing.
class PhotoMoreOptionsSheet extends StatelessWidget {
  const PhotoMoreOptionsSheet({
    super.key,
    required this.ext,
    required this.pictureId,
  });

  final AppThemeExtension ext;

  /// The picture's backend id — what the report is filed against.
  final String pictureId;

  static void show(
    BuildContext context, {
    required AppThemeExtension ext,
    required String pictureId,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => PhotoMoreOptionsSheet(ext: ext, pictureId: pictureId),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.flag_outlined,
                      color: Colors.redAccent, size: 20.sp),
                ),
                title: Text(
                  'Report photo',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w500,
                    fontSize: 15.sp,
                  ),
                ),
                subtitle: Text(
                  'Inappropriate, harmful or infringing content',
                  style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
                ),
                trailing: AppSvgIcon(AppIcons.chevronRight,
                    color: ext.searchHintColor, size: 20.sp),
                onTap: () {
                  Navigator.of(context).pop();
                  ReportSheet.show(
                    context,
                    ext: ext,
                    assetType: 'picture',
                    assetId: pictureId,
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
