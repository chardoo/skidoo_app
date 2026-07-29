import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// Selectable pill used by every group in the Found filter sheet (date,
/// visibility, photographer). Selected = accent fill with white label.
class FoundFilterChip extends StatelessWidget {
  const FoundFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;

  /// Photos this chip would match, from the server's facet counts. Null hides
  /// the number — either the endpoint sent none for this chip (the "Custom
  /// range" chip has no server-side facet) or the count in hand belongs to a
  /// selection the user has already moved on from.
  ///
  /// Rendered as its own [Text] rather than folded into [label] so the number
  /// can carry its own colour and so callers can still find a chip by name.
  final int? count;

  final bool selected;
  final VoidCallback onTap;

  /// A chip matching nothing is dead weight — unless it's the one currently
  /// applied, which is exactly how the user got to zero and the only way back
  /// out. Disabled rather than hidden so the group doesn't reflow underneath
  /// the finger as counts come and go.
  bool get _disabled => count == 0 && !selected;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final foreground = selected
        ? Colors.white
        : ext.greetingColor.withValues(alpha: _disabled ? 0.38 : 1);

    return Semantics(
      button: true,
      selected: selected,
      enabled: !_disabled,
      label: count == null ? label : '$label, $count photos',
      child: GestureDetector(
        onTap: _disabled ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg.w, vertical: AppSpacing.md.h),
          decoration: BoxDecoration(
            color: selected ? ext.accentGold : ext.searchFieldFill,
            borderRadius: BorderRadius.circular(AppRadius.pill.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13.sp,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (count != null) ...[
                SizedBox(width: AppSpacing.sm.w),
                Text(
                  '$count',
                  style: TextStyle(
                    color: foreground.withValues(alpha: selected ? 0.75 : 0.5),
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Uppercase group caption above a row of [FoundFilterChip]s.
class FoundFilterGroupLabel extends StatelessWidget {
  const FoundFilterGroupLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: ext.searchHintColor,
        fontSize: 11.sp,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
  }
}
