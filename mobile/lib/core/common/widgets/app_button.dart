import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

/// App-wide button — one shape/radius/loading-state recipe, four variants.
///
///   • [primary]     — teal fill, white text. The default CTA everywhere.
///   • [secondary]   — subtle fill + hairline border. Toggled/"already done" states.
///   • [destructive] — red fill, white text. Logout / delete / report actions.
///   • [text]        — no fill, just a label. Cancel / dismiss / link actions.
///
/// Change the shape, radius, or loading spinner here and every button in the
/// app picks it up.
enum AppButtonVariant { primary, secondary, destructive, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
    this.width,
    this.height,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final effectiveWidth = width ?? (fullWidth ? double.infinity : null);

    final Color background;
    final Color foreground;
    final BorderSide side;
    switch (variant) {
      case AppButtonVariant.primary:
        background = ext.accentGold;
        foreground = Colors.white;
        side = BorderSide.none;
        break;
      case AppButtonVariant.secondary:
        background = ext.searchFieldFill;
        foreground = ext.greetingColor;
        side = BorderSide(color: ext.searchHintColor.withValues(alpha: 0.35));
        break;
      case AppButtonVariant.destructive:
        background = const Color(0xFFB00020);
        foreground = Colors.white;
        side = BorderSide.none;
        break;
      case AppButtonVariant.text:
        background = Colors.transparent;
        foreground = ext.accentGold;
        side = BorderSide.none;
        break;
    }

    if (variant == AppButtonVariant.text) {
      return SizedBox(
        width: effectiveWidth,
        height: height,
        child: TextButton(
          onPressed: isLoading ? null : onPressed,
          style: TextButton.styleFrom(foregroundColor: foreground),
          child: _content(foreground),
        ),
      );
    }

    return SizedBox(
      width: effectiveWidth,
      height: height ?? 50.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.5),
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 14.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
            side: side,
          ),
        ),
        child: _content(foreground),
      ),
    );
  }

  Widget _content(Color foreground) {
    if (isLoading) {
      return SizedBox(
        width: 18.w,
        height: 18.w,
        child: CircularProgressIndicator(strokeWidth: 2, color: foreground),
      );
    }
    if (icon == null) {
      return Text(
        label,
        style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16.sp),
        SizedBox(width: 6.w),
        Text(label,
            style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
