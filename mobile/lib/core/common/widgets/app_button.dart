import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

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
    this.borderRadius,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;
  final double? width;
  final double? height;

  /// Corner radius override. Defaults to the app's standard 14; pass
  /// [AppRadius.pill] for the fully-rounded pill the Found filter sheet uses.
  final double? borderRadius;

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
          // A caller-supplied height is a budget, not a suggestion. 14.h above
          // and below the label needs ~48 before the text is even drawn, so a
          // compact button (the 40 the group-name Save and the confirm dialog
          // ask for) clipped its own label in half. With an explicit height the
          // SizedBox sets the size and the button centres the label inside it.
          //
          // Horizontal is the other way round: a button with no width of its
          // own is exactly as wide as its label, so with no padding the text
          // ran to the very edge — and under a pill radius the corner curve
          // cut straight through the first and last glyph. A button that was
          // given a width has already had its room measured, so it keeps the
          // tight fit it was sized for.
          padding: EdgeInsets.symmetric(
            horizontal: effectiveWidth == null ? 20.w : 0,
            vertical: height != null ? 0 : 14.h,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular((borderRadius ?? 14).r),
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
    final text = Text(
      label,
      maxLines: 1,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
    );

    // Shrinks the label rather than letting it spill. The height is fixed and
    // the width is often somebody else's (a full-width CTA, a 84.w Save), so a
    // long label or a large system text size has nowhere to grow — and a
    // button is the one place where a clipped word costs you the tap. Scales
    // down only when it has to; at ordinary sizes nothing moves.
    if (icon == null) {
      return FittedBox(fit: BoxFit.scaleDown, child: text);
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp),
          SizedBox(width: 6.w),
          text,
        ],
      ),
    );
  }
}
