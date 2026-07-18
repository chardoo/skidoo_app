import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

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
      child: Container(
        width: size.w,
        height: size.w,
        decoration: BoxDecoration(
          color: ext.glassFill,
          shape: BoxShape.circle,
          border: Border.all(color: ext.glassBorder, width: 1.5),
        ),
        child: IconButton(
          padding: EdgeInsets.zero,
          tooltip: tooltip,
          icon: Icon(icon, color: ext.glassIcon, size: (iconSize ?? 20).sp),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
