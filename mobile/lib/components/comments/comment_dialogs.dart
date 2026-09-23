import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import 'package:jperg_app/core/theme/app_typography.dart';

/// Shows a bottom sheet with Edit / Delete options.
/// [onEdit] and [onDelete] receive no arguments — callers close over
/// the specific comment they need.
void showCommentOptionsSheet(
  BuildContext context, {
  required AppThemeExtension ext,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  bool canEdit = true,
  bool canDelete = true,
}) {
  // Nothing on offer, nothing to open. A sheet with an empty list reads as a
  // broken screen rather than as "you may not do this".
  if (!canEdit && !canDelete) return;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.fromLTRB(0, 12.h, 0, 32.h),
      // ListTile ink paints on the nearest Material ancestor; this decorated
      // Container sits between the sheet's Material and the tiles and would
      // swallow it (and assert in debug). A transparency Material paints
      // nothing and just gives the ink somewhere to land.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: AppSpacing.lg.h),
              decoration: BoxDecoration(
                color: ext.searchHintColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            // Edit is the author's alone; delete is also the creator's. The
            // two are listed separately because they are separately granted —
            // a photographer moderating their album sees only Delete.
            if (canEdit)
              ListTile(
                leading: AppSvgIcon(AppIcons.edit,
                    color: ext.accentGold, size: 22.sp),
                title: Text('Edit comment',
                    style: TextStyle(color: ext.greetingColor, fontSize: 15.sp)),
                onTap: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
              ),
            if (canDelete)
              ListTile(
                leading: const AppSvgIcon(AppIcons.trash,
                    color: Colors.redAccent),
                title: Text('Delete comment',
                    style: TextStyle(color: Colors.redAccent, fontSize: 15.sp)),
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
              ),
          ],
        ),
      ),
    ),
  );
}

// `showEditCommentDialog` lived here. Editing a comment now loads it into the
// composer the way the chat room does — the thread stays on screen while the
// comment is rewritten, instead of a dialog covering the conversation the
// comment belongs to. See [CommentInputBarWidget.editingContent].

/// Shows a delete confirmation dialog.
void showDeleteCommentDialog(
  BuildContext context, {
  required AppThemeExtension ext,
  required VoidCallback onConfirm,
}) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ext.cardSurface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg.r)),
      title: Text('Delete comment',
          style: TextStyle(
              fontFamily: AppTypography.displayFontFamily,
              color: ext.greetingColor,
              fontSize: 16.sp)),
      content: Text(
        'Are you sure you want to delete this comment?',
        style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancel', style: TextStyle(color: ext.searchHintColor)),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            onConfirm();
          },
          child: const Text('Delete',
              style: TextStyle(
                  color: Colors.redAccent, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}
