import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Follow and Message, on either kind of profile.
///
/// One widget because there are two profile screens — [PublicProfilePage] for
/// a viewer and [CreatorProfilePage] for a creator — and they had a private
/// copy of this each. The copies had already drifted: only one of them could
/// be drawn disabled, which is the state this pair most needs.
class ProfilePillButton extends StatelessWidget {
  const ProfilePillButton({
    super.key,
    required this.ext,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.enabled = true,
  });

  final AppThemeExtension ext;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Filled marks the state you are already in — following. The action you
  /// have not taken is an outline, the same rule the reaction rail follows.
  final bool filled;

  /// False draws it dimmed and ignores taps, rather than removing it.
  ///
  /// A Message button that is simply absent for somebody who has messages
  /// switched off leaves the reader wondering whether the app is still
  /// deciding — which is exactly what it looked like while the check was in
  /// flight. Present-and-dimmed says the thing is real and the answer is no.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    // One alpha for every disabled part, so the glyph, the label and the
    // border fade together instead of the text going first.
    final content = enabled ? 1.0 : 0.4;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: content,
          child: Container(
            height: 44.h,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: filled
                  ? ext.searchHintColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              border: Border.all(
                color: ext.searchHintColor.withValues(alpha: 0.35),
                width: 0.9,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17.sp, color: ext.greetingColor),
                SizedBox(width: AppSpacing.sm.w),
                Text(
                  label,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
