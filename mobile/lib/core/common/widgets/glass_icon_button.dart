import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/glass_surface.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The circular "glass" icon button used in app bars/headers across the app
/// (back, more, notifications, etc.). One fill/border/icon-color recipe —
/// change it here and every glass icon button in the app updates.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 40,
    this.iconSize,
    this.tooltip,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double? iconSize;
  final String? tooltip;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Semantics(
      button: true,
      label: semanticLabel ?? tooltip,
      // Real frost on iOS, a tonal circle elsewhere — see [GlassSurface].
      // This used to be a flat tint that only *called* itself glass: over a
      // busy photo it was a grey disc, because there was nothing behind it
      // being blurred.
      child: SizedBox(
        width: size.w,
        height: size.w,
        child: GlassSurface(
          borderRadius: BorderRadius.circular(size.w / 2),
          blurSigma: 18,
          child: IconButton(
            padding: EdgeInsets.zero,
            tooltip: tooltip,
            icon: Icon(icon, color: ext.glassIcon, size: (iconSize ?? 20).sp),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }
}
