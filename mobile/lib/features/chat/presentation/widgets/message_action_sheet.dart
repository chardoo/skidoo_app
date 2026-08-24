import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

/// What long-pressing a message offers.
///
/// Every action the designs show is on one flat list — no icon tiles, no
/// grouping. The order is fixed (Reply, Forward, Copy Text, Pin, Edit, Delete)
/// so the row a regular does not read is always in the same place; entries that
/// don't apply are omitted rather than disabled, since a greyed row that never
/// becomes available is just noise.
class MessageActionSheet extends StatelessWidget {
  const MessageActionSheet({
    super.key,
    required this.onReply,
    this.onForward,
    this.onCopy,
    this.onPin,
    this.isPinned = false,
    this.onEdit,
    this.onDelete,
  });

  final VoidCallback onReply;

  /// Null for a message with nothing to forward (an encrypted body the app
  /// could not decrypt).
  final VoidCallback? onForward;

  /// Null when the message has no text — copying "Photo" helps nobody.
  final VoidCallback? onCopy;

  /// Null in rooms where the reader may not change the pin.
  final VoidCallback? onPin;

  /// Whether this message is the one currently pinned, which turns the row into
  /// "Unpin".
  final bool isPinned;

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(top: AppSpacing.sm.h, bottom: 28.h),
      decoration: BoxDecoration(
        color: ext.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36.w,
            height: 4.h,
            margin: EdgeInsets.only(bottom: AppSpacing.md.h),
            decoration: BoxDecoration(
              color: ext.searchHintColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          _ActionRow(
            icon: Icons.reply_rounded,
            label: 'Reply',
            onTap: onReply,
          ),
          if (onForward != null)
            _ActionRow(
              icon: Icons.shortcut_rounded,
              label: 'Forward',
              onTap: onForward!,
            ),
          if (onCopy != null)
            _ActionRow(
              icon: Icons.copy_rounded,
              label: 'Copy Text',
              onTap: onCopy!,
            ),
          if (onPin != null)
            _ActionRow(
              icon: isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              label: isPinned ? 'Unpin' : 'Pin',
              onTap: onPin!,
            ),
          if (onEdit != null)
            _ActionRow(
              icon: Icons.edit_outlined,
              label: 'Edit',
              onTap: onEdit!,
            ),
          if (onDelete != null)
            _ActionRow(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              onTap: onDelete!,
              // The one row that cannot be undone, and the only one coloured.
              color: ext.errorRed,
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Overrides both the icon and the label — they always agree, which is what
  /// makes a destructive row read as one thing rather than a red icon next to
  /// ordinary text.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final tint = color ?? ext.greetingColor;

    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: 22.w, vertical: AppSpacing.md.h),
          child: Row(
            children: [
              Icon(icon, size: 21.sp, color: tint),
              SizedBox(width: 20.w),
              Text(
                label,
                style: TextStyle(
                  color: tint,
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
