import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// One button in a vertical action rail over full-bleed media: a filled white
/// icon with its count underneath, both shadowed so they stay legible on any
/// photo.
///
/// Shared by the home feed's [FullBleedEventCard] and the Found tab's photo
/// viewer so the two rails can't drift — they are the same control in the
/// design, and the icon set (`favorite` / `mode_comment` / `bookmark` /
/// `near_me`) is part of that.
class MediaRailAction extends StatelessWidget {
  const MediaRailAction({
    super.key,
    required this.icon,
    this.iconColor = Colors.white,
    this.label,
    required this.onTap,
    this.busy = false,
    this.semanticLabel,
  });

  final IconData icon;
  final Color iconColor;

  /// Count shown under the icon. Null renders the icon alone — used where
  /// there is genuinely no count rather than showing a hardcoded zero.
  final String? label;

  final VoidCallback onTap;

  /// Shows a small spinner in place of the icon while an async action (e.g.
  /// the external share round trip) is in flight.
  final bool busy;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel ?? label,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            busy
                ? SizedBox(
                    width: 22.sp,
                    height: 22.sp,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: iconColor),
                  )
                : Icon(icon, color: iconColor, size: 28.sp, shadows: const [
                    Shadow(color: Colors.black45, blurRadius: 4),
                  ]),
            if (label != null) ...[
              SizedBox(height: 3.h),
              Text(
                label!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
