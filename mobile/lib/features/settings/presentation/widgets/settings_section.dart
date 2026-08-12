import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The two pieces every settings screen is built from: a small grey heading,
/// and a rounded card holding rows divided by hairlines.
///
/// Written against the theme's tokens rather than the mock's light palette.
/// The Dark Mode switch lives on one of these screens, so hardcoding the
/// design's colours would break the setting sitting inside it.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.title,
    this.trailing,
    required this.children,
  });

  /// The grey caps heading. Null for a card with no heading of its own — the
  /// Delete Account row at the foot of Account & Security, for one.
  final String? title;

  /// Sits on the heading's own line, at the right. The Notifications screen
  /// puts its master switch there rather than in a row of its own — it governs
  /// the whole section, and drawing it as a row would make it look like one
  /// more thing in the list it actually controls.
  final Widget? trailing;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(
          height: 1,
          thickness: 0.5,
          indent: AppSpacing.lg.w,
          color: ext.searchHintColor.withValues(alpha: 0.15),
        ));
      }
      rows.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.xs.w, 0, AppSpacing.xs.w, AppSpacing.sm.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title!.toUpperCase(),
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ],
        if (children.isNotEmpty)
          DecoratedBox(
            decoration: BoxDecoration(
              color: ext.cardSurface,
              borderRadius: BorderRadius.circular(AppRadius.lg.r),
              border: Border.all(
                color: ext.searchHintColor.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
            child: Column(children: rows),
          ),
        SizedBox(height: AppSpacing.xl.h),
      ],
    );
  }
}

/// One row: a label, an optional second line, and one of three things on the
/// right — a chevron that opens a screen, a switch, or nothing.
///
/// The three are mutually exclusive on purpose. A row that both navigates and
/// toggles has two meanings for one tap, and the design never draws one.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.subtitle,
    this.icon,
    this.onTap,
    this.value,
    this.onChanged,
    this.isBusy = false,
    this.destructive = false,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;

  /// Makes this a row that opens something. Draws the chevron.
  final VoidCallback? onTap;

  /// Makes this a row that toggles. Draws the switch.
  final bool? value;
  final ValueChanged<bool>? onChanged;

  /// The switch is waiting on the server. It holds its position rather than
  /// flicking back and forth, and stops taking taps.
  final bool isBusy;

  /// Log Out and Delete Account: red label, red icon.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    // The same red AppButton's destructive variant uses; there is no token for
    // it on the theme extension, and inventing a second red for the same
    // meaning is how two reds end up in one app.
    final colour = destructive ? const Color(0xFFB00020) : ext.greetingColor;
    final toggles = value != null;

    return Semantics(
      button: onTap != null,
      toggled: value,
      child: InkWell(
        onTap: onTap ??
            (toggles && !isBusy && onChanged != null
                ? () => onChanged!(!value!)
                : null),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w, vertical: AppSpacing.md.h),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20.sp, color: colour),
                SizedBox(width: AppSpacing.md.w),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: colour,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 12.sp,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (toggles)
                Switch.adaptive(
                  value: value!,
                  onChanged: isBusy ? null : onChanged,
                )
              else if (onTap != null)
                Icon(Icons.chevron_right_rounded,
                    size: 22.sp, color: ext.searchHintColor),
            ],
          ),
        ),
      ),
    );
  }
}
