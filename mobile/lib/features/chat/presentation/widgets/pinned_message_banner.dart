import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

/// The strip under the app bar naming the room's pinned message.
///
/// One line, always — a pin is a pointer, not a copy. Tapping the strip jumps
/// to the message in the conversation; the crossed-out pin on the left removes
/// it, which is where the designs put that control.
class PinnedMessageBanner extends StatelessWidget {
  const PinnedMessageBanner({
    super.key,
    required this.pinned,
    this.onTap,
    this.onUnpin,
  });

  final PinnedMessage pinned;

  /// Scroll the conversation to the pinned message. Null when it isn't loaded
  /// and cannot be reached, which leaves the banner as a reminder only.
  final VoidCallback? onTap;

  /// Null in a room where the reader may not change the pin (admin-only rooms
  /// they don't administer) — the banner then has no control at all rather
  /// than one that always fails.
  final VoidCallback? onUnpin;

  /// The struck-through pin. Named so tests can reach the control without
  /// depending on which icon happens to draw it.
  static const Key unpinKey = Key('pinned-message-unpin');

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Material(
      color: ext.accentGold.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg.w, AppSpacing.sm.h, AppSpacing.sm.w, AppSpacing.sm.h),
          decoration: BoxDecoration(
            border: Border(
              bottom:
                  BorderSide(color: ext.searchHintColor.withValues(alpha: 0.12)),
            ),
          ),
          child: Row(
            children: [
              if (onUnpin != null)
                Semantics(
                  button: true,
                  label: 'Unpin message',
                  child: InkResponse(
                    key: unpinKey,
                    onTap: onUnpin,
                    radius: 22.r,
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.xs.w),
                      child: _UnpinIcon(color: ext.accentGold, size: 18.sp),
                    ),
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.all(AppSpacing.xs.w),
                  child:
                      Icon(Icons.push_pin_outlined, size: 18.sp, color: ext.accentGold),
                ),
              SizedBox(width: AppSpacing.sm.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'PINNED MESSAGE',
                      style: TextStyle(
                        color: ext.accentGold,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      pinned.preview,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 13.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pin with a line struck through it — "tap to unpin".
///
/// Drawn rather than picked from the icon set: Material ships `push_pin` and
/// `push_pin_outlined` but no struck-through variant, and the plain pin as a
/// button reads as decoration rather than a control.
class _UnpinIcon extends StatelessWidget {
  const _UnpinIcon({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.push_pin_outlined, size: size, color: color),
          Transform.rotate(
            angle: -0.7854, // 45°, corner to corner
            child: Container(
              width: size * 1.15,
              height: 1.6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
