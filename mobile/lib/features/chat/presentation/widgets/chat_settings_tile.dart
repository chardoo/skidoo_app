import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_section_label.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// One row inside a CHAT SETTINGS card — a label, and either a chevron, a
/// switch, or nothing.
///
/// Shared by the contact and group info screens so the two stay identical
/// where they overlap, which is most of them.
class ChatSettingsTile extends StatelessWidget {
  const ChatSettingsTile({
    super.key,
    required this.label,
    this.trailing,
    this.onTap,
    this.labelColor,
  });

  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  /// Overrides the label colour — used for the destructive rows (Block, Leave).
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return InkWell(
      onTap: onTap,
      child: Padding(
        // Vertical padding is tighter when a switch is present: the switch is
        // taller than the text, and the row would otherwise tower over its
        // neighbours.
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: trailing is Switch ? AppSpacing.xs.h : 14.h,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: labelColor ?? ext.greetingColor,
                  fontSize: 15.sp,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// A settings heading, optionally with a control on the right.
///
/// Wraps [AppSectionLabel] rather than restyling one, so these headings stay
/// identical to every other section heading in the app; this only adds the
/// trailing-action row the settings screens need.
class ChatSettingsLabel extends StatelessWidget {
  const ChatSettingsLabel({super.key, required this.label, this.action});

  final String label;

  /// Optional trailing control, e.g. "Add Member" beside GROUP MEMBERS.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      child: Row(
        children: [
          Expanded(child: AppSectionLabel(label)),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Rounded container the settings rows sit in, matching the designs' grouped
/// card. Owns the dividers so the rows themselves stay dumb.
class ChatSettingsCard extends StatelessWidget {
  const ChatSettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.md.r),
        border: Border.all(color: ext.searchHintColor.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: AppSpacing.md.w,
                endIndent: AppSpacing.md.w,
                color: ext.searchHintColor.withValues(alpha: 0.2),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}
