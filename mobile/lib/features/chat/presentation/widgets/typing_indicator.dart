import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The three-dot bubble shown while someone else is typing.
///
/// Sits where their next message will appear, on the received side, so the
/// arriving message replaces it in place rather than shifting the thread.
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, this.label});

  /// Who is typing. Shown above the dots in groups, where "someone is typing"
  /// is not enough to know who to expect; null in DMs, where it is obvious.
  final String? label;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null && widget.label!.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 4.w, bottom: 3.h),
              child: Text(
                widget.label!,
                style: TextStyle(
                  color: ext.accentGold,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: 14.w, vertical: AppSpacing.sm.h),
            decoration: BoxDecoration(
              color: ext.cardSurface,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18.r),
                topRight: Radius.circular(18.r),
                bottomLeft: Radius.circular(4.r),
                bottomRight: Radius.circular(18.r),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < 3; i++) ...[
                    if (i > 0) SizedBox(width: 4.w),
                    _Dot(
                      // Each dot leads the one before it by a third of the
                      // cycle, which is what makes the row read as a travelling
                      // wave rather than three things blinking together.
                      opacity: _opacityFor(i),
                      color: ext.accentGold,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _opacityFor(int index) {
    final phase = (_controller.value + index / 3) % 1.0;
    // Triangle wave: up for the first half of the phase, back down after.
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return 0.3 + wave * 0.7;
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.opacity, required this.color});

  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 7.w,
        height: 7.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: opacity),
        ),
      );
}
