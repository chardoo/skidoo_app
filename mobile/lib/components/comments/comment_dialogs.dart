import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Shows a bottom sheet with Edit / Delete options.
/// [onEdit] and [onDelete] receive no arguments — callers close over
/// the specific comment they need.
void showCommentOptionsSheet(
  BuildContext context, {
  required AppThemeExtension ext,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      padding: EdgeInsets.fromLTRB(0, 12.h, 0, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40.w,
            height: 4.h,
            margin: EdgeInsets.only(bottom: 16.h),
            decoration: BoxDecoration(
              color: ext.searchHintColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          ListTile(
            leading:
                Icon(Icons.edit_rounded, color: ext.accentGold, size: 22.sp),
            title: Text('Edit comment',
                style: TextStyle(color: ext.greetingColor, fontSize: 15.sp)),
            onTap: () {
              Navigator.of(context).pop();
              onEdit();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent),
            title: Text('Delete comment',
                style:
                    TextStyle(color: Colors.redAccent, fontSize: 15.sp)),
            onTap: () {
              Navigator.of(context).pop();
              onDelete();
            },
          ),
        ],
      ),
    ),
  );
}

/// Shows an [AlertDialog] pre-filled with [initialContent].
/// Calls [onSave] with the new text when the user confirms.
void showEditCommentDialog(
  BuildContext context, {
  required AppThemeExtension ext,
  required String initialContent,
  required void Function(String newContent) onSave,
}) {
  final ctrl = TextEditingController(text: initialContent);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ext.cardSurface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text('Edit comment',
          style: TextStyle(color: ext.greetingColor, fontSize: 16.sp)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        maxLines: 4,
        minLines: 1,
        style: TextStyle(color: ext.greetingColor, fontSize: 14.sp),
        decoration: InputDecoration(
          filled: true,
          fillColor: ext.searchFieldFill,
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(12.r),
          ),
          contentPadding:
              EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancel',
              style: TextStyle(color: ext.searchHintColor)),
        ),
        TextButton(
          onPressed: () {
            final text = ctrl.text.trim();
            if (text.isNotEmpty) onSave(text);
            Navigator.of(ctx).pop();
          },
          child: Text('Save',
              style: TextStyle(
                  color: ext.accentGold, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Text('Delete comment',
          style: TextStyle(color: ext.greetingColor, fontSize: 16.sp)),
      content: Text(
        'Are you sure you want to delete this comment?',
        style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text('Cancel',
              style: TextStyle(color: ext.searchHintColor)),
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
